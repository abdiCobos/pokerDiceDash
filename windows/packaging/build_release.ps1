# Builds the Windows release and packages it as a portable ZIP and (if Inno Setup 6 is
# installed) a setup .exe, both in dist/.  Run from the repository root:
#   powershell -ExecutionPolicy Bypass -File windows/packaging/build_release.ps1
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $root

$version = ((Select-String -Path pubspec.yaml -Pattern '^version:\s*([0-9.]+)').Matches[0].Groups[1].Value)
$name = "PokerDiceDash-$version-windows-x64"
$dist = Join-Path $root 'dist'
$stage = Join-Path $dist $name

flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'flutter build windows failed' }

if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force $stage | Out-Null
Copy-Item -Recurse 'build\windows\x64\runner\Release\*' $stage

# App-local Visual C++ runtime so the game starts on a PC without the redistributable.
foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
  Copy-Item (Join-Path $env:WINDIR "System32\$dll") $stage
}
Copy-Item 'LICENSE' (Join-Path $stage 'LICENSE.txt')
Copy-Item 'windows\packaging\LEEME.txt' $stage

$zip = Join-Path $dist "$name.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path $stage -DestinationPath $zip
Write-Host "ZIP: $zip"

$iscc = @(
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($iscc) {
  & $iscc "/DAppVersion=$version" "/DSourceDir=$stage" "/DOutputDir=$dist" 'windows\packaging\poker_dice_dash.iss'
  if ($LASTEXITCODE -ne 0) { throw 'Inno Setup failed' }
  Write-Host "Instalador: $(Join-Path $dist "PokerDiceDash-$version-setup.exe")"
} else {
  Write-Warning 'Inno Setup 6 no esta instalado: solo se genero el ZIP.'
}
