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

	var test_url := "%s/tests/fixtures/session_test_page.html" % base_url
	var open_id = session.open(test_url, {"timeout_ms": 10_000})
	var open_resp = await T.wait_for_completed(self, pending, open_id)
	if not T.require_ok_response(self, open_resp, "session.open"):
		return

	var eval_id = session.eval("() => document.title")
	var eval_resp = await T.wait_for_completed(self, pending, eval_id)
	if not T.require_ok_response(self, eval_resp, "session.eval title"):
		return
	if not T.require_eq(self, T.parse_json_or_null(String(eval_resp.get("result_json", "null"))), "GWry Session Fixture", "headless title mismatch"):
		return

	var close_id = session.close()
	var close_resp = await T.wait_for_completed(self, pending, close_id)
	if not T.require_ok_response(self, close_resp, "session.close"):
		return

	T.pass_and_quit(self)

