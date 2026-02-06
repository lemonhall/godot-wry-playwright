# v3 Plan: CLI Command Catalog (Playwright -> Addon)

## Goal

建立 `playwright-cli.md` 的完整命令目录，并为每条命令定义唯一 addon API 映射。

## PRD Trace

- REQ-101
- REQ-102
- REQ-103
- REQ-104
- REQ-106
- REQ-110

## Scope

- 覆盖 `playwright-cli.md` 中全部独立命令。
- 每行包含：命令域、addon API、signature 草案、目标阶段、当前缺口。

## Acceptance

- A1: 覆盖校验脚本通过（无 missing、无 extra、无 empty API）。
- A2: 每条命令对应一个 addon API（不得留空）。
- A3: 目录变更后文档门禁仍通过。

## Files

- Modify: `docs/plan/v3-cli-command-catalog.md`
- Verify: `scripts/check_playwright_cli_command_map.py`

## Steps

1) Red: 运行覆盖脚本，确认 catalog 缺失时失败。
2) Green: 写全命令目录与映射。
3) Green verify: 覆盖脚本 PASS。
4) Refactor: 统一命名规则与阶段标识，减少歧义。

## Risks

- `playwright-cli.md` 若更新而目录未同步，会立即出现覆盖缺口。
- 某些命令在 WebView2 上能力有限，需要在后续计划中标注降级语义。

## Naming Rule

- CLI `kebab-case` 命令映射为 addon `snake_case` 方法名。
- 保留语义冲突处理：`type` 使用 `type_text`。
- Session 范围命令挂在 `session.*`；运行时命令挂在 `runtime.*`。

## Command Table

| CLI Command | Domain | Addon API | Signature Draft | Target Phase | Current Gap |
|---|---|---|---|---|---|

| `open` | `core` | `session.open` | `open(url: String, options := {}) -> int` | `M3.1` | `implemented_gdscript` |
| `close` | `core` | `session.close` | `close() -> int` | `M3.1` | `implemented_gdscript` |
| `type` | `core` | `session.type_text` | `type_text(text: String) -> int` | `M3.1` | `implemented_gdscript` |
| `click` | `core` | `session.click` | `click(ref: String, button := "left") -> int` | `M3.1` | `implemented_gdscript` |
| `dblclick` | `core` | `session.dblclick` | `dblclick(ref: String, button := "left") -> int` | `M3.1` | `implemented_gdscript` |
| `fill` | `core` | `session.fill` | `fill(ref: String, text: String) -> int` | `M3.1` | `implemented_gdscript` |
| `drag` | `core` | `session.drag` | `drag(start_ref: String, end_ref: String) -> int` | `M3.1` | `implemented_gdscript` |
| `hover` | `core` | `session.hover` | `hover(ref: String) -> int` | `M3.1` | `implemented_gdscript` |
| `select` | `core` | `session.select` | `select(ref: String, value: String) -> int` | `M3.1` | `implemented_gdscript` |
| `upload` | `core` | `session.upload` | `upload(files: PackedStringArray) -> int` | `M3.1` | `implemented_gdscript_best_effort` |
| `check` | `core` | `session.check` | `check(ref: String) -> int` | `M3.1` | `implemented_gdscript` |
| `uncheck` | `core` | `session.uncheck` | `uncheck(ref: String) -> int` | `M3.1` | `implemented_gdscript` |
| `snapshot` | `core` | `session.snapshot` | `snapshot(filename := "") -> int` | `M3.1` | `implemented_gdscript` |
| `eval` | `core` | `session.eval` | `eval(func_or_expr: String, ref := "") -> int` | `M3.1` | `implemented_gdscript` |
| `dialog-accept` | `core` | `session.dialog_accept` | `dialog_accept(prompt_text := "") -> int` | `M3.1` | `implemented_gdscript` |
| `dialog-dismiss` | `core` | `session.dialog_dismiss` | `dialog_dismiss() -> int` | `M3.1` | `implemented_gdscript` |
| `resize` | `core` | `session.resize` | `resize(width: int, height: int) -> int` | `M3.1` | `implemented_gdscript` |
| `go-back` | `navigation` | `session.go_back` | `go_back() -> int` | `M3.1` | `implemented_gdscript` |
| `go-forward` | `navigation` | `session.go_forward` | `go_forward() -> int` | `M3.1` | `implemented_gdscript` |
| `reload` | `navigation` | `session.reload` | `reload() -> int` | `M3.1` | `implemented_gdscript` |
| `press` | `keyboard` | `session.press` | `press(key: String) -> int` | `M3.1` | `implemented_gdscript` |
| `keydown` | `keyboard` | `session.keydown` | `keydown(key: String) -> int` | `M3.1` | `implemented_gdscript` |
| `keyup` | `keyboard` | `session.keyup` | `keyup(key: String) -> int` | `M3.1` | `implemented_gdscript` |
| `mousemove` | `mouse` | `session.mouse_move` | `mouse_move(x: float, y: float) -> int` | `M3.1` | `implemented_gdscript` |
| `mousedown` | `mouse` | `session.mouse_down` | `mouse_down(button := "left") -> int` | `M3.1` | `implemented_gdscript` |
| `mouseup` | `mouse` | `session.mouse_up` | `mouse_up(button := "left") -> int` | `M3.1` | `implemented_gdscript` |
| `mousewheel` | `mouse` | `session.mouse_wheel` | `mouse_wheel(dx: float, dy: float) -> int` | `M3.1` | `implemented_gdscript` |
| `screenshot` | `capture` | `session.screenshot` | `screenshot(ref := "", filename := "") -> int` | `M3.2` | `implemented_gdscript_best_effort` |
| `pdf` | `capture` | `session.pdf` | `pdf(filename := "page.pdf") -> int` | `M3.2` | `implemented_gdscript_best_effort` |
| `tab-list` | `tabs` | `session.tab_list` | `tab_list() -> int` | `M3.2` | `implemented_gdscript_best_effort` |
| `tab-new` | `tabs` | `session.tab_new` | `tab_new(url := "") -> int` | `M3.2` | `implemented_gdscript_best_effort` |
| `tab-close` | `tabs` | `session.tab_close` | `tab_close(index := -1) -> int` | `M3.2` | `implemented_gdscript_best_effort` |
| `tab-select` | `tabs` | `session.tab_select` | `tab_select(index: int) -> int` | `M3.2` | `implemented_gdscript_best_effort` |
| `state-save` | `storage` | `session.state_save` | `state_save(filename := "state.json") -> int` | `M3.2` | `implemented_gdscript_best_effort` |
| `state-load` | `storage` | `session.state_load` | `state_load(filename: String) -> int` | `M3.2` | `implemented_gdscript_best_effort` |
| `cookie-list` | `storage` | `session.cookie_list` | `cookie_list(domain := "") -> int` | `M3.2` | `implemented_gdscript_best_effort` |
| `cookie-get` | `storage` | `session.cookie_get` | `cookie_get(name: String) -> int` | `M3.2` | `implemented_gdscript_best_effort` |
| `cookie-set` | `storage` | `session.cookie_set` | `cookie_set(name: String, value: String) -> int` | `M3.2` | `implemented_gdscript_best_effort` |
| `cookie-delete` | `storage` | `session.cookie_delete` | `cookie_delete(name: String) -> int` | `M3.2` | `implemented_gdscript_best_effort` |
| `cookie-clear` | `storage` | `session.cookie_clear` | `cookie_clear() -> int` | `M3.2` | `implemented_gdscript_best_effort` |
| `localstorage-list` | `storage` | `session.localstorage_list` | `localstorage_list() -> int` | `M3.2` | `implemented_gdscript_best_effort` |
| `localstorage-get` | `storage` | `session.localstorage_get` | `localstorage_get(key: String) -> int` | `M3.2` | `implemented_gdscript_best_effort` |
| `localstorage-set` | `storage` | `session.localstorage_set` | `localstorage_set(key: String, value: String) -> int` | `M3.2` | `implemented_gdscript_best_effort` |
| `localstorage-delete` | `storage` | `session.localstorage_delete` | `localstorage_delete(key: String) -> int` | `M3.2` | `implemented_gdscript_best_effort` |
| `localstorage-clear` | `storage` | `session.localstorage_clear` | `localstorage_clear() -> int` | `M3.2` | `implemented_gdscript_best_effort` |
| `sessionstorage-list` | `storage` | `session.sessionstorage_list` | `sessionstorage_list() -> int` | `M3.2` | `implemented_gdscript_best_effort` |
| `sessionstorage-get` | `storage` | `session.sessionstorage_get` | `sessionstorage_get(key: String) -> int` | `M3.2` | `implemented_gdscript_best_effort` |
| `sessionstorage-set` | `storage` | `session.sessionstorage_set` | `sessionstorage_set(key: String, value: String) -> int` | `M3.2` | `implemented_gdscript_best_effort` |
| `sessionstorage-delete` | `storage` | `session.sessionstorage_delete` | `sessionstorage_delete(key: String) -> int` | `M3.2` | `implemented_gdscript_best_effort` |
| `sessionstorage-clear` | `storage` | `session.sessionstorage_clear` | `sessionstorage_clear() -> int` | `M3.2` | `implemented_gdscript_best_effort` |
| `route` | `network` | `session.route` | `route(pattern: String, options := {}) -> int` | `M3.3` | `missing` |
| `route-list` | `network` | `session.route_list` | `route_list() -> int` | `M3.3` | `missing` |
| `unroute` | `network` | `session.unroute` | `unroute(pattern := "") -> int` | `M3.3` | `missing` |
| `console` | `devtools` | `session.console` | `console(min_level := "info") -> int` | `M3.3` | `missing` |
| `network` | `devtools` | `session.network` | `network() -> int` | `M3.3` | `missing` |
| `run-code` | `devtools` | `session.run_code` | `run_code(code: String) -> int` | `M3.3` | `missing` |
| `tracing-start` | `devtools` | `session.tracing_start` | `tracing_start(options := {}) -> int` | `M3.3` | `missing` |
| `tracing-stop` | `devtools` | `session.tracing_stop` | `tracing_stop() -> int` | `M3.3` | `missing` |
| `video-start` | `devtools` | `session.video_start` | `video_start(options := {}) -> int` | `M3.3` | `missing` |
| `video-stop` | `devtools` | `session.video_stop` | `video_stop(filename := "") -> int` | `M3.3` | `missing` |
| `install` | `runtime` | `runtime.install_skills` | `install_skills() -> int` | `M3.3` | `missing` |
| `install-browser` | `runtime` | `runtime.install_browser` | `install_browser() -> int` | `M3.3` | `missing` |
| `config` | `runtime` | `runtime.config` | `config(options := {}) -> int` | `M3.3` | `missing` |
| `delete-data` | `runtime` | `runtime.delete_data` | `delete_data(session_name := "default") -> int` | `M3.3` | `missing` |
| `-s=name <cmd>` | `runtime` | `runtime.session_run` | `session_run(name: String, command: String, args := {}) -> int` | `M3.3` | `missing` |
| `-s=name close` | `runtime` | `runtime.session_close` | `session_close(name: String) -> int` | `M3.3` | `missing` |
| `-s=name delete-data` | `runtime` | `runtime.session_delete_data` | `session_delete_data(name: String) -> int` | `M3.3` | `missing` |
| `list` | `runtime` | `runtime.list_sessions` | `list_sessions() -> int` | `M3.3` | `missing` |
| `close-all` | `runtime` | `runtime.close_all` | `close_all() -> int` | `M3.3` | `missing` |
| `kill-all` | `runtime` | `runtime.kill_all` | `kill_all() -> int` | `M3.3` | `missing` |
