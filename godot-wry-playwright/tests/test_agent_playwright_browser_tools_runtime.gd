extends SceneTree

const T := preload("res://tests/_test_util.gd")


func _init() -> void:
	await process_frame

	var base_url := String(OS.get_environment("GODOT_TEST_HTTP_BASE_URL"))
	if not T.require_true(self, base_url != "", "GODOT_TEST_HTTP_BASE_URL is required"):
		return

	var packed := load("res://demo/agent_playwright.tscn")
	if not T.require_true(self, packed is PackedScene, "agent_playwright.tscn should load"):
		return

	var scene := (packed as PackedScene).instantiate()
	scene.set("agent_enabled", false)
	scene.set("auto_navigate_on_ready", false)
	scene.set("tool_driver_mode", "session")
	get_root().add_child(scene)
	await process_frame

	var test_url := "%s/tests/fixtures/session_test_page.html" % base_url

	var open_result: Variant = await scene.call("_tool_browser_open", {"url": test_url, "timeout_ms": 10_000}, {})
	if not _require_tool_ok(open_result, "browser.open"):
		return

	var title_result: Variant = await scene.call("_tool_browser_title", {"timeout_ms": 8_000}, {})
	if not _require_tool_ok(title_result, "browser.title"):
		return
	if not T.require_eq(self, String((title_result as Dictionary).get("title", "")), "GWry Session Fixture", "browser.title mismatch"):
		return

	var fill_result: Variant = await scene.call("_tool_browser_fill", {"selector": "#text_input", "text": "agent-runtime", "timeout_ms": 8_000}, {})
	if not _require_tool_ok(fill_result, "browser.fill"):
		return

	var click_result: Variant = await scene.call("_tool_browser_click", {"selector": "#submit_btn", "timeout_ms": 8_000}, {})
	if not _require_tool_ok(click_result, "browser.click"):
		return

	var status_result: Variant = await scene.call("_tool_browser_eval", {
		"script": "() => document.querySelector('#status').textContent",
		"timeout_ms": 8_000,
	}, {})
	if not _require_tool_ok(status_result, "browser.eval status"):
		return
	if not T.require_eq(self, String((status_result as Dictionary).get("value", "")), "submitted:agent-runtime", "fixture status mismatch"):
		return

	var missing_click_result: Variant = await scene.call("_tool_browser_click", {"selector": "#not_exists", "timeout_ms": 3_000}, {})
	if not _require_tool_error_contains(missing_click_result, "browser.click missing", "selector_not_found"):
		return

	get_root().remove_child(scene)
	scene.free()
	await process_frame

	T.pass_and_quit(self)


func _require_tool_ok(result: Variant, label: String) -> bool:
	if typeof(result) != TYPE_DICTIONARY:
		T.fail_and_quit(self, "%s result should be Dictionary" % label)
		return false

	var payload: Dictionary = result
	if bool(payload.get("ok", false)):
		return true

	T.fail_and_quit(self, "%s failed: %s" % [label, String(payload.get("error", "unknown_error"))])
	return false


func _require_tool_error_contains(result: Variant, label: String, expect_fragment: String) -> bool:
	if typeof(result) != TYPE_DICTIONARY:
		T.fail_and_quit(self, "%s result should be Dictionary" % label)
		return false

	var payload: Dictionary = result
	if bool(payload.get("ok", true)):
		T.fail_and_quit(self, "%s expected error but got ok" % label)
		return false

	var err := String(payload.get("error", ""))
	if expect_fragment != "" and not err.contains(expect_fragment):
		T.fail_and_quit(self, "%s error mismatch: %s" % [label, err])
		return false

	return true
