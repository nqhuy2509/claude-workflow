---
description: Cấu hình agent cho project — executor (agy/codex), model agy/codex, model theo độ lớn việc, chuỗi dự phòng khi hết quota
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
- `fallback <m1,m2,…> [kho]` / `fallback none [kho]`: đặt / bỏ chuỗi model dự phòng khi hết quota (khớp tên gần đúng như `set`).
- `executor <agy|codex|none> [kho]`: executor mặc định. `codex <model|none> [kho]`: model cho codex (không có lệnh liệt kê — dùng tên người dùng đưa).
  `exec-fallback <codex|none>`: agy hết quota trên cả chuỗi model → chuyển codex.
  Khi chạy, agy hết quota → `run-agy.sh` tự chuyển model kế tiếp, tiếp tục đúng phiên, ghi `fallback.log`.

Model được ghi vào `.agy/config.json` (`"model"` chung hoặc trong `repos.<kho>`). Lần chạy agy sau của `/crew` sẽ dùng nó;
một lần chạy riêng có thể ghi đè bằng biến `AGY_MODEL=<mã>`. Model đã dùng cho mỗi lượt được ghi ở `.agy/tasks/<việc>/<kho>/model.txt`.
