# 小狼毫 · 万象 Pro 编码重写补丁 — v0.17.4.1-rewrite-ui

基于上游 Weasel `d73f6295`（0.17.4 时代）的定制二进制补丁，为 Windows 小狼毫
增加「未上屏编码快速重写」的**原生 UI**。

```text
Build-ID:  rewrite-ui-software-render-20260928
文件版本:  0.17.4.1（未做发行代码签名）
适用平台:  Windows x64 与 x86（不支持 ARM64）
```

## 下载

`Weasel-Rewrite-UI.zip`（约 8.7 MB）。解压后先读包内 `README.md`。

## 这个包做了什么

**Rewrite UI（原生绘制）** —— 在未上屏的编码上按音节重写：

```text
普通输入     jxjirzbj
Tab          jx¹   ji²   rz³   bj⁴            ← 第 1 音节高亮
3            jx¹   ji²  [rz³]  bj⁴      ³     ← 高亮即时移动 + 索引 badge
jm           jx¹   ji²  [jm³]  bj⁴      ³     ← replacement 即时更新
Esc          jxjirzbj                         ← 恢复原编码
```

`[ ]` 是真正的圆角背景高亮（界面上不显示括号），`³` 是独立的弱背景 badge。
关键难点是：按数字选音节时 property 变了但 `context.input` 没变，
translation / filter / preedit 都不会重算，UI 不动 —— 纯 Lua 侧试过的几条
刷新路线全部无效，所以改在 Weasel 侧：每次按键后主动读取属性、构造独立状态、
原生绘制。

**顺带的两个独立改动**：

- **D2D 软件渲染**：render target 改为 `D2D1_RENDER_TARGET_TYPE_SOFTWARE`，
  减少新宿主进程的硬件设备初始化开销（[rime/weasel#1913](https://github.com/rime/weasel/issues/1913)）。
- **WeaselSetup 命令行修复**：容忍参数首尾空白，修掉「尾部空格导致 `/s`
  未被识别、进入隐藏交互窗口」的问题；另加 `WEASEL_SETUP_LOG` 门控的安装 trace。

## 环境要求

- 已安装小狼毫 Weasel —— 本包是**覆盖式补丁**，不含词库与安装器
- 万象 Pro + 小鹤双拼方案
- 核心 Lua `indexed_rewrite_pro.lua`（在 `rewrite-source.zip` 的 `rime/` 里）
- x64 或 x86 Windows；**ARM64 不支持**

## 安装

完整步骤见包内 `README.md`，要点：

1. 覆盖程序文件，并**保留原目录的 `data`、词库和其他资源**
2. 以管理员权限运行 `WeaselSetup.exe /s` 重新注册 TSF DLL
   （只替换 `WeaselServer.exe` 是不够的，`System32`/`SysWOW64` 里的客户端也要换）
3. 在 `weasel.custom.yaml` 里开启 `rewrite_ui/enabled: true`
   （附带的 `install-rime-files.ps1 -Apply` 会装好 Lua、补上开关，并自动删掉
   已废弃的 `lua_filter@*indexed_rewrite_tab_ui_v2` 行，不需要手工改 YAML）
4. **重新部署（`WeaselDeployer.exe /deploy`）并重启服务**
   —— 服务端读的是编译产物 `%APPDATA%\Rime\build\weasel.yaml`
5. 注销并重新登录 Windows，使宿主进程加载新的 TSF DLL

## 验证情况

已在真实万象 Pro + 小鹤双拼 + 直接辅助配置上完成真机验收：

- `Tab` 进入编辑模式 ✅
- 按数字即时移动高亮并显示索引 badge ✅
- 多位索引 `32` / `321` / 退格回退 ✅
- `j` → `jm` → 退格的 replacement 实时更新 ✅
- `Esc` 恢复原编码 ✅
- 普通输入、候选与直接辅助未受影响 ✅

**尚未覆盖**（不影响已有结论）：多位索引 badge 的肉眼确认、
`Space`/`Enter`/标点提交后的上屏结果、`Tab` 后直接打字母的 `head_replace` 路径。

## 校验

包内 `SHA256SUMS.txt` 列出全部 21 个文件的 SHA256，可逐一核对：

```powershell
Get-FileHash .\WeaselServer.exe -Algorithm SHA256
```

## 源码

配套源码仓库 [mianxiu/weasel-ui-patch](https://github.com/mianxiu/weasel-ui-patch)
**只保存补丁**（约 283 KB，不含上游源码）。在补丁仓库里跑 `setup.ps1` 会从官方
clone Weasel 并打上全部补丁，重建出与本次构建完全一致的源码树
（用 `EXPECTED-TREE.txt` 校验 tree hash）。

包内 `rewrite-source.zip` 是补丁应用后的源码快照，便于离线查阅。

## 许可

基于 [rime/weasel](https://github.com/rime/weasel) 修改，沿用其 **GPLv3**
（见包内 `licenses/`）。上游作者与贡献者名单见上游仓库。
万象 Pro 词库与方案数据不属于本项目，也不随本包分发。

