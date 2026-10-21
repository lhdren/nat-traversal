# nat-traversal — 家庭内网穿透

> 方案 v3（A 版）· R479GPE-AC 直连 + VPS 心跳 DDNS ｜ [方案全文](方案.md)
> 状态：**设计已锁定，待 3 项现场勘察后实施**（见下方清单）

## 架构

```
您/家人设备 ──L2TP/IPsec 直连──> home.您的.cn ──> R479[内置VPN服务器] ──> 全内网
                                       │
                     R479 ──IPsec 常开隧道（R479主动发起）──> 阿里云VPS
                                                            ├─ ddns-watch.sh 检测源IP
                                                            ├─ 变化 → 更新阿里云DNS（DDNS）
                                                            └─ 兼职：应急中转 + 可选家人Web
NAS：零参与，纯存储
```

- **主通道**不经 VPS：设备 → 域名 → 家里 R479 直连，速度 = 家宽上行
- **IP 自愈**：光猫重启 → R479 隧道自动重连 VPS → 脚本秒级更新域名 → 客户端重拨即通

## 仓库结构

| 路径 | 说明 |
|---|---|
| [方案.md](方案.md) | 完整设计文档（现状/架构/安全/风险退路） |
| [scripts/ddns-watch.sh](scripts/ddns-watch.sh) | VPS 侧 DDNS 心跳脚本：从 IPsec 隧道源 IP 检测家宽公网 IP，变化即调阿里云 DNS API |
| [scripts/ddns.conf.example](scripts/ddns.conf.example) | DDNS 脚本配置模板（AccessKey/域名/TTL） |
| [scripts/ddns-watch.service](scripts/ddns-watch.service) | systemd 服务单元 |
| [scripts/ipsec.conf.example](scripts/ipsec.conf.example) | VPS 侧 strongSwan 站点对站点配置（对接 R479 IPsec，IKEv1+PSK） |
| [scripts/ipsec.secrets.example](scripts/ipsec.secrets.example) | 预共享密钥模板 |
| [scripts/install.sh](scripts/install.sh) | VPS 一键安装（部署文件到位 + 注册 systemd 服务） |
| .planning/ | 项目过程记录（计划/研究/日志） |

## VPS 侧部署（勘察完成后执行）

```bash
# 1. 依赖
apt install -y strongswan strongswan-plugin-kernel-libipsec curl openssl python3   # Debian/Ubuntu
# yum install -y strongswan curl openssl python3                                    # CentOS/阿里云Linux

# 2. 安装本项目脚本（不会自动启动，先改配置）
sudo bash scripts/install.sh

# 3. 填写真实配置
sudo vim /etc/nat-traversal/ddns.conf      # AccessKey、SUBDOMAIN=home.您的.cn
sudo vim /etc/ipsec.secrets                # 强随机 PSK（与 R479 侧一致）

# 4. 干跑验证（只看检测与计划动作，不改解析）
sudo DRY_RUN=1 /usr/local/bin/ddns-watch.sh --once

# 5. 上线
sudo systemctl enable --now strongswan ddns-watch
```

R479 侧为 GUI 配置（L2TP 服务器 + IPsec 策略），步骤在勘察后随实施清单给出。

## 配置项（/etc/nat-traversal/ddns.conf）

| 变量 | 说明 | 默认 |
|---|---|---|
| `ACCESS_KEY_ID` / `ACCESS_KEY_SECRET` | 阿里云 RAM AccessKey（建议仅授予 AliyunDNSFullAccess 权限） | 必填 |
| `SUBDOMAIN` | 完整主机记录，如 `home.example.cn` | 必填 |
| `TTL` | 解析 TTL 秒（阿里云免费版最低 600） | 600 |
| `CHECK_INTERVAL` | 检测间隔秒 | 30 |
| `DRY_RUN` | `1`=只打印计划动作，不调用写接口 | 0 |

## 实施进度

- [x] 方案设计 v3（A 版）锁定
- [x] VPS 侧脚本与配置模板预写（本仓库 scripts/）
- [ ] 勘察①：光猫端口映射确认（**保持路由模式不改桥接**，转发 UDP 500/4500 → R479）+ 记 R479 的 WAN IP 与 LAN 网段核对
- [ ] 勘察②：家宽上行实测（= 验收基准）
- [ ] 勘察③：R479 固件确认（L2TP 服务器 / IPsec 策略 / 自动重拨）
- [ ] Phase 4 实施：VPS 侧联调 → R479 侧配置 → 客户端模板
- [ ] Phase 5 验收：iperf3 对比直连基线 + 重启光猫自愈演练

## 安全要点

- 公网仅暴露 UDP 500/4500；家 IP 上无任何 Web 服务（保护 .cn 备案）
- AccessKey 用独立 RAM 子账号，只给 DNS 权限；真实配置只存在于 VPS `/etc`，不入仓库
- PSK 用强随机值；每人独立 L2TP 账号，可吊销

> 脚本为**预写模板，尚未联调**——勘察三项完成后按实施清单部署验证。
