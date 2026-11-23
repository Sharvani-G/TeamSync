# Simple Local Wi-Fi APK Server
# Run this script to easily download the APK onto your Android phone connected to the same Wi-Fi.

$port = 8080
$apkPath = "dist\android\TeamSync-Android-Testing.apk"

if (-not (Test-Path $apkPath)) {
    Write-Host "[-] APK not found at $apkPath" -ForegroundColor Red
    exit 1
}

# Get local IP address
$localIp = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi*', 'Ethernet*' -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' } |
            Select-Object -First 1).IPAddress

if (-not $localIp) {
    $localIp = "localhost"
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "TeamSync APK Wi-Fi Download Server" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Ensure your Android phone is on the same Wi-Fi network as this PC." -ForegroundColor Yellow
Write-Host "2. Open Chrome or any browser on your Android phone." -ForegroundColor Yellow
Write-Host "3. Navigate to:" -ForegroundColor Yellow
Write-Host "   http://$($localIp):$port/download" -ForegroundColor Green
Write-Host ""
Write-Host "Press Ctrl+C to stop the server when download is finished." -ForegroundColor Gray
Write-Host ""

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://*:$port/")
try {
    $listener.Start()
} catch {
    # If wildcard binding fails due to permissions, bind to localhost/IP
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://$($localIp):$port/")
    $listener.Start()
}

Write-Host "[+] Server is listening on port $port..." -ForegroundColor Green

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    if ($request.Url.AbsolutePath -eq "/download" -or $request.Url.AbsolutePath -eq "/TeamSync.apk") {
        Write-Host "[+] Sending APK to $($request.RemoteEndPoint.Address)..." -ForegroundColor Cyan
        $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $apkPath).Path)
        $response.ContentType = "application/vnd.android.package-archive"
        $response.AddHeader("Content-Disposition", "attachment; filename=TeamSync-Testing.apk")
        $response.ContentLength64 = $bytes.Length
        $response.OutputStream.Write($bytes, 0, $bytes.Length)
        $response.OutputStream.Close()
        Write-Host "[OK] APK downloaded successfully by $($request.RemoteEndPoint.Address)" -ForegroundColor Green
    } else {
        $html = "<html><body style='font-family:sans-serif;text-align:center;padding:50px;'>" +
                "<h1>TeamSync Android APK</h1>" +
                "<p>Tap below to download the application directly to your Android device:</p>" +
                "<a href='/download' style='display:inline-block;padding:16px 32px;background:#074ce0;color:#fff;border-radius:8px;text-decoration:none;font-weight:bold;font-size:18px;'>Download TeamSync APK (47.4 MB)</a>" +
                "</body></html>"
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
        $response.ContentType = "text/html"
        $response.ContentLength64 = $buffer.Length
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
        $response.OutputStream.Close()
    }
}

