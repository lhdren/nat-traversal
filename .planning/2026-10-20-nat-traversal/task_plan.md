# 任务计划：家庭内网穿透方案（速度优先）

## Goal
为家庭网络（互联网→光猫→TL-R479GPE-AC→5×TP-Link AP）设计并落地一套远程访问方案，核心指标：速度尽可能快（目标逼近家宽上行极限），兼顾安全与可维护性。

## Next Step
等用户回家补勘察：①光猫模式 ②speedtest 上行 ③R479 固件确认（VPN→L2TP 服务器页、IPsec 策略页、自动重拨选项）。齐了进入 Phase 4：VPS 侧（strongSwan+DDNS 脚本）与 R479 侧分步实施清单（含回滚与 iperf 验收标准）。

## Current Phase
Phase 2

## Phases

### Phase 1: 需求澄清（brainstorming）
- [x] 用途/场景确认（整网访问 / 个别服务 / 临时运维）→ 四项全选，全场景需求
- [x] 公网 IP 现状 → 确认有动态公网 IPv4（重启光猫会变，DDNS 覆盖）
- [x] 常开设备 → 群晖入门款 NAS（WG/VPN/DDNS 落点）
- [x] 访问端环境 → 自己设备为主（L2TP/Tailscale 客户端）；家人/外人走 VPS Web 零门槛层
- [x] 预算与设备意愿 → 已有 NAS + VPS，无新增硬件，仅域名几十元/年
- [x] 速度预期 → "直连保证速度"为硬约束，上限=家宽上行（待实测数值）
- **Status:** complete

### Phase 2: 现状勘察
- [ ] 光猫工作模式（看 R479 WAN 口 IP 是否公网 → 桥接/路由判定）→ 用户回家看
- [~] 家宽上行带宽：套餐 1000M 已知，上行数值待实测（speedtest）
- [x] VPS：阿里云入门款 3M 固定带宽 → 角色降级为应急中转+可选轻量 Web 入口
- [ ] 群晖具体型号 + DSM 版本（回家顺带看信息中心；套件中心确认 VPN Server/Tailscale）
- [x] 域名：.cn 已备案 → 子域做 DDNS（仅 VPN），主域留 VPS
- **Status:** in_progress

### Phase 3: 方案选型对比与决策
- [x] 候选方案对比已给出（A/B/C 三案）
- [x] 用户约束收敛（NAS 零参与 / AC 做穿透 / 域名必须用 / 可跑脚本）→ **架构 v3 锁定**：R479 L2TP/IPsec 服务器做直连主干 + R479↔VPS IPsec 常开隧道（VPS 脚本更新阿里云 DNS + 兜底中转 + 可选家人 Web）
- **Status:** complete

### Phase 4: 部署设计与实施
- [x] 预写（2026-10-20）：README + VPS 侧脚本与模板（ddns-watch.sh / strongSwan 两模板 / install.sh，语法检查通过，已推 GitHub；待勘察后联调）
- [ ] VPS 侧：strongSwan（IKEv1 站点对站点，对接 R479 IPsec）+ 源 IP 监听脚本 → 阿里云 DNS API 更新 home 子域
- [ ] R479 侧：L2TP/IPsec 服务器开启（账号/PSK）+ IPsec 策略指向 VPS + 客户端地址池（LAN 网段）
- [ ] 光猫：桥接（或 DMZ 兜底）确保公网 IP 落在 R479
- [ ] 客户端配置模板（iOS/macOS/Windows/Android 系统 L2TP）
- [ ] 分步实施清单输出（每步含回滚方法）
- **Status:** pending

### Phase 5: 测速验证与调优
- [ ] iperf3 / 实际业务测速（对比直连基线）
- [ ] 失败场景演练（打洞失败回退、断线重连）
- [ ] 记录最终架构与配置
- **Status:** pending

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| 记录目录定为 /home/work/nat-traversal | 用户要求在 work 下新建目录存放项目记录；ASCII 路径对脚本/钩子兼容性最好 |
| 方案 v3 = A（VPS 心跳版）：R479 L2TP/IPsec 服务器直连 + R479↔VPS IPsec 常开隧道做 DDNS/应急 + NAS 零参与 | 用户逐条拍板（2026-10-20）：直连硬约束、NAS 仅存储、AC 做穿透、域名必须用、脚本可接受；B（花生壳极简版）被否 |

## Errors Encountered
| Error | Resolution |
|-------|------------|
