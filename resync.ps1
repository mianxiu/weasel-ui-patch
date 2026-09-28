# 同步上游并重新导出补丁。
#
#   cd weasel-ui-patch
#   pwsh -NoProfile -File .\resync.ps1              # fetch + rebase + 重新导出
#   pwsh -NoProfile -File .\resync.ps1 -ExportOnly  # 只重新导出（改完代码、没动上游）
#   pwsh -NoProfile -File .\resync.ps1 -Push        # 顺带提交并推送补丁仓库
#
# 遇到冲突时脚本会停下，你手工解决后：
#   cd ..\weasel ; git add <文件> ; git rebase --continue
#   cd ..\weasel-ui-patch ; pwsh -NoProfile -File .\resync.ps1 -ExportOnly
[CmdletBinding()]
param(
  [string]$WorkDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'weasel'),
  [string]$UpstreamRef = 'upstream/master',
  [switch]$ExportOnly,
  [switch]$NoFetch,
  [switch]$Push
)
$ErrorActionPreference = 'Stop'

if (!(Test-Path -LiteralPath (Join-Path $WorkDir '.git'))) {
  throw "工作副本不存在或不是 git 仓库：$WorkDir`n先跑 setup.ps1。"
}

# ---------------------------------------------------------------- 1. 同步上游
if (!$ExportOnly) {
  $dirty = (& git -C $WorkDir status --porcelain)
  if ($dirty) {
    throw "工作副本有未提交的改动，先提交或 stash：`n$dirty"
  }
  if (!$NoFetch) {
    Write-Host "fetch upstream..."
    & git -C $WorkDir fetch --quiet upstream
    if ($LASTEXITCODE -ne 0) { throw "git fetch upstream 失败" }
  }
  $behind = [int](& git -C $WorkDir rev-list --count "HEAD..$UpstreamRef")
  Write-Host ("落后 {0} 个上游提交" -f $behind)
  if ($behind -gt 0) {
    Write-Host "rebase 到 $UpstreamRef ..."
    $rb = & git -C $WorkDir rebase $UpstreamRef 2>&1
    if ($LASTEXITCODE -ne 0) {
      Write-Host ($rb | Out-String)
      Write-Host ""
      Write-Host "有冲突，脚本停下。处理办法："
      Write-Host "  1. cd `"$WorkDir`""
      Write-Host "  2. 编辑冲突文件（找 <<<<<<< ======= >>>>>>>），git add 它们"
      Write-Host "  3. git rebase --continue"
      Write-Host "  4. 回到补丁仓库重新导出：pwsh -NoProfile -File .\resync.ps1 -ExportOnly"
      Write-Host "  想放弃：git rebase --abort"
      throw "rebase 冲突"
    }
    Write-Host "rebase 完成"
  }
  else { Write-Host "上游没有新提交" }
}

# ------------------------------------------------------------ 2. 重新导出补丁
$base = (& git -C $WorkDir rev-parse $UpstreamRef).Trim()
$tree = (& git -C $WorkDir rev-parse 'HEAD^{tree}').Trim()

$oldBase = $null; $oldTree = $null
try { $oldBase = (Get-Content (Join-Path $PSScriptRoot 'BASE-COMMIT.txt') | Where-Object { $_ -and -not $_.StartsWith('#') } | Select-Object -First 1).Trim() } catch { }
try { $oldTree = (Get-Content (Join-Path $PSScriptRoot 'EXPECTED-TREE.txt') | Where-Object { $_ -and -not $_.StartsWith('#') } | Select-Object -First 1).Trim() } catch { }

if ($base -eq $oldBase -and $tree -eq $oldTree) {
  Write-Host "补丁已经是最新的（基线与 tree hash 都没变），无需导出。"
  if (!$Push) { return }
  Write-Host "仍按 -Push 处理..."
}

$patchDir = Join-Path $PSScriptRoot 'patches'
Write-Host "重新导出补丁到 patches\ ..."
Get-ChildItem -LiteralPath $patchDir -Filter '*.patch' -File -ErrorAction SilentlyContinue | Remove-Item -Force
& git -C $WorkDir format-patch "$base..HEAD" --quiet -o $patchDir
if ($LASTEXITCODE -ne 0) { throw "git format-patch 失败" }
$n = (Get-ChildItem -LiteralPath $patchDir -Filter '*.patch' -File | Measure-Object).Count

Set-Content -LiteralPath (Join-Path $PSScriptRoot 'BASE-COMMIT.txt') -Encoding ascii -Value @(
  '# 补丁基于的上游提交；resync.ps1 会在 rebase 后更新这里',
  $base
)
Set-Content -LiteralPath (Join-Path $PSScriptRoot 'EXPECTED-TREE.txt') -Encoding ascii -Value @(
  '# 应用完 patches/ 之后工作副本应有的 tree hash；setup.ps1 用它校验重建结果',
  $tree
)

Write-Host ("  补丁 {0} 个" -f $n)
$fromLabel = if ($oldBase) { $oldBase.Substring(0,8) } else { '(无)' }
Write-Host ("  基线 {0} → {1}" -f $fromLabel, $base.Substring(0,8))
Write-Host ("  tree {0}" -f $tree)

$isRepo = Test-Path -LiteralPath (Join-Path $PSScriptRoot '.git')
if ($isRepo) {
  Write-Host ""
  Write-Host "请自检后提交："
  & git -C $PSScriptRoot status --short
}

if ($Push) {
  & git -C $PSScriptRoot add -A
  if ($LASTEXITCODE -ne 0) { throw "git add 失败" }
  & git -C $PSScriptRoot commit -m ("patches: rebase onto upstream {0}" -f $base.Substring(0,8)) 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { Write-Warning "没有需要提交的改动" }
  # 用 -u origin HEAD：本地分支若没配 upstream，裸 git push 会直接失败
  & git -C $PSScriptRoot push -u origin HEAD
  if ($LASTEXITCODE -ne 0) { throw "git push 失败（改动已在本地提交，请手动推送）" }
  Write-Host "已提交并推送"
}
else {
  Write-Host ""
  Write-Host "确认无误后："
  Write-Host "  git add -A ; git commit -m 'patches: ...' ; git push"
  Write-Host "（或者下次加 -Push 让脚本代劳）"
}
