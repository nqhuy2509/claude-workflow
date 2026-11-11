#!/usr/bin/env bash
# Xem / đổi model agy dùng cho một project.
#   agy-model.sh list                         các model agy hỗ trợ (đánh dấu model đang dùng)
#   agy-model.sh show   [gốc-project]         model đang cấu hình (mặc định chung + từng kho)
#   agy-model.sh set <model> [kho] [gốc]      đặt model mặc định (hoặc riêng cho một kho)
#   agy-model.sh unset [kho] [gốc]            bỏ đặt (dùng mặc định của agy)
#   agy-model.sh fallback <m1,m2,…|none> [kho] [gốc]  chuỗi model dự phòng khi hết quota
#   agy-model.sh executor <agy|codex|none> [kho] [gốc] executor mặc định (none = bỏ đặt)
#   agy-model.sh codex <model|none> [kho] [gốc]         model cho codex
#   agy-model.sh exec-fallback <codex|none> [gốc]       agy hết quota cả chuỗi → chuyển codex
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
  show|set|unset|fallback|executor|codex|exec-fallback)
    if [[ "$CMD" == set ]]; then
      MODEL="${1:?thiếu tên model}"; REPO="${2:-}"; ROOT="${3:-$PWD}"
      models | cut -f1 | grep -qx "$MODEL" || { echo "Model không có trong 'agy models': $MODEL" >&2; exit 2; }
    elif [[ "$CMD" == unset ]]; then MODEL=""; REPO="${1:-}"; ROOT="${2:-$PWD}"
    elif [[ "$CMD" == executor || "$CMD" == codex ]]; then
      MODEL="${1:?thiếu giá trị}"; REPO="${2:-}"; ROOT="${3:-$PWD}"
      [[ "$CMD" == executor && ! "$MODEL" =~ ^(agy|codex|none)$ ]] && { echo "executor phải là agy | codex | none" >&2; exit 2; }
    elif [[ "$CMD" == exec-fallback ]]; then
      MODEL="${1:?thiếu giá trị (codex|none)}"; REPO=""; ROOT="${2:-$PWD}"
    elif [[ "$CMD" == fallback ]]; then
      MODEL="${1:?thiếu danh sách model, vd m1,m2 hoặc none}"; REPO="${2:-}"; ROOT="${3:-$PWD}"
      if [[ "$MODEL" != none ]]; then AV="$(models | cut -f1)"
        for m in ${MODEL//,/ }; do grep -qx "$m" <<<"$AV" || { echo "Model không có trong 'agy models': $m" >&2; exit 2; }; done; fi
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
    elif cmd == "unset": target.pop("model", None)
    elif cmd in ("executor", "codex", "exec-fallback"):
        key = {"executor": "executor", "codex": "codex_model", "exec-fallback": "executor_fallback"}[cmd]
        if model == "none": target.pop(key, None)
        else: target[key] = model
    elif model == "none": target.pop("model_fallback", None)
    else: target["model_fallback"] = [m for m in model.split(",") if m]
    json.dump(cfg, open(cfg_path, "w", encoding="utf-8"), ensure_ascii=False, indent=2); open(cfg_path, "a").write("\n")
d = cfg.get("model") or "(mặc định của agy)"
ex = cfg.get("executor") or "agy"
print(f"executor: {ex}" + (f"   (agy hết quota → {cfg['executor_fallback']})" if cfg.get("executor_fallback") else "")
      + f"   model codex: {cfg.get('codex_model') or 'mặc định của codex'}")
fb = cfg.get("model_fallback") or []
print(f"chung: {d}" + (f"   dự phòng: {' → '.join(fb)}" if fb else ""))
for name, rc in (cfg.get("repos") or {}).items():
    rfb = rc.get("model_fallback")
    extra = "".join(f"   {k}: {rc[k]}" for k in ("executor", "codex_model") if rc.get(k))
    print(f"  {name}: {rc.get('model') or '→ ' + d}" + (f"   dự phòng: {' → '.join(rfb)}" if rfb else "") + extra)
print("(chạy: model đã đặt, hết quota thì lần lượt theo chuỗi dự phòng; chưa đặt model thì bắt đầu từ model đầu chuỗi)")
PY
    ;;
  *) sed -n '2,7p' "$0"; exit 1 ;;
esac
