# 小狼毫 / 万象 Pro 补丁

为小狼毫增加 Tab 音节编辑、连接圆角候选框、四款 Azure Pill 皮肤，以及可配置的行内下划线。

## 安装

先安装小狼毫 0.17.4 和万象 Pro 方案、词库。支持 Windows x64 / x86。

1. 从 [最新 Release](https://github.com/mianxiu/weasel-ui-patch/releases/latest) 下载 `Weasel-Rewrite-UI.zip`。
2. 完整解压，普通双击 `Apply-Patch.cmd`。
3. 允许程序替换时的提权，等待 `SUCCESS`，完全退出并重开输入应用。

一个入口安装全部程序补丁、Lua、配置、皮肤及预览图，自动部署并校验。保留当前皮肤选择和布局。只换皮肤可运行包内的 `Apply-Skin*.cmd`。

## Tab 编辑

按 Tab，输入序号选择音节，再输入替换编码。序号只用 1–4：`1–4、11–14、21–24…`，7–0 保留声调输入。连续序号超过 350 毫秒间隔就重新开始，保留最后选择。

Backspace 删除替换内容，Esc 恢复原输入。拼音行自动换行，选中音节与主候选使用连接圆角。

## 行内下划线

在 `%APPDATA%\Rime\weasel.custom.yaml` 中设置：

```yaml
patch:
  style/inline_underline/style: solid
  style/inline_underline/color: "#286CF4"
  style/inline_underline/bold: false
```

线型：`none`（无）、`solid`（实线）、`dot`（点线）、`dash`（虚线）、`squiggle`（波浪线）。

颜色用带引号的 `"#RRGGBB"`；填 `theme` 可跟随皮肤选中候选的背景色。`bold: true` 使用粗线。默认是细蓝色实线。

把这三项合并到现有 `patch:` 下，不要覆盖整份配置。修改后重新部署并重启小狼毫服务。部分应用可能忽略线型或颜色。

完整示例随安装包提供。当前构建：`rewrite-ui-wechat-key-dedup-20261003`。

## 输入异常排查

`Collect-IME-Diagnostics.cmd` 用于对比两台电脑的系统、输入组件和实际加载的 DLL；不读取剪贴板或聊天内容。

`Fix-IME-First-Key.cmd` 提供可选的触摸键盘绕过办法，并支持恢复。它不会随安装自动执行，也不能保证解决吞字。

修复微信等应用中因按键回调参数差异导致的重复输入。安装后必须完全退出并重开输入应用，才能加载新 DLL。

需要排查输入异常时，可运行 `Start-Key-Trace.cmd` 开启按键记录；24 小时后自动停止，活动日志最多约 64 MiB。`Stop-Key-Trace.cmd` 关闭记录，`Capture-Key-Trace.cmd` 停止并打包日志。默认关闭，日志含按键码，请仅保留本机。
## 源码与维护

本仓库保存 96 个补丁及维护脚本。重建源码：

```powershell
git clone https://github.com/mianxiu/weasel-ui-patch.git
cd weasel-ui-patch
pwsh -NoProfile -File .\setup.ps1
```

源码生成在 `..\weasel\`。构建依赖和操作见其中的 `REWRITE-UI.md`、`agent.md`。

- `resync.ps1`：同步上游并导出补丁。
- `resync.ps1 -ExportOnly`：仅导出本地改动。
- `release.ps1`：发布编译好的安装包。

手工重建须使用 `core.autocrlf=false` 和 `git am --keep-cr`，并保留本仓库的 `.gitattributes`；脚本已处理这些设置。

基于 [rime/weasel](https://github.com/rime/weasel)，沿用 GPLv3。万象方案及词库不随包分发。
