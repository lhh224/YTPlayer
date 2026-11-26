#!/bin/bash
# ==============================================================================
# YT Player — Script đóng gói ứng dụng thành file YTPlayer.ipa (ESign / Sideloadly)
#
# Hỗ trợ tự động 2 chế độ:
#   1. Local Xcode Build (--local): Biên dịch trực tiếp bằng xcodebuild nếu máy có Xcode.
#   2. Cloud Build (--cloud): Nếu máy chỉ có Command Line Tools (chưa cài Xcode),
#      tự động đồng bộ mã nguồn lên GitHub Actions (macos-latest), chờ biên dịch xong
#      và tải thẳng file build/YTPlayer.ipa về máy!
#
# Cách dùng:
#   ./build_ipa.sh              # Tự động chọn Local Xcode hoặc Cloud Build
#   ./build_ipa.sh --local      # Bắt buộc biên dịch cục bộ bằng Xcode
#   ./build_ipa.sh --cloud      # Bắt buộc đóng gói qua GitHub Actions và tải IPA về
#   ./build_ipa.sh --check-only # Chỉ kiểm tra cú pháp Swift & cấu hình Plist
# ==============================================================================

set -euo pipefail

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_DIR="$ROOT_DIR/build"
PAYLOAD_DIR="$BUILD_DIR/Payload"
IPA_PATH="$BUILD_DIR/YTPlayer.ipa"
CACHE_DIR="/tmp/clang-cache"

MODE="auto"
for arg in "$@"; do
  case "$arg" in
    --local)      MODE="local" ;;
    --cloud)      MODE="cloud" ;;
    --check-only) MODE="check" ;;
    -h|--help)
      sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "⚠️ Tham số không hợp lệ: $arg (dùng --help để xem hướng dẫn)"
      exit 1
      ;;
  esac
done

cd "$ROOT_DIR"

echo "======================================================================"
echo "  📦 YT PLAYER — ĐÓNG GÓI ỨNG DỤNG SANG FILE YTPlayer.ipa"
echo "======================================================================"

# ------------------------------------------------------------------------------
# Bước 1: Chuẩn bị & Kiểm tra cấu hình + mã nguồn Swift trước khi đóng gói
# ------------------------------------------------------------------------------
if [ ! -f "$ROOT_DIR/Config/APIKeys.plist" ]; then
  cp "$ROOT_DIR/Config/APIKeys.plist.example" "$ROOT_DIR/Config/APIKeys.plist"
  echo "ℹ️ Đã tạo Config/APIKeys.plist từ bản mẫu."
fi

echo "▶ [1/4] Kiểm tra tính hợp lệ của Info.plist & Xcode Project..."
plutil -lint "$ROOT_DIR/Resources/Info.plist" "$ROOT_DIR/YTPlayer.xcodeproj/project.pbxproj"

INFO_PLIST_DUMP=$(plutil -p "$ROOT_DIR/Resources/Info.plist" 2>/dev/null || true)
if [[ "$INFO_PLIST_DUMP" != *'"audio"'* ]]; then
  echo "❌ Thiếu cấu hình UIBackgroundModes -> audio trong Resources/Info.plist!"
  exit 1
fi
echo "  ✅ Đã xác nhận quyền chạy nền âm thanh (UIBackgroundModes = audio)."

if command -v swiftc >/dev/null 2>&1; then
  echo "▶ [2/4] Kiểm tra biên dịch (Typecheck) toàn bộ mã nguồn Swift..."
  mkdir -p "$CACHE_DIR"
  swiftc -module-cache-path "$CACHE_DIR" -typecheck -parse-as-library \
    "$ROOT_DIR"/App/*.swift \
    "$ROOT_DIR"/Core/DesignSystem/*.swift \
    "$ROOT_DIR"/Core/DesignSystem/Components/*.swift \
    "$ROOT_DIR"/Core/Models/*.swift \
    "$ROOT_DIR"/Core/Navigation/*.swift \
    "$ROOT_DIR"/Core/Networking/*.swift \
    "$ROOT_DIR"/Core/Persistence/*.swift \
    "$ROOT_DIR"/Features/Home/*.swift \
    "$ROOT_DIR"/Features/Home/Components/*.swift \
    "$ROOT_DIR"/Features/Search/*.swift \
    "$ROOT_DIR"/Features/Player/*.swift \
    "$ROOT_DIR"/Features/Player/Components/*.swift \
    "$ROOT_DIR"/Features/Library/*.swift \
    "$ROOT_DIR"/Features/Library/Components/*.swift \
    "$ROOT_DIR"/Features/Settings/*.swift \
    "$ROOT_DIR"/Services/*.swift
  echo "  ✅ Tất cả file Swift hợp lệ 100% (0 lỗi)."
fi

if [ "$MODE" = "check" ]; then
  echo "✅ Hoàn tất kiểm tra (--check-only)."
  exit 0
fi

# ------------------------------------------------------------------------------
# Hàm kiểm tra & in thông tin file IPA sau khi đóng gói
# ------------------------------------------------------------------------------
verify_and_report_ipa() {
  local ipa_file="$1"
  if [ ! -f "$ipa_file" ]; then
    echo "❌ Không tìm thấy file IPA tại: $ipa_file"
    exit 1
  fi

  echo "▶ [4/4] Kiểm tra cấu trúc gói IPA..."
  unzip -tq "$ipa_file" >/dev/null

  local tmp_plist="/tmp/ytplayer_ipa_info_$$.plist"
  unzip -p "$ipa_file" "Payload/YTPlayer.app/Info.plist" > "$tmp_plist"
  local bundle_id
  bundle_id=$(plutil -extract CFBundleIdentifier raw -o - "$tmp_plist" 2>/dev/null || echo "com.ytplayer.app")
  local version_str
  version_str=$(plutil -extract CFBundleShortVersionString raw -o - "$tmp_plist" 2>/dev/null || echo "1.0")
  local has_bg_audio="Không"
  local ipa_plist_dump
  ipa_plist_dump=$(plutil -p "$tmp_plist" 2>/dev/null || true)
  if [[ "$ipa_plist_dump" == *'"audio"'* ]]; then
    has_bg_audio="Có (UIBackgroundModes: audio)"
  fi
  rm -f "$tmp_plist"

  local file_size
  file_size=$(du -h "$ipa_file" | awk '{print $1}')
  local sha256_hash
  sha256_hash=$(shasum -a 256 "$ipa_file" | awk '{print $1}')

  echo ""
  echo "======================================================================"
  echo "  🎉 ĐÓNG GÓI THÀNH CÔNG FILE IPA!"
  echo "----------------------------------------------------------------------"
  echo "  📁 Đường dẫn file : $ipa_file"
  echo "  📦 Dung lượng     : $file_size"
  echo "  🆔 Bundle ID      : $bundle_id (v$version_str)"
  echo "  🎵 Phát nhạc nền  : $has_bg_audio"
  echo "  🔒 SHA-256        : $sha256_hash"
  echo "----------------------------------------------------------------------"
  echo "  📲 Hướng dẫn ký & cài đặt lên iPhone:"
  echo "     • ESign / Feather / Scarlet : Gửi file YTPlayer.ipa qua AirDrop/Files"
  echo "       vào iPhone -> Nhập vào ESign -> Ký (Sign) -> Cài đặt (Install)."
  echo "     • Sideloadly / AltStore     : Mở Sideloadly trên Mac và kéo thả file"
  echo "       $ipa_file vào để cài đặt."
  echo "======================================================================"
}

# ------------------------------------------------------------------------------
# Hàm đóng gói cục bộ bằng Xcode (Local Build)
# ------------------------------------------------------------------------------
build_local_xcode() {
  echo "▶ [3/4] Đang biên dịch YTPlayer.app bằng Xcode cục bộ (Release - iphoneos)..."
  rm -rf "$BUILD_DIR"
  mkdir -p "$PAYLOAD_DIR"

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

  local app_bundle
  app_bundle=$(find "$BUILD_DIR/DerivedData/Build/Products/Release-iphoneos" -maxdepth 1 -name "YTPlayer.app" -print -quit)

  if [ -z "$app_bundle" ] || [ ! -d "$app_bundle" ]; then
    echo "❌ Không tìm thấy YTPlayer.app sau khi biên dịch."
    exit 1
  fi

  # Dọn sạch extended attributes & .DS_Store để ESign / Sideloadly ký không lỗi
  xattr -cr "$app_bundle" 2>/dev/null || true
  find "$app_bundle" -name ".DS_Store" -delete 2>/dev/null || true

  cp -R "$app_bundle" "$PAYLOAD_DIR/YTPlayer.app"
  (
    cd "$BUILD_DIR"
    zip -qry "$IPA_PATH" Payload
  )
  rm -rf "$PAYLOAD_DIR" "$BUILD_DIR/DerivedData"

  verify_and_report_ipa "$IPA_PATH"
}

# ------------------------------------------------------------------------------
# Hàm tìm đường dẫn GitHub CLI (gh) nếu có trên máy
# ------------------------------------------------------------------------------
find_gh_cli() {
  if command -v gh >/dev/null 2>&1; then
    command -v gh
    return 0
  fi
  for candidate in \
    "/opt/homebrew/bin/gh" \
    "/usr/local/bin/gh" \
    "$HOME/.gemini/antigravity/brain/"*/scratch/gh_*/bin/gh; do
    if [ -x "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

# ------------------------------------------------------------------------------
# Hàm đóng gói tự động qua GitHub Actions Cloud Builder (khi máy chưa cài Xcode)
# ------------------------------------------------------------------------------
build_cloud_github_actions() {
  echo "▶ [3/4] Máy chưa cài Xcode đầy đủ -> Chuyển sang đóng gói tự động qua GitHub Actions..."

  if ! git remote get-url origin >/dev/null 2>&1; then
    echo "❌ Chưa cấu hình git remote 'origin'. Hãy chạy ./push_github.sh trước."
    exit 1
  fi

  local remote_url
  remote_url=$(git remote get-url origin)
  local repo_slug
  repo_slug=$(echo "$remote_url" | sed -E 's#.*github\.com[:/]([^/]+/[^/.]+)(\.git)?$#\1#')

  local gh_bin=""
  gh_bin=$(find_gh_cli || true)

  # Đồng bộ khóa API YouTube cục bộ lên GitHub Secret (nếu có gh CLI & khóa hợp lệ)
  local local_api_key=""
  local_api_key=$(/usr/libexec/PlistBuddy -c "Print :YouTubeAPIKey" "$ROOT_DIR/Config/APIKeys.plist" 2>/dev/null || true)
  if [ -n "$gh_bin" ] && [[ "$local_api_key" == AIzaSy* ]]; then
    echo "  🔑 Đang đồng bộ khóa YouTubeAPIKey vào GitHub Actions Secret..."
    printf "%s" "$local_api_key" | "$gh_bin" secret set YOUTUBE_API_KEY -R "$repo_slug" >/dev/null 2>&1 || true
  fi

  # Commit & đẩy toàn bộ mã nguồn mới nhất lên nhánh main
  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "Build YTPlayer.ipa: background audio + ESign playback fix"
  fi

  local head_sha
  head_sha=$(git rev-parse HEAD)
  echo "  ☁️  Đang đẩy commit ${head_sha:0:7} lên GitHub ($repo_slug)..."
  git push origin HEAD:main

  # Nếu chưa có commit mới (working tree sạch từ trước), kích hoạt workflow_dispatch
  if [ -n "$gh_bin" ]; then
    "$gh_bin" workflow run build-ipa.yml -R "$repo_slug" >/dev/null 2>&1 || true
  fi

  echo "  ⏳ Đang chờ máy chủ macOS của GitHub Actions biên dịch YTPlayer.ipa (~1-3 phút)..."
  local run_id=""
  local status=""
  local conclusion=""

  for attempt in $(seq 1 45); do
    sleep 8
    local api_json
    api_json=$(curl -fsSL "https://api.github.com/repos/$repo_slug/actions/workflows/build-ipa.yml/runs?per_page=5" 2>/dev/null || true)
    if [ -n "$api_json" ]; then
      read -r run_id status conclusion < <(python3 -c '
import json, sys
sha = sys.argv[1]
data = json.loads(sys.stdin.read() or "{}")
runs = data.get("workflow_runs", [])
match = next((r for r in runs if r.get("head_sha") == sha), runs[0] if runs else None)
if match:
    print(match.get("id", ""), match.get("status", ""), match.get("conclusion") or "pending")
' "$head_sha" <<< "$api_json" 2>/dev/null || true)

      if [ -n "$run_id" ]; then
        printf "     • [Lần kiểm tra %02d] Run #%s — Trạng thái: %s (%s)\n" "$attempt" "$run_id" "$status" "$conclusion"
        if [ "$status" = "completed" ]; then
          break
        fi
      fi
    fi
  done

  if [ "$status" != "completed" ] || [ "$conclusion" != "success" ]; then
    echo "❌ Tiến trình build trên GitHub Actions chưa hoàn tất hoặc gặp lỗi (status=$status, conclusion=$conclusion)."
    echo "👉 Kiểm tra chi tiết tại: https://github.com/$repo_slug/actions"
    exit 1
  fi

  mkdir -p "$BUILD_DIR"
  rm -f "$IPA_PATH"

  if [ -n "$gh_bin" ] && [ -n "$run_id" ]; then
    echo "  ⬇️  Đang tải artifact YTPlayer-iOS-IPA từ Run #$run_id..."
    local tmp_dl="$BUILD_DIR/tmp_artifact_$$"
    rm -rf "$tmp_dl"
    if "$gh_bin" run download "$run_id" -R "$repo_slug" -n "YTPlayer-iOS-IPA" -D "$tmp_dl" >/dev/null 2>&1; then
      mv "$tmp_dl/YTPlayer.ipa" "$IPA_PATH"
      rm -rf "$tmp_dl"
    fi
  fi

  if [ ! -f "$IPA_PATH" ]; then
    local release_url="https://github.com/$repo_slug/releases/download/latest-ipa/YTPlayer.ipa"
    echo "  ⬇️  Đang tải YTPlayer.ipa từ GitHub Releases ($release_url)..."
    curl -fL "$release_url" -o "$IPA_PATH"
  fi

  echo "  🔗 Link tải trực tiếp cho ESign trên iPhone:"
  echo "     https://github.com/$repo_slug/releases/download/latest-ipa/YTPlayer.ipa"

  verify_and_report_ipa "$IPA_PATH"
}

# ------------------------------------------------------------------------------
# Điều phối chế độ chạy
# ------------------------------------------------------------------------------
HAS_XCODE=false
if xcodebuild -version >/dev/null 2>&1; then
  HAS_XCODE=true
fi

case "$MODE" in
  local)
    if [ "$HAS_XCODE" = false ]; then
      echo "❌ Chế độ --local yêu cầu cài đặt Xcode.app đầy đủ (hiện chỉ có Command Line Tools)."
      echo "👉 Bỏ cờ --local hoặc chạy './build_ipa.sh --cloud' để đóng gói qua GitHub Actions."
      exit 1
    fi
    build_local_xcode
    ;;
  cloud)
    build_cloud_github_actions
    ;;
  auto)
    if [ "$HAS_XCODE" = true ]; then
      build_local_xcode
    else
      build_cloud_github_actions
    fi
    ;;
esac
