#!/usr/bin/env bash
# Xem / đổi model agy dùng cho một project.
#   agy-model.sh list                         các model agy hỗ trợ (đánh dấu model đang dùng)
#   agy-model.sh show   [gốc-project]         model đang cấu hình (mặc định chung + từng kho)
#   agy-model.sh set <model> [kho] [gốc]      đặt model mặc định (hoặc riêng cho một kho)
#   agy-model.sh unset [kho] [gốc]            bỏ đặt (dùng mặc định của agy)
# Thứ tự ưu tiên khi chạy: biến AGY_MODEL > "model" của kho > "model" chung trong .agy/config.json > mặc định của agy.
set -uo pipefail
CMD="${1:-show}"; shift || true
models() { agy models 2>/dev/null | awk -F'\t' 'NF>=2{print $1"\t"$2}'; }

case "$CMD" in
  list)
    ROOT="${1:-$PWD}"; CUR=""
    [[ -f "$ROOT/.agy/config.json" ]] && CUR="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("model",""))' "$ROOT/.agy/config.json")"
    models | while IFS=$'\t' read -r id name; do
      [[ "$id" == "$CUR" ]] && m="*" || m=" "; printf "%s %-28s %s\n" "$m" "$id" "$name"; done ;;
  show|set|unset)
    if [[ "$CMD" == set ]]; then
      MODEL="${1:?thiếu tên model}"; REPO="${2:-}"; ROOT="${3:-$PWD}"
      models | cut -f1 | grep -qx "$MODEL" || { echo "Model không có trong 'agy models': $MODEL" >&2; exit 2; }
    elif [[ "$CMD" == unset ]]; then MODEL=""; REPO="${1:-}"; ROOT="${2:-$PWD}"
    else MODEL=""; REPO=""; ROOT="${1:-$PWD}"; fi
    CFG="$ROOT/.agy/config.json"
    [[ -f "$CFG" ]] || { echo "Chưa có $CFG" >&2; exit 2; }
    python3 - "$CFG" "$CMD" "$MODEL" "$REPO" <<'PY'
import json, sys
cfg_path, cmd, model, repo = sys.argv[1:]
cfg = json.load(open(cfg_path, encoding="utf-8"))
if cmd != "show":
    target = cfg if not repo else cfg.get("repos", {}).get(repo)
    if target is None: sys.exit(f"Không có kho '{repo}' trong config")
    if cmd == "set": target["model"] = model
    else: target.pop("model", None)
    json.dump(cfg, open(cfg_path, "w", encoding="utf-8"), ensure_ascii=False, indent=2); open(cfg_path, "a").write("\n")
d = cfg.get("model") or "(mặc định của agy)"
print(f"chung: {d}")
for name, rc in (cfg.get("repos") or {}).items():
    print(f"  {name}: {rc.get('model') or '→ ' + d}")
PY
    ;;
  *) sed -n '2,7p' "$0"; exit 1 ;;
esac
