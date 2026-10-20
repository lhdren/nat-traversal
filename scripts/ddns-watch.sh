#!/usr/bin/env bash
# ddns-watch.sh — VPS 侧 DDNS 心跳脚本（nat-traversal 方案 A）
#
# 原理：家里 R479 与本 VPS 保持 IPsec 常开隧道（R479 主动发起、断线自动重拨）。
#       本脚本周期性检测隧道对端（家里）的公网源 IP：
#         1) 优先读内核 xfrm state（strongSwan 协商出的 SA，最权威）
#         2) 回退读 conntrack 里 UDP 500/4500（IKE/NAT-T）会话源地址
#       检测到 IP 变化 → 调阿里云 DNS API 更新 SUBDOMAIN 的 A 记录。
#
# 运行位置：阿里云 VPS（systemd 服务 ddns-watch.service 托管）
# 依赖：bash curl openssl python3 ip(iproute2)；conntrack 可选（回退检测用）
# 配置：/etc/nat-traversal/ddns.conf（可用 CONFFILE 环境变量覆盖路径）
# 用法：ddns-watch.sh [--once]     --once=单次检测后退出（调试用）
#       DRY_RUN=1 时只打印计划动作，不调用写接口（Describe 只读调用照常）

set -uo pipefail
export LC_ALL=C

CONFFILE="${CONFFILE:-/etc/nat-traversal/ddns.conf}"
STATE_DIR="${STATE_DIR:-/var/lib/nat-traversal}"
STATE_FILE="$STATE_DIR/last_ip"
DRY_RUN="${DRY_RUN:-0}"
ONCE=0
[[ "${1:-}" == "--once" ]] && ONCE=1

log() { printf '[ddns-watch] %s %s\n' "$(date '+%F %T')" "$*"; }
die() { log "FATAL: $*"; exit 1; }

# ---------- 配置加载与校验 ----------
[[ -r "$CONFFILE" ]] || die "配置文件不可读: $CONFFILE（可 CONFFILE=/path 覆盖）"
# shellcheck disable=SC1090
source "$CONFFILE"

ACCESS_KEY_ID="${ACCESS_KEY_ID:?配置缺失: ACCESS_KEY_ID}"
ACCESS_KEY_SECRET="${ACCESS_KEY_SECRET:?配置缺失: ACCESS_KEY_SECRET}"
SUBDOMAIN="${SUBDOMAIN:?配置缺失: SUBDOMAIN（完整主机名，如 home.example.cn）}"
ENDPOINT="${ENDPOINT:-https://alidns.aliyuncs.com}"
TTL="${TTL:-600}"
CHECK_INTERVAL="${CHECK_INTERVAL:-30}"
VERIFY_EVERY="${VERIFY_EVERY:-20}"   # 即使 IP 未变，每 N 轮向 API 核对一次解析

for bin in curl openssl python3 ip; do
  command -v "$bin" >/dev/null 2>&1 || die "缺少依赖: $bin"
done

RR="${SUBDOMAIN%%.*}"
DOMAIN_NAME="${SUBDOMAIN#*.}"
mkdir -p "$STATE_DIR"

# ---------- 阿里云 DNS API（RPC 风格, HMAC-SHA1 签名） ----------
# 注：参数值均为 ASCII（域名/IP/时间戳），按字节逐字符编码即可
rawurlencode() {
  local s="$1" out="" c i hex
  for ((i = 0; i < ${#s}; i++)); do
    c="${s:i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) out+="$c" ;;
      *)
        printf -v hex '%%%02X' "'$c"
        out+="$hex"
        ;;
    esac
  done
  printf '%s' "$out"
}

# 参数：ACTION k1=v1 k2=v2 ...  → stdout 输出 API JSON 应答
aliyun_api() {
  local action="$1"; shift
  local ts nonce sig_secret params=() sorted=() canonical="" sts signature k v
  local query_args=()
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  nonce="$(date +%s%N)-$$-${RANDOM}"
  sig_secret="${ACCESS_KEY_SECRET}&"

  params=(
    "AccessKeyId=${ACCESS_KEY_ID}"
    "Action=${action}"
    "Format=JSON"
    "SignatureMethod=HMAC-SHA1"
    "SignatureNonce=${nonce}"
    "SignatureVersion=1.0"
    "Timestamp=${ts}"
    "Version=2015-01-09"
    "$@"
  )
  # 参数名排序 → 规范化查询串（键值各编码一次）
  mapfile -t sorted < <(printf '%s\n' "${params[@]}" | LC_ALL=C sort)
  for p in "${sorted[@]}"; do
    k="${p%%=*}"; v="${p#*=}"
    canonical+="$(rawurlencode "$k")=$(rawurlencode "$v")&"
  done
  canonical="${canonical%&}"
  # StringToSign = GET&%2F&<canonical 再整体编码一次>
  sts="GET&%2F&$(rawurlencode "$canonical")"
  signature="$(printf '%s' "$sts" | openssl dgst -sha1 -hmac "$sig_secret" -binary | base64 | tr -d '\n')"

  query_args=(-sS -G "$ENDPOINT")
  for p in "${sorted[@]}"; do
    query_args+=(--data-urlencode "$p")
  done
  query_args+=(--data-urlencode "Signature=${signature}")
  curl "${query_args[@]}"
}

# 从 JSON 提取字段：json_get <json> <python表达式(变量名d)>
# 例：json_get "$resp" "d['DomainRecords']['Record'][0]['RecordId'] if d.get('DomainRecords',{}).get('Record') else ''"
json_get() {
  printf '%s' "$1" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print(''); sys.exit(0)
try:
    print(eval(sys.argv[1]))
except Exception:
    print('')
" "$2"
}

# ---------- 家宽公网 IP 检测 ----------
is_public_ip() {
  local ip="$1"
  [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || return 1
  case "$ip" in
    0.*|10.*|127.*|169.254.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*|\
    100.6[4-9].*|100.[7-9][0-9].*|100.1[01][0-9].*|100.12[0-7].*|\
    224.*|239.*|24[0-9].*|25[0-5].*|255.255.255.255)
      return 1 ;;
  esac
  return 0
}

detect_home_ip() {
  local candidates=() own_ips=() ip best="" best_cnt=0
  # 本机地址集合（排除 VPS 自己）
  mapfile -t own_ips < <(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
  own_ips+=("$(ip -4 route get 1 2>/dev/null | awk '{for(i=1;i<=NF;i++)if($i=="src"){print $(i+1);exit}}')")

  # 来源1：内核 xfrm state（strongSwan SA 的对端 src）
  mapfile -t candidates < <(ip -4 xfrm state 2>/dev/null | awk '/^src[ \t]/{print $2}')
  # 来源2：conntrack 的 IKE/NAT-T 会话源（conntrack 不存在则跳过）
  if command -v conntrack >/dev/null 2>&1; then
    mapfile -t candidates < <(
      { conntrack -L -p udp --dport 500 2>/dev/null; conntrack -L -p udp --dport 4500 2>/dev/null; } \
        | awk '/src=/{s=substr($1,5); print s}'
      printf '%s\n' "${candidates[@]:-}"
    )
  fi

  # 计票：出现次数最多、非本机、且为公网地址者胜出
  local -A tally=()
  for ip in "${candidates[@]:-}"; do
    [[ -n "$ip" ]] || continue
    is_public_ip "$ip" || continue
    local own=0 o
    for o in "${own_ips[@]:-}"; do [[ "$ip" == "$o" ]] && { own=1; break; }; done
    [[ $own -eq 1 ]] && continue
    tally["$ip"]=$(( ${tally["$ip"]:-0} + 1 ))
  done
  for ip in "${!tally[@]}"; do
    if (( ${tally["$ip"]} > best_cnt )); then best="$ip"; best_cnt=${tally["$ip"]}; fi
  done
  printf '%s' "$best"
}

# ---------- 主逻辑 ----------
cycle() {
  local detected last_ip resp record_id record_value
  detected="$(detect_home_ip)"

  if [[ -z "$detected" ]]; then
    log "WARN: 未检测到隧道源 IP（隧道未建立或依赖缺失）——保持解析不动，等待隧道重连"
    return 0
  fi
  last_ip="$(cat "$STATE_FILE" 2>/dev/null || true)"
  log "检测到家里公网 IP: $detected（上次记录: ${last_ip:-无}）"

  if [[ "$detected" == "$last_ip" && $VERIFY_EVERY -gt 0 && $(cat "$STATE_DIR/verify_count" 2>/dev/null || echo 0) -lt $VERIFY_EVERY ]]; then
    echo $(( $(cat "$STATE_DIR/verify_count" 2>/dev/null || echo 0) + 1 )) > "$STATE_DIR/verify_count"
    return 0
  fi
  echo 0 > "$STATE_DIR/verify_count"

  # 查询当前 A 记录
  resp="$(aliyun_api DescribeSubDomainRecords "SubDomain=${SUBDOMAIN}" "Type=A")"
  record_id="$(json_get "$resp" "d['DomainRecords']['Record'][0]['RecordId'] if d.get('DomainRecords',{}).get('Record') else ''")"
  record_value="$(json_get "$resp" "d['DomainRecords']['Record'][0]['Value'] if d.get('DomainRecords',{}).get('Record') else ''")"
  if [[ -z "$resp" ]]; then
    log "WARN: DescribeSubDomainRecords 无应答（网络/密钥问题），本轮跳过"; return 0
  fi
  if [[ "$record_value" == "$detected" ]]; then
    log "阿里云解析已是 $detected，无需更新"
    printf '%s' "$detected" > "$STATE_FILE"
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log "DRY_RUN: 将更新 ${SUBDOMAIN} A ${last_ip:-?} -> ${detected}（RecordId=${record_id:-新建}）"
    return 0
  fi

  if [[ -n "$record_id" ]]; then
    resp="$(aliyun_api UpdateDomainRecord "RecordId=${record_id}" "RR=${RR}" "Type=A" "Value=${detected}" "TTL=${TTL}")"
  else
    resp="$(aliyun_api AddDomainRecord "DomainName=${DOMAIN_NAME}" "RR=${RR}" "Type=A" "Value=${detected}" "TTL=${TTL}")"
  fi
  local code
  code="$(json_get "$resp" "d.get('Code','')")"
  if [[ -n "$code" ]]; then
    log "ERROR: API 返回错误 Code=$code Msg=$(json_get "$resp" "d.get('Message','')")"; return 0
  fi
  printf '%s' "$detected" > "$STATE_FILE"
  log "OK: ${SUBDOMAIN} A 记录已更新为 ${detected}（原值 ${record_value:-无记录，新建}）"
}

trap 'log "退出"; exit 0' INT TERM
log "启动：SUBDOMAIN=${SUBDOMAIN} TTL=${TTL} 间隔=${CHECK_INTERVAL}s DRY_RUN=${DRY_RUN} ONCE=${ONCE}"
while true; do
  cycle
  [[ $ONCE -eq 1 ]] && break
  sleep "$CHECK_INTERVAL"
done
