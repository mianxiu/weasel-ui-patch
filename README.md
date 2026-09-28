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
# 2. 把 Rime 侧文件装进用户目录
pwsh -NoProfile -File ..\weasel\rime\install-rime-files.ps1 -Apply

# 3. 编译并安装（构建还需要不被 git 跟踪的 weasel.props 与 deps\）
cd ..\weasel
.\build-rewrite.cmd
pwsh -NoProfile -File .\package-rewrite.ps1
.\Apply-Patch.cmd

# 4. 让配置生效
& 'C:\Program Files\Rime\weasel-0.17.4\WeaselDeployer.exe' /deploy
& 'C:\Program Files\Rime\weasel-0.17.4\WeaselServer.exe' /quit
Start-Process 'C:\Program Files\Rime\weasel-0.17.4\WeaselServer.exe'

# 5. 注销并重新登录 Windows
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

## 两个必须知道的坑

上游仓库里的 blob **行尾是不一致的**：`RimeWithWeasel/RimeWithWeasel.cpp` 是
CRLF + BOM，`WeaselUI/DirectWriteResources.cpp` 却是纯 LF。因此：

1. **`git clone` 时必须带 `--config core.autocrlf=false`**（在 checkout 之前生效），
   否则工作区行尾与补丁不一致，补丁会以 `patch does not apply` 失败。
2. **必须用 `git am --keep-cr`**。`git am` 内部先经过 `git mailsplit`，
   而 mailsplit 默认剥掉内容行末尾的 CR，CRLF 补丁就再也对不上。
   （`git apply` 不走 mailsplit，所以它单独测是通的，这点很容易误判。）

两个参数都已经写在 `setup.ps1` 里，手工操作时别忘了。

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
