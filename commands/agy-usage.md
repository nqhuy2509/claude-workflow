---
description: Xem số token đã dùng cho việc giao agy/codex (executor + phần Claude)
argument-hint: "[tên-việc | --all]"
---
Tham số: $ARGUMENTS

Chạy `~/.claude/agy/bin/agy-usage.sh <gốc-project> $ARGUMENTS` từ thư mục đang mở (không tham số = việc mới nhất; `--all` = mọi việc + tổng)
rồi trình bày bằng tiếng Việt, gọn:
- Bảng executor: mỗi lượt (kho, agy/codex, model, thời gian, input, output, thinking, cache đọc) và tổng.
- Dòng Claude: số lượt gọi, input, output, cache đọc — nói rõ là **ước tính** từ transcript.
- Một câu nhận xét nếu đáng chú ý (vd vòng Làm lại tốn gần bằng vòng đầu, việc nhỏ mà dùng model lớn).
Token **cache đọc** rẻ hơn nhiều so với input thường — nêu riêng, không cộng vào tổng chính.
