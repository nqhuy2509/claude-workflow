#!/usr/bin/env bash
# Dọn những gì quy trình /agent để lại. Mặc định CHỈ LIỆT KÊ; thêm --apply mới thực hiện.
#
#   agy-clean.sh [gốc-project] [--apply] [--days N]
#
# An toàn (làm khi --apply):
#   - thư mục rỗng trong .agy-worktrees/, worktree tạm .verify-base, `git worktree prune`
#   - nhánh agy/* ĐÃ merge vào base mà không còn worktree      → git branch -d (không bao giờ -D)
#   - worktree agy/* sạch (không thay đổi) và nhánh ĐÃ merge   → git worktree remove
#   - việc trong .agy/tasks/ cũ hơn N ngày (mặc định 30), không còn worktree → chuyển vào .agy/tasks/archive/
# Chỉ báo, không đụng: worktree còn thay đổi chưa commit, nhánh agy/* CHƯA merge, việc đang chạy.
set -uo pipefail
ROOT="$PWD"; APPLY=""; DAYS=30
while (( $# )); do case "$1" in --apply) APPLY=1;; --days) DAYS="$2"; shift;; *) ROOT="$1";; esac; shift; done
ROOT="$(cd "$ROOT" && pwd)"; CFG="$ROOT/.agy/config.json"
[[ -f "$CFG" ]] || { echo "Chưa có $CFG"; exit 0; }
SAFE=(); KEEP=()
act() { SAFE+=("$1"); [[ -n "$APPLY" ]] && eval "$2" >/dev/null 2>&1 && echo "✓ $1" ; }
RUNNING="$(ps -axo command= | grep -E '[a]gy --mode|[c]odex exec')"

BASE="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("base_branch","develop"))' "$CFG")"
while IFS=$'\t' read -r name path; do
  R="$ROOT/$path"; [[ -d "$R/.git" || -f "$R/.git" ]] || continue
  git -C "$R" worktree prune --dry-run -v 2>/dev/null | grep -q . && act "[$name] git worktree prune (worktree mất thư mục)" "git -C '$R' worktree prune"
  git -C "$R" rev-parse -q --verify "$BASE" >/dev/null || { KEEP+=("[$name] không có nhánh $BASE — bỏ qua"); continue; }
  # worktree agy/*
  while read -r wt br; do
    [[ "$br" == refs/heads/agy/* ]] || continue; b="${br#refs/heads/}"
    if grep -qF -- "$wt" <<<"$RUNNING"; then KEEP+=("[$name] $b đang chạy — giữ"); continue; fi
    dirty="$(git -C "$wt" status --porcelain 2>/dev/null | grep -v ' AGY_REPORT.md$' | head -1)"
    if git -C "$R" merge-base --is-ancestor "$b" "$BASE" && [[ -z "$dirty" ]]; then
      act "[$name] gỡ worktree đã merge $wt ($b)" "git -C '$R' worktree remove --force '$wt' && git -C '$R' branch -d '$b'"
    else KEEP+=("[$name] worktree $b ${dirty:+còn thay đổi chưa commit}${dirty:-chưa merge vào $BASE} — cần bạn quyết (Merge/Bỏ)"); fi
  done < <(git -C "$R" worktree list --porcelain | awk '/^worktree /{w=$2} /^branch /{print w, $2}')
  # nhánh agy/* không còn worktree
  for b in $(git -C "$R" for-each-ref --format='%(refname:short)' 'refs/heads/agy/*'); do
    git -C "$R" worktree list --porcelain | grep -q "refs/heads/$b$" && continue
    if git -C "$R" merge-base --is-ancestor "$b" "$BASE"; then act "[$name] xoá nhánh đã merge $b" "git -C '$R' branch -d '$b'"
    else KEEP+=("[$name] nhánh $b chưa merge, không có worktree — cần bạn quyết"); fi
  done
done < <(python3 -c 'import json,sys
for n,r in (json.load(open(sys.argv[1])).get("repos") or {}).items(): print(n, r.get("path","."), sep="\t")' "$CFG")

# worktree tạm của verify, thư mục rỗng
for v in "$ROOT"/.agy/tasks/*/*/.verify-base; do [[ -d "$v" ]] && act "xoá worktree tạm $v" "git -C '$v' worktree remove --force '$v' || rm -rf '$v'"; done
# thư mục rỗng (kể cả cha chỉ chứa thư mục rỗng): find -delete xoá từ trong ra ngoài
if [[ -d "$ROOT/.agy-worktrees" ]]; then
  E="$(find "$ROOT/.agy-worktrees" -mindepth 1 -type d -empty 2>/dev/null | sed "s|^$ROOT/||" | tr '\n' ' ')"
  [[ -n "$E" ]] && act "xoá thư mục rỗng trong .agy-worktrees: $E" "find '$ROOT/.agy-worktrees' -mindepth 1 -type d -empty -delete"
fi

# lưu trữ việc cũ
for t in "$ROOT"/.agy/tasks/*/; do
  n="$(basename "$t")"; [[ "$n" == archive ]] && continue
  [[ -n "$(find "$t" -maxdepth 0 -mtime +"$DAYS" 2>/dev/null)" ]] || continue
  live=""; for w in "$t"*/worktree.txt; do [[ -f "$w" && -d "$(cat "$w")" ]] && live=1; done
  [[ -n "$live" ]] && { KEEP+=("việc $n cũ hơn $DAYS ngày nhưng còn worktree — giữ"); continue; }
  act "lưu trữ việc cũ $n → .agy/tasks/archive/" "mkdir -p '$ROOT/.agy/tasks/archive' && mv '$t' '$ROOT/.agy/tasks/archive/'"
done

echo
if (( ${#SAFE[@]} )); then
  if [[ -n "$APPLY" ]]; then echo "Đã dọn ${#SAFE[@]} mục."; else echo "Có thể dọn an toàn (${#SAFE[@]}) — chạy lại với --apply:"; printf '  - %s\n' "${SAFE[@]}"; fi
else echo "Không có gì cần dọn."; fi
(( ${#KEEP[@]} )) && { echo "Giữ nguyên / cần bạn quyết:"; printf '  - %s\n' "${KEEP[@]}"; }
exit 0
