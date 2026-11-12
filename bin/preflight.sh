#!/usr/bin/env bash
# Kiểm tra đầu vào trước khi giao một kho cho agy/codex — lỗi thì dừng ngay thay vì để executor chạy vô ích.
#
#   preflight.sh <thư-mục-việc> <tên-kho> <agy|codex> [resume]
#
# Mã thoát 0 = sẵn sàng (có thể kèm cảnh báo), 5 = có lỗi chặn.
set -uo pipefail
TASK_DIR="$(cd "$1" && pwd)"; REPO="$2"; EXEC="$3"; RESUME="${4:-}"
DIR="$TASK_DIR/$REPO"; ERRS=(); WARN=()
err() { ERRS+=("$1"); }; warn() { WARN+=("$1"); }

# Worktree
WT="$(cat "$DIR/worktree.txt" 2>/dev/null || true)"
if [[ -z "$WT" ]]; then err "thiếu $DIR/worktree.txt"
elif [[ ! -d "$WT" ]]; then err "worktree không tồn tại: $WT"
else
  BR="$(git -C "$WT" branch --show-current 2>/dev/null)"
  [[ -z "$BR" ]] && err "worktree không phải kho Git / đang detached: $WT"
  [[ -n "$BR" && "$BR" != agy/* ]] && err "worktree đang ở nhánh '$BR' (phải là agy/…) — không giao để tránh sửa nhánh thật"
  git -C "$WT" rev-parse --git-common-dir >/dev/null 2>&1 && [[ "$(git -C "$WT" rev-parse --git-dir)" == "$(git -C "$WT" rev-parse --git-common-dir)" ]] \
    && err "đây là thư mục chính của kho, không phải worktree riêng: $WT"
  [[ -f "$DIR/base.txt" ]] || warn "thiếu base.txt (verify sẽ so với HEAD)"
fi

# Prompt
if [[ -n "$RESUME" ]]; then
  ls "$DIR"/feedback-*.md >/dev/null 2>&1 || err "resume nhưng không có feedback-*.md"
  case "$EXEC" in
    agy)   [[ -s "$DIR/conversation.txt" ]] || warn "không có conversation.txt — agy sẽ mở phiên mới" ;;
    codex) [[ -s "$DIR/session.txt" ]] || warn "không có session.txt — codex sẽ mở phiên mới" ;;
  esac
else
  B="$DIR/brief.md"
  if [[ ! -s "$B" ]]; then err "thiếu brief.md"
  else
    python3 - "$B" <<'PY' || err "brief.md thiếu mục bắt buộc (xem trên)"
import re, sys
t = open(sys.argv[1], encoding="utf-8").read(); bad = []
sec = lambda h: re.search(rf"^## {h}.*?\n(.*?)(?=^## |\Z)", t, re.S | re.M)
a = sec("Allowed paths")
if not a or not re.search(r"^\s*-\s*`[^`]+`", a.group(1), re.M): bad.append("## Allowed paths (ít nhất một dòng - `đường/dẫn`)")
c = sec("Acceptance criteria")
if not c or not re.search(r"^\s*-\s*\[ \]\s*\S", c.group(1), re.M): bad.append("## Acceptance criteria (ít nhất một - [ ] …)")
if "AGY_REPORT.md" not in t: bad.append("yêu cầu ghi AGY_REPORT.md")
if not sec("Self-check commands"): bad.append("## Self-check commands")
if re.search(r"<(task name|repo|absolute worktree path|path/glob|criterion)[^>]*>", t): bad.append("còn chỗ trống của mẫu (<…>)")
for b in bad: print(f"  - brief thiếu: {b}")
sys.exit(1 if bad else 0)
PY
  fi
fi

# Executor
case "$EXEC" in
  agy)
    command -v agy >/dev/null || err "chưa cài agy"
    command -v agy >/dev/null && { agy models >/dev/null 2>&1 || err "agy không lấy được danh sách model — chưa đăng nhập hoặc mất mạng"; } ;;
  codex)
    command -v codex >/dev/null || err "chưa cài codex"
    command -v codex >/dev/null && { codex login status >/dev/null 2>&1 || err "codex chưa đăng nhập (codex login)"; } ;;
  *) err "executor không hợp lệ: $EXEC" ;;
esac

# Việc khác đang chạy trên cùng worktree
[[ -n "$WT" ]] && ps -axo command= | grep -E "[a]gy --mode|[c]odex exec" | grep -qF -- "$WT" && err "đã có agy/codex đang chạy trên worktree này"

for w in "${WARN[@]+"${WARN[@]}"}"; do echo "CẢNH BÁO: $w"; done
if (( ${#ERRS[@]} )); then
  echo "PREFLIGHT KHÔNG ĐẠT ($REPO, $EXEC):" >&2; for e in "${ERRS[@]}"; do echo "  - $e" >&2; done; exit 5
fi
echo "preflight ok ($REPO, $EXEC)"
