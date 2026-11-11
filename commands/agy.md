---
description: Giao việc cho Antigravity (agy) — Claude đề xuất tiếng Việt, bạn duyệt, agy làm trong worktree riêng, Claude kiểm tra và commit
argument-hint: <yêu cầu bằng tiếng Việt>
---
Yêu cầu: $ARGUMENTS

Bạn (Claude) lập đề xuất, viết hướng dẫn và kiểm tra. **agy viết code — bạn không tự sửa code sản phẩm.**
Nói với người dùng bằng **tiếng Việt**; mọi thứ gửi cho agy bằng **tiếng Anh**.

Bộ công cụ: `~/.claude/agy/` — mẫu ở `templates/`, preset quyền ở `presets/`, script `bin/run-agy.sh`.
**Gốc project** = thư mục đang mở trong Claude Code (thư mục làm việc hiện tại).

## Bước 0 — Cấu hình project
- Đọc `<gốc>/.agy/config.json` nếu có. Mẫu:
  ```json
  {
    "repos": { "<tên>": { "path": ".", "preset": "flutter", "test": ["flutter analyze", "flutter test"], "allow": [] } },
    "base_branch": "develop",
    "commit_style": "type(scope): mô tả, không Co-Authored-By"
  }
  ```
  `path` tính từ gốc (`.` = gốc là một kho). `preset` là tên file trong `~/.claude/agy/presets/` (có thể là mảng).
  `test` là lệnh Claude chạy khi kiểm tra; thiếu thì dùng `test` của preset. `allow` thêm lệnh riêng cho agy (dạng `command(<tiền tố>)`).
- **Chưa có file**: tự nhận diện — gốc là kho Git → một kho `"."`; không thì mỗi thư mục con có `.git` là một kho; preset theo file
  đặc trưng (`pubspec.yaml` → flutter, `*.sln/*.slnx/*.csproj` → dotnet, `package.json` → node, `pyproject.toml`/`requirements.txt` → python).
  Đề xuất nội dung `config.json` ngay trong Bước 2 và chỉ ghi file khi người dùng duyệt.
- Đảm bảo `.agy/tasks/` và `.agy-worktrees/` không bị commit: nếu gốc là kho Git thì thêm vào `.gitignore` của gốc (khi tạo việc đầu tiên).
- Quy ước code của từng kho lấy từ `CLAUDE.md` / `AGENTS.md` của kho đó.

## Bước 1 — Mở việc
- Tạo `.agy/tasks/<yyyyMMdd-HHmm>-<ten-ngan-khong-dau>/` trong gốc project.
- Còn việc đang dở (worktree trong `.agy-worktrees/`) liên quan yêu cầu này → hỏi người dùng có gộp vào không.

## Bước 2 — Đề xuất (tiếng Việt) rồi DỪNG
- Đọc `CLAUDE.md` và đúng phần code liên quan (vừa đủ — tiết kiệm token là mục đích của quy trình).
- Viết `proposal.md` theo `~/.claude/agy/templates/proposal.md`: mục tiêu, phạm vi, cách làm, bảng phân việc (kho → session → file được phép sửa),
  tiêu chí nghiệm thu kiểm chứng được, cách kiểm tra, rủi ro.
- **Việc đụng nhiều kho** (vd backend + frontend): mỗi kho **một session chạy song song**; chốt *Hợp đồng dùng chung*
  (route API, tên/kiểu trường, enum) để các bên khớp nhau.
- Tóm tắt đề xuất cho người dùng rồi **DỪNG**: `wrap_up` với câu hỏi duyệt, nút **"Duyệt"** / **"Sửa đề xuất"**, `blocked: true`.
  Không sang Bước 3 khi chưa có lời duyệt của chính người dùng. Yêu cầu sửa → cập nhật `proposal.md`, trình lại, dừng.

## Bước 3 — Brief (tiếng Anh) + worktree
Với **mỗi kho** trong bảng phân việc:
1. Ghi nhánh hiện tại của kho vào `.agy/tasks/<việc>/<kho>/base.txt`, rồi tạo worktree (không đụng thư mục chính, không cần kho sạch):
   `git -C <đường-dẫn-kho> worktree add -b agy/<tên-việc> <gốc>/.agy-worktrees/<tên-việc>/<kho> HEAD`
   Ghi đường dẫn tuyệt đối của worktree vào `.agy/tasks/<việc>/<kho>/worktree.txt`.
2. Viết `.agy/tasks/<việc>/<kho>/brief.md` theo `~/.claude/agy/templates/brief.md`, **hoàn toàn tiếng Anh**: mục tiêu, bối cảnh,
   các bước, *Allowed paths*, hợp đồng dùng chung (nếu nhiều session), quy ước bắt buộc trích từ `CLAUDE.md`, tiêu chí nghiệm thu,
   lệnh tự kiểm tra, danh sách lệnh agy được chạy (đọc từ preset), yêu cầu ghi `AGY_REPORT.md`.

## Bước 4 — Giao cho agy
- Mỗi kho **một lệnh nền riêng** (`run_in_background: true`); nhiều kho thì chạy **song song**:
  `bash ~/.claude/agy/bin/run-agy.sh <gốc>/.agy/tasks/<việc> <kho>`
- agy chạy `--mode accept-edits`, chỉ được dùng lệnh ghép từ `presets/common.json` + preset của kho + `allow` trong config.
  Giới hạn mặc định 30 phút (`AGY_TIMEOUT=…s` để đổi).
- Báo người dùng một dòng: đã giao cho agy, đang chờ. **Không poll** — chờ thông báo tiến trình kết thúc.

## Bước 5 — Kiểm tra độc lập (khi agy xong)
Không coi báo cáo của agy là đủ. Với mỗi kho, trong worktree:
1. Đọc `agy-N.json` (`status`, `denied_actions`) và `AGY_REPORT.md`.
2. `git status --porcelain` + `git diff --stat`: có thay đổi thật không; file nào **ngoài *Allowed paths*** → ghi là vi phạm.
3. Chạy lệnh `test` của kho (config hoặc preset). Lệnh quá lâu thì lọc theo phần liên quan và ghi rõ đã lọc.
4. Đọc diff, đối chiếu từng tiêu chí. Việc giao diện: chạy app / simulator và chụp màn hình khi khả thi; việc API: gọi thử.
5. Nhiều session: kiểm tra các bên khớp *Hợp đồng dùng chung*.
6. Chuyển `AGY_REPORT.md` từ worktree vào `.agy/tasks/<việc>/<kho>/` (không để lọt vào commit).

## Bước 6 — Báo cáo (tiếng Việt) rồi DỪNG
- Viết `.agy/tasks/<việc>/report.md` theo `~/.claude/agy/templates/report.md`: từng tiêu chí **Đạt / Không đạt / Chưa kiểm được** kèm
  bằng chứng; ghi rõ chỗ agy tự báo khác với kiểm tra của bạn. Không báo "đạt" khi chưa có bằng chứng.
- Trình bày rồi **DỪNG** với `wrap_up`: nút **"Merge"** / **"Làm lại"** / **"Bỏ"**, `blocked: true`.

## Bước 7 — Theo lựa chọn của người dùng
- **Làm lại**: viết góp ý **tiếng Anh**, cụ thể (tiêu chí trượt, cách sửa) vào `.agy/tasks/<việc>/<kho>/feedback-<n>.md`, rồi chạy tiếp đúng phiên:
  `bash ~/.claude/agy/bin/run-agy.sh <gốc>/.agy/tasks/<việc> <kho> "$(cat <gốc>/.agy/tasks/<việc>/<kho>/conversation.txt)"`
  Quay lại Bước 5. **Tối đa 3 vòng** mỗi kho; quá thì dừng và hỏi người dùng.
- **Merge** (Claude commit luôn):
  1. Trong worktree: `git add` đúng các file đã đổi (không gồm `AGY_REPORT.md`), commit theo `commit_style` trong config,
     không có thì theo quy ước trong `CLAUDE.md` / lịch sử commit của kho. Tôn trọng quy định về `Co-Authored-By` của kho.
  2. Thư mục chính của kho: đang ở nhánh trong `base.txt` và merge không đụng file người dùng đang sửa dở →
     `git merge --ff-only agy/<tên-việc>` (không được thì `--no-ff`). Khác nhánh hoặc chồng file đang sửa → dừng, hỏi người dùng.
  3. `git worktree remove` + xoá nhánh `agy/<tên-việc>`. **Không push** — người dùng tự quyết.
- **Bỏ**: `git worktree remove --force` + `git branch -D agy/<tên-việc>`; giữ `.agy/tasks/<việc>` làm lịch sử.

## Nguyên tắc
- Không tự sửa code thay agy, kể cả lỗi nhỏ — ghi vào góp ý vòng sau.
- Không chạy agy với `--dangerously-skip-permissions`; không nới quyền (preset / `allow`) khi chưa hỏi người dùng.
- Đánh giá dựa trên Git và test, không dựa vào việc agy báo SUCCESS.
