#!/usr/bin/env bash
# Liệt kê các việc agy của một project và trạng thái.
#   agy-status.sh [gốc-project]
# Trạng thái mỗi kho: ĐANG CHẠY | CHỜ KIỂM TRA | CHỜ QUYẾT | ĐÃ XONG/BỎ | CHƯA GIAO
set -uo pipefail
ROOT="$(cd "${1:-$PWD}" && pwd)"
[[ -d "$ROOT/.agy/tasks" ]] || { echo "Chưa có việc nào ($ROOT/.agy/tasks)"; exit 0; }
PS="$(ps -axo pid=,etime=,command= | grep -E '[a]gy --mode')"
python3 - "$ROOT" "$PS" <<'PY'
import json, os, sys, glob
root, ps = sys.argv[1], sys.argv[2]
rows = []
for task in sorted(glob.glob(os.path.join(root, ".agy/tasks/*/"))):
    name = os.path.basename(task.rstrip("/"))
    has_report = os.path.exists(os.path.join(task, "report.md"))
    for rd in sorted(glob.glob(os.path.join(task, "*/"))):
        repo = os.path.basename(rd.rstrip("/"))
        rd = rd.rstrip("/")
        wt = open(os.path.join(rd, "worktree.txt")).read().strip() if os.path.exists(os.path.join(rd, "worktree.txt")) else ""
        runs = sorted(glob.glob(os.path.join(rd, "agy-*.json")), key=lambda p: int(p.rsplit("-",1)[1].split(".")[0]))
        model = open(os.path.join(rd, "model.txt")).read().strip() if os.path.exists(os.path.join(rd, "model.txt")) else "mặc định"
        proc = next((l for l in ps.splitlines() if wt and f"--add-dir {wt} " in l + " "), None)
        last = ""
        if runs:
            try:
                d = json.load(open(runs[-1]))
                den = len(d.get("denied_actions") or [])
                last = f"{d.get('status')} {round(d.get('duration_seconds') or 0)//60}ph" + (f" chặn={den}" if den else "")
            except Exception: last = "đang ghi"
        if proc:
            st = f"ĐANG CHẠY ({proc.split()[1]})"
        elif not wt or not os.path.isdir(wt):
            st = "ĐÃ XONG/BỎ" if runs else "CHƯA GIAO"
        elif not runs:
            st = "CHƯA GIAO"
        elif has_report:
            st = "CHỜ QUYẾT"
        else:
            st = "CHỜ KIỂM TRA"
        rounds = len(runs) + (1 if proc and last != "đang ghi" else 0)
        if proc and last == "đang ghi": last = "—"
        rows.append((name, repo, st, model, str(rounds), last))
if not rows: print("Chưa có việc nào."); sys.exit()
hdr = ("Việc", "Kho", "Trạng thái", "Model", "Vòng", "Lần chạy cuối")
w = [max(len(r[i]) for r in rows + [hdr]) for i in range(6)]
for r in [hdr] + rows: print("  ".join(c.ljust(w[i]) for i, c in enumerate(r)))
PY
