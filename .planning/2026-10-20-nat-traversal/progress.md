# Progress Log

## Session: 2026-10-20

### Current Status
- **Phase:** 2 - 现状勘察（in_progress）；方案方向已定 A，待勘察确认
- **Started:** 2026-10-20
- **PLAN_ID:** 2026-10-20-nat-traversal（pin: export PLAN_ID=2026-10-20-nat-traversal）

### Actions Taken
- 创建 /home/work/nat-traversal 并初始化 planning 文件（init-session.sh "NAT Traversal"）
- 完成 R479GPE-AC 官方规格查证（VPN/DDNS/端口转发能力），写入 findings.md
- 完成 2025 年内网穿透方案速度对比研究（直连/打洞/中转三类），写入 findings.md
- 向用户提出第一个需求澄清问题：远程访问用途/场景
- 用户答复①：用途四项全选（整网当在家/个别服务/临时运维/给家人外人）
- 用户答复②：**确定有公网 IPv4** → 主路线锁定 DDNS+直连；运营商未补充（后续可顺带问，影响 QoS 风险评估）
- 用户答复③：IPv4 为动态（重启光猫即变）→ 正常现象，DDNS 即可覆盖，不影响直连路线；Phase 2 需勘察光猫模式（桥接/路由）确定 IP 落点
- 用户答复④：要求有 IPv4 同步机制 → 确认 DDNS 为必选组件；向用户说明了机制（检测→API更新→客户端自愈）与选型（内置花生壳 vs ddns-go+自有域名）
- 用户答复⑤：家里有 NAS → WG 服务端 + ddns-go 落点 = NAS；下一步问访问端形态（家人/外人如何访问），随后进入 Phase 3 方案汇总
- 用户答复⑥：NAS 为群晖入门款（j 系列 ARM）→ 无 Docker；VPN 候选改为 Tailscale 官方套件 / 群晖 VPN Server(L2TP) / R479 自带 L2TP；ddns-go 用二进制+计划任务或 DSM 内置 DDNS。待问：家人访问形态、上行带宽
- 用户答复⑦：另有一台外网 VPS；**硬约束=主通道必须直连家里**。需求图谱完整，进入 Phase 3：提出 A/B/C 三方案（A=DDNS+群晖L2TP/IPsec+Tailscale备线+VPS暴露层，推荐），待用户拍板
- 用户拍板：**倾向方案 A，先勘察**。已更新计划（Phase 1 complete，Phase 2 in_progress），向用户输出了 5 项勘察清单（光猫模式/上行带宽/VPS位置/群晖型号/域名）
- 插曲：question 工具选项文本混入换行符导致首长看不全 → 重新用干净文本提问成功；教训：选项 JSON 不要手工插入 \r\n
- 插曲2：勘察清单消息在首长侧被截断两次（停在③ VPS 处）→ 最终精简补发完整版成功；教训：长清单消息控制篇幅、分段简短
- 用户答复⑧（勘察回报）：光猫待回家看；1000M 套餐；VPS=阿里云 3M；NAS 七八年前入门款；.cn 域名已备案 → 设计微调：VPS 降级应急、家人走 L2TP 直连、VPN 端点双候选（R479 vs 群晖）、DDNS 用 .cn 子域。剩 3 项待回家补：光猫模式/上行实测/群晖型号
- 用户答复⑨（约束变更）：NAS 仅存储不中转；R479（AC）做穿透端点；域名必须用上；可跑脚本 → 架构重构为 v3：R479 L2TP/IPsec 服务器直连 + R479↔VPS IPsec 常开隧道（VPS 脚本调阿里云 API 做 DDNS + 应急中转），NAS 零参与、零新增硬件。Phase 3 complete，待回家勘察光猫/上行/R479 固件后进 Phase 4
- 用户答复⑩：要求重新梳理方案 → 输出《方案.md》v3 定稿（/home/work/nat-traversal/方案.md），含现状盘点/架构/三职责/自愈链路/安全/勘察/实施/风险退路，聊天中同步精简版
- 流程教训（出现3次）：追加日志时误用旧行整行替换导致丢记录 → 统一改为"锚定最后一条，newString=旧行+新行"
- 用户答复⑫：**选定 A（VPS 心跳版）**，方案 v3 全部锁定；仅剩回家勘察 3 项（光猫模式/上行实测/R479固件确认）即可出实施清单
- 用户答复⑪：疑问 R479↔VPS 隧道是什么、是否借用 VPS、3M 是否拖慢访问 → 已解释：隧道=心跳线（每分钟几个字节），主访问路径完全不经 VPS；同时给出无 VPS 极简备选（R479 内置花生壳 DDNS，放弃自有域名），待用户二选一
- 执行：按用户指示创建公共仓库 github.com/lhdren/nat-traversal 并上传（方案.md + .planning 过程记录；3 个原子提交；敏感信息扫描通过）
- 执行：预写 VPS 侧全部脚本并入库推送——README.md、scripts/{ddns-watch.sh, ddns.conf.example, ddns-watch.service, ipsec.conf.example, ipsec.secrets.example, install.sh}，bash -n 全过（本机无 shellcheck）；要点：源IP检测用 xfrm 优先/conntrack 回退、阿里云 HMAC-SHA1 签名手写实现、DRY_RUN+--once 调试开关、ipsec.conf 带 TODO 标注待勘察项；README 含部署步骤与进度清单

### Test Results
| Test | Expected | Actual | Status |
|------|----------|--------|--------|
| （Phase 5 填写） | | | |

### Errors
| Error | Resolution |
|-------|------------|
