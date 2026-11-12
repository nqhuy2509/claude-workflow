#!/usr/bin/env bash
# Cài bộ quy trình /crew (executor agy hoặc codex) cho máy hiện tại: liên kết vào ~/.claude để mọi project dùng được.
#   ./install.sh             cài (tạo symlink cho mọi lệnh trong commands/)
#   ./install.sh --uninstall gỡ
set -euo pipefail
KIT="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CMD_DIR="$CLAUDE_DIR/commands"

# Gỡ symlink lệnh trỏ vào kit này (kể cả tên cũ đã bị đổi, vd agy-model.md, agy-status.md…).
remove_links() {
  for p in "$CMD_DIR"/*.md; do
    [[ -L "$p" ]] || continue
    t="$(readlink "$p")"
    [[ "$t" == "$KIT"/* || "$t" == "$CLAUDE_DIR/agy/"* ]] || continue
    if [[ "${1:-}" == all || ! -e "$p" ]]; then rm "$p" && echo "đã gỡ $p"; fi
  done
}

if [[ "${1:-}" == "--uninstall" ]]; then
  remove_links all
  [[ -L "$CLAUDE_DIR/agy" ]] && rm "$CLAUDE_DIR/agy" && echo "đã gỡ $CLAUDE_DIR/agy"
  exit 0
fi

mkdir -p "$CMD_DIR"
link() {  # link <đích> <liên kết>
  if [[ -e "$2" && ! -L "$2" ]]; then
    echo "BỎ QUA: $2 đã tồn tại và không phải symlink — hãy xem lại rồi xoá thủ công." >&2; return 1
  fi
  ln -sfn "$1" "$2" && echo "liên kết $2 -> $1"
}
remove_links stale   # dọn symlink lệnh cũ đã gãy (sau khi đổi tên lệnh)
for c in "$KIT"/commands/*.md; do link "$c" "$CMD_DIR/$(basename "$c")" || true; done
link "$KIT" "$CLAUDE_DIR/agy"
chmod +x "$KIT"/bin/*.sh

echo
command -v agy >/dev/null && echo "agy: $(agy --version 2>/dev/null | head -1)" || echo "(tuỳ chọn) chưa cài agy (Antigravity CLI)."
command -v codex >/dev/null && echo "codex: $(codex --version 2>/dev/null | head -1)" || echo "(tuỳ chọn) chưa cài codex."
command -v agy >/dev/null || command -v codex >/dev/null || echo "CẦN ít nhất một executor: agy hoặc codex."
command -v python3 >/dev/null || echo "CHƯA CÓ python3 — các script cần python3."
echo "Xong. Lệnh: /crew <yêu cầu> · /agy <yêu cầu> · /codex <yêu cầu> · /crew-status · /crew-config · /crew-usage · /crew-clean"
