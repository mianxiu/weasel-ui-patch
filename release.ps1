# 把 dist 包发成 GitHub Release。
#
#   # 1) 先在本地准备一个令牌（不要贴到任何对话里）
#   #    推荐 fine-grained PAT，只勾这一个仓库的 Contents: Read and write
#   $env:GITHUB_TOKEN = '<你的令牌>'
#
#   # 2) 发版
#   pwsh -NoProfile -File .\release.ps1 -Tag v0.17.4.1-rewrite-ui
#
#   # 只预览、不上传：
#   pwsh -NoProfile -File .\release.ps1 -Tag v0.17.4.1-rewrite-ui -WhatIf
#
# 不带 -Token 时会用安全方式提示输入（不回显、不进历史记录）。
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Tag,
  [string]$ReleaseName,
  [string]$NotesFile = (Join-Path $PSScriptRoot 'RELEASE-NOTES.md'),
  [string]$Asset = (Join-Path (Split-Path $PSScriptRoot -Parent) 'weasel\dist\Weasel-Rewrite-UI.zip'),
  [string]$Owner = 'mianxiu',
  [string]$Repo = 'weasel-ui-patch',
  [string]$TargetCommitish = 'main',
  [switch]$Prerelease,
  [switch]$Draft,
  [switch]$WhatIf
)
$ErrorActionPreference = 'Stop'

if (!$ReleaseName) { $ReleaseName = $Tag }

# ------------------------------------------------------------------ 前置检查
if (!(Test-Path -LiteralPath $Asset)) {
  throw "找不到要上传的文件：$Asset`n先在工作副本里跑 package-rewrite.ps1 出包。"
}
$assetItem = Get-Item -LiteralPath $Asset
if (!(Test-Path -LiteralPath $NotesFile)) { throw "找不到 release 说明：$NotesFile" }
$notes = Get-Content -LiteralPath $NotesFile -Raw
if (!$notes.Trim()) { throw "release 说明是空的：$NotesFile" }

Write-Host "仓库      : $Owner/$Repo"
Write-Host "Tag       : $Tag"
Write-Host "Release 名: $ReleaseName"
Write-Host ("附件      : {0}  ({1:N1} MB)" -f $assetItem.Name, ($assetItem.Length / 1MB))
Write-Host ("说明      : {0}  ({1} 字符)" -f (Split-Path $NotesFile -Leaf), $notes.Length)
Write-Host ("草稿/预发布: draft={0} prerelease={1}" -f [bool]$Draft, [bool]$Prerelease)

# 顺便报一下包的身份，避免发错东西
$sums = Join-Path (Join-Path $assetItem.DirectoryName $assetItem.BaseName) 'SHA256SUMS.txt'
if (Test-Path $sums) {
  $serverHash = (Get-Content $sums | Where-Object { $_ -match 'WeaselServer\.exe$' } | Select-Object -First 1)
  if ($serverHash) { Write-Host ("包内 WeaselServer.exe: " + ($serverHash -split '\s+')[0].Substring(0,16) + '…') }
}

if ($WhatIf) {
  Write-Host ""
  Write-Host "预览模式（-WhatIf），没有做任何请求。"
  return
}

# ------------------------------------------------------------------ 取令牌
$token = $env:GITHUB_TOKEN
if (!$token) {
  $credentialText = "protocol=https`nhost=github.com`n`n" | git credential fill 2>$null
  if ($LASTEXITCODE -eq 0) {
    foreach ($line in $credentialText) {
      if ($line -match '^password=(.+)$') { $token = $Matches[1]; break }
    }
  }
}
if (!$token) { throw '请先配置本机 GitHub 登录，或设置 GITHUB_TOKEN；不要将令牌发送到对话中。' }

$headers = @{
  Authorization          = "Bearer $token"
  Accept                 = 'application/vnd.github+json'
  'User-Agent'           = 'weasel-ui-patch-release'
  'X-GitHub-Api-Version' = '2022-11-28'
}

# ------------------------------------------------------------- 创建 release
# 先看 tag 是否已经有 release，避免重复
try {
  $existing = Invoke-RestMethod -Method Get -Headers $headers `
    -Uri "https://api.github.com/repos/$Owner/$Repo/releases/tags/$Tag"
  if ($existing) {
    throw "tag $Tag 已经有一个 release 了：$($existing.html_url)`n换一个 tag，或先在网页上删掉旧的。"
  }
} catch {
  if ($_.Exception.Response.StatusCode.value__ -ne 404) { throw }
}

Write-Host ""
Write-Host "创建 release ..."
$payload = @{
  tag_name   = $Tag
  target_commitish = $TargetCommitish
  name       = $ReleaseName
  body       = $notes
  draft      = $true
  prerelease = [bool]$Prerelease
} | ConvertTo-Json -Depth 4

$release = Invoke-RestMethod -Method Post -Headers $headers -ContentType 'application/json' `
  -Uri "https://api.github.com/repos/$Owner/$Repo/releases" -Body $payload
Write-Host ("  已创建: " + $release.html_url)

# --------------------------------------------------------------- 上传附件
Write-Host "上传附件 ..."
$uploadUri = "https://uploads.github.com/repos/$Owner/$Repo/releases/$($release.id)/assets?name=$([uri]::EscapeDataString($assetItem.Name))"
try {
  Invoke-RestMethod -Method Post -Headers $headers -ContentType 'application/zip' `
    -Uri $uploadUri -InFile $assetItem.FullName | Out-Null
}
catch {
  throw "附件上传失败，Release 保持草稿：$($release.html_url)。$($_.Exception.Message)"
}

# 不要相信 POST 的响应体（实测可能返回空对象），重新拉一次列表来核对
$assets = @(Invoke-RestMethod -Method Get -Headers $headers `
  -Uri "https://api.github.com/repos/$Owner/$Repo/releases/$($release.id)/assets")
$mine = $assets | Where-Object { $_.name -eq $assetItem.Name } | Select-Object -First 1
if (!$mine) {
  throw "上传后没在附件列表里找到 $($assetItem.Name)，请到网页上确认：$($release.html_url)"
}
if ($mine.size -ne $assetItem.Length) {
  throw "附件大小不符：远端 $($mine.size) 字节 / 本地 $($assetItem.Length) 字节"
}
if ($mine.state -ne 'uploaded') { throw '附件尚未完成上传，Release 保持草稿。' }
if ($mine.digest) {
  $localDigest = 'sha256:' + (Get-FileHash -LiteralPath $Asset -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($mine.digest -ne $localDigest) { throw '远端附件 SHA256 不符，Release 保持草稿。' }
}
Write-Host ("  已上传并核对: {0}  ({1:N1} MB, state={2})" -f $mine.name, ($mine.size / 1MB), $mine.state)
Write-Host ("  下载地址: " + $mine.browser_download_url)
if (!$Draft) {
  $publish = @{draft=$false; make_latest= if ($Prerelease) { 'false' } else { 'true' }} | ConvertTo-Json
  $release = Invoke-RestMethod -Method Patch -Headers $headers -ContentType 'application/json' `
    -Uri "https://api.github.com/repos/$Owner/$Repo/releases/$($release.id)" -Body $publish
  if ($release.draft) { throw 'Release 发布后仍是草稿，请检查 GitHub 状态。' }
}

Write-Host ""
Write-Host "完成。"
Write-Host ("  release 页面: " + $release.html_url)
Write-Host "  如果显示的是 draft，去网页上点 Publish release。"
