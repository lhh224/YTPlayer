#!/bin/bash
# ==============================================================================
# YT Player — Đóng gói file YTPlayer.ipa để cài vào iPhone (Sideloadly / AltStore)
# ==============================================================================
set -e

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_DIR="$ROOT_DIR/build"
PAYLOAD_DIR="$BUILD_DIR/Payload"
IPA_PATH="$BUILD_DIR/YTPlayer.ipa"

echo "======================================================================"
echo "  📦 ĐANG ĐÓNG GÓI ỨNG DỤNG iOS: YTPlayer.ipa"
echo "======================================================================"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "❌ Máy Mac chưa cài đặt Xcode đầy đủ (hiện mới chỉ có Command Line Tools)."
  echo ""
  echo "👉 Bạn có 2 lựa chọn:"
  echo "   1. Không cần cài Xcode nặng máy: Đẩy code lên GitHub để GitHub Actions"
  echo "      tự động xuất file YTPlayer.ipa miễn phí (xem .github/workflows/build-ipa.yml),"
  echo "      sau đó cài vào iPhone bằng Sideloadly."
  echo "   2. Cài Xcode 14.2 trên macOS Monterey 12.7.6 tại:"
  echo "      https://developer.apple.com/download/all/ rồi chạy lại ./build_ipa.sh"
  exit 1
fi

# Đảm bảo Config/APIKeys.plist tồn tại trước khi build
if [ ! -f "$ROOT_DIR/Config/APIKeys.plist" ]; then
  cp "$ROOT_DIR/Config/APIKeys.plist.example" "$ROOT_DIR/Config/APIKeys.plist"
  echo "ℹ️ Đã khởi tạo Config/APIKeys.plist từ bản mẫu."
fi

rm -rf "$BUILD_DIR"
mkdir -p "$PAYLOAD_DIR"

echo "🔨 Đang biên dịch YTPlayer (Release - iphoneos)..."
xcodebuild build \
  -project "$ROOT_DIR/YTPlayer.xcodeproj" \
  -scheme "YTPlayer" \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

APP_BUNDLE=$(find "$BUILD_DIR/DerivedData/Build/Products/Release-iphoneos" -name "YTPlayer.app" -maxdepth 1 | head -n 1)

if [ -z "$APP_BUNDLE" ] || [ ! -d "$APP_BUNDLE" ]; then
  echo "❌ Không tìm thấy YTPlayer.app sau khi build."
  exit 1
fi

cp -R "$APP_BUNDLE" "$PAYLOAD_DIR/YTPlayer.app"
(
  cd "$BUILD_DIR"
  zip -qry "$IPA_PATH" Payload
)
rm -rf "$PAYLOAD_DIR"

echo ""
echo "✅ ĐÓNG GÓI THÀNH CÔNG!"
echo "📁 File IPA tại: $IPA_PATH"
echo "📲 Mở Sideloadly / AltStore, cắm cáp iPhone và kéo thả file YTPlayer.ipa để cài đặt."
