<#
.SYNOPSIS
  Build APK của app Flutter trỏ tới backend qua ngrok.

.EXAMPLE
  .\build-apk.ps1 -Domain ten-cua-ban.ngrok-free.app

.NOTES
  Cần Flutter và Android SDK (flutter doctor phải báo Android toolchain xanh).
  Địa chỉ được nhúng vào APK lúc build; dùng tên miền ngrok tĩnh thì không phải build lại mỗi lần.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Domain
)

$ErrorActionPreference = 'Stop'
$Domain = $Domain -replace '^https?://', '' -replace '/+$', ''
$frontend = Resolve-Path (Join-Path $PSScriptRoot '..\..\frontend')

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Chưa có 'flutter' trong PATH."
}

Push-Location $frontend
try {
    flutter build apk --release `
        "--dart-define=API_BASE_URL=https://$Domain/api/v1" `
        "--dart-define=SOCKET_URL=https://$Domain"
    if ($LASTEXITCODE -ne 0) { throw "flutter build apk thất bại (mã $LASTEXITCODE)." }
}
finally {
    Pop-Location
}

$apk = Join-Path $frontend 'build\app\outputs\flutter-apk\app-release.apk'
Write-Host ''
Write-Host "Xong. File APK: $apk"
Write-Host 'Gửi file sang điện thoại (cáp USB, Zalo, Drive...), bật "cài từ nguồn không rõ" rồi cài.'
