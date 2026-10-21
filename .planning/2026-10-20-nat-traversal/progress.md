# Progress Log

## Session: 2026-10-20

### Current Status
- **Phase:** 2 - 现状勘察（in_progress，仅剩 3 项现场勘察）
- **设计状态：** 架构 v3 = 方案 A（VPS 心跳版）已锁定；光猫第 2 档（端口转发不改桥接）已锁定；VPS 侧脚本已预写入库
- **Started:** 2026-10-20
- **PLAN_ID:** 2026-10-20-nat-traversal（pin: export PLAN_ID=2026-10-20-nat-traversal）
- **仓库:** https://github.com/lhdren/nat-traversal（本地 /home/work/nat-traversal，main 分支）

### Actions Taken
- 创建 /home/work/nat-traversal 并初始化 planning 文件（init-session.sh "NAT Traversal"）
- 完成 R479GPE-AC 官方规格查证（VPN/DDNS/端口转发能力），写入 findings.md
- 完成 2025 年内网穿透方案速度对比研究（直连/打洞/中转三类），写入 findings.md
- 访谈过程（问题→答复，按时间序）：
  - 答复①：用途四项全选（整网当在家/个别服务/临时运维/给家人外人）
  - 答复②：**确定有公网 IPv4** → 主路线锁定 DDNS+直连
  - 答复③：IPv4 为动态（重启光猫即变）→ DDNS 必选
  - 答复④：要求 IP 同步机制 → 确认 DDNS 组件（检测→API 更新→客户端自愈）
  - 答复⑤：家里有 NAS →（当时定为 WG/DDNS 落点，后被⑨推翻）
  - 答复⑥：NAS 为群晖入门款（j 系列 ARM，无 Docker）→ 当时调整 VPN 候选（后被⑨收敛）
  - 答复⑦：另有一台外网 VPS（后知 3M）；**硬约束=主通道必须直连家里**
  - 拍板：倾向方案 A，先勘察
  - 答复⑧（勘察回报）：1000M 套餐；VPS=阿里云 3M；NAS 七八年前入门款；.cn 域名已备案
  - 答复⑨（约束变更）：NAS 仅存储；R479（AC）做穿透端点；域名必须用；可跑脚本 → 架构重构为 v3
  - 答复⑩：要求重新梳理 → 输出《方案.md》v3 定稿（仓库根目录）
  - 答复⑪：疑问隧道/是否借 VPS/3M 影响 → 解释心跳线机制；给出 B（花生壳极简版）备选
  - 答复⑫：**选定 A（VPS 心跳版）**，方案锁定
  - 答复⑬：不想调整光猫 → 三档可行性分析
  - 答复⑭：**已有光猫账号密码** → 锁定第 2 档（路由模式+端口转发 UDP 500/4500→R479）
- 执行：
  - 创建公共仓库 github.com/lhdren/nat-traversal 并上传（敏感信息扫描通过）
  - 预写 VPS 侧全部脚本并推送：README.md + scripts/{ddns-watch.sh, ddns.conf.example, ddns-watch.service, ipsec.conf.example, ipsec.secrets.example, install.sh}，bash -n 全过；要点：xfrm 优先/conntrack 回退源 IP 检测、阿里云 HMAC-SHA1 手写签名、DRY_RUN+--once 调试开关、ipsec 模板 TODO 标注勘察项
  - DNS 实查：NS=阿里云✓；home 子域 A 记录已生效（手动添加，无自动更新）；主域指向阿里云 IP（疑 VPS）——仅"解析层"可用
  - 光猫策略变更同步：更新 方案.md/README/ipsec.conf 注释（NAT-T 说明）并推送
  - planning 三文件重整（最终态快照化、时序修正、错误归档）并推送
- 插曲：question 工具选项混入换行符致显示截断；长消息两次截断；progress 追加误替换丢记录 3 次（均已恢复+归档，见 Errors）

### Test Results
| Test | Expected | Actual | Status |
|------|----------|--------|--------|
| （Phase 5 填写：iperf3 验收 / 自愈演练） | | | |

### Errors
| Error | Resolution |
|-------|------------|
| question 工具选项文本混入换行符，首长端显示截断 | 重发干净文本提问成功；教训：选项 JSON 不手工插 \r\n |
| 长消息两次在首长侧被截断 | 精简分段补发成功；教训：清单类消息控制篇幅 |
| progress.md 追加日志误用旧行整行替换，丢过 3 次历史记录 | 发现后逐条恢复；教训：锚定最后一行，newString=旧行+新行 |

### Next Session Resume（新会话从这里继续）
1. 读 task_plan.md + findings.md（本目录）恢复上下文
2. 若用户带回勘察 3 项结果 → Phase 2 置 complete，进 Phase 4：按 README 部署 VPS（install.sh→填配置→DRY_RUN→上线）+ 输出 R479/光猫/客户端分步清单
3. 工作目录：/home/work/nat-traversal（git 仓库，改动后记得 add/commit/push，遵循原子提交）
