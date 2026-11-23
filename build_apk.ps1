# TeamSync Release APK Builder (PowerShell for Windows)
# Execute this script once Flutter SDK, Git, JDK 17, and Android SDK are installed.

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "TeamSync Android APK Builder" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check Git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[-] Git for Windows not found in PATH." -ForegroundColor Red
    Write-Host "    Please install Git from: https://git-scm.com/download/win" -ForegroundColor Yellow
    exit 1
}

# Check Flutter
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "[-] Flutter SDK not found in PATH." -ForegroundColor Red
    Write-Host "    Please install Flutter SDK (>=3.38.0) and add to PATH." -ForegroundColor Yellow
    Write-Host "    Guide: https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Yellow
    exit 1
}

# Check ANDROID_HOME
if (-not $env:ANDROID_HOME -and -not (Test-Path "$env:LOCALAPPDATA\Android\Sdk")) {
    Write-Host "[-] Android SDK not found. Set ANDROID_HOME or install Android Studio / Command-line Tools." -ForegroundColor Red
    exit 1
}

if (-not $env:ANDROID_HOME -and (Test-Path "$env:LOCALAPPDATA\Android\Sdk")) {
    $env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
}

Write-Host "[+] Flutter detected: $(flutter --version | Select-Object -First 1)" -ForegroundColor Green
Write-Host "[+] Android SDK: $env:ANDROID_HOME" -ForegroundColor Green
Write-Host ""

# Step 1: Health check
Write-Host "Step 1: Running flutter doctor..." -ForegroundColor Cyan
flutter doctor -v

# Step 2: Dependencies
Write-Host ""
Write-Host "Step 2: Resolving dependencies (flutter pub get)..." -ForegroundColor Cyan
flutter pub get

# Step 3: Static Analysis & Unit Tests
Write-Host ""
Write-Host "Step 3: Running static analyzer and tests..." -ForegroundColor Cyan
flutter analyze
flutter test

# Step 4: Build APK
Write-Host ""
Write-Host "Step 4: Compiling release APK..." -ForegroundColor Cyan
Write-Host "(This typically takes 3-10 minutes...)" -ForegroundColor Gray
flutter build apk --release

# Step 5: Deliver to dist/android/
Write-Host ""
Write-Host "Step 5: Packaging into dist/android/..." -ForegroundColor Cyan
if (-not (Test-Path "dist\android")) {
    New-Item -ItemType Directory -Force -Path "dist\android" | Out-Null
}

$sourceApk = "build\app\outputs\flutter-apk\app-release.apk"
$destApk = "dist\android\TeamSync-Android-Testing.apk"

if (Test-Path $sourceApk) {
    Copy-Item $sourceApk -Destination $destApk -Force
    $hash = (Get-FileHash $destApk -Algorithm SHA256).Hash
    $size = (Get-Item $destApk).Length
    $sizeMb = [math]::Round($size / 1MB, 2)

    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "[OK] APK BUILD AND DELIVERY COMPLETE!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "APK Location: $destApk" -ForegroundColor White
    Write-Host "File Size:    $size bytes ($sizeMb MB)" -ForegroundColor White
    Write-Host "SHA-256:      $hash" -ForegroundColor White
    Write-Host ""
    Write-Host "Refer to 'docs/ui-ux/manual-apk-testing-guide.md' for device installation and test execution." -ForegroundColor Cyan
} else {
    Write-Host "[-] Expected APK build output not found at: $sourceApk" -ForegroundColor Red
    exit 1
}

