#!/usr/bin/env bash
# Thống kê token đã dùng cho các việc /agy.
#
#   agy-usage.sh [gốc-project] [lọc-tên-việc | --all] [--write]
#
# Không lọc: việc mới nhất. --all: mọi việc + tổng. --write: ghi <việc>/usage.md.
# Nguồn: agy-N.json ("usage"), codex-N.jsonl (sự kiện turn.completed), và phần của Claude ước tính từ transcript
# của các phiên Claude Code trong project (~/.claude/projects/<project>/*.jsonl): cộng các lượt trả lời từ lần đầu
# transcript nhắc tên việc đến lúc file cuối của việc được ghi (+15 phút), bỏ trùng theo message id. Phần Claude là ƯỚC TÍNH (có thể lẫn việc khác làm xen kẽ).
set -uo pipefail
ROOT="$PWD"; FILTER=""; WRITE=""
for a in "$@"; do case "$a" in --write) WRITE=1;; --all) FILTER="--all";; *) if [[ -d "$a/.agy" ]]; then ROOT="$a"; else FILTER="$a"; fi;; esac; done
ROOT="$(cd "$ROOT" && pwd)"
CDIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/$(sed 's|[^A-Za-z0-9]|-|g' <<<"$ROOT")"
python3 - "$ROOT" "$FILTER" "$WRITE" "$CDIR" <<'PY'
import json, os, re, sys, glob
root, flt, write, cdir = sys.argv[1:]
tasks = sorted(p for p in glob.glob(os.path.join(root, ".agy/tasks/*/")) if not p.rstrip("/").endswith("archive"))
if flt and flt != "--all": tasks = [t for t in tasks if flt in os.path.basename(t.rstrip("/"))]
elif not flt: tasks = tasks[-1:]
if not tasks: print("Không có việc nào khớp."); sys.exit()

def k(n):
    n = n or 0
    return f"{n/1e6:.2f}M" if n >= 1e6 else f"{n/1e3:.1f}k" if n >= 1e3 else str(n)

def executor_runs(t):
    rows = []
    for rd in sorted(glob.glob(os.path.join(t, "*/"))):
        repo = os.path.basename(rd.rstrip("/"))
        model = open(os.path.join(rd, "model.txt")).read().strip() if os.path.exists(os.path.join(rd, "model.txt")) else "mặc định"
        for f in sorted(glob.glob(os.path.join(rd, "agy-*.json")), key=lambda p: int(re.search(r"-(\d+)\.", p).group(1))):
            try: d = json.load(open(f))
            except Exception: continue
            u = d.get("usage") or {}
            rows.append(dict(repo=repo, run=os.path.basename(f), ex="agy", model=model, sec=d.get("duration_seconds") or 0,
                             inp=u.get("input_tokens", 0), out=u.get("output_tokens", 0), think=u.get("thinking_tokens", 0),
                             cache=u.get("cache_read_tokens", 0)))
        for f in sorted(glob.glob(os.path.join(rd, "codex-*.jsonl")), key=lambda p: int(re.search(r"-(\d+)\.", p).group(1))):
            r = dict(repo=repo, run=os.path.basename(f), ex="codex", model=model.replace("codex:", ""), sec=0, inp=0, out=0, think=0, cache=0)
            for line in open(f, errors="ignore"):
                try: e = json.loads(line)
                except Exception: continue
                if e.get("type") == "turn.completed":
                    u = e.get("usage") or {}
                    r["inp"] += (u.get("input_tokens", 0) - u.get("cached_input_tokens", 0))
                    r["cache"] += u.get("cached_input_tokens", 0)
                    r["out"] += u.get("output_tokens", 0); r["think"] += u.get("reasoning_output_tokens", 0)
            rows.append(r)
    return rows

from datetime import datetime, timezone, timedelta
def ts(d):
    try: return datetime.fromisoformat(d["timestamp"].replace("Z", "+00:00"))
    except Exception: return None

def claude_usage(name, tdir):
    # Khoảng tính: từ lần đầu transcript nhắc tên việc → file cuối cùng của việc được ghi (+15 phút cho bước Merge).
    mt = [os.path.getmtime(f) for f in glob.glob(os.path.join(tdir, "**", "*"), recursive=True)
          if os.path.isfile(f) and os.path.basename(f) not in ("usage.md",)]
    end = datetime.fromtimestamp(max(mt), timezone.utc) + timedelta(minutes=15) if mt else None
    tot = dict(inp=0, write=0, cache=0, out=0, calls=0); seen = set(); sessions = 0
    for f in glob.glob(os.path.join(cdir, "*.jsonl")):
        try: lines = open(f, errors="ignore").read().splitlines()
        except Exception: continue
        start = None
        for l in lines:
            if name in l:
                try: start = ts(json.loads(l))
                except Exception: pass
                if start: break
        if not start: continue
        used = False
        for l in lines:
            if '"assistant"' not in l or '"usage"' not in l: continue
            try: d = json.loads(l)
            except Exception: continue
            m = d.get("message") or {}; u = m.get("usage") or {}; t = ts(d)
            if d.get("type") != "assistant" or not u or not t or t < start or (end and t > end) or m.get("id") in seen: continue
            seen.add(m.get("id")); used = True
            tot["inp"] += u.get("input_tokens", 0); tot["write"] += u.get("cache_creation_input_tokens", 0)
            tot["cache"] += u.get("cache_read_input_tokens", 0); tot["out"] += u.get("output_tokens", 0); tot["calls"] += 1
        sessions += used
    return tot, sessions

grand = dict(inp=0, out=0, think=0, cache=0, cin=0, cwrite=0, ccache=0, cout=0)
for t in tasks:
    name = os.path.basename(t.rstrip("/")); rows = executor_runs(t); c, ns = claude_usage(name, t)
    L = [f"# Token — {name}", "", "## Executor (agy / codex)",
         "| Kho | Lượt | Executor | Model | Thời gian | Input | Output | Thinking | Cache đọc |", "|---|---|---|---|---|---|---|---|---|"]
    s = dict(inp=0, out=0, think=0, cache=0, sec=0)
    for r in rows:
        L.append(f"| {r['repo']} | {r['run']} | {r['ex']} | {r['model']} | {round(r['sec']/60)} ph | {k(r['inp'])} | {k(r['out'])} | {k(r['think'])} | {k(r['cache'])} |")
        for x in s: s[x] += r[x]
    if not rows: L.append("| — | chưa chạy | | | | | | | |")
    else: L.append(f"| **Tổng** | {len(rows)} lượt | | | {round(s['sec']/60)} ph | **{k(s['inp'])}** | **{k(s['out'])}** | {k(s['think'])} | {k(s['cache'])} |")
    L += ["", "## Claude (lập đề xuất, brief, kiểm tra — ước tính từ transcript)"]
    if c["calls"]:
        L += [f"- {c['calls']} lượt gọi trong {ns} phiên · input {k(c['inp'] + c['write'])} (ghi cache {k(c['write'])}) · cache đọc {k(c['cache'])} · output **{k(c['out'])}**"]
    else: L += ["- Không tìm thấy trong transcript (phiên khác máy, đã xoá, hoặc chưa làm)."]
    L += ["", f"**Tổng việc**: executor {k(s['inp'] + s['out'])} (input+output) · Claude {k(c['inp'] + c['write'] + c['out'])} (input+output, không tính cache đọc)"]
    txt = "\n".join(L) + "\n"; print(txt)
    if write: open(os.path.join(t, "usage.md"), "w").write(txt)
    for a, b in (("inp", "inp"), ("out", "out"), ("think", "think"), ("cache", "cache")): grand[a] += s[b]
    grand["cin"] += c["inp"] + c["write"]; grand["ccache"] += c["cache"]; grand["cout"] += c["out"]
if len(tasks) > 1:
    print(f"## Tổng {len(tasks)} việc\n- Executor: input {k(grand['inp'])} · output {k(grand['out'])} · thinking {k(grand['think'])} · cache đọc {k(grand['cache'])}"
          f"\n- Claude: input {k(grand['cin'])} · cache đọc {k(grand['ccache'])} · output {k(grand['cout'])}")
PY
