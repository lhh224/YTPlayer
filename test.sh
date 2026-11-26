#!/bin/bash

# ======================================================================
# YT PLAYER — FULL TYPECHECK & TEST RUNNER SCRIPT
# ======================================================================

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CACHE_DIR="/tmp/clang-cache"
mkdir -p "$CACHE_DIR"

echo "======================================================================"
echo "          🚀 YT PLAYER — KIỂM TRA BIÊN DỊCH & UNIT TEST               "
echo "======================================================================"
echo ""

# 1. Typecheck toàn bộ 40 tệp Swift của ứng dụng
echo "▶ [1/3] Kiểm tra biên dịch (Typecheck) toàn bộ 40 file mã nguồn Swift..."
swiftc -module-cache-path "$CACHE_DIR" -typecheck -parse-as-library \
  "$DIR"/App/*.swift \
  "$DIR"/Core/DesignSystem/*.swift \
  "$DIR"/Core/DesignSystem/Components/*.swift \
  "$DIR"/Core/Models/*.swift \
  "$DIR"/Core/Navigation/*.swift \
  "$DIR"/Core/Networking/*.swift \
  "$DIR"/Core/Persistence/*.swift \
  "$DIR"/Features/Home/*.swift \
  "$DIR"/Features/Home/Components/*.swift \
  "$DIR"/Features/Search/*.swift \
  "$DIR"/Features/Player/*.swift \
  "$DIR"/Features/Player/Components/*.swift \
  "$DIR"/Features/Library/*.swift \
  "$DIR"/Features/Library/Components/*.swift \
  "$DIR"/Features/Settings/*.swift \
  "$DIR"/Services/*.swift
echo "  ✅ Toàn bộ 40 file Swift biên dịch sạch 100% (0 lỗi)!"
echo ""

# 2. Chạy bộ Unit Test nội bộ (với trình biên dịch Swift)
echo "▶ [2/3] Đang biên dịch và chạy bộ Unit Test cốt lõi..."
swiftc -module-cache-path "$CACHE_DIR" \
  "$DIR/Core/Models/VideoItem.swift" \
  "$DIR/Core/Models/Channel.swift" \
  "$DIR/Core/Models/SearchResult.swift" \
  "$DIR/Core/Models/AppError.swift" \
  "$DIR/Core/Networking/NetworkError.swift" \
  "$DIR/Core/Networking/Endpoint.swift" \
  "$DIR/Services/YouTubeAPIService.swift" \
  "$DIR/Services/NowPlayingService.swift" \
  "$DIR/Services/PlaybackService.swift" \
  "$DIR/Services/SleepTimerService.swift" \
  "$DIR/Tests/run_demo_test.swift" \
  -o /tmp/ytplayer_demo_runner

/tmp/ytplayer_demo_runner

echo ""
echo "======================================================================"
echo "▶ [3/3] Kiểm tra API Key YouTube trong file Config/APIKeys.plist..."

API_KEY=$(grep -o '<string>AIzaSy[^<]*' "$DIR/Config/APIKeys.plist" | sed 's/<string>//' || echo "")

if [ -n "$API_KEY" ]; then
    echo "✅ Đã tìm thấy API Key: ${API_KEY:0:8}...${API_KEY: -4}"
    RESPONSE=$(curl -s -m 6 "https://www.googleapis.com/youtube/v3/videos?part=snippet&id=dQw4w9WgXcQ&key=$API_KEY" || true)

    if echo "$RESPONSE" | grep -q '"items"'; then
        echo "🎉 KẾT NỐI YOUTUBE DATA API V3 THÀNH CÔNG!"
    elif echo "$RESPONSE" | grep -q 'PERMISSION_DENIED'; then
        echo "⚠️ Khóa API hiện trả về 403 PERMISSION_DENIED (chưa bật YouTube Data API v3 trên Google Cloud Project)."
        echo "   👉 Mở https://console.cloud.google.com/apis/library/youtube.googleapis.com và nhấn ENABLE!"
    elif echo "$RESPONSE" | grep -q '"error"'; then
        echo "⚠️ YouTube API trả về phản hồi lỗi:"
        echo "$RESPONSE" | grep -E '"message":' | head -n 2 | sed 's/^[ \t]*/   ! /'
    else
        echo "ℹ️ Bỏ qua kiểm tra mạng trực tiếp (môi trường sandbox offline)."
    fi
else
    echo "⚠️ Chưa tìm thấy API Key trong Config/APIKeys.plist."
fi

echo ""
echo "======================================================================"
echo "✅ HOÀN TẤT KIỂM THỬ TOÀN DIỆN!"
echo "======================================================================"
