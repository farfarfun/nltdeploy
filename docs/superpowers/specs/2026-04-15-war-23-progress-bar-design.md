# WAR-23：可复用进度条工具 — 设计说明

**日期：** 2026-04-15  
**状态：** 已定稿（与 [WAR-23](/WAR/issues/WAR-23) 描述一致）  
**关联规范：** [工具与服务命令规范](2026-04-11-nltdeploy-tool-service-conventions.md)

---

## 1. 定位

在 nltdeploy 仓库中新增 **可被其他 shell 脚本 source 的进度条库**（非长期守护进程）。工单标题「添加服务」在此上下文中指 **为生态增加一项可复用能力**；按术语表归类为 **工具/库**，不进入 `nlt-services status` 的常驻进程列表。

## 2. 目标与成功标准

| 需求（来自工单） | 设计要点 |
|------------------|----------|
| 多平台 macOS + Linux | Bash 3.2+；文件大小用 `stat`（macOS `-f%z`，GNU `stat -c%s`）封装为单一探测函数 |
| 百分比 | 已知 `current`/`total` 时渲染；`total` 未知时可退化为不确定模式或仅显示已传输量 |
| 剩余时间 / 已用时间 | 基于起始 epoch 秒与当前速度估算 ETA；无速度时不显示 ETA 或显示 `—` |
| 下载场景：速度、已下、总大小 | 提供「监控增长中的本地文件 + 已知总字节」的辅助流程，与 `curl -o` 等组合使用 |
| 彩色、观感上档次 | TTY 时使用 256 色渐变条与分区文字颜色；非 TTY 则单行纯文本，避免控制序列污染日志 |
| 其他自由发挥 | 文档中给出在 `code-server`/`new-api` 下载路径中的集成示例片段 |

## 3. 架构

- **主文件：** `scripts/lib/nlt-progress.sh`  
  - 由其他脚本 `source`（与 `nlt-common.sh` 同目录，便于 `install.sh` 同步到 libexec）。  
  - 导出函数式 API，例如：初始化、按字节刷新、结束换行、人类可读字节格式化、可选「下载监视循环」。
- **安装路径：** 在 `install.sh` 的 `do_install_or_update` 中增加对 `nlt-progress.sh` 的 `_nlt_cp_first`，与 `nlt-common.sh` 一并复制到 `${LIBEXEC}/lib/`。
- **不强制** 新增独立 `nlt-progress` 二进制包装，除非实现阶段需要 **demo** 子命令便于验收；若增加，遵循无参 gum / 有参直跑惯例。

## 4. 接口（草案，实现时可微调命名）

- `_nlt_pb_now_s`：当前 epoch 秒（内部）。
- `nlt_pb_human_bytes`：字节 → `1.2 MiB` 形式。
- `nlt_pb_render`：输入 current、total、label、start_ts、终端宽度；绘制一行含条形、百分比、elapsed、ETA、（可选）速率与 xfer 大小。
- `nlt_pb_download_watch`（或等价）：后台 `curl` 写文件时，轮询部分文件大小直至稳定或达 total，周期性调用 `nlt_pb_render`。

## 5. 风险与边界

- **终端宽度：** 使用 `COLUMNS` 或 `tput cols`，缺省 80。  
- **性能：** 轮询间隔建议 0.2–0.5s，避免磁盘 stat 过高频。  
- **并发：** 单进程单条进度线；多任务需文档说明限制。

## 6. 验收

- `bash -n scripts/lib/nlt-progress.sh` 通过。  
- 新增或扩展现有冒烟脚本（如 `tests/` 下）在非交互环境能跑通最小示例。  
- README 或 `scripts/lib/` 头注释中说明用法与依赖（仅 bash/awk/date）。
