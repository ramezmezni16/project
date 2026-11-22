
$ip = Get-NetIPConfiguration |
    Where-Object {
        $_.IPv4DefaultGateway -ne $null -and
        $_.IPv4Address -ne $null
    } |
    Select-Object -First 1 -ExpandProperty IPv4Address |
    Select-Object -First 1 -ExpandProperty IPAddress

if (-not $ip) {
    Write-Host "Could not detect your local IP. Run ipconfig and check your Wi-Fi IPv4 address."
    exit 1
}

Write-Host "Using API: http://${ip}:8000"

Set-Location "$PSScriptRoot\livestock_app"

flutter run --dart-define="API_BASE_URL=http://${ip}:8000"
