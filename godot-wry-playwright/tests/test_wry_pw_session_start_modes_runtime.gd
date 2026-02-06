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

	T.pass_and_quit(self)

