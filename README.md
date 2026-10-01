> **2026-10-01 窗口切换修复：** 沿用原有离开窗口时取消未上屏输入的行为，同步清除 Rime/TSF 状态、按键待处理标记及候选 UI 注册；旧的异步输入与位置回调失效，切回后下一次输入可重新创建候选框。自动验证覆盖真实 TSF 对象的 COM 模拟宿主、延迟回调与两个独立 Rime 会话；具体应用仍需安装后实测。

# weasel-ui-patch

为 Windows 小狼毫（Weasel）加「未上屏编码快速重写」**原生 UI** 的个人补丁集。

**这个仓库只有补丁，没有上游源码**。
上游 [rime/weasel](https://github.com/rime/weasel) 的源码由 `setup.ps1`
在需要时从官方 clone（公开永久，几秒）。

> **个人自用，不向上游提 PR。**

## 当前预览版

构建标识为 `rewrite-ui-half-tab-spacing-20261001`。当前本地分发目录是 `weasel/dist/Weasel-Rewrite-UI-Floating-Preview`，压缩包为同名 ZIP。候选框内显示 Tab 声调拼音行，共用主候选圆角；不再使用独立编辑窗口或上标。第 1–4 个音节隐藏编号显示，数字定位仍从 1 开始；字号约为候选的 80%（至少 10pt）。

Azure Pill 提供蓝、深蓝、深黑、深绿四种配色，普通及悬停候选使用黑字，悬停背景为浅灰色 `#EEEEEE`；前 4 个 Tab 音节按隐藏编号宽度的一半增加间距。该版本为本地预览，更新文档和打包不会自动发布 Release。

## Tab 音节编辑

按 `Tab` 后输入序号定位原音节，再输入替换编码。默认支持连续多音节替换：例如把第 3 项从 `bǐ` 改成 `bù shì hǎo`，所有替换读音显示在原第 3 项的位置，后续原音节及编号保持不变。直接输入字母则从头连续覆盖原编码。

被编辑部分随当前首候选的词典读音实时更新，其他音节保持原读音。按 `Backspace` 逐步删除替换内容，清空后恢复原读音；`Esc` 恢复进入 Tab 前的原输入。缺少可靠读音时保留已有读音，原本缺少读音的音节单独显示编码。

不限制替换字母的长度，也不需要额外配置开关。

## 新电脑上快速部署

```powershell
git clone https://github.com/mianxiu/weasel-ui-patch.git
cd weasel-ui-patch

# 重建工作副本：clone 官方 → 检出基线 → 打补丁 → 初始化 submodule
pwsh -NoProfile -File .\setup.ps1
```

几秒钟后生成 `..\weasel\`（约 19 MB），里面是完整的、可编译的源码树，
同时拥有上游的全部历史和本补丁的全部改动 —— 所以 `git rebase upstream/master`
照常可用。

接着：

```powershell
# 1. 装好小狼毫与万象 Pro，准备好词库
# 2. 编译并打包（构建还需要不被 git 跟踪的 weasel.props 与 deps\）
cd ..\weasel
.\build-rewrite.cmd
pwsh -NoProfile -File .\package-rewrite.ps1
# 3. 一键安装：程序、YAML、Lua、启用、部署与验证
.\dist\Weasel-Rewrite-UI-Floating-Preview\Apply-Patch.cmd

# 4. 完全退出并重开测试应用；仍未刷新时再注销或重启 Windows
```

构建依赖（`weasel.props`、`deps\boost_1_84_0`、`deps\rime-x64`、`deps\rime-x86`、
MSVC v143）不进 git，准备方法见工作副本里的 `REWRITE-UI.md` 与 `agent.md` §25.1。

## 上游发新版后

```powershell
cd weasel-ui-patch
pwsh -NoProfile -File .\resync.ps1
```

它做四件事：`git fetch upstream` → 在 `..\weasel\` 里 `git rebase upstream/master`
→ 重新导出 `patches/` → 更新 `BASE-COMMIT.txt` 与 `EXPECTED-TREE.txt`。

有冲突时它停下并提示；解决完 `git rebase --continue`，再跑
`resync.ps1 -ExportOnly`。最后 `git commit && git push`（或下次加 `-Push`）。

**只改代码、没动上游**时，直接 `resync.ps1 -ExportOnly` 重新导出即可 ——
这是补丁式维护唯一新增的纪律：**工作副本没有远端，忘了导出就等于改动只在本机。**

## 目录内容

| 文件 | 说明 |
|---|---|
| `patches/0001..00NN.patch` | 完整改动集。工作副本里的一切（`rime/`、构建脚本、文档、测试）都由它生成 |
| `BASE-COMMIT.txt` | 补丁基于哪个上游提交 |
| `EXPECTED-TREE.txt` | 打完补丁后应有的 `tree` hash，`setup.ps1` 用它校验重建结果 |
| `setup.ps1` | 重建工作副本 |
| `resync.ps1` | 同步上游并重新导出补丁 |
| `release.ps1` | 把工作副本里打好的包发成 GitHub Release |
| `RELEASE-NOTES.md` | Release 说明（发版时作为正文） |

## 发 Release（二进制包）

编译好的安装包体积约 9 MB，不放进 git，而是作为 **Release 附件**上传
—— 这样仓库始终只维护补丁与脚本。

```powershell
# 1) 在工作副本里出包
cd ..\weasel
.\build-rewrite.cmd
pwsh -NoProfile -File .\package-rewrite.ps1      # 生成 dist\Weasel-Rewrite-UI-Floating-Preview.zip

# 2) 准备令牌（推荐 fine-grained PAT，只勾本仓库的 Contents: Read and write）
#    不要把它写进任何文件或贴到对话里
$env:GITHUB_TOKEN = '<你的令牌>'

# 3) 发版（先加 -WhatIf 预览）
cd ..\weasel-ui-patch
pwsh -NoProfile -File .\release.ps1 -Tag '你的新版本标签' -Asset ..\weasel\dist\Weasel-Rewrite-UI-Floating-Preview.zip -WhatIf
pwsh -NoProfile -File .\release.ps1 -Tag '你的新版本标签' -Asset ..\weasel\dist\Weasel-Rewrite-UI-Floating-Preview.zip
```

不改脚本也可以，直接走网页：**Releases → Draft a new release** → 选 tag →
正文粘贴 `RELEASE-NOTES.md` → 把 `weasel\dist\Weasel-Rewrite-UI-Floating-Preview.zip` 拖进附件区 →
Publish release。

## 两个必须知道的坑

上游仓库里的 blob **行尾是不一致的**：`RimeWithWeasel/RimeWithWeasel.cpp` 是
CRLF + BOM，`WeaselUI/DirectWriteResources.cpp` 却是纯 LF。因此：

1. **本仓库的 `.gitattributes` 必须是 `* -text`**（已配置，别删）。
   否则全局 `core.autocrlf=true` 会在 `git add` 时把补丁里那些 CRLF 内容行
   规范化成 LF —— 补丁被改坏、打上去必然失败，而且**从文件大小上看不出来**。
   顺序很重要：**先 `.gitattributes`，再提交补丁**。
2. **`git clone` 上游时必须带 `--config core.autocrlf=false`**（要在 checkout
   之前生效），否则工作区行尾与补丁不一致。
3. **必须用 `git am --keep-cr`**。`git am` 内部先经过 `git mailsplit`，
   而 mailsplit 默认剥掉内容行末尾的 CR，CRLF 补丁就再也对不上。
   （`git apply` 不走 mailsplit，所以它单独测是通的，这点很容易误判。）

三条都已经写在 `setup.ps1` / `resync.ps1` 里，手工操作时别忘了。
另外 `setup.ps1` 会用 `EXPECTED-TREE.txt` 校验重建结果，任何行尾损坏都会立刻暴露。

## 完整文档

`README.md`、`REWRITE-UI.md`、`agent.md` 都在**工作副本**里（它们本身也是补丁的一部分），
跑完 `setup.ps1` 就能看到：

- `..\weasel\README.md` —— 这个补丁是什么、怎么用
- `..\weasel\REWRITE-UI.md` —— 安装、验证情况、构建基线、已知遗留
- `..\weasel\agent.md` —— 完整开发记录与约定（设计、踩坑、冲突热点、结构演进取舍）

## 许可

基于 [rime/weasel](https://github.com/rime/weasel) 修改，沿用其 **GPLv3**。
上游的 `LICENSE.txt` 与作者名单随源码一起由 `setup.ps1` 取回。
万象 Pro 词库与方案数据不属于本项目，也不随补丁分发。
