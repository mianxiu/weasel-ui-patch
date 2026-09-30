> **2026-09-30 当前分发包：** dist 已清理，只保留 weasel/dist/Weasel-Rewrite-UI-Floating-Preview 文件夹及同名 ZIP。运行 Apply-Patch.cmd 更新完整补丁；同一文件夹内 Apply-Skin.cmd 使用原蓝色，Apply-Skin-navy.cmd / Apply-Skin-black.cmd / Apply-Skin-green.cmd 分别切换深蓝、深黑、深绿。次要候选 hover 使用深色强调文字，正式选中保持白字；hover 修复需要安装本次程序。四种配色的真实 librime 部署、原生 UI 回归和分发包校验通过。

> **紧凑贴合 Tab 标签：** 字号按旧皮肤备份恢复为 12pt（候选、编号、注释）。Tab 标签 padding 6×2px、圆角 6px、无独立阴影、末尾预留 48px；与候选左边缘对齐并重叠 2px。连接处取消圆角与内横边，外侧保留圆角，形成上下可翻转的混合轮廓。仍使用独立窗口，保持候选内容布局和高度；退出 Tab 后候选恢复完整圆角。32/64 位构建、连接轮廓/DPI/原生窗口回归、四种配色真实 librime 部署测试通过。Build-ID：rewrite-ui-compact-joined-editor-20260930。

> **悬浮声调预览版：** 行内输入已恢复旧版。Tab 时显示万象词典声调全拼、小字号和独立圆角上标编号；序号及替换输入在末尾。没有可靠拼音时回退原始编码。皮肤定义在 rime/skins/azure_pill*.yaml。皮肤部署参数空格问题已修复。当前为本地预览分支，稳定线上 Release 保持原有版本。

# weasel-ui-patch

为 Windows 小狼毫（Weasel）加「未上屏编码快速重写」**原生 UI** 的个人补丁集。

**这个仓库只有补丁，没有上游源码** —— 全部内容约 300 KB。
上游 [rime/weasel](https://github.com/rime/weasel) 的源码由 `setup.ps1`
在需要时从官方 clone（公开永久，几秒）。

> **个人自用，不向上游提 PR。**

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
.\dist\Weasel-Rewrite-UI\Apply-Patch.cmd

# 4. 注销并重新登录 Windows
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

编译好的安装包体积约 8.7 MB，不放进 git，而是作为 **Release 附件**上传
—— 这样仓库始终只有几百 KB。

```powershell
# 1) 在工作副本里出包
cd ..\weasel
.\build-rewrite.cmd
pwsh -NoProfile -File .\package-rewrite.ps1      # 生成 dist\Weasel-Rewrite-UI.zip

# 2) 准备令牌（推荐 fine-grained PAT，只勾本仓库的 Contents: Read and write）
#    不要把它写进任何文件或贴到对话里
$env:GITHUB_TOKEN = '<你的令牌>'

# 3) 发版（先加 -WhatIf 预览）
cd ..\weasel-ui-patch
pwsh -NoProfile -File .\release.ps1 -Tag v0.17.4.1-rewrite-ui -WhatIf
pwsh -NoProfile -File .\release.ps1 -Tag v0.17.4.1-rewrite-ui
```

不改脚本也可以，直接走网页：**Releases → Draft a new release** → 选 tag →
正文粘贴 `RELEASE-NOTES.md` → 把 `weasel\dist\Weasel-Rewrite-UI.zip` 拖进附件区 →
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
