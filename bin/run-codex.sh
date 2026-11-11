#!/usr/bin/env bash
# Chạy Codex CLI không tương tác cho MỘT kho của một việc (thay thế / dự phòng cho agy).
#
#   run-codex.sh <thư-mục-việc> <tên-kho> [resume] [ghi-chú-thêm]
#
# Đọc giống run-agy.sh: worktree.txt, brief.md (vòng đầu) hoặc feedback-N.md mới nhất (khi resume),
# config: "codex_model" của kho > "codex_model" chung > model mặc định của codex. CODEX_MODEL=… ghi đè.
# Ghi: codex-N.jsonl, codex-N.err, codex-N.last.md (tin nhắn cuối), session.txt (thread id), model.txt.
# Quyền: --sandbox workspace-write (chỉ ghi trong worktree, mặc định không có mạng), approval never.
# Không bao giờ dùng --dangerously-bypass-approvals-and-sandbox.
set -uo pipefail
TASK_DIR="$(cd "$1" && pwd)"; REPO="$2"; RESUME="${3:-}"; EXTRA="${4:-}"
DIR="$TASK_DIR/$REPO"; PROJECT="$(cd "$TASK_DIR/../../.." && pwd)"
WORKTREE="$(cat "$DIR/worktree.txt")"
command -v codex >/dev/null || { echo "Chưa cài codex (Codex CLI)." >&2; exit 3; }

if [[ -n "$RESUME" && -f "$DIR/session.txt" ]]; then
  SESSION="$(cat "$DIR/session.txt")"
  PROMPT_FILE="$(ls -1 "$DIR"/feedback-*.md 2>/dev/null | sort -V | tail -1)"
else
  SESSION=""; PROMPT_FILE="$DIR/brief.md"
fi
[[ -f "${PROMPT_FILE:-}" ]] || { echo "Không thấy prompt (${PROMPT_FILE:-feedback-*.md})" >&2; exit 2; }

PREAMBLE="EXECUTOR NOTE (Codex): You run inside a sandbox that can write only inside this worktree; network access may be unavailable (dependencies are expected to be restored already). Unlike the 'Commands' allowlist in the brief, you MAY run any build / test / lint / format command inside the worktree, and you should run the self-check commands yourself. All other rules still apply: do NOT commit, push, switch branches, or touch files outside the allowed paths. Write AGY_REPORT.md exactly as the brief describes."
PROMPT="$(cat "$PROMPT_FILE")"

# Bài học tích luỹ của project (.agy/lessons.md) → chèn vào prompt vòng đầu.
LESSONS_FILE="$PROJECT/.agy/lessons.md"
lessons_block() {  # lessons_block <kho>: dòng "- …"; dòng có "[kho: X]" chỉ áp cho kho X
  [[ -s "$LESSONS_FILE" ]] || return 0
  local body; body="$(python3 - "$LESSONS_FILE" "$1" <<'PY'
import re, sys
f, repo = sys.argv[1:]
for l in open(f, encoding="utf-8"):
    if not l.lstrip().startswith("-"): continue
    m = re.search(r"\[(?:kho|repo):\s*([^\]]+)\]", l)
    if m and repo not in [x.strip() for x in m.group(1).split(",")]: continue
    print(l.rstrip())
PY
)"
  [[ -n "$body" ]] && printf '\n\n## Lessons from previous tasks in this project (follow them)\n%s\n' "$body"
  return 0
}
[[ -z "$SESSION" ]] && PROMPT="$PREAMBLE"$'\n\n'"$PROMPT$(lessons_block "$REPO")"
[[ -n "$EXTRA" ]] && PROMPT="$PROMPT"$'\n\n'"$EXTRA"

SIZE="$(cat "$DIR/size.txt" 2>/dev/null || cat "$TASK_DIR/size.txt" 2>/dev/null || true)"
MODEL="${CODEX_MODEL:-$(python3 -c 'import json,os,sys
p,r,z=sys.argv[1:]
c=json.load(open(p)) if os.path.exists(p) else {}
rc=(c.get("repos") or {}).get(r) or {}
bs=(rc.get("codex_model_by_size") or c.get("codex_model_by_size") or {}).get(z.strip().upper(),"")
print(rc.get("codex_model") or bs or c.get("codex_model") or "")' "$PROJECT/.agy/config.json" "$REPO" "$SIZE")}"

N=$(( $(ls -1 "$DIR"/codex-*.jsonl 2>/dev/null | wc -l) + 1 ))
OUT="$DIR/codex-$N.jsonl"; ERR="$DIR/codex-$N.err"
ARGS=(exec --json -s workspace-write -c 'approval_policy="never"' -C "$WORKTREE" -o "$DIR/codex-$N.last.md")
[[ -n "$MODEL" ]] && ARGS+=(-m "$MODEL")
[[ -n "$SESSION" ]] && ARGS+=(resume "$SESSION")
echo "codex" > "$DIR/executor.txt"; echo "codex:${MODEL:-mặc định}" > "$DIR/model.txt"
echo "executor=codex model=${MODEL:-mặc định} lượt=codex-$N${SESSION:+ resume=$SESSION}"

codex "${ARGS[@]}" "$PROMPT" < /dev/null > "$OUT" 2> "$ERR"
CODE=$?

python3 - "$OUT" "$DIR/session.txt" <<'PY'
import json, re, sys
out, sess = sys.argv[1:]
status, cmds, errs, usage = "UNKNOWN", 0, [], {}
for line in open(out, errors="ignore"):
    try: d = json.loads(line)
    except Exception: continue
    t = d.get("type")
    if t == "thread.started": open(sess, "w").write(d["thread_id"])
    elif t == "turn.completed": status, usage = "SUCCESS", d.get("usage") or {}
    elif t == "turn.failed": status = "FAILED"; errs.append(str((d.get("error") or {}).get("message", d)))
    elif t == "error": errs.append(d.get("message", ""))
    elif t == "item.completed" and (d.get("item") or {}).get("type") == "command_execution": cmds += 1
quota = any(re.search(r"quota|rate[ _-]?limit|usage limit|exhausted|too many requests|\b429\b", e, re.I) for e in errs)
print(f"codex status={status} commands={cmds} out_tokens={usage.get('output_tokens')} quota={'yes' if quota else 'no'}"
      + (f" errors={[e[:120] for e in errs if 'metadata' not in e][:2]}" if errs else ""))
sys.exit(4 if quota and status != "SUCCESS" else 0)
PY
Q=$?
[[ $Q -eq 4 ]] && { echo "HẾT QUOTA codex" >&2; CODE=4; }
echo "exit=$CODE output=$OUT"
exit $CODE
