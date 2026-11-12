---
description: Dọn worktree, nhánh agy/* đã merge, thư mục rỗng và việc cũ mà quy trình /agent để lại
argument-hint: "[--days N]"
---
Tham số: $ARGUMENTS

1. Chạy `~/.claude/agy/bin/agy-clean.sh <gốc-project> $ARGUMENTS` (chỉ liệt kê) từ thư mục đang mở; trình bày bằng tiếng Việt:
   mục **dọn an toàn** và mục **cần bạn quyết**.
2. Có mục dọn an toàn → hỏi người dùng (`wrap_up`, nút "Dọn" / "Để sau", `blocked: true`); chỉ khi người dùng đồng ý mới chạy lại với `--apply`.
3. Mục cần quyết (worktree còn thay đổi, nhánh chưa merge): chỉ báo, gợi ý dùng `/agent-status` để xem việc đó và chọn Merge/Bỏ theo quy trình `/agent`.
   Không tự `git branch -D`, không `worktree remove --force` cho các mục này.
