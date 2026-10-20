#!/usr/bin/env bash
# install.sh — nat-traversal VPS 侧一键安装
# 作用：把 ddns-watch 脚本/配置/systemd 单元放到系统位置，并注册服务（不自动启动）
# 用法：sudo bash install.sh [--force]     --force 覆盖已存在的配置文件
set -uo pipefail

FORCE=0; [[ "${1:-}" == "--force" ]] && FORCE=1
[[ $EUID -eq 0 ]] || { echo "请用 root/sudo 运行"; exit 1; }

SRC="$(cd "$(dirname "$0")" && pwd)"
ok() { printf '  [OK] %s\n' "$*"; }
warn() { printf '  [!!] %s\n' "$*"; }

# 1) ddns-watch.sh
install -m 0755 "$SRC/ddns-watch.sh" /usr/local/bin/ddns-watch.sh
ok "ddns-watch.sh -> /usr/local/bin/"

# 2) 配置（不覆盖已有）
mkdir -p /etc/nat-traversal
if [[ -f /etc/nat-traversal/ddns.conf && $FORCE -eq 0 ]]; then
  warn "/etc/nat-traversal/ddns.conf 已存在，未覆盖"
else
  install -m 0600 "$SRC/ddns.conf.example" /etc/nat-traversal/ddns.conf
  ok "ddns.conf.example -> /etc/nat-traversal/ddns.conf（记得填 AccessKey 与 SUBDOMAIN）"
fi

# 3) systemd 服务
install -m 0644 "$SRC/ddns-watch.service" /etc/systemd/system/ddns-watch.service
systemctl daemon-reload
systemctl enable ddns-watch >/dev/null 2>&1 && ok "systemd 服务 ddns-watch 已注册并设为开机自启（未启动）"

# 4) strongSwan 模板：仅在系统尚无 ipsec.conf 时自动放置，否则放模板供人工合并
mkdir -p /etc/ipsec.d/nat-traversal
if [[ ! -f /etc/ipsec.secrets ]]; then
  install -m 0600 "$SRC/ipsec.secrets.example" /etc/ipsec.secrets
  ok "ipsec.secrets.example -> /etc/ipsec.secrets（务必改强随机 PSK）"
else
  install -m 0600 "$SRC/ipsec.secrets.example" /etc/ipsec.d/nat-traversal/ipsec.secrets.example
  warn "已存在 /etc/ipsec.secrets，模板放在 /etc/ipsec.d/nat-traversal/ 请人工合并"
fi
if [[ ! -f /etc/ipsec.conf || ! -s /etc/ipsec.conf ]]; then
  install -m 0644 "$SRC/ipsec.conf.example" /etc/ipsec.conf
  ok "ipsec.conf.example -> /etc/ipsec.conf（按 TODO 注释修改）"
else
  install -m 0644 "$SRC/ipsec.conf.example" /etc/ipsec.d/nat-traversal/ipsec.conf.example
  warn "已存在 /etc/ipsec.conf，模板放在 /etc/ipsec.d/nat-traversal/ 请人工合并"
fi

echo
echo "下一步："
echo "  1) vim /etc/nat-traversal/ddns.conf        # 填 AccessKey / SUBDOMAIN"
echo "  2) vim /etc/ipsec.conf                     # 按 TODO 改网段/提案"
echo "  3) vim /etc/ipsec.secrets                  # 强随机 PSK（与 R479 一致）"
echo "  4) DRY_RUN=1 /usr/local/bin/ddns-watch.sh --once   # 干跑验证"
echo "  5) systemctl start strongswan ddns-watch   # 上线"
