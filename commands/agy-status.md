---
description: Xem các việc agy của project này và trạng thái (đang chạy, chờ kiểm tra, chờ quyết, đã xong)
---
Chạy `~/.claude/agy/bin/agy-status.sh` từ gốc project (thư mục đang mở) rồi trình bày bảng bằng tiếng Việt.
- **ĐANG CHẠY (thời gian)**: tiến trình agy còn sống. **CHỜ KIỂM TRA**: agy xong, Claude chưa kiểm tra (chưa có `report.md`).
  **CHỜ QUYẾT**: đã có báo cáo, worktree còn — người dùng cần chọn Merge / Làm lại / Bỏ. **ĐÃ XONG/BỎ**: worktree đã gỡ. **CHƯA GIAO**: chưa chạy agy.
- Việc ĐANG CHẠY do phiên Claude khác giao thì chỉ báo, không can thiệp (không dừng tiến trình, không kiểm tra thay).
- Nhắc thư mục rỗng sót lại trong `.agy-worktrees/` (nếu có) — chỉ xoá khi người dùng đồng ý.
