#!/bin/bash
# Khởi chạy máy chủ HTTP cho YTPlayer (hỗ trợ cả máy Mac và cài PWA qua Wi-Fi trên iPhone)

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/web_preview"
PORT=8085
LAN_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "")

echo "======================================================================"
echo "  🎬 YT PLAYER — ĐANG CHẠY MÁY CHỦ APP"
echo "  💻 Trên Mac:    http://localhost:$PORT"
if [ -n "$LAN_IP" ]; then
  echo "  📱 Trên iPhone: http://$LAN_IP:$PORT"
  echo "     (Mở bằng Safari trên iPhone cùng Wi-Fi -> Chia sẻ -> Thêm vào MH chính)"
fi
echo "  (Nhấn Ctrl + C để dừng máy chủ)"
echo "======================================================================"

open "http://localhost:$PORT" 2>/dev/null || true
python3 -m http.server "$PORT" --bind 0.0.0.0 --directory "$DIR"
