---
description: Xem số token đã dùng cho việc giao agy/codex (executor + phần Claude)
argument-hint: "[số | từ khoá | --all]"
---
Tham số: $ARGUMENTS

Chạy `~/.claude/agy/bin/agy-usage.sh <gốc-project> $ARGUMENTS` từ thư mục đang mở rồi trình bày bằng tiếng Việt, gọn.
Người dùng **không cần biết tên việc**:
- Không tham số → bảng mọi việc (số thứ tự, tên, tiêu đề tiếng Việt, token executor, token Claude) + chi tiết việc mới nhất.
- Số (vd `2`) → việc thứ 2 trong bảng. Từ khoá (vd `tong cong`, `chứng từ`) → khớp tên hoặc tiêu đề, không phân biệt dấu.
  Khớp nhiều việc → trình bày tất cả; không khớp → chạy `--list` và cho người dùng chọn số.
- `--all` → chi tiết mọi việc + tổng.
Với chi tiết từng việc:
- Bảng executor: mỗi lượt (kho, agy/codex, model, thời gian, input, output, thinking, cache đọc) và tổng.
- Dòng Claude: số lượt gọi, input, output, cache đọc — nói rõ là **ước tính** từ transcript.
- Một câu nhận xét nếu đáng chú ý (vd vòng Làm lại tốn gần bằng vòng đầu, việc nhỏ mà dùng model lớn).
Token **cache đọc** rẻ hơn nhiều so với input thường — nêu riêng, không cộng vào tổng chính.
