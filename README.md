# crew — Claude lập kế hoạch & kiểm tra, agent viết code

Quy trình dùng chung cho mọi project: **Claude** đề xuất, viết hướng dẫn và kiểm tra; **agent** (Antigravity `agy` hoặc `codex`) viết code
trong git worktree riêng. Bạn chỉ duyệt đề xuất và chọn Merge / Làm lại / Bỏ.

```
Bạn ─/crew <yêu cầu>─► Claude: đề xuất tiếng Việt (kèm độ lớn S/M/L, executor mỗi kho) ─► Bạn duyệt
                       Claude: brief tiếng Anh + git worktree riêng + preflight
                       agy/codex: làm trong worktree, ghi AGY_REPORT.md   (hết quota → tự đổi model / sang codex)
                       Claude: verify.sh + đọc diff có chọn lọc + chạy thử ─► báo cáo tiếng Việt + token
Bạn: Merge (Claude commit + merge, không push) · Làm lại (góp ý, tối đa 3 vòng) · Bỏ
```
Việc đụng nhiều kho (vd backend + frontend) → mỗi kho một session chạy song song, có *hợp đồng dùng chung*.

## Lệnh
| Lệnh | Việc |
|---|---|
| `/crew <yêu cầu>` | Quy trình đầy đủ; executor mỗi kho theo config / loại việc (đổi được lúc duyệt) |
| `/agy <yêu cầu>` · `/codex <yêu cầu>` | Như `/crew`, ép mọi kho dùng agy / codex |
| `/crew-status` | Các việc: kho, executor, trạng thái (đang chạy · chờ kiểm tra · chờ quyết · đã xong · chưa giao), model, số vòng |
| `/crew-config` | Executor, model agy/codex, model theo độ lớn S/M/L, chuỗi dự phòng khi hết quota |
| `/crew-usage [số \| từ khoá \| --all]` | Token theo việc; không tham số → bảng việc có số thứ tự + chi tiết việc mới nhất |
| `/crew-clean` | Dọn worktree, nhánh `agy/*` đã merge, thư mục rỗng, việc cũ (hỏi trước khi dọn) |

## Cài đặt (mỗi máy một lần)
```bash
git clone https://github.com/nqhuy2509/claude-workflow.git ~/Developer/agy-workflow
~/Developer/agy-workflow/install.sh
```
Cần: Claude Code, ít nhất một executor đã đăng nhập (`agy` và/hoặc `codex`), `python3`, công cụ build của project (flutter, dotnet, node…).
`install.sh` tạo symlink cho mọi lệnh trong `commands/` vào `~/.claude/commands/` (tự gỡ symlink lệnh cũ đã đổi tên) và `~/.claude/agy` → kho này.
Cập nhật: `git pull` rồi `./install.sh`. Gỡ: `./install.sh --uninstall`.

## Cấu hình project — `.agy/config.json`
Lần đầu chạy `/crew`, Claude tự nhận diện kho + loại project và đề xuất file này để bạn duyệt. Đầy đủ các khoá:
```json
{
  "repos": {
    "api": { "path": "backend", "preset": "dotnet",  "test": ["dotnet build", "dotnet test"], "executor": "codex" },
    "app": { "path": "mobile",  "preset": "flutter", "test": ["flutter analyze", "flutter test"], "allow": [] }
  },
  "base_branch": "develop",
  "commit_style": "type(scope): mô tả, không Co-Authored-By",
  "executor": "agy",
  "executor_fallback": "codex",
  "model_by_size": { "S": "gemini-3.8-flash-high", "M": "claude-sonnet-5-5-high", "L": "claude-opus-5-5-high" },
  "model_fallback": ["claude-opus-5-5-high", "gemini-4-argon-high", "claude-sonnet-5-5-high", "gemini-3.8-flash-high"],
  "codex_model": "gpt-6-astra"
}
```
- `path`: tính từ gốc project; project một kho dùng `"."`. `preset`: tên file trong `presets/` (chuỗi hoặc mảng).
- `test`: lệnh Claude chạy khi kiểm tra (thiếu thì lấy của preset). `allow`: thêm lệnh agy được chạy, dạng `command(<tiền tố>)`.
- `executor`, `model`, `model_by_size`, `model_fallback`, `codex_model`, `codex_model_by_size` đặt được ở mức chung hoặc trong từng kho
  (kho ưu tiên hơn). Chỉnh bằng `/crew-config` thay vì sửa tay.
- Quy ước code lấy từ `CLAUDE.md` / `AGENTS.md` của từng kho.
- Dữ liệu mỗi việc ở `.agy/tasks/<việc>/`, worktree ở `.agy-worktrees/` (không commit). Bài học tích luỹ ở `.agy/lessons.md`.

## Executor: agy hay codex
| | agy (Antigravity) | codex |
|---|---|---|
| Quyền | `--mode accept-edits`: sửa file trong worktree; **chỉ chạy được lệnh trong danh sách** (preset + `allow`) | `--sandbox workspace-write`: chỉ ghi trong worktree, **không mạng**, được tự chạy build/test |
| Hợp với | UI, làm theo thiết kế | backend, sửa lỗi, việc phải chạy test nhiều vòng |
| Kết quả | `agy-N.json`, `conversation.txt` | `codex-N.jsonl`, `codex-N.last.md`, `session.txt` |
| Tiếp tục phiên | `--conversation <id>` | `codex exec resume <id>` |

- `bin/run-task.sh` chọn executor (ưu tiên: biến `EXECUTOR` > `executor` của kho > `executor` chung > `agy`), ghi vào `executor.txt`;
  "Làm lại" dùng lại đúng executor + phiên đó.
- Trước khi giao cho codex, Claude khôi phục gói trong worktree (`flutter pub get`, `npm ci`, `dotnet restore`…) vì sandbox không có mạng.
- Không bao giờ dùng `--dangerously-skip-permissions` (agy) hay `--dangerously-bypass-approvals-and-sandbox` (codex).

## Model
- **Thứ tự chọn model agy**: `AGY_MODEL` > `model` của kho > `model_by_size[S|M|L]` > `model` chung > đầu `model_fallback` > mặc định của agy.
  Độ lớn lấy từ `<việc>/size.txt` (Claude ghi theo đề xuất đã duyệt: S ≤3 file · M một màn/tính năng · L nhiều màn/kho, kiến trúc).
- **Codex**: `CODEX_MODEL` > `codex_model` của kho > `codex_model_by_size` > `codex_model` chung > mặc định trong `~/.codex/config.toml`.
- **Hết quota**: nhận diện qua `quota`, `rate limit`, `RESOURCE_EXHAUSTED`, `429`… trong kết quả → chuyển model kế tiếp trong `model_fallback`,
  tiếp tục đúng phiên (không được thì phiên mới trên cùng worktree). Hết cả chuỗi → `executor_fallback: "codex"` thì chuyển codex; không thì thoát mã 4.
  Mọi lần chuyển ghi ở `<việc>/<kho>/fallback.log`; `/crew-status` đánh dấu ⇄.
- Lệnh: `/crew-config` (xem) · `set <model> [kho]` · `unset [kho]` · `size S <model>` · `fallback m1,m2,…` · `executor agy|codex [kho]`
  · `codex <model>` · `exec-fallback codex|none`.

## Kiểm tra: preflight → verify → báo cáo
- **Preflight** (`bin/preflight.sh`, tự chạy trong `run-task.sh`, lỗi → mã 5, không chạy): brief đủ mục (*Allowed paths*, *Acceptance criteria*,
  *Self-check*, `AGY_REPORT.md`, không còn chỗ trống `<…>`); worktree tồn tại, ở nhánh `agy/*`, không phải thư mục chính; resume có `feedback-*.md`;
  executor đã cài + đăng nhập; không có lượt khác đang chạy trên worktree.
- **Verify** (`bin/verify.sh <việc> <kho>` → `verify.md`, test lỗi chi tiết ở `verify.log`): file ngoài *Allowed paths*; symbol cấm sửa
  (dòng `Do NOT change \`A\`` trong brief); dòng mới đáng ngờ theo preset (`"suspect"`: chuỗi tiếng Việt viết cứng, màu hex, định dạng số…);
  chạy toàn bộ `test` của kho — lệnh lỗi được chạy lại trên base, giống hệt base thì hạ thành 🟡 "có sẵn"; tóm `AGY_REPORT.md`.
  Claude đọc bảng này trước, chỉ đọc diff ở chỗ 🔴/🟡 và tiêu chí script không tự kiểm được.
- **Báo cáo** (`report.md`, tiếng Việt): từng tiêu chí Đạt / Không đạt / Chưa kiểm được kèm bằng chứng, chỗ agent tự báo khác kiểm tra,
  việc chuyển model/executor, và **token** (`agy-usage.sh --write` → `usage.md`).

## Tiết kiệm mà vẫn chắc chắn
- **Model theo độ lớn**: việc nhỏ dùng model nhanh/rẻ, việc lớn mới dùng model mạnh nhất.
- **Test có trọng tâm**: brief chỉ cho agent chạy analyze/test của phần thay đổi; bộ đầy đủ chạy một lần trong `verify.sh`.
- **Việc cỡ S**: đề xuất và brief rút gọn.
- **Bài học** `.agy/lessons.md`: mỗi dòng `- …` (tiếng Anh; `[kho: X]` để chỉ áp cho kho X) tự chèn vào prompt vòng đầu.
  Claude thêm dòng sau mỗi lần Làm lại, agent bị chặn lệnh, hoặc verify bắt lỗi lặp lại; giữ ≤ 30 dòng.

## Token đã dùng — `/crew-usage`
`bin/agy-usage.sh [gốc] [số | từ-khoá | --list | --all] [--write]`
- Không tham số → bảng mọi việc (số thứ tự, tên, tiêu đề tiếng Việt, token) + chi tiết việc mới nhất. Chọn bằng số (`2`) hoặc từ khoá
  không dấu khớp tên/tiêu đề (`tong cong`). `--all` → chi tiết mọi việc + tổng.
- agy: `usage` trong `agy-N.json`; codex: `turn.completed` trong `codex-N.jsonl` — chính xác, theo từng lượt, kèm model và thời gian.
- Claude: **ước tính** từ transcript phiên (`~/.claude/projects/<project>/*.jsonl`), từ lần đầu nhắc tên việc đến khi file cuối của việc được ghi
  (+15 phút), bỏ trùng theo message id. Token cache đọc tách riêng (rẻ hơn nhiều).

## Dọn dẹp — `/crew-clean`
`bin/agy-clean.sh [gốc] [--apply] [--days N]` — mặc định chỉ liệt kê; `--apply` (sau khi bạn đồng ý) dọn phần an toàn: worktree sạch đã merge,
nhánh `agy/*` đã merge (`branch -d`, không bao giờ `-D`), thư mục rỗng, worktree tạm của verify, `worktree prune`,
việc cũ hơn N ngày (mặc định 30) → `.agy/tasks/archive/`. Worktree còn thay đổi / nhánh chưa merge chỉ được báo.

## Cấu trúc kho
| Đường dẫn | Vai trò |
|---|---|
| `commands/crew.md` | Quy trình `/crew`: các bước, chỗ dừng chờ duyệt, nguyên tắc |
| `commands/agy.md`, `commands/codex.md` | Lệnh tắt: gọi lại `crew.md` với executor cố định |
| `commands/crew-status.md` · `bin/agy-status.sh` | Danh sách việc và trạng thái |
| `commands/crew-config.md` · `bin/agy-model.sh` | Cấu hình executor / model |
| `commands/crew-usage.md` · `bin/agy-usage.sh` | Thống kê token |
| `commands/crew-clean.md` · `bin/agy-clean.sh` | Dọn dẹp |
| `bin/run-task.sh` | Điều phối: preflight, chọn executor, resume đúng phiên, sang codex khi agy hết quota |
| `bin/run-agy.sh` · `bin/run-codex.sh` | Chạy một kho bằng agy / codex (model, quota, bài học) |
| `bin/preflight.sh` · `bin/verify.sh` | Kiểm tra đầu vào · kiểm tra kết quả |
| `templates/` | `proposal.md` (VI), `brief.md` (EN, kèm mẫu `AGY_REPORT.md`), `report.md` (VI) |
| `presets/` | Theo loại project (`common`, `flutter`, `dotnet`, `node`, `python`): lệnh agy được phép, lệnh test, luật `suspect` cho verify |

Tên thư mục dữ liệu (`.agy/`, `~/.claude/agy`), tên script (`agy-*.sh`) và `AGY_REPORT.md` giữ nguyên từ bản đầu để không làm hỏng project đang dùng.

## Mã thoát của script
| Mã | Ý nghĩa |
|---|---|
| 0 | Xong |
| 2 | Thiếu file / tham số |
| 3 | Chưa cài executor |
| 4 | Hết quota trên cả chuỗi model (và không có / đã hết dự phòng codex) |
| 5 | Preflight không đạt — sửa đầu vào rồi giao lại |

## Ghi chú kỹ thuật về agy
- Prompt phải gắn vào cờ: `--print="<prompt>"` (đặt cuối); `--print <prompt>` sẽ nuốt nhầm cờ phía sau.
- macOS không có `timeout`; dùng `--print-timeout 1800s` của agy (đổi bằng `AGY_TIMEOUT`).
- Kết quả `--output-format json`: `conversation_id`, `status`, `num_turns`, `usage`, `denied_actions`.
- **Một lệnh bị chặn làm agy kết thúc lượt ngay** (`status` vẫn là SUCCESS). Vì vậy brief liệt kê chính xác lệnh được phép (tiền tố, không `*`),
  bài học "không nối lệnh" được chèn sẵn, và `/crew` tự chạy tiếp đúng phiên một lần khi thấy `denied_actions` hoặc thiếu `AGY_REPORT.md`.
- Shell mặc định của macOS chạy script là bash 3.2 — script không dùng `mapfile` hay cú pháp bash 4+.
