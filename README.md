# agy-workflow

Quy trình làm việc **Claude lập kế hoạch & kiểm tra — Antigravity (`agy`) viết code**, dùng chung cho mọi project.

```
Bạn ─/agy <yêu cầu>─► Claude: đề xuất tiếng Việt ─► Bạn duyệt
                      Claude: brief tiếng Anh + git worktree riêng
                      agy:    làm trong worktree (--mode accept-edits), ghi AGY_REPORT.md
                      Claude: kiểm tra độc lập (phạm vi file, test, chạy thử) ─► báo cáo tiếng Việt
Bạn: Merge (Claude commit + merge, không push) · Làm lại (góp ý, tối đa 3 vòng) · Bỏ
```
Việc đụng nhiều kho (vd backend + frontend) → mỗi kho một session agy chạy song song, có *hợp đồng dùng chung*.

## Cài đặt (mỗi máy một lần)
```bash
git clone <url-kho-này> ~/Developer/agy-workflow
~/Developer/agy-workflow/install.sh
```
Cần: Claude Code, `agy` (Antigravity CLI) đã đăng nhập, `python3`, và công cụ build của project (flutter, dotnet, node…).
`install.sh` tạo symlink `~/.claude/commands/agy.md` và `~/.claude/agy` → kho này. Cập nhật: `git pull` là xong.
Gỡ: `./install.sh --uninstall`.

## Dùng trong một project
Mở project trong Claude Code, gõ `/agy <yêu cầu bằng tiếng Việt>`.

Lần đầu, nếu project chưa có `.agy/config.json`, Claude tự nhận diện kho + loại project và đề xuất file cấu hình để bạn duyệt:
```json
{
  "repos": {
    "api": { "path": "backend",  "preset": "dotnet",  "test": ["dotnet build", "dotnet test"] },
    "app": { "path": "mobile",   "preset": "flutter", "test": ["flutter analyze", "flutter test"], "allow": [] }
  },
  "base_branch": "develop",
  "commit_style": "type(scope): mô tả, không Co-Authored-By"
}
```
- Project một kho: `"path": "."`.
- `allow`: thêm lệnh riêng agy được chạy, dạng tiền tố `command(<lệnh>)`, vd `command(make test)`.
- Quy ước code lấy từ `CLAUDE.md` / `AGENTS.md` của từng kho.
- Dữ liệu mỗi việc ở `.agy/tasks/`, worktree ở `.agy-worktrees/` (không commit).

## Cấu trúc
| Đường dẫn | Vai trò |
|---|---|
| `commands/agy.md` | Lệnh `/agy`: các bước, chỗ dừng chờ duyệt, quy tắc |
| `commands/agy-status.md`, `bin/agy-status.sh` | Xem các việc và trạng thái |
| `commands/agy-model.md`, `bin/agy-model.sh` | Xem / đổi model agy |
| `bin/preflight.sh` | Kiểm tra đầu vào trước khi giao |
| `commands/agy-clean.md`, `bin/agy-clean.sh` | Dọn worktree/nhánh/việc cũ |
| `bin/verify.sh` | Kiểm tra tự động một kho → `verify.md` |
| `bin/run-task.sh` | Điều phối: chọn executor, resume đúng phiên, chuyển codex khi agy hết quota |
| `bin/run-codex.sh` | Chạy codex cho một kho (sandbox workspace-write) |
| `bin/run-agy.sh` | Chạy agy cho một kho; ghép quyền từ preset; tiếp tục phiên (`--conversation`) |
| `templates/` | `proposal.md` (VI), `brief.md` (EN, kèm mẫu `AGY_REPORT.md`), `report.md` (VI) |
| `presets/` | Lệnh agy được phép theo loại project: `common`, `flutter`, `dotnet`, `node`, `python` |

## Executor: agy hoặc codex
Mỗi kho trong một việc do **agy** (mặc định) hoặc **codex** làm; `bin/run-task.sh` chọn và chạy đúng executor.
- `/agy-model executor codex [kho]` — đổi executor mặc định (chung hoặc một kho). Một lần: `EXECUTOR=codex run-task.sh …`.
- `/agy-model codex <model>` — model cho codex (`"codex_model"`); không đặt thì dùng mặc định trong `~/.codex/config.toml`.
- `/agy-model exec-fallback codex` — agy hết quota trên cả chuỗi model → tự chuyển codex (phiên mới, cùng worktree, ghi `fallback.log`).
- codex chạy `codex exec --sandbox workspace-write -c approval_policy="never"`: chỉ ghi trong worktree, **không mạng**, được tự chạy build/test
  (khác agy chỉ được chạy lệnh trong danh sách). Claude khôi phục gói trong worktree trước khi giao. Kết quả: `codex-N.jsonl`, `codex-N.last.md`, `session.txt`.
- Gợi ý: UI / theo thiết kế → agy; backend, sửa lỗi, việc phải chạy test nhiều vòng → codex. Việc hai kho có thể mỗi kho một executor, chạy song song.

## Tiết kiệm mà vẫn chắc chắn
- **Kiểm tra tự động** `bin/verify.sh <việc> <kho>` → `verify.md`: file ngoài *Allowed paths*, symbol cấm sửa (dòng `Do NOT change \`A\`` trong brief),
  dòng mới đáng ngờ theo preset (`"suspect"`: chuỗi viết cứng, màu hex, định dạng số…), chạy toàn bộ test (lỗi giống hệt base → 🟡 "có sẵn"),
  tóm `AGY_REPORT.md`. Claude đọc bảng này rồi chỉ đọc diff ở chỗ cần.
- **Model theo độ lớn việc**: đề xuất ghi S/M/L → `<việc>/size.txt` → `"model_by_size"` (`/agy-model size S gemini-3.8-flash-high`).
- **Test có trọng tâm**: brief chỉ cho agy chạy test của phần thay đổi; bộ đầy đủ chạy một lần trong `verify.sh`.
- **Bài học** `.agy/lessons.md` của project: mỗi dòng `- …` (tiếng Anh, `[kho: X]` để giới hạn) tự chèn vào prompt vòng đầu; Claude thêm dòng sau mỗi lần Làm lại / bị chặn lệnh.

## Kiểm tra đầu vào và dọn dẹp
- **Preflight** (`bin/preflight.sh`, tự chạy trong `run-task.sh`): brief đủ mục (*Allowed paths*, *Acceptance criteria*, *Self-check*, `AGY_REPORT.md`,
  không còn chỗ trống `<…>`), worktree tồn tại và ở nhánh `agy/*` (không phải thư mục chính), resume có `feedback-*.md`,
  executor đã cài + đăng nhập, không có agy/codex khác đang chạy trên worktree. Lỗi → thoát mã 5, không chạy.
- **`/agy-clean`** (`bin/agy-clean.sh [gốc] [--apply] [--days N]`): mặc định chỉ liệt kê. `--apply` dọn phần an toàn — worktree sạch đã merge,
  nhánh `agy/*` đã merge (`branch -d`), thư mục rỗng, worktree tạm của verify, `worktree prune`, việc cũ hơn N ngày (30) → `.agy/tasks/archive/`.
  Worktree còn thay đổi / nhánh chưa merge chỉ được báo, không bị đụng.

## Xem việc đang chạy
`/agy-status` — bảng mọi việc trong `.agy/tasks/`: kho, trạng thái (ĐANG CHẠY / CHỜ KIỂM TRA / CHỜ QUYẾT / ĐÃ XONG/BỎ / CHƯA GIAO), model, số vòng, lần chạy cuối.
Chạy tay: `~/.claude/agy/bin/agy-status.sh [gốc-project]`.

## Chọn model cho agy
- `/agy-model` — xem model đang dùng và danh sách model (`agy models`).
- `/agy-model set claude-opus-5-5-high` — đặt model mặc định cho project; `/agy-model set gemini-3.8-flash-high libra-app` — riêng một kho.
- `/agy-model unset [kho]` — về mặc định. Ghi vào `"model"` trong `.agy/config.json`.
- **Tự chuyển model khi hết quota**: `/agy-model fallback claude-opus-5-5-high,gemini-4-argon-high,claude-sonnet-5-5-high,gemini-3.8-flash-high`
  → ghi `"model_fallback"` vào config. agy hết quota (nhận diện qua `quota`, `rate limit`, `RESOURCE_EXHAUSTED`, `429`… trong kết quả)
  → `run-agy.sh` chuyển model kế tiếp, **tiếp tục đúng phiên** (không được thì mở phiên mới trên worktree cũ), ghi `fallback.log`.
  Thử hết chuỗi vẫn hết quota → thoát mã 4.
- Ghi đè một lần: `AGY_MODEL=<mã> run-agy.sh …`. Ưu tiên: `AGY_MODEL` > model của kho > model chung > mặc định của agy.

## Quyền của agy
agy chạy `--mode accept-edits`: tự sửa file trong worktree, **mọi lệnh terminal bị chặn trừ danh sách cho phép**
(ghép từ `presets/common.json` + preset của kho + `allow` trong config). Quy tắc dùng **tiền tố lệnh, không dấu `*`**:
`command(flutter test)` cho phép `flutter test …`. Không bao giờ dùng `--dangerously-skip-permissions`.

## Ghi chú kỹ thuật về agy
- Prompt phải gắn vào cờ: `--print="<prompt>"` (đặt cuối); `--print <prompt>` sẽ nuốt nhầm cờ phía sau.
- macOS không có `timeout`; dùng `--print-timeout 1800s` của agy.
- Kết quả `--output-format json`: `conversation_id`, `status`, `num_turns`, `denied_actions`.
- **Một lệnh bị chặn làm agy kết thúc lượt ngay** (`status` vẫn là SUCCESS, các bước sau bị bỏ dở). Vì vậy brief liệt kê chính xác
  lệnh được phép, và `/agy` tự chạy tiếp đúng phiên một lần khi thấy `denied_actions` hoặc thiếu `AGY_REPORT.md`.
