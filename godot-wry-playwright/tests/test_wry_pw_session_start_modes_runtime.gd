extends SceneTree

const T := preload("res://tests/_test_util.gd")


func _init() -> void:
	await process_frame

	var pending: Dictionary = {}
	var session = T.create_session(self, pending, false)
	await process_frame

	var resize_before_start_id = session.resize(640, 360)
	var resize_before_start_resp = await T.wait_for_completed(self, pending, resize_before_start_id)
	if not T.require_error_response(self, resize_before_start_resp, "resize before start"):
		return

	var resize_error = String(resize_before_start_resp.get("error", ""))
	var allowed_error = (
		resize_error.contains("start_view_error")
		or resize_error.contains("missing parent_hwnd")
		or resize_error.contains("missing_parent_hwnd")
	)
	if not T.require_true(self, allowed_error, "resize error should be start_view related"):
		return

	var close_id = session.close()
	var close_resp = await T.wait_for_completed(self, pending, close_id)
	if not T.require_ok_response(self, close_resp, "close session"):
		return

	var base_url := String(OS.get_environment("GODOT_TEST_HTTP_BASE_URL"))
	if not T.require_true(self, base_url != "", "GODOT_TEST_HTTP_BASE_URL is required"):
		return

	var open_texture_id = session.open("%s/tests/fixtures/session_test_page.html" % base_url, {
		"timeout_ms": 10_000,
		"texture": {
			"width": 640,
			"height": 360,
			"fps": 2,
		},
	})
	var open_texture_resp = await T.wait_for_completed(self, pending, open_texture_id)
	if not T.require_ok_response(self, open_texture_resp, "open texture mode"):
		return

	var eval_texture_id = session.eval("() => document.title")
	var eval_texture_resp = await T.wait_for_completed(self, pending, eval_texture_id)
	if not T.require_ok_response(self, eval_texture_resp, "eval in texture mode"):
		return
	if not T.require_eq(self, T.parse_json_or_null(String(eval_texture_resp.result_json)), "GWry Session Fixture", "texture mode title mismatch"):
		return

	var resize_texture_id = session.resize(600, 300)
	var resize_texture_resp = await T.wait_for_completed(self, pending, resize_texture_id)
	if not T.require_error_response(self, resize_texture_resp, "resize in texture mode", "resize_requires_view_mode"):
		return

	var close_texture_id = session.close()
	var close_texture_resp = await T.wait_for_completed(self, pending, close_texture_id)
	if not T.require_ok_response(self, close_texture_resp, "close texture mode"):
		return

	T.pass_and_quit(self)
