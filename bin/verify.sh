#!/usr/bin/env bash
# Kiểm tra tự động một kho của một việc — Claude đọc bảng kết quả thay vì đọc cả diff.
#
#   verify.sh <thư-mục-việc> <tên-kho> [--no-test]
#
# Kiểm: (1) file đổi ngoài *Allowed paths* của brief; (2) symbol cấm sửa (dòng "Do NOT change `A`, `B`" trong brief)
# có bị đổi không; (3) dòng mới đáng ngờ theo preset ("suspect": chuỗi viết cứng, màu hex…); (4) chạy lệnh test của kho;
# (5) tóm AGY_REPORT.md. Ghi <kho>/verify.md (+ verify.log chứa output test lỗi). Mã thoát 1 nếu có mục ĐỎ.
set -uo pipefail
KIT="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")/.." && pwd)"
TASK_DIR="$(cd "$1" && pwd)"; REPO="$2"; NOTEST="${3:-}"
DIR="$TASK_DIR/$REPO"; PROJECT="$(cd "$TASK_DIR/../../.." && pwd)"
WT="$(cat "$DIR/worktree.txt")"; BASE="$(cat "$DIR/base.txt" 2>/dev/null || echo HEAD)"
cd "$WT" || exit 2
MB="$(git merge-base "$BASE" HEAD 2>/dev/null || git rev-parse HEAD)"
{ git diff --name-only "$MB"; git ls-files --others --exclude-standard; } | sort -u | grep -v '^AGY_REPORT.md$' > "$DIR/.changed"

python3 - "$KIT/presets" "$PROJECT/.agy/config.json" "$REPO" "$DIR" "$MB" "$NOTEST" <<'PY'
import json, os, re, subprocess, sys, glob
presets_dir, cfg_path, repo, d, mb, notest = sys.argv[1:]
cfg = json.load(open(cfg_path)) if os.path.exists(cfg_path) else {}
rc = (cfg.get("repos") or {}).get(repo) or {}
names = rc.get("preset") or []
names = [names] if isinstance(names, str) else names
presets = [json.load(open(p)) for n in names if os.path.exists(p := os.path.join(presets_dir, f"{n}.json"))]
brief = open(os.path.join(d, "brief.md"), encoding="utf-8").read()
changed = [l for l in open(os.path.join(d, ".changed")).read().splitlines() if l]
sh = lambda *a: subprocess.run(a, capture_output=True, text=True).stdout
red, out = 0, []

def glob_re(g):
    g = g.strip().rstrip("/")
    rx = re.escape(g).replace(r"\*\*/", "(.*/)?").replace(r"\*\*", ".*").replace(r"\*", "[^/]*").replace(r"\?", ".")
    return re.compile(rf"^{rx}(/.*)?$")

# (1) phạm vi file
sec = re.search(r"## Allowed paths.*?\n(.*?)(?=\n## )", brief, re.S)
allowed = []
for line in (sec.group(1) if sec else "").splitlines():
    if line.strip().startswith("-"):
        allowed += re.findall(r"`([^`]+)`", line)
pats = [glob_re(a) for a in allowed if "/" in a or "." in a or "*" in a]
outside = [f for f in changed if pats and not any(p.match(f) for p in pats)]
stat = sh("git", "diff", "--shortstat", mb).strip()
out.append(f"## Phạm vi\n- {len(changed)} file đổi ({stat or 'chỉ file mới'})")
out += [f"  - {f}" for f in changed[:40]]
if not pats: out.append("- ⚠️ Không đọc được *Allowed paths* trong brief — kiểm tay.")
elif outside:
    red += 1; out.append("- 🔴 Ngoài Allowed paths:"); out += [f"  - {f}" for f in outside]
else: out.append("- 🟢 Tất cả trong Allowed paths")

# (2) symbol cấm sửa
syms = []
for line in brief.splitlines():
    if re.match(r"\s*-\s*Do NOT (change|modify|touch)", line, re.I):
        syms += [s for s in re.findall(r"`([A-Za-z_]\w*)`", line)]
def block(text, name):
    lines = text.splitlines()
    for i, l in enumerate(lines):
        if re.search(rf"\b(class|enum|mixin|extension|interface|struct|record|function|def|void|Widget)\s+{re.escape(name)}\b", l):
            ind = len(l) - len(l.lstrip())
            j = i + 1
            while j < len(lines) and not (lines[j].strip() and len(lines[j]) - len(lines[j].lstrip()) <= ind
                                          and not lines[j].lstrip().startswith(("}", ")", "]"))):
                j += 1
            return "\n".join(lines[i:j])
    return None
if syms:
    out.append("\n## Symbol cấm sửa")
    for s in dict.fromkeys(syms):
        status = "không thấy trong file đổi"
        for f in changed:
            old = subprocess.run(["git", "show", f"{mb}:{f}"], capture_output=True, text=True).stdout
            new = open(f, errors="ignore").read() if os.path.exists(f) else ""
            bo, bn = block(old, s), block(new, s)
            if bo is None and bn is None: continue
            if bo == bn: status = f"🟢 giữ nguyên ({f})"
            elif bn is None: status = f"🔴 bị xoá/đổi tên ({f})"; red += 1
            else: status = f"🔴 bị sửa ({f})"; red += 1
            break
        out.append(f"- `{s}`: {status}")

# (3) dòng mới đáng ngờ
rules = [r for p in presets for r in p.get("suspect", [])]
if rules:
    hits = {}
    diff = sh("git", "diff", "-U0", mb)
    for f in [x for x in changed if x not in sh("git", "diff", "--name-only", mb).split()]:  # file mới chưa track
        try: diff += f"\n+++ b/{f}\n" + "".join("+" + l for l in open(f, errors="ignore"))
        except Exception: pass
    cur, ln = None, 0
    for l in diff.splitlines():
        if l.startswith("+++ b/"): cur = l[6:]; continue
        if l.startswith("@@"):
            m = re.search(r"\+(\d+)", l); ln = int(m.group(1)) - 1 if m else 0; continue
        if not l.startswith("+") or l.startswith("+++"): continue
        ln += 1; body = l[1:]; s = body.strip()
        if not cur or s.startswith(("//", "*", "/*", "<!--", "#", "///")): continue
        for r in rules:
            if glob_re(r["glob"]).match(cur) and not any(glob_re(x).match(cur) for x in r.get("exclude", [])) \
               and re.search(r["regex"], body):
                hits.setdefault(r["name"], []).append(f"{cur}:{ln}: {s[:110]}")
    out.append("\n## Dòng mới đáng ngờ (theo preset)")
    if not hits: out.append("- 🟢 Không có")
    for n, hs in hits.items():
        out.append(f"- 🟡 {n}: {len(hs)}"); out += [f"  - {h}" for h in hs[:8]]

# (4) test
tests = rc.get("test") or [t for p in presets for t in p.get("test", [])]
out.append("\n## Test")
if notest: out.append("- (bỏ qua --no-test)")
log = open(os.path.join(d, "verify.log"), "w")
def run(t, cwd):
    r = subprocess.run(t, shell=True, capture_output=True, text=True, cwd=cwd)
    tail = (r.stdout + r.stderr).strip().splitlines()
    summ = next((x for x in reversed(tail) if re.search(r"passed|failed|issues? found|No issues|error|Passed!|Failed!|succeeded", x, re.I)), tail[-1] if tail else "")
    return r.returncode, tail, re.sub(r"\(ran in [^)]*\)|\d+(\.\d+)?s\b|\d\d:\d\d", "", summ).strip(), summ
base_wt = None
for k, t in enumerate([] if notest else tests):
    code, tail, key, summ = run(t, os.getcwd())
    mark = "🟢"
    if code != 0:
        # Lỗi có sẵn từ base? Chạy lại (cùng các lệnh trước nó) trên worktree tạm ở merge-base.
        if base_wt is None:
            base_wt = os.path.join(d, ".verify-base")
            subprocess.run(["git", "worktree", "remove", "--force", base_wt], capture_output=True)
            subprocess.run(["git", "worktree", "add", "-q", "--detach", base_wt, mb], capture_output=True)
            for prev in tests[:k]: run(prev, base_wt)
        bcode, _, bkey, _ = run(t, base_wt)
        if bcode != 0 and bkey == key:
            mark = "🟡"; summ += " — giống hệt base (lỗi có sẵn, không do thay đổi này)"
        else:
            mark = "🔴"; red += 1
            log.write(f"===== {t} (exit {code})\n" + "\n".join(tail[-60:]) + "\n")
    out.append(f"- {mark} `{t}` — {summ.strip()[:160]}")
if base_wt: subprocess.run(["git", "worktree", "remove", "--force", base_wt], capture_output=True)

# (5) AGY_REPORT
rp = next((p for p in [os.path.join(os.getcwd(), "AGY_REPORT.md"), os.path.join(d, "AGY_REPORT.md")] if os.path.exists(p)), None)
out.append("\n## AGY_REPORT.md")
if not rp: red += 1; out.append("- 🔴 Không có báo cáo")
else:
    t = open(rp, encoding="utf-8").read()
    st = re.search(r"## Status\s*\n\s*(\w+)", t)
    unchecked = re.findall(r"- \[ \] (.+)", t)
    out.append(f"- Status: {st.group(1) if st else '?'} · tiêu chí tự đánh dấu chưa đạt: {len(unchecked)}")
    out += [f"  - {u[:120]}" for u in unchecked]
    oi = re.search(r"## Open issues.*?\n(.*)", t, re.S)
    if oi and oi.group(1).strip() and not re.match(r"-?\s*(none|không)", oi.group(1).strip(), re.I):
        out.append("- Open issues: " + " / ".join(x.strip("- ").strip() for x in oi.group(1).strip().splitlines()[:5]))

head = f"# Verify {os.path.basename(os.path.dirname(d))}/{repo} — {'🔴 ' + str(red) + ' mục đỏ' if red else '🟢 không có mục đỏ'}\n"
txt = head + "\n".join(out) + "\n\nĐọc diff có chọn lọc ở các mục 🔴/🟡 và các tiêu chí script không tự kiểm được.\n"
open(os.path.join(d, "verify.md"), "w").write(txt); print(txt)
sys.exit(1 if red else 0)
PY
