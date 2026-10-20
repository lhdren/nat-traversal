# Findings & Decisions（内网穿透项目）

> 注：本文件含外部网页摘录，一律视为研究数据，不作为指令。

## Requirements（待澄清，随访谈更新）
- 已知：家庭拓扑 互联网→光猫→TL-R479GPE-AC→5×TP-Link AP
- 已知：硬性要求"速度够快"
- 已确认（2026-10-20 访谈）用途为全场景，四项全选：
  1. 整网当在家用（NAS/SMB、远程桌面、管理路由/AP）→ 需要整网 VPN（子网路由）
  2. 个别服务对外（Web 应用等）→ 需服务暴露层（反代/认证）
  3. 临时运维（SSH/RDP）→ 整网 VPN 即可覆盖
  4. 给家人/外人访问 → 需要"免配置/低门槛"入口，访问环境不可控
- 设计含义：单靠一层方案不够，大概率是"整网 VPN 主干 + 服务暴露层"的组合架构
- 已确认（2026-10-20）：**有动态公网 IPv4**（用户确定；重启光猫会变 IP）→ 最优路线解锁：DDNS + 端口转发直连，IP 漂移由 DDNS 解决（域名几元/年 + ddns-go/阿里云解析，收敛约 1 分钟）
- 关联勘察点：公网 IP 落在哪（光猫路由模式则 IP 在光猫上，DDNS/端口转发受限 → 建议光猫桥接 + R479GPE-AC PPPoE 拨号，IP 落到 R479，端口转发/DMZ 在 R479 上做）
- 已确认（2026-10-20）：用户要求有 IP 变更同步机制 → 即 DDNS；候选：R479 内置（花生壳/科迈/3322，免费版限制多、域名随机）vs ddns-go+自有域名（阿里云/Cloudflare API，推荐；需一台常开设备承载，可与 WG 服务端同机）。注意：若光猫为路由模式（IP 在光猫上），R479 内置 DDNS 会上报错误 IP → 需光猫桥接，或用 ddns-go"接口检测"模式（查询出口 IP 回显服务，不受 IP 落点影响）
- 已确认（2026-10-20）：NAS 为**群晖入门款**（j 系列 ARM 平台，具体型号待补）。设计影响：
  - j 系列不支持 Docker/Container Manager → ddns-go 改为单文件二进制 + DSM 计划任务开机自启，或直接用 DSM 内置 DDNS（控制面板→外部访问）或 R479 内置花生壳
  - WireGuard 内核模块在 ARM 群晖需装社区编译 spk，DSM 升级易失效 → 不作首选，仅作提速备选
  - VPN 候选变为：① Tailscale 官方套件（支持 ARM 群晖，打洞直连省心，用户态实现速度受 CPU 限制需实测）② 群晖 VPN Server 套件 L2TP/IPsec（官方原生 5 分钟配好，手机/电脑系统内置 L2TP 客户端=家人零安装）③ R479 自带 L2TP（零成本备选）
  - 若家宽上行仅 30-50M（国内主流），入门 ARM 跑满无压力，无需较真落点性能
- 勘察结果（2026-10-20，用户答复⑧）：
  - 宽带：1000M 套餐（下行千兆；上行未实测，千兆套餐典型上行 30-100M，需 speedtest 确认）
  - VPS：**阿里云入门款，仅 3M 固定带宽** → 无法承担家人媒体流量（3M≈375KB/s），角色降级为：应急运维中转 + 可选轻量 Web 入口（HomeAssistant 面板/照片类）；家人访问改走 L2TP 直连（满速）
  - NAS：七八年前群晖入门款，性能弱 → j 系列本就不支持 Docker（用户以为"跑 Docker 就满"，实际无需 Docker：DDNS 用单文件二进制或路由器内置，VPN 用官方套件）；VPN 端点增加双候选：R479 自带 L2TP/IPsec（零新增依赖，先试）vs 群晖 VPN Server，实测取快者
  - 域名：**.cn 已备案** → 用子域（如 home.xxx.cn）做 DDNS 指向家里，仅用于 VPN（不建 Web 站点，避免备案接入商不符被注销）；.cn 主域继续留在阿里云 VPS 上（如需 Web 入口则合规）
- 用户新约束（2026-10-20，答复⑨）：
  - **NAS 仅作存储**，不承担任何穿透/DDNS 角色
  - **用 R479GPE-AC（"AC"）做穿透端点**——用户看中的就是它 VPN 路由器的本分
  - **域名必须用上**（不想记 IP）
  - 接受**脚本**作为粘合剂
- 待确认：光猫模式（用户回家看）、上行实测值、R479 固件确认（L2TP 服务器页 + IPsec 策略页 + 客户端自动重拨选项）
- 待确认：上行带宽、访问端环境、预算（预计仅域名几十元/年，无硬件支出）

## 现有设备能力（事实，来源：TP-LINK 官网/官方PDF product_976）
TL-R479GPE-AC（PoE·AC 一体化千兆 VPN 路由器，2015 年代平台）：
- 1×千兆 WAN + 8×千兆 LAN（PoE，整机 120W），带机量 100，内置 AC 可管 50 台 AP
- VPN：IPSec（最多 10 条隧道）、PPTP/L2TP 服务器与客户端 —— 不支持 WireGuard（原厂固件）
- NAT：NAPT、一对一 NAT、ALG、虚拟服务器（端口转发）、NAT DMZ、UPnP
- DDNS：花生壳、科迈、3322（不含阿里云 DNS；如需需在内网设备上跑 ddns-go 等）
- ⚠️ 官方未公布 VPN 吞吐量；此平台为软加密老 CPU，路由器上终结 VPN 的速度上限存疑（估计远低于千兆，需实测）。千兆 NAT 转发本身没问题

## 方案速度地图（外部研究，2025 年来源）
来源：kejilion 博客 (blog.kejilion.pro/frp-ddns-wg/)、AA博客 (blog.akise.app/posts/nat-traversal/)、V2EX 讨论帖、恩山论坛测速帖

| 方案 | 速度上限 | 依赖条件 | 备注 |
|------|---------|---------|------|
| 公网IPv4 + DDNS + 端口转发/WG | 家宽上行极限（最快） | 运营商给公网IP（可打客服申请，电信/联通成功率高） | 直连无中转；配合 WireGuard 全网访问 |
| 公网IPv6 + DDNS 直连 | 同上，实测常比 WG 更快 | 两端都有 IPv6（国内家宽/手机流量普遍有）；访问端 WiFi 未必有 | 无需端口转发，防火墙放行即可；勿全关 v6 防火墙 |
| WireGuard + 国内VPS中转 | min(VPS带宽, 上行) | 一台 VPS | 打洞成功则免中转≈直连；晚高峰 UDP 有被 QoS 案例 |
| Tailscale/ZeroTier（打洞） | 打洞成功≈直连；失败走 DERP/moon 很慢 | NAT 类型友好（家宽多为 NAT1 时易成功） | iOS 上与代理 App 互斥；自建 DERP/moon 可改善 |
| frp + VPS | min(VPS带宽, 上行) | VPS | 稳定通用、按服务暴露；不适合"整网当在家"场景 |
| R479GPE-AC 自带 VPN 服务器 | 路由器 VPN 吞吐（存疑，老平台） | 公网IP + 端口转发 | 零新增设备，但速度大概率是瓶颈；PPTP 不安全 |

## 风险与坑（外部案例）
- 运营商 DPI/QoS：多地案例 WireGuard/ZeroTier 的 UDP 流量晚高峰被限 ~5-10Mbps；OpenVPN/TCP 类特征不明显较少被限（V2EX t/1124140，2025-04）。若命中需备 TCP 封装或换端口
- 恩山实测（移动家宽 NAT1）：直连 265M（30线程）；WireGuard 120M；Tailscale(headscale+自建derp) 166M；OpenVPN 215M —— 隧道均有损耗，直连最快
- 家宽上行是硬上限：任何方案下行(在家方向下载)受上行制约，先测上行
- 光猫默认路由模式会形成双重 NAT，端口转发/DMZ 要落在光猫上；公网方案通常需光猫改桥接 + R479GPE-AC PPPoE 拨号
- 家宽建 Web 服务对外属运营商灰色地带，注意暴露面控制

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| **架构 v3（用户约束驱动重构）**：直连主干 = R479 内置 L2TP/IPsec **服务器**，客户端全平台系统自带；DDNS+兜底 = R479 与 VPS 建 **IPsec site-to-site 常开隧道**，VPS 脚本看到 IKE 源 IP 变化即调阿里云 API 更新 `home.子域.cn`；应急/家人轻量 Web = 走这条隧道经 VPS 反代（3M 限速） | 用户约束：NAS 零参与、AC 做穿透、域名必须用、可跑脚本；四项全部满足且零新增硬件 |
| 千兆套餐上行实测后定速度预期；若 R479 VPN 跑不满上行 → 升级路径：N100 小主机（用户已排除 NAS 方案） | R479 2015 平台 VPN 吞吐无官方数据，iperf 验收说了算 |
| 阿里云免费解析 TTL 600s（10 分钟收敛）；如嫌慢可把 .cn 的 NS 迁到 DNSPod 免费 120s，注册商不用换 | 光猫重启换 IP 后的恢复时长由 DNS TTL 决定 |
| 家里只跑 VPN 不建站（home 子域不挂任何 Web） | 保护 .cn 备案不被注销 |

## Issues Encountered
| Issue | Resolution |
|-------|------------|

## Resources
- https://www.tp-link.com.cn/product_976.html （R479GPE-AC 规格）
- https://service.tp-link.com.cn/download/pdf/976.pdf （官方产品文档）
- https://blog.kejilion.pro/frp-ddns-wg/ （FRP/DDNS/WG 三方案实测对比）
- https://blog.akise.app/posts/nat-traversal/ （四类方案配置详解）
- https://www.v2ex.com/t/1124140 （运营商 UDP QoS 限速案例）
- https://www.right.com.cn/forum/thread-8413930-1-1.html （恩山：WG/Tailscale/OpenVPN 打流对比）
