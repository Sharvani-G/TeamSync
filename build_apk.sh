#!/bin/bash
# TeamSync APK Build Script
# Run this on a machine with Android Studio and Android SDK installed

set -e

echo "=========================================="
echo "TeamSync Release APK Builder"
echo "=========================================="
echo ""

# Check Flutter installation
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

# Check Android SDK
if [ -z "$ANDROID_HOME" ]; then
    echo "❌ ANDROID_HOME not set. Please set up Android SDK path:"
    echo "   export ANDROID_HOME=/path/to/android-sdk"
    exit 1
fi

cd "$(dirname "$0")"

echo "✓ Flutter detected: $(flutter --version | head -1)"
echo "✓ Android SDK: $ANDROID_HOME"
echo ""

# Step 1: Validate
echo "Step 1: Validating environment..."
flutter doctor

echo ""
echo "Step 2: Cleaning previous builds..."
flutter clean

echo ""
echo "Step 3: Getting dependencies..."
flutter pub get

echo ""
echo "Step 4: Running tests..."
flutter test

echo ""
echo "Step 5: Running analyzer..."
flutter analyze | grep -E "error -|^[0-9]+ issues" || true

echo ""
echo "Step 6: Building release APK..."
echo "(This may take 5-15 minutes...)"
flutter build apk --release

echo ""
echo "=========================================="
echo "✅ APK BUILD COMPLETE!"
echo "=========================================="
echo ""
echo "APK Location:"
echo "  $(pwd)/build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "To build App Bundle for Play Store instead:"
echo "  flutter build appbundle --release"
echo ""
echo "App Bundle Location:"
echo "  $(pwd)/build/app/outputs/bundle/release/app-release.aab"
echo ""
echo "Next steps:"
echo "1. Test the APK on Android 5.0+ devices"
echo "2. Generate signed keystore for production"
echo "3. Sign APK with production keystore"
echo "4. Upload to Google Play Store"
echo ""
