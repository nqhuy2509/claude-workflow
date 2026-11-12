---
description: Giao việc cho Antigravity (agy) — Claude đề xuất tiếng Việt, bạn duyệt, agy làm trong worktree riêng, Claude kiểm tra và commit
argument-hint: <yêu cầu bằng tiếng Việt>
---
Yêu cầu: $ARGUMENTS

Bạn (Claude) lập đề xuất, viết hướng dẫn và kiểm tra. **agy viết code — bạn không tự sửa code sản phẩm.**
Nói với người dùng bằng **tiếng Việt**; mọi thứ gửi cho agy bằng **tiếng Anh**.

Bộ công cụ: `~/.claude/agy/` — mẫu ở `templates/`, preset quyền ở `presets/`, script `bin/run-task.sh` (điều phối executor **agy** hoặc **codex**: `run-agy.sh`, `run-codex.sh`).
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
- **Executor**: `"executor"` (chung hoặc theo kho) = `agy` (mặc định) | `codex`; `"executor_fallback": "codex"` = agy hết quota cả chuỗi model
  thì chuyển codex. Gợi ý khi đề xuất: UI / làm theo thiết kế → agy; backend, sửa lỗi, việc cần chạy test nhiều vòng → codex.
  Người dùng đổi được bằng `/agy-model executor …` hoặc ngay lúc duyệt đề xuất.

## Bước 1 — Mở việc
- Tạo `.agy/tasks/<yyyyMMdd-HHmm>-<ten-ngan-khong-dau>/` trong gốc project.
- Còn việc đang dở (worktree trong `.agy-worktrees/`) liên quan yêu cầu này → hỏi người dùng có gộp vào không.

## Bước 2 — Đề xuất (tiếng Việt) rồi DỪNG
- Đọc `CLAUDE.md` và đúng phần code liên quan (vừa đủ — tiết kiệm token là mục đích của quy trình).
- Viết `proposal.md` theo `~/.claude/agy/templates/proposal.md`: mục tiêu, phạm vi, cách làm, bảng phân việc (kho → session → file được phép sửa),
  tiêu chí nghiệm thu kiểm chứng được (mỗi tiêu chí gắn test/lệnh chứng minh), cách kiểm tra, rủi ro, và **độ lớn S/M/L**:
  S = ≤3 file, thay đổi cục bộ; M = một màn/một tính năng; L = nhiều màn, nhiều kho hoặc thay đổi kiến trúc.
  Độ lớn chọn model (`"model_by_size"` trong config). Việc **S**: đề xuất và brief rút gọn (5–7 dòng mỗi phần).
- **Việc đụng nhiều kho** (vd backend + frontend): mỗi kho **một session chạy song song**; chốt *Hợp đồng dùng chung*
  (route API, tên/kiểu trường, enum) để các bên khớp nhau.
- Tóm tắt đề xuất cho người dùng rồi **DỪNG**: `wrap_up` với câu hỏi duyệt, nút **"Duyệt"** / **"Sửa đề xuất"**, `blocked: true`.
  Không sang Bước 3 khi chưa có lời duyệt của chính người dùng. Yêu cầu sửa → cập nhật `proposal.md`, trình lại, dừng.

## Bước 3 — Brief (tiếng Anh) + worktree
Với **mỗi kho** trong bảng phân việc:
1. Ghi nhánh hiện tại của kho vào `.agy/tasks/<việc>/<kho>/base.txt`, rồi tạo worktree (không đụng thư mục chính, không cần kho sạch):
   `git -C <đường-dẫn-kho> worktree add -b agy/<tên-việc> <gốc>/.agy-worktrees/<tên-việc>/<kho> HEAD`
   Ghi đường dẫn tuyệt đối của worktree vào `.agy/tasks/<việc>/<kho>/worktree.txt`, độ lớn đã duyệt (S/M/L) vào `.agy/tasks/<việc>/size.txt`.
2. Viết `.agy/tasks/<việc>/<kho>/brief.md` theo `~/.claude/agy/templates/brief.md`, **hoàn toàn tiếng Anh**: mục tiêu, bối cảnh,
   các bước, *Allowed paths*, hợp đồng dùng chung (nếu nhiều session), quy ước bắt buộc trích từ `CLAUDE.md`, tiêu chí nghiệm thu,
   lệnh tự kiểm tra **có trọng tâm** (chỉ test/analyze của phần thay đổi — bộ test đầy đủ do `verify.sh` chạy), yêu cầu ghi `AGY_REPORT.md`.
   Không chép lại bài học trong `.agy/lessons.md` vào brief — script tự chèn ở vòng đầu.
3. **Danh sách lệnh agy được chạy**: ghép giống script (`presets/common.json` + preset của kho + `allow`), chép nguyên văn vào mục
   *Commands* của brief. agy chạy một lệnh ngoài danh sách là **bị chặn và kết thúc lượt ngay** — nên chỉ yêu cầu agy tự kiểm tra
   bằng đúng các lệnh trong danh sách. (Script ghi lại danh sách thực tế vào `allowed-commands.txt` sau mỗi lần chạy để đối chiếu.)

## Bước 4 — Giao cho agy
- Mỗi kho **một lệnh nền riêng** (`run_in_background: true`); nhiều kho thì chạy **song song**:
  `bash ~/.claude/agy/bin/run-task.sh <gốc>/.agy/tasks/<việc> <kho>` (executor theo bảng phân việc: thêm `EXECUTOR=codex` phía trước nếu khác config)
- `run-task.sh` tự chạy `preflight.sh` trước; thoát mã **5** = đầu vào lỗi (brief thiếu mục, worktree sai, executor chưa đăng nhập…) →
  sửa theo thông báo rồi giao lại, không coi là lượt của agy.
- **codex** chạy `--sandbox workspace-write` (chỉ ghi trong worktree, **không có mạng**): trước khi giao, Claude tự chạy bước khôi phục gói
  trong worktree (`flutter pub get` / `npm ci` / `dotnet restore`…). codex được tự chạy build/test, nên brief giữ mục *Commands* như cũ
  (script tự thêm ghi chú cho codex). Không bao giờ dùng `--dangerously-bypass-approvals-and-sandbox`, không bật mạng khi chưa hỏi người dùng.
- agy chạy `--mode accept-edits`, chỉ được dùng lệnh ghép từ `presets/common.json` + preset của kho + `allow` trong config.
  Model theo `"model"` trong config (đổi bằng `/agy-model`); nêu model đang dùng trong dòng báo người dùng.
  Hết quota → script tự chuyển model theo `"model_fallback"` và tiếp tục phiên; thoát mã 4 = đã thử hết chuỗi → báo người dùng.
  Giới hạn mặc định 30 phút (`AGY_TIMEOUT=…s` để đổi).
- Báo người dùng một dòng: đã giao cho agy, đang chờ. **Không poll** — chờ thông báo tiến trình kết thúc.

## Bước 5 — Kiểm tra độc lập (khi agy xong)
Không coi báo cáo của agy là đủ. Với mỗi kho, trong worktree:
1. Đọc kết quả lượt cuối — agy: `agy-N.json` (`status`, `denied_actions`); codex: `codex-N.jsonl` (`turn.completed`/`turn.failed`) và `codex-N.last.md` — cùng `AGY_REPORT.md`.
   **Có `denied_actions` hoặc không có `AGY_REPORT.md`** → agy đã bị dừng giữa chừng vì một lệnh bị chặn. Tự chạy tiếp đúng phiên
   **một lần** (không cần hỏi người dùng): viết `feedback-<n>.md` tiếng Anh nói lệnh đó không được phép, đừng chạy lại, hoàn tất các bước
   còn lại và ghi báo cáo; chạy `run-task.sh <thư-mục-việc> <kho> resume`. Lần này tính vào giới hạn 3 vòng.
2. Chạy `bash ~/.claude/agy/bin/verify.sh <gốc>/.agy/tasks/<việc> <kho>` (nền nếu test lâu) rồi **đọc `verify.md` trước**: phạm vi file,
   symbol cấm sửa, dòng đáng ngờ theo preset, toàn bộ test (lỗi trùng base được hạ thành 🟡), tóm `AGY_REPORT.md`. Chi tiết test lỗi ở `verify.log`.
3. **Đọc diff có chọn lọc**: chỉ các chỗ 🔴/🟡 và phần cần cho tiêu chí script không tự kiểm được (`git diff <base> -- <file>` hoặc theo hàm),
   không đọc toàn bộ diff lớn khi verify đã sạch.
4. Đối chiếu từng tiêu chí. Việc giao diện: chạy app / simulator và chụp màn hình khi khả thi; việc API: gọi thử.
5. Nhiều session: kiểm tra các bên khớp *Hợp đồng dùng chung*.
6. Có `fallback.log` → nêu trong báo cáo: model nào hết quota, chuyển sang model nào, ở lượt nào.
7. Chuyển `AGY_REPORT.md` từ worktree vào `.agy/tasks/<việc>/<kho>/` (không để lọt vào commit).

## Bước 6 — Báo cáo (tiếng Việt) rồi DỪNG
- Viết `.agy/tasks/<việc>/report.md` theo `~/.claude/agy/templates/report.md`: từng tiêu chí **Đạt / Không đạt / Chưa kiểm được** kèm
  bằng chứng; ghi rõ chỗ agy tự báo khác với kiểm tra của bạn. Không báo "đạt" khi chưa có bằng chứng.
- **Token (mặc định)**: chạy `bash ~/.claude/agy/bin/agy-usage.sh <gốc> <tên-việc> --write`, chép phần tổng vào mục *Token* của `report.md`
  và nêu một dòng trong tin nhắn cho người dùng (executor input/output theo model + Claude ước tính). Báo lại sau mỗi vòng Làm lại và khi Merge.
- Trình bày rồi **DỪNG** với `wrap_up`: nút **"Merge"** / **"Làm lại"** / **"Bỏ"**, `blocked: true`.

## Bước 7 — Theo lựa chọn của người dùng
- **Làm lại**: viết góp ý **tiếng Anh**, cụ thể (tiêu chí trượt, cách sửa) vào `.agy/tasks/<việc>/<kho>/feedback-<n>.md`, rồi chạy tiếp đúng phiên:
  `bash ~/.claude/agy/bin/run-task.sh <gốc>/.agy/tasks/<việc> <kho> resume` (tự dùng đúng executor + phiên trong `executor.txt`)
  Quay lại Bước 5. **Tối đa 3 vòng** mỗi kho; quá thì dừng và hỏi người dùng.
- **Merge** (Claude commit luôn):
  1. Trong worktree: `git add` đúng các file đã đổi (không gồm `AGY_REPORT.md`), commit theo `commit_style` trong config,
     không có thì theo quy ước trong `CLAUDE.md` / lịch sử commit của kho. Tôn trọng quy định về `Co-Authored-By` của kho.
  2. Thư mục chính của kho: đang ở nhánh trong `base.txt` và merge không đụng file người dùng đang sửa dở →
     `git merge --ff-only agy/<tên-việc>` (không được thì `--no-ff`). Khác nhánh hoặc chồng file đang sửa → dừng, hỏi người dùng.
  3. `git worktree remove` + xoá nhánh `agy/<tên-việc>`. **Không push** — người dùng tự quyết.
- **Bài học**: sau mỗi việc, nếu có Làm lại, lệnh bị chặn, hoặc verify bắt lỗi mà một câu trong brief có thể tránh được → thêm **một dòng tiếng Anh**
  `- …` (kèm `[kho: <tên>]` nếu chỉ áp cho một kho) vào `<gốc>/.agy/lessons.md` và nói cho người dùng. Không thêm bài học trùng; giữ file ngắn (≤ 30 dòng),
  gộp/xoá dòng cũ khi cần. Script tự chèn các dòng này vào prompt vòng đầu của agy/codex.
- Thỉnh thoảng (hoặc khi người dùng hỏi) gợi ý `/agy-clean` để dọn phần sót lại.
- **Bỏ**: `git worktree remove --force` + `git branch -D agy/<tên-việc>`; giữ `.agy/tasks/<việc>` làm lịch sử.

## Nguyên tắc
- Không tự sửa code thay agy, kể cả lỗi nhỏ — ghi vào góp ý vòng sau.
- Không chạy agy với `--dangerously-skip-permissions`; không nới quyền (preset / `allow`) khi chưa hỏi người dùng.
- Đánh giá dựa trên Git và test, không dựa vào việc agy báo SUCCESS.
