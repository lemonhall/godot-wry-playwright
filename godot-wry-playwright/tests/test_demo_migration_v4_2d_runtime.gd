extends SceneTree

const T := preload("res://tests/_test_util.gd")


func _init() -> void:
	await process_frame

	var base_url := String(OS.get_environment("GODOT_TEST_HTTP_BASE_URL"))
	if not T.require_true(self, base_url != "", "GODOT_TEST_HTTP_BASE_URL is required"):
		return

	var pending: Dictionary = {}
	var session: WryPwSession = T.create_session(self, pending, false)
	await process_frame

	var open_options := {
		"timeout_ms": 10_000,
		"view_rect": {
			"x": 20,
			"y": 20,
			"width": 960,
			"height": 640,
		},
	}
	var test_url := "%s/tests/fixtures/session_test_page.html" % base_url
	var open_resp: Dictionary = await _open_with_retry(session, pending, test_url, open_options)
	var open_ok := bool(open_resp.get("ok", false))
	if open_ok:
		var resize_id = session.resize(820, 520)
		var resize_resp = await T.wait_for_completed(self, pending, resize_id)
		if not T.require_ok_response(self, resize_resp, "session.resize"):
			return
	else:
		var open_error := String(open_resp.get("error", ""))
		var expected_open_error := (
			open_error.contains("webview_not_started")
			or open_error.contains("missing parent_hwnd")
			or open_error.contains("missing_parent_hwnd")
			or open_error.contains("timeout_wait_completed")
		)
		if not T.require_true(self, expected_open_error, "view mode open error mismatch: %s" % open_error):
			return

		var fallback_open_resp: Dictionary = await _open_with_retry(session, pending, test_url, {"timeout_ms": 10_000})
		if not bool(fallback_open_resp.get("ok", false)):
			var fallback_error := String(fallback_open_resp.get("error", ""))
			var fallback_expected := (
				fallback_error.contains("webview_not_started")
				or fallback_error.contains("timeout_wait_completed")
			)
			if not T.require_true(self, fallback_expected, "fallback hidden open error mismatch: %s" % fallback_error):
				return
		else:
			open_ok = true

	if open_ok:
		var title_id = session.eval("() => document.title")
		var title_resp = await T.wait_for_completed(self, pending, title_id)
		if not T.require_ok_response(self, title_resp, "session.eval title"):
			return
		if not T.require_eq(self, T.parse_json_or_null(String(title_resp.get("result_json", "null"))), "GWry Session Fixture", "2d title mismatch"):
			return

	var close_id = session.close()
	var close_resp = await T.wait_for_completed(self, pending, close_id)
	if not T.require_ok_response(self, close_resp, "session.close"):
		return

	T.pass_and_quit(self)


func _open_with_retry(session: WryPwSession, pending: Dictionary, url: String, options: Dictionary) -> Dictionary:
	for _attempt in range(3):
		var open_id = session.open(url, options)
		var open_resp = await T.wait_for_completed(self, pending, open_id)
		if bool(open_resp.get("ok", false)):
			return open_resp

		var error_text := String(open_resp.get("error", ""))
		if not error_text.contains("webview_not_started"):
			return open_resp

		await process_frame

	var final_id = session.open(url, options)
	return await T.wait_for_completed(self, pending, final_id)
