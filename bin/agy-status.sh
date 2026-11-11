#!/usr/bin/env bash
# Liệt kê các việc agy của một project và trạng thái.
#   agy-status.sh [gốc-project]
# Trạng thái mỗi kho: ĐANG CHẠY | CHỜ KIỂM TRA | CHỜ QUYẾT | ĐÃ XONG/BỎ | CHƯA GIAO
set -uo pipefail
ROOT="$(cd "${1:-$PWD}" && pwd)"
[[ -d "$ROOT/.agy/tasks" ]] || { echo "Chưa có việc nào ($ROOT/.agy/tasks)"; exit 0; }
PS="$(ps -axo pid=,etime=,command= | grep -E '[a]gy --mode|[c]odex exec')"
python3 - "$ROOT" "$PS" <<'PY'
import json, os, sys, glob, re
root, ps = sys.argv[1], sys.argv[2]
rows = []
for task in sorted(glob.glob(os.path.join(root, ".agy/tasks/*/"))):
    name = os.path.basename(task.rstrip("/"))
    has_report = os.path.exists(os.path.join(task, "report.md"))
    for rd in sorted(glob.glob(os.path.join(task, "*/"))):
        repo = os.path.basename(rd.rstrip("/"))
        rd = rd.rstrip("/")
        wt = open(os.path.join(rd, "worktree.txt")).read().strip() if os.path.exists(os.path.join(rd, "worktree.txt")) else ""
        num = lambda p: int(re.search(r"-(\d+)\.", os.path.basename(p)).group(1))
        agy_runs = sorted(glob.glob(os.path.join(rd, "agy-*.json")), key=num)
        cx_runs = sorted(glob.glob(os.path.join(rd, "codex-*.jsonl")), key=num)
        runs = agy_runs + cx_runs
        ex = open(os.path.join(rd, "executor.txt")).read().strip() if os.path.exists(os.path.join(rd, "executor.txt")) else ("codex" if cx_runs and not agy_runs else "agy")
        model = open(os.path.join(rd, "model.txt")).read().strip() if os.path.exists(os.path.join(rd, "model.txt")) else "mặc định"
        proc = next((l for l in ps.splitlines() if wt and (f"--add-dir {wt} " in l + " " or f"-C {wt} " in l + " ")), None)
        last = ""
        latest = (cx_runs if ex == "codex" and cx_runs else agy_runs or cx_runs)
        if latest:
            f = latest[-1]
            try:
                if f.endswith(".jsonl"):
                    st_, n = "đang ghi", 0
                    for line in open(f, errors="ignore"):
                        try: d = json.loads(line)
                        except Exception: continue
                        if d.get("type") == "turn.completed": st_ = "SUCCESS"
                        elif d.get("type") == "turn.failed": st_ = "FAILED"
                        elif d.get("type") == "item.completed" and (d.get("item") or {}).get("type") == "command_execution": n += 1
                    last = f"{st_} lệnh={n}"
                else:
                    d = json.load(open(f))
                    den = len(d.get("denied_actions") or [])
                    last = f"{d.get('status')} {round(d.get('duration_seconds') or 0)//60}ph" + (f" chặn={den}" if den else "")
            except Exception: last = "đang ghi"
        if os.path.exists(os.path.join(rd, "fallback.log")): last += " ⇄"
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
        rows.append((name, repo, ex, st, model, str(rounds), last))
if not rows: print("Chưa có việc nào."); sys.exit()
note = "(⇄ = đã chuyển model/executor, xem fallback.log)"
hdr = ("Việc", "Kho", "Executor", "Trạng thái", "Model", "Vòng", "Lần chạy cuối")
w = [max(len(r[i]) for r in rows + [hdr]) for i in range(7)]
for r in [hdr] + rows: print("  ".join(c.ljust(w[i]) for i, c in enumerate(r)))
if any("⇄" in r[-1] for r in rows): print(note)
PY
