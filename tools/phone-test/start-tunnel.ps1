<#
.SYNOPSIS
  Mở đường hầm ngrok tới backend (qua Caddy) để điện thoại thật gọi được API và chat realtime.

.EXAMPLE
  .\start-tunnel.ps1 -Domain ten-cua-ban.ngrok-free.app

.NOTES
  Cần chạy backend (Spring Boot) trước, cổng 8080 và 9092. Dừng bằng Ctrl+C.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Domain
)

$ErrorActionPreference = 'Stop'
$Domain = $Domain -replace '^https?://', '' -replace '/+$', ''
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

foreach ($tool in 'caddy', 'ngrok') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "Chưa cài '$tool' (hoặc chưa có trong PATH). Xem README.md trong thư mục này."
    }
}

# Cảnh báo sớm nếu backend chưa chạy, thay vì để điện thoại báo lỗi khó hiểu.
foreach ($port in 8080, 9092) {
    $up = Test-NetConnection -ComputerName localhost -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue
    if (-not $up) {
        Write-Warning "Chưa thấy gì ở cổng $port. Hãy chạy backend trước (cổng 8080 là API, 9092 là chat realtime)."
    }
}

$caddy = Start-Process -FilePath 'caddy' -ArgumentList 'run', '--config', (Join-Path $here 'Caddyfile') `
    -PassThru -WindowStyle Hidden
Write-Host "Caddy đang chạy ở cổng 8000 (PID $($caddy.Id))."
Write-Host "API:    https://$Domain/api/v1"
Write-Host "Socket: https://$Domain"
Write-Host "Build APK: .\build-apk.ps1 -Domain $Domain"
Write-Host ''

try {
    # ngrok từ 3.16 dùng --url; các bản cũ hơn (vd. 3.3.x do winget cài) dùng --domain.
    $versionText = ((ngrok version) -join ' ')
    $flag = '--domain'
    if ($versionText -match '(\d+\.\d+\.\d+)' -and [version]$Matches[1] -ge [version]'3.16.0') {
        $flag = '--url'
    }
    ngrok http "$flag=$Domain" 8000
}
finally {
    if ($caddy -and -not $caddy.HasExited) {
        Stop-Process -Id $caddy.Id -Force
        Write-Host 'Đã dừng Caddy.'
    }
}
