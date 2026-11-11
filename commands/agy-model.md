---
description: Xem danh sách model của agy và đổi model agy dùng cho project này
argument-hint: "[list | show | set <model> [kho] | unset [kho]]"
---
Tham số: $ARGUMENTS

Dùng script `~/.claude/agy/bin/agy-model.sh`, chạy từ gốc project (thư mục đang mở). Trả lời bằng tiếng Việt.

- Không có tham số hoặc `show`: chạy `show` và `list`, trình bày model đang dùng (chung + từng kho) và bảng model có sẵn.
- `list`: chạy `list`, trình bày bảng (dấu `*` = model mặc định đang đặt).
- `set <model> [kho]`: chỉ chạy khi chính người dùng gõ lệnh này. Tên model phải đúng mã trong `list`;
  người dùng gõ tên gần đúng (vd "opus high", "flash") → khớp với một mã duy nhất trong `list`, mơ hồ thì hỏi lại.
  Có `kho` → đặt riêng cho kho đó. Sau khi đặt, chạy `show` để xác nhận.
- `unset [kho]`: bỏ đặt, quay về mặc định (của config chung hoặc của agy).

Model được ghi vào `.agy/config.json` (`"model"` chung hoặc trong `repos.<kho>`). Lần chạy agy sau của `/agy` sẽ dùng nó;
một lần chạy riêng có thể ghi đè bằng biến `AGY_MODEL=<mã>`. Model đã dùng cho mỗi lượt được ghi ở `.agy/tasks/<việc>/<kho>/model.txt`.
