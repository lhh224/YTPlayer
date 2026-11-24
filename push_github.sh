#!/bin/bash
# ==============================================================================
# YT Player — Đẩy code lên GitHub để tự động đóng gói file YTPlayer.ipa
# Cách dùng:
#   ./push_github.sh https://github.com/<TEN_USER>/<TEN_REPO>.git
# ==============================================================================
set -e

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$ROOT_DIR"

REPO_URL="$1"
if [ -z "$REPO_URL" ]; then
  echo "======================================================================"
  echo "  🚀 ĐẨY DỰ ÁN LÊN GITHUB ĐỂ TỰ ĐỘNG BUILD FILE YTPlayer.ipa"
  echo "======================================================================"
  printf "👉 Dán đường dẫn GitHub Repo của bạn (VD: https://github.com/user/YTPlayer.git): "
  read -r REPO_URL
fi

if [ -z "$REPO_URL" ]; then
  echo "❌ Bạn chưa nhập đường dẫn GitHub Repo."
  exit 1
fi

git add -A
if ! git diff --cached --quiet; then
  git commit -m "Update YTPlayer iOS build"
fi

git branch -M main

if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$REPO_URL"
else
  git remote add origin "$REPO_URL"
fi

echo ""
echo "☁️  Đang đẩy mã nguồn lên GitHub ($REPO_URL)..."
echo "   (Nếu Git hỏi mật khẩu, hãy dán Personal Access Token của GitHub)"
git push -u origin main

ACTIONS_URL="${REPO_URL%.git}/actions"
SECRETS_URL="${REPO_URL%.git}/settings/secrets/actions"

echo ""
echo "======================================================================"
echo "  ✅ ĐÃ ĐẨY LÊN GITHUB THÀNH CÔNG!"
echo "  1. Theo dõi & tải file YTPlayer.ipa (~2-3 phút) tại:"
echo "     $ACTIONS_URL"
echo "  2. (Tùy chọn) Thêm sẵn YouTube API Key vào biến YOUTUBE_API_KEY tại:"
echo "     $SECRETS_URL"
echo "======================================================================"
open "$ACTIONS_URL" 2>/dev/null || true
