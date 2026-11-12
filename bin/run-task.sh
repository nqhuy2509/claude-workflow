#!/usr/bin/env bash
# Điều phối: chạy việc cho MỘT kho bằng executor đã chọn (agy hoặc codex), có dự phòng.
#
#   run-task.sh <thư-mục-việc> <tên-kho> [resume]
#
# Executor: EXECUTOR=… > "executor" của kho > "executor" chung > "agy".
# Vòng đầu ghi executor vào <kho>/executor.txt; khi resume (Làm lại / chạy tiếp) dùng lại đúng executor + phiên đó.
# Trước khi chạy: preflight.sh (mã 5 = đầu vào lỗi, không chạy).
# agy hết quota trên cả chuỗi model (mã 4) và "executor_fallback": "codex" → chuyển sang codex (phiên mới, cùng worktree).
set -uo pipefail
KIT="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")/.." && pwd)"
TASK_DIR="$(cd "$1" && pwd)"; REPO="$2"; RESUME="${3:-}"
DIR="$TASK_DIR/$REPO"; PROJECT="$(cd "$TASK_DIR/../../.." && pwd)"
cfg() { python3 -c 'import json,os,sys
p,r,k=sys.argv[1:]
c=json.load(open(p)) if os.path.exists(p) else {}
print(((c.get("repos") or {}).get(r) or {}).get(k) or c.get(k) or "")' "$PROJECT/.agy/config.json" "$REPO" "$1"; }

if [[ -n "$RESUME" && -f "$DIR/executor.txt" ]]; then EXEC="$(cat "$DIR/executor.txt")"
else EXEC="${EXECUTOR:-$(cfg executor)}"; EXEC="${EXEC:-agy}"; fi
FALLBACK="$(cfg executor_fallback)"
QUOTA_NOTE="NOTE: A previous executor stopped on this task because it ran out of quota. Continue from the current state of the worktree (files already changed are kept): check git status / git diff and AGY_REPORT.md, finish the remaining steps, run the self-checks and update AGY_REPORT.md."

bash "$KIT/bin/preflight.sh" "$TASK_DIR" "$REPO" "$EXEC" "$RESUME" || exit 5

case "$EXEC" in
  codex) bash "$KIT/bin/run-codex.sh" "$TASK_DIR" "$REPO" "$RESUME"; exit $? ;;
  agy)
    echo "agy" > "$DIR/executor.txt"
    CONV=""; [[ -n "$RESUME" && -f "$DIR/conversation.txt" ]] && CONV="$(cat "$DIR/conversation.txt")"
    bash "$KIT/bin/run-agy.sh" "$TASK_DIR" "$REPO" $CONV; CODE=$?
    if [[ $CODE -eq 4 && "$FALLBACK" == codex ]]; then
      echo "$(date '+%F %T') agy hết quota trên cả chuỗi model → chuyển executor codex" | tee -a "$DIR/fallback.log"
      rm -f "$DIR/session.txt"
      bash "$KIT/bin/run-codex.sh" "$TASK_DIR" "$REPO" "" "$QUOTA_NOTE"; CODE=$?
    fi
    exit $CODE ;;
  *) echo "executor không hợp lệ: $EXEC (agy|codex)" >&2; exit 2 ;;
esac
