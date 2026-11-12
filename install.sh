#!/usr/bin/env bash
# Cài bộ quy trình /agy cho máy hiện tại: liên kết vào ~/.claude để mọi project dùng được.
#   ./install.sh            cài (tạo symlink)
#   ./install.sh --uninstall gỡ
set -euo pipefail
KIT="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

if [[ "${1:-}" == "--uninstall" ]]; then
  for p in "$CLAUDE_DIR/commands/agy.md" "$CLAUDE_DIR/commands/agy-model.md" "$CLAUDE_DIR/commands/agy-status.md" "$CLAUDE_DIR/commands/agy-clean.md" "$CLAUDE_DIR/commands/agy-usage.md" "$CLAUDE_DIR/agy"; do
    [[ -L "$p" ]] && rm "$p" && echo "đã gỡ $p"
  done
  exit 0
fi

mkdir -p "$CLAUDE_DIR/commands"
link() {  # link <đích> <liên kết>
  if [[ -e "$2" && ! -L "$2" ]]; then
    echo "BỎ QUA: $2 đã tồn tại và không phải symlink — hãy xem lại rồi xoá thủ công." >&2; return 1
  fi
  ln -sfn "$1" "$2" && echo "liên kết $2 -> $1"
}
link "$KIT/commands/agy.md" "$CLAUDE_DIR/commands/agy.md"
link "$KIT/commands/agy-model.md" "$CLAUDE_DIR/commands/agy-model.md"
link "$KIT/commands/agy-status.md" "$CLAUDE_DIR/commands/agy-status.md"
link "$KIT/commands/agy-clean.md" "$CLAUDE_DIR/commands/agy-clean.md"
link "$KIT/commands/agy-usage.md" "$CLAUDE_DIR/commands/agy-usage.md"
link "$KIT" "$CLAUDE_DIR/agy"
chmod +x "$KIT/bin/run-agy.sh" "$KIT/bin/agy-model.sh" "$KIT/bin/agy-status.sh" "$KIT/bin/run-codex.sh" "$KIT/bin/run-task.sh" "$KIT/bin/verify.sh" "$KIT/bin/preflight.sh" "$KIT/bin/agy-clean.sh" "$KIT/bin/agy-usage.sh"

echo
command -v agy >/dev/null && echo "agy: $(agy --version 2>/dev/null | head -1)" \
  || echo "CHƯA CÀI agy (Antigravity CLI) — cài và đăng nhập trước khi dùng /agy."
command -v codex >/dev/null && echo "codex: $(codex --version 2>/dev/null | head -1)" || echo "(tuỳ chọn) chưa cài codex — chỉ dùng executor agy."
command -v python3 >/dev/null || echo "CHƯA CÓ python3 — run-agy.sh cần python3."
echo "Xong. Mở project bất kỳ trong Claude Code và gõ: /agy <yêu cầu>"
