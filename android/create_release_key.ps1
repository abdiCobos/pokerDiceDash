# Creates the release signing key for the APK published on GitHub and writes
# android/key.properties (both stay out of git). Run it yourself: it asks for the
# password and nobody else ever sees it. F-Droid signs its own builds and does not use this key.
#   powershell -ExecutionPolicy Bypass -File android\create_release_key.ps1
$ErrorActionPreference = 'Stop'
$keyDir = Join-Path $env:USERPROFILE 'keys'
$keyFile = Join-Path $keyDir 'pokerdicedash-release.jks'
$props = Join-Path $PSScriptRoot 'key.properties'
if (Test-Path $keyFile) { throw "Ya existe $keyFile; no se sobrescribe." }

$keytool = @(
  "$env:JAVA_HOME\bin\keytool.exe",
  'C:\AndroidSDK\jdk-21.0.10.7-hotspot\bin\keytool.exe'
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $keytool) { $keytool = (Get-Command keytool -ErrorAction Stop).Source }

$p1 = Read-Host 'Contrasena para la clave (min. 6 caracteres)' -AsSecureString
$p2 = Read-Host 'Repite la contrasena' -AsSecureString
$plain1 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p1))
$plain2 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p2))
if ($plain1 -ne $plain2) { throw 'Las contrasenas no coinciden.' }
if ($plain1.Length -lt 6) { throw 'La contrasena debe tener al menos 6 caracteres.' }

New-Item -ItemType Directory -Force $keyDir | Out-Null
& $keytool -genkeypair -v -keystore $keyFile -storetype PKCS12 -alias pokerdicedash `
  -keyalg RSA -keysize 4096 -validity 10000 `
  -dname 'CN=abdiCobos, O=Poker Dice Dash' -storepass $plain1 -keypass $plain1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'keytool fallo.' }

@(
  "storeFile=$($keyFile -replace '\\', '/')",
  "storePassword=$plain1",
  'keyAlias=pokerdicedash',
  "keyPassword=$plain1"
) | Set-Content -Encoding ascii $props
$plain1 = $null; $plain2 = $null

Write-Host ''
Write-Host "Clave creada: $keyFile"
Write-Host "Configuracion: $props (no se sube a git)"
Write-Host 'IMPORTANTE: guarda una copia de la clave y su contrasena en un lugar seguro.'
Write-Host 'Sin ellas no podras publicar actualizaciones del APK de GitHub con la misma firma.'
