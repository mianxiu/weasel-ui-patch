# 小狼毫 / 万象 Pro 全部补丁一键安装

完整解压 `Weasel-Rewrite-UI.zip`，普通双击 `Apply-Patch.cmd`，等待 `SUCCESS` 后重开输入应用。

适用于已安装小狼毫 0.17.4 和万象 Pro 的 Windows x64 / x86。

## 本次更新 · 2026-10-03

- 行内下划线支持 YAML 配置线型、颜色和粗细；默认保持细蓝色实线。
- 颜色可固定为 `"#RRGGBB"`，或用 `theme` 跟随皮肤。
- 重写仓库及安装包 README，集中说明安装、Tab 编辑和配置方法。

包含全部 91 个补丁。构建标识：`rewrite-ui-yaml-inline-underline-20261002`。

## 下划线配置

在 `weasel.custom.yaml` 中设置：

```yaml
patch:
  style/inline_underline/style: solid
  style/inline_underline/color: "#286CF4"
  style/inline_underline/bold: false
```

线型：`none`（无）、`solid`（实线）、`dot`（点线）、`dash`（虚线）、`squiggle`（波浪线）。

颜色用带引号的 `"#RRGGBB"`；填 `theme` 可跟随皮肤选中候选的背景色。`bold: true` 使用粗线。默认是细蓝色实线。

把这三项合并到现有 `patch:` 下，不要覆盖整份配置。修改后重新部署并重启小狼毫服务。部分应用可能忽略线型或颜色。

## 已有功能

- 一个入口安装全部程序补丁、Lua、配置、四款皮肤和预览图。
- Tab 序号仅使用 1–4，保留 7–0 声调输入；支持连续编辑、退格和 Esc 恢复。
- 拼音行换行及连接圆角；保留中文候选的间距。
- 可选输入异常绕过工具和只读诊断工具。吞字问题仍需在具体应用中复测。

x64 / x86 下划线、IPC 和布局测试通过，本机已安装并验证 YAML 设置传递。包内含源码、校验表和许可证；安装自动备份。
