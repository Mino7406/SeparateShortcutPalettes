<#
  Packages the release archive into out/.

  There is nothing to compile: the mod is one lua file. The archive holds it in the
  folder layout the game expects, plus a plain-text readme, so it can be extracted
  straight into the Monster Hunter Wilds folder.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root  = Split-Path -Parent $MyInvocation.MyCommand.Path
$out   = Join-Path $root 'out'
$stage = Join-Path $out 'stage'
$zip   = Join-Path $out 'SeparateShortcutPalettes.zip'

Remove-Item $stage, $zip -Recurse -Force -ErrorAction SilentlyContinue
$autorun = Join-Path $stage 'reframework\autorun'
New-Item -ItemType Directory -Force $autorun | Out-Null

Copy-Item (Join-Path $root 'lua\SeparateShortcutPalettes.lua') $autorun
Copy-Item (Join-Path $root 'dist\README.txt') $stage

# bsdtar (ships with Windows 10+) writes forward-slash paths, which every extractor
# understands; Compress-Archive in Windows PowerShell 5.1 writes backslashes.
Push-Location $stage
try {
    & tar.exe -a -c -f $zip reframework README.txt
    if ($LASTEXITCODE -ne 0) { throw 'tar failed' }
} finally {
    Pop-Location
}
Remove-Item $stage -Recurse -Force

Write-Host ("built : {0} ({1:N0} bytes)" -f $zip, (Get-Item $zip).Length) -ForegroundColor Green
