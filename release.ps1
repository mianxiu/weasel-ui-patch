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
$sums = Join-Path $assetItem.DirectoryName 'Weasel-Rewrite-UI\SHA256SUMS.txt'
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
  $secure = Read-Host -Prompt 'GitHub 令牌（输入不回显）' -AsSecureString
  $token = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
             [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
}
if (!$token) { throw "没有拿到令牌" }

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
  name       = $ReleaseName
  body       = $notes
  draft      = [bool]$Draft
  prerelease = [bool]$Prerelease
} | ConvertTo-Json -Depth 4

$release = Invoke-RestMethod -Method Post -Headers $headers -ContentType 'application/json' `
  -Uri "https://api.github.com/repos/$Owner/$Repo/releases" -Body $payload
Write-Host ("  已创建: " + $release.html_url)

# --------------------------------------------------------------- 上传附件
Write-Host "上传附件 ..."
$uploadUri = "https://uploads.github.com/repos/$Owner/$Repo/releases/$($release.id)/assets?name=$([uri]::EscapeDataString($assetItem.Name))"
$asset = Invoke-RestMethod -Method Post -Headers $headers -ContentType 'application/zip' `
  -Uri $uploadUri -InFile $assetItem.FullName
Write-Host ("  已上传: {0}  ({1:N1} MB)" -f $asset.name, ($asset.size / 1MB))
Write-Host ("  下载地址: " + $asset.browser_download_url)

Write-Host ""
Write-Host "完成。"
Write-Host ("  release 页面: " + $release.html_url)
Write-Host "  如果显示的是 draft，去网页上点 Publish release。"
