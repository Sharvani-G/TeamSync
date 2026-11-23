# TeamSync Remote Push & GitHub Actions Build Automator
# Usage:
#   .\push_and_build.ps1 -RepoOwner "YOUR_GITHUB_USERNAME" -RepoName "YOUR_REPO" -Token "YOUR_GITHUB_TOKEN"
# Or:
#   .\push_and_build.ps1 -RepoUrl "https://TOKEN@github.com/USERNAME/REPO.git"

param(
    [string]$RepoOwner,
    [string]$RepoName,
    [string]$Token,
    [string]$RepoUrl
)

$ErrorActionPreference = "Stop"
$env:PATH = "$pwd\.tools\git\cmd;$env:PATH"

if (-not $RepoUrl -and $RepoOwner -and $RepoName -and $Token) {
    $RepoUrl = "https://$($Token)@github.com/$RepoOwner/$RepoName.git"
} elseif ($RepoUrl -and $Token -and $RepoUrl -match "https://github.com/([^/]+)/([^/.]+)") {
    $RepoOwner = $matches[1]
    $RepoName = $matches[2]
    $RepoUrl = "https://$($Token)@github.com/$RepoOwner/$RepoName.git"
}

if (-not $RepoUrl) {
    Write-Host "Usage: .\push_and_build.ps1 -RepoOwner <username> -RepoName <repo> -Token <token>" -ForegroundColor Red
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "TeamSync Remote Push & Actions Builder" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Configure remote
$existingRemote = git remote get-url origin 2>$null
if ($existingRemote) {
    git remote set-url origin $RepoUrl
} else {
    git remote add origin $RepoUrl
}

Write-Host "[+] Pushing redesigned source code to remote repository..." -ForegroundColor Cyan
git push -u origin main --force

Write-Host "[+] Code successfully pushed!" -ForegroundColor Green
Write-Host "[+] Waiting 15 seconds for GitHub Actions to trigger build-apk.yml..." -ForegroundColor Gray
Start-Sleep -Seconds 15

# Poll for workflow run
$headers = @{
    "User-Agent" = "TeamSync-Builder"
}
if ($Token) {
    $headers["Authorization"] = "Bearer $Token"
}

$apiUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/actions/workflows/build-apk.yml/runs"
Write-Host "[+] Polling GitHub Actions status at: $apiUrl" -ForegroundColor Cyan

$run = $null
for ($i = 0; $i -30; $i++) {
    try {
        $resp = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get
        if ($resp.workflow_runs -and $resp.workflow_runs.Count -gt 0) {
            $run = $resp.workflow_runs[0]
            Write-Host "[+] Found active build run ID: $($run.id) (Status: $($run.status), Conclusion: $($run.conclusion))" -ForegroundColor Yellow
            if ($run.status -eq "completed") {
                break
            }
        }
    } catch {
        Write-Host "[-] Waiting for workflow run to register..." -ForegroundColor Gray
    }
    Start-Sleep -Seconds 15
}

if (-not $run) {
    Write-Host "[-] Timed out waiting for workflow run." -ForegroundColor Red
    exit 1
}

while ($run.status -ne "completed") {
    Write-Host "[*] Build in progress... current status: $($run.status) ($([datetime]::UtcNow.ToString('HH:mm:ss')) UTC)" -ForegroundColor Gray
    Start-Sleep -Seconds 20
    $runDetails = Invoke-RestMethod -Uri "https://api.github.com/repos/$RepoOwner/$RepoName/actions/runs/$($run.id)" -Headers $headers
    $run = $runDetails
}

if ($run.conclusion -ne "success") {
    Write-Host "[-] GitHub Actions build finished with conclusion: $($run.conclusion)" -ForegroundColor Red
    Write-Host "    Logs: $($run.html_url)" -ForegroundColor Yellow
    exit 1
}

Write-Host "[+] GitHub Actions build SUCCEEDED!" -ForegroundColor Green

# Fetch artifacts
$artifactsUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/actions/runs/$($run.id)/artifacts"
$artResp = Invoke-RestMethod -Uri $artifactsUrl -Headers $headers
$apkArt = $artResp.artifacts | Where-Object { $_.name -like "*apk*" } | Select-Object -First 1

if (-not $apkArt) {
    Write-Host "[-] No APK artifact found in completed build." -ForegroundColor Red
    exit 1
}

Write-Host "[+] Downloading APK artifact: $($apkArt.name) ($($apkArt.size_in_bytes) bytes)..." -ForegroundColor Cyan
$zipDest = "dist\android\apk_artifact.zip"
Invoke-WebRequest -Uri $apkArt.archive_download_url -Headers $headers -OutFile $zipDest

tar.exe -xf $zipDest -C "dist\android\"
if (Test-Path "dist\android\app-release.apk") {
    Move-Item -Path "dist\android\app-release.apk" -Destination "dist\android\TeamSync-Android-Testing.apk" -Force
}
Remove-Item $zipDest -Force -ErrorAction SilentlyContinue

$finalApk = "dist\android\TeamSync-Android-Testing.apk"
$hash = (Get-FileHash $finalApk -Algorithm SHA256).Hash
$size = (Get-Item $finalApk).Length
$sizeMb = [math]::Round($size / 1MB, 2)

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "[OK] REDESIGNED APK GENERATED AND VERIFIED!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Path:    $finalApk" -ForegroundColor White
Write-Host "Size:    $size bytes ($sizeMb MB)" -ForegroundColor White
Write-Host "SHA-256: $hash" -ForegroundColor White
Write-Host "Commit:  $($run.head_sha)" -ForegroundColor White

