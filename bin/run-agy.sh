#!/usr/bin/env bash
# Chạy agy (Antigravity CLI) không tương tác cho MỘT kho của một việc. Dùng chung cho mọi project.
#
#   run-agy.sh <thư-mục-việc> <tên-kho> [conversation-id]
#
# <thư-mục-việc> = <gốc project>/.agy/tasks/<việc>. Script đọc:
#   <thư-mục-việc>/<tên-kho>/worktree.txt   đường dẫn worktree agy được làm
#   <thư-mục-việc>/<tên-kho>/brief.md       hướng dẫn tiếng Anh (vòng đầu)
#   <thư-mục-việc>/<tên-kho>/feedback-N.md  góp ý mới nhất (khi có conversation-id)
#   <gốc project>/.agy/config.json          preset + lệnh bổ sung của kho (tuỳ chọn)
# Ghi: agy-N.json, agy-N.err, settings.json (quyền đã ghép), allowed-commands.txt, conversation.txt.
# LƯU Ý: ở chế độ không tương tác, một lệnh bị chặn làm agy KẾT THÚC LƯỢT ngay (bỏ dở các bước sau).
# Quyền: --mode accept-edits + chỉ các lệnh ghép từ presets/common.json, preset của kho và "allow" trong config.
set -uo pipefail

KIT="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")/.." && pwd)"
TASK_DIR="$(cd "$1" && pwd)"; REPO="$2"; CONV="${3:-}"
DIR="$TASK_DIR/$REPO"
PROJECT="$(cd "$TASK_DIR/../../.." && pwd)"          # .agy/tasks/<việc> → gốc project
WORKTREE="$(cat "$DIR/worktree.txt")"
TIMEOUT="${AGY_TIMEOUT:-1800s}"

command -v agy >/dev/null || { echo "Chưa cài agy (Antigravity CLI)." >&2; exit 3; }

if [[ -n "$CONV" ]]; then
  PROMPT_FILE="$(ls -1 "$DIR"/feedback-*.md 2>/dev/null | sort -V | tail -1)"
else
  PROMPT_FILE="$DIR/brief.md"
fi
[[ -f "$PROMPT_FILE" ]] || { echo "Không thấy $PROMPT_FILE" >&2; exit 2; }

# Ghép quyền: common + preset(s) của kho + allow bổ sung trong config.
python3 - "$KIT/presets" "$PROJECT/.agy/config.json" "$REPO" "$WORKTREE" "$DIR/settings.json" <<'EOF'
import json, sys, glob, os
presets_dir, config_path, repo, worktree, out = sys.argv[1:]
def load(p):
    with open(p, encoding="utf-8") as f: return json.load(f)
allow, names = [], []
cfg = load(config_path) if os.path.exists(config_path) else {}
rc = (cfg.get("repos") or {}).get(repo, {})
names = rc.get("preset") or []
if isinstance(names, str): names = [names]
if not names:  # không khai preset → tự nhận diện theo file trong worktree
    for p in sorted(glob.glob(os.path.join(presets_dir, "*.json"))):
        d = load(p)
        if any(glob.glob(os.path.join(worktree, pat)) for pat in d.get("detect", [])):
            names.append(os.path.splitext(os.path.basename(p))[0])
for n in ["common", *names]:
    p = os.path.join(presets_dir, f"{n}.json")
    if os.path.exists(p): allow += load(p).get("allow", [])
allow += rc.get("allow", [])
allow = list(dict.fromkeys(allow))
json.dump({"permissions": {"allow": allow}}, open(out, "w"), indent=2)
# Danh sách dạng đọc được để Claude chép vào brief (agy chỉ được chạy đúng các tiền tố này).
with open(os.path.join(os.path.dirname(out), "allowed-commands.txt"), "w") as f:
    f.write("\n".join(a[len("command("):-1] for a in allow if a.startswith("command(")) + "\n")
print(f"preset={names or ['(chỉ common)']} lệnh_được_phép={len(allow)}")
EOF

N=$(( $(ls -1 "$DIR"/agy-*.json 2>/dev/null | wc -l) + 1 ))
OUT="$DIR/agy-$N.json"; ERR="$DIR/agy-$N.err"
ARGS=(--mode accept-edits --add-dir "$WORKTREE" --output-format json
      --settings "$DIR/settings.json" --print-timeout "$TIMEOUT")
[[ -n "$CONV" ]] && ARGS+=(--conversation "$CONV")
# Model: AGY_MODEL > "model" của kho > "model" chung trong config > mặc định của agy (xem bin/agy-model.sh).
MODEL="${AGY_MODEL:-$(python3 -c 'import json,os,sys
p,r=sys.argv[1:]
c=json.load(open(p)) if os.path.exists(p) else {}
print(((c.get("repos") or {}).get(r) or {}).get("model") or c.get("model") or "")' "$PROJECT/.agy/config.json" "$REPO")}"
if [[ -n "$MODEL" ]]; then ARGS+=(--model "$MODEL"); echo "$MODEL" > "$DIR/model.txt"; echo "model=$MODEL"; fi

cd "$WORKTREE"
agy "${ARGS[@]}" --print="$(cat "$PROMPT_FILE")" > "$OUT" 2> "$ERR"
CODE=$?

python3 - "$OUT" "$DIR/conversation.txt" <<'EOF' || true
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    if d.get("conversation_id"): open(sys.argv[2], "w").write(d["conversation_id"])
    denied = [x.get("display_name") for x in d.get("denied_actions") or []]
    print(f"agy status={d.get('status')} turns={d.get('num_turns')} "
          f"seconds={round(d.get('duration_seconds') or 0)} denied={denied}")
except Exception as e:
    print(f"Không đọc được kết quả JSON của agy: {e}")
EOF
echo "exit=$CODE output=$OUT"
exit $CODE
