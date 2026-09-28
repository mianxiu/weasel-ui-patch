# 从补丁系列重建工作副本。
#
#   git clone https://github.com/mianxiu/weasel-ui-patch.git
#   cd weasel-ui-patch
#   pwsh -NoProfile -File .\setup.ps1
#
# 做四件事：clone 官方 weasel → 检出补丁基线 → git am --keep-cr 打上补丁
#           → 初始化 librime submodule
#
# 【重要】两个参数不能省：
#   --config core.autocrlf=false  必须在检出前设好，否则工作区行尾与补丁不一致
#   git am --keep-cr              mailsplit 默认会剥掉内容行的 CR，导致 CRLF 补丁打不上
# 上游仓库里 CRLF 与 LF 的 blob 是混着的（RimeWithWeasel.cpp 是 CRLF+BOM，
# DirectWriteResources.cpp 是纯 LF），所以这两条是必需的，不是保险。
[CmdletBinding()]
param(
  [string]$WorkDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'weasel'),
  [string]$UpstreamUrl = 'https://github.com/rime/weasel.git',
  [switch]$SkipSubmodules,
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
$patchDir = Join-Path $PSScriptRoot 'patches'

function Read-MetaFile([string]$name) {
  $p = Join-Path $PSScriptRoot $name
  if (!(Test-Path -LiteralPath $p)) { throw "缺少 $name" }
  $line = (Get-Content -LiteralPath $p | Where-Object { $_ -and -not $_.StartsWith('#') } | Select-Object -First 1)
  if (!$line) { throw "$name 里没有有效内容" }
  return $line.Trim()
}

$base = Read-MetaFile 'BASE-COMMIT.txt'
$expectedTree = $null
try { $expectedTree = Read-MetaFile 'EXPECTED-TREE.txt' } catch { }

$patchFiles = @(Get-ChildItem -LiteralPath $patchDir -Filter '*.patch' -File -ErrorAction SilentlyContinue |
                Sort-Object Name | ForEach-Object { $_.FullName })
if ($patchFiles.Count -eq 0) { throw "patches\ 里没有补丁文件" }

Write-Host "补丁仓库   : $PSScriptRoot"
Write-Host "工作副本   : $WorkDir"
Write-Host "上游       : $UpstreamUrl"
Write-Host "基线提交   : $base"
Write-Host ("补丁数量   : {0}" -f $patchFiles.Count)
Write-Host ""

if (Test-Path -LiteralPath $WorkDir) {
  if (!$Force) {
    throw "目标目录已存在：$WorkDir`n如果确认要重建（会删掉现有内容），加 -Force；`n如果只是想同步上游，用 resync.ps1。"
  }
  Write-Host "删除已存在的目标目录（-Force）..."
  Remove-Item -LiteralPath $WorkDir -Recurse -Force
}

# 1) clone：--config 会在 fetch/checkout 之前写入新仓库的配置
Write-Host "[1/5] clone 官方 weasel（约 19 MB，几秒）..."
& git clone --config core.autocrlf=false --quiet $UpstreamUrl $WorkDir
if ($LASTEXITCODE -ne 0) { throw "git clone 失败" }

# 2) 检出基线并建本地主线分支
Write-Host "[2/5] 检出基线 $($base.Substring(0,8))..."
& git -C $WorkDir checkout --quiet -B main $base
if ($LASTEXITCODE -ne 0) { throw "git checkout 失败" }

# 3) 打补丁（--keep-cr 必需）
Write-Host "[3/5] 应用补丁（git am --keep-cr）..."
$amOut = & git -C $WorkDir am --keep-cr @patchFiles 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Host ($amOut | Out-String)
  Write-Host "补丁没能干净应用。可能原因：上游在补丁涉及的位置改过代码。"
  Write-Host "手工处理：cd `"$WorkDir`" ; 修冲突 ; git add ; git am --continue"
  throw "git am 失败"
}
Write-Host ("      {0} 个补丁全部应用成功" -f $patchFiles.Count)

# 4) 校验重建结果
$actualTree = (& git -C $WorkDir rev-parse 'HEAD^{tree}').Trim()
Write-Host "[4/5] 校验 tree hash..."
Write-Host "      期望 $expectedTree"
Write-Host "      实际 $actualTree"
if ($expectedTree -and $actualTree -ne $expectedTree) {
  throw "重建出来的树与 EXPECTED-TREE.txt 不一致 —— 不要继续编译，先查清原因"
}
if ($expectedTree) { Write-Host "      ✓ 完全一致" }

# 5) submodule（构建需要 librime/include）
if (!$SkipSubmodules) {
  Write-Host "[5/5] 初始化 submodule（构建需要 librime 的头文件）..."
  & git -C $WorkDir submodule update --init --recursive --quiet
  if ($LASTEXITCODE -ne 0) { Write-Warning "submodule 初始化失败；构建前需要手动 git submodule update --init --recursive" }
}
else { Write-Host "[5/5] 跳过 submodule（-SkipSubmodules）" }

# 工作副本不该被推送：把 origin 改名成 upstream
& git -C $WorkDir remote rename origin upstream 2>$null
if ($LASTEXITCODE -ne 0) { & git -C $WorkDir remote add upstream $UpstreamUrl 2>$null }

Write-Host ""
Write-Host "重建完成。工作副本的 remote 只有 upstream（没有 origin，避免误推 19 MB 历史）。"
Write-Host ""
Write-Host "后续步骤："
Write-Host "  1. 装好小狼毫与万象 Pro，准备好词库"
Write-Host "  2. pwsh -NoProfile -File `"$WorkDir\rime\install-rime-files.ps1`" -Apply"
Write-Host "  3. cd `"$WorkDir`" ; .\build-rewrite.cmd"
Write-Host "     （构建还需要不被 git 跟踪的 weasel.props 与 deps\，见 REWRITE-UI.md）"
Write-Host "  4. pwsh -NoProfile -File .\package-rewrite.ps1"
Write-Host "  5. .\Apply-Patch.cmd"
Write-Host "  6. WeaselDeployer.exe /deploy，然后重启 WeaselServer.exe"
Write-Host "  7. 注销并重新登录 Windows"
Write-Host ""
Write-Host "上游发新版后用 resync.ps1 同步。"
