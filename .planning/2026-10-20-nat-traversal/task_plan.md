# 任务计划：家庭内网穿透方案（速度优先）

## Goal
为家庭网络（互联网→光猫→TL-R479GPE-AC→5×TP-Link AP）设计并落地一套远程访问方案，核心指标：速度尽可能快（目标逼近家宽上行极限），兼顾安全与可维护性。

## Next Step
等用户回家补勘察 3 项：①光猫端口映射确认（UDP 500/4500→R479，记 R479 WAN IP 与 LAN 网段）②speedtest 上行值 ③R479 固件确认（L2TP 服务器页/IPsec 策略页/自动重拨）。齐了进入 Phase 4：按仓库 README 部署 VPS 侧 + R479 侧配置 + 客户端模板（每步含回滚与 iperf 验收标准）。

## Current Phase
Phase 2

## Phases

### Phase 1: 需求澄清（brainstorming）
- [x] 用途/场景确认 → 四项全选（整网当在家/个别服务/临时运维/给家人外人）
- [x] 公网 IP 现状 → 动态公网 IPv4（重启光猫会变，DDNS 覆盖）
- [x] 常开设备 → 群晖 NAS（后续被约束排除，仅存储；穿透落点归 R479）
- [x] 访问端环境 → 自己+家人设备全走 L2TP 直连（系统内置客户端）；VPS 仅应急与可选轻量 Web
- [x] 预算与设备意愿 → 已有 NAS + VPS + 域名 + 光猫账号，零新增硬件
- [x] 速度预期 → "直连保证速度"硬约束，上限=家宽上行（待实测数值）
- [x] 用户约束六条成型（直连/NAS 零参与/AC 端点/域名/光猫第 2 档/脚本可接受）
- **Status:** complete

### Phase 2: 现状勘察
- [ ] 光猫：登录（用户已有账号）确认端口映射页可转发 UDP 500/4500→R479（或 DMZ）；记 R479 的 WAN IP 与 LAN 网段——**不改桥接，保持路由模式**
- [~] 家宽上行带宽：套餐 1000M 已知，上行数值待实测（speedtest）
- [x] VPS：阿里云入门款 3M 固定带宽 → 角色降级为应急中转+可选轻量 Web 入口
- [x] NAS：零参与（型号已无架构影响）
- [x] 域名：.cn 已备案，NS=阿里云；home 子域 A 记录已手动存在（将由 ddns-watch 接管自动更新）
- [ ] R479 固件确认（L2TP 服务器页 / IPsec 策略页 / 自动重拨）
- **Status:** in_progress

### Phase 3: 方案选型对比与决策
- [x] 候选方案对比已给出（A/B/C 三案）
- [x] 用户约束收敛 → **架构 v3 = 方案 A 锁定**：R479 L2TP/IPsec 服务器直连主干 + R479↔VPS IPsec 常开隧道（VPS 脚本更新阿里云 DNS + 兜底中转 + 可选家人 Web）+ NAS 零参与
- **Status:** complete

### Phase 4: 部署设计与实施
- [x] 预写（2026-10-20）：README + VPS 侧脚本与模板（ddns-watch.sh / strongSwan 两模板 / install.sh，语法检查通过，已推 GitHub；待勘察后联调）
- [ ] VPS 侧联调：install.sh 部署 → ddns.conf 填真实值 → DRY_RUN 干跑 → strongSwan 上线
- [ ] R479 侧：L2TP/IPsec 服务器开启（账号/PSK）+ IPsec 策略指向 VPS + 客户端地址池
- [ ] 光猫：端口转发 UDP 500/4500 → R479（或 DMZ 兜底；LAN 网段冲突则改 R479 LAN）
- [ ] 客户端配置模板（iOS/macOS/Windows/Android 系统 L2TP）
- [ ] 分步实施清单输出（每步含回滚方法）
- **Status:** pending

### Phase 5: 测速验证与调优
- [ ] iperf3 / 实际业务测速（对比直连基线=上行实测值）
- [ ] 自愈演练（重启光猫计时：隧道重连→DDNS 更新→客户端重拨全链路）
- [ ] 记录最终架构与配置（更新 方案.md 与 README）
- **Status:** pending

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| 记录目录定为 /home/work/nat-traversal | 用户要求在 work 下新建目录存放项目记录；ASCII 路径对脚本/钩子兼容性最好 |
| 方案 v3 = A（VPS 心跳版）：R479 L2TP/IPsec 直连 + R479↔VPS 常开隧道做 DDNS/应急 + NAS 零参与 | 用户逐条拍板：直连硬约束、NAS 仅存储、AC 做穿透、域名必须用、脚本可接受；B（花生壳极简版）被否 |
| 光猫第 2 档：保持路由模式，仅端口转发 UDP 500/4500→R479 | 用户不想改桥接且已有管理账号；NAT-T 无损、可随时回滚 |
| VPS 3M 定位 = 应急中转 + 可选轻量 Web，不承载主流量 | 3M 扛不动媒体；家人走 L2TP 直连满速 |
| 脚本/模板预写并开源（github.com/lhdren/nat-traversal，公共仓库） | 用户指示；敏感扫描通过，仓库不含真实 IP/密钥 |
| R479 吞吐不达标的退路 = N100 小主机（约¥400-700） | 2015 平台无官方 VPN 吞吐数据，iperf 验收说了算 |

## Errors Encountered
| Error | Resolution |
|-------|------------|
| question 工具选项文本混入换行符，首长端显示截断 | 重发干净文本提问成功；教训：选项 JSON 不手工插 \r\n |
| 长消息两次在首长侧被截断 | 精简分段补发成功；教训：清单类消息控制篇幅 |
| progress.md 追加日志误用旧行整行替换，丢过 3 次历史记录 | 发现后逐条恢复；教训：锚定最后一行，newString=旧行+新行 |
