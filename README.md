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
| `bin/run-agy.sh` | Chạy agy cho một kho; ghép quyền từ preset; tiếp tục phiên (`--conversation`) |
| `templates/` | `proposal.md` (VI), `brief.md` (EN, kèm mẫu `AGY_REPORT.md`), `report.md` (VI) |
| `presets/` | Lệnh agy được phép theo loại project: `common`, `flutter`, `dotnet`, `node`, `python` |

## Xem việc đang chạy
`/agy-status` — bảng mọi việc trong `.agy/tasks/`: kho, trạng thái (ĐANG CHẠY / CHỜ KIỂM TRA / CHỜ QUYẾT / ĐÃ XONG/BỎ / CHƯA GIAO), model, số vòng, lần chạy cuối.
Chạy tay: `~/.claude/agy/bin/agy-status.sh [gốc-project]`.

## Chọn model cho agy
- `/agy-model` — xem model đang dùng và danh sách model (`agy models`).
- `/agy-model set claude-opus-5-5-high` — đặt model mặc định cho project; `/agy-model set gemini-3.8-flash-high libra-app` — riêng một kho.
- `/agy-model unset [kho]` — về mặc định. Ghi vào `"model"` trong `.agy/config.json`.
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
