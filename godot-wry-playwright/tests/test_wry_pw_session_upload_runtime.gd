extends SceneTree

const T := preload("res://tests/_test_util.gd")


func _init() -> void:
	await process_frame

	var base_url = String(OS.get_environment("GODOT_TEST_HTTP_BASE_URL"))
	if not T.require_true(self, base_url != "", "GODOT_TEST_HTTP_BASE_URL is required"):
		return

	var pending: Dictionary = {}
	var session = T.create_session(self, pending, false)
	await process_frame

	var test_url = "%s/tests/fixtures/session_test_page.html" % base_url
	var open_id = session.open(test_url, {"timeout_ms": 10_000})
	var open_resp = await T.wait_for_completed(self, pending, open_id)
	if not T.require_ok_response(self, open_resp, "open fixture"):
		return

	if not await _run_upload_assertions(session, pending):
		return

	var close_id = session.close()
	var close_resp = await T.wait_for_completed(self, pending, close_id)
	if not T.require_ok_response(self, close_resp, "close"):
		return

	T.pass_and_quit(self)


func _run_upload_assertions(session: Node, pending: Dictionary) -> bool:
	var output_base = "user://test_outputs/runtime"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_base))

	var upload_file_1 = "%s/upload_one.txt" % output_base
	var upload_file_2 = "%s/upload_two.json" % output_base

	if not _write_text(upload_file_1, "first upload content"):
		return false
	if not _write_text(upload_file_2, "{\"kind\":\"second\"}"):
		return false

	var upload_missing_id = session.upload("user://test_outputs/runtime/missing.txt")
	var upload_missing_resp = await T.wait_for_completed(self, pending, upload_missing_id)
	if not T.require_error_response(self, upload_missing_resp, "upload missing file", "upload_file_not_found"):
		return false

	var upload_empty_id = session.upload("", -1, "#upload_input")
	var upload_empty_resp = await T.wait_for_completed(self, pending, upload_empty_id)
	if not T.require_error_response(self, upload_empty_resp, "upload empty", "upload_empty"):
		return false

	var upload_ok_id = session.upload([upload_file_1, upload_file_2], 10_000, "#upload_input")
	var upload_ok_resp = await T.wait_for_completed(self, pending, upload_ok_id)
	if not T.require_ok_response(self, upload_ok_resp, "upload success"):
		return false

	var upload_data: Variant = T.parse_json_or_null(String(upload_ok_resp.result_json))
	if not T.require_true(self, upload_data is Dictionary, "upload response should be dictionary"):
		return false
	if not T.require_eq(self, int((upload_data as Dictionary).get("count", 0)), 2, "upload count mismatch"):
		return false

	var upload_status_id = session.eval("() => document.querySelector('#upload_status').textContent")
	var upload_status_resp = await T.wait_for_completed(self, pending, upload_status_id)
	if not T.require_ok_response(self, upload_status_resp, "upload status text"):
		return false
	var upload_status_text = String(T.parse_json_or_null(String(upload_status_resp.result_json)))
	if not T.require_true(self, upload_status_text.contains("upload_one.txt"), "upload status should include first filename"):
		return false
	if not T.require_true(self, upload_status_text.contains("upload_two.json"), "upload status should include second filename"):
		return false

	var upload_bad_target_id = session.upload(upload_file_1, -1, "#status")
	var upload_bad_target_resp = await T.wait_for_completed(self, pending, upload_bad_target_id)
	if not T.require_error_response(self, upload_bad_target_resp, "upload bad target", "upload_target_not_file_input"):
		return false

	return true


func _write_text(path: String, content: String) -> bool:
	var full_path = ProjectSettings.globalize_path(path)
	var directory = full_path.get_base_dir()
	if directory != "":
		var mk_err = DirAccess.make_dir_recursive_absolute(directory)
		if mk_err != OK and mk_err != ERR_ALREADY_EXISTS:
			T.fail_and_quit(self, "failed to create upload directory: %s" % directory)
			return false

	var file = FileAccess.open(full_path, FileAccess.WRITE)
	if file == null:
		T.fail_and_quit(self, "failed to open upload file: %s" % full_path)
		return false

	file.store_string(content)
	return true


