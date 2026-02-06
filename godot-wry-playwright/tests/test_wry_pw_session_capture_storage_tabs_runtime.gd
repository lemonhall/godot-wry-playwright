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

	var run_id = await _run_capture_storage_tabs_assertions(session, pending, test_url)
	if run_id == -1:
		return

	var close_id = session.close()
	var close_resp = await T.wait_for_completed(self, pending, close_id)
	if not T.require_ok_response(self, close_resp, "close"):
		return

	T.pass_and_quit(self)


func _run_capture_storage_tabs_assertions(session: Node, pending: Dictionary, test_url: String) -> int:
	var output_base = "user://test_outputs/runtime"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_base))

	var screenshot_path = "%s/snapshot.json" % output_base
	var screenshot_id = session.screenshot("", screenshot_path)
	var screenshot_resp = await T.wait_for_completed(self, pending, screenshot_id)
	if not T.require_ok_response(self, screenshot_resp, "screenshot"):
		return -1
	var screenshot_file = T.read_text_file(screenshot_path)
	if not T.require_true(self, bool(screenshot_file.ok), "screenshot file missing"):
		return -1
	var screenshot_json: Variant = T.parse_json_or_null(String(screenshot_file.text))
	if not T.require_true(self, screenshot_json is Dictionary, "screenshot should be dictionary"):
		return -1
	if not T.require_eq(self, String((screenshot_json as Dictionary).get("format", "")), "svg_data_url", "screenshot format mismatch"):
		return -1
	if not T.require_true(self, String((screenshot_json as Dictionary).get("data_url", "")).begins_with("data:image/svg+xml;base64,"), "screenshot data_url missing"):
		return -1

	var snapshot_path = "%s/snapshot_alias.json" % output_base
	var snapshot_id = session.snapshot(snapshot_path)
	var snapshot_resp = await T.wait_for_completed(self, pending, snapshot_id)
	if not T.require_ok_response(self, snapshot_resp, "snapshot alias"):
		return -1
	var snapshot_file = T.read_text_file(snapshot_path)
	if not T.require_true(self, bool(snapshot_file.ok), "snapshot alias file missing"):
		return -1

	var pdf_path = "%s/page_dump.json" % output_base
	var pdf_id = session.pdf(pdf_path)
	var pdf_resp = await T.wait_for_completed(self, pending, pdf_id)
	if not T.require_ok_response(self, pdf_resp, "pdf"):
		return -1
	var pdf_file = T.read_text_file(pdf_path)
	if not T.require_true(self, bool(pdf_file.ok), "pdf output file missing"):
		return -1
	var pdf_json: Variant = T.parse_json_or_null(String(pdf_file.text))
	if not T.require_true(self, pdf_json is Dictionary, "pdf output should be dictionary"):
		return -1
	if not T.require_eq(self, String((pdf_json as Dictionary).get("format", "")), "html_json", "pdf format marker mismatch"):
		return -1

	var set_cookie_id = session.cookie_set("session_cookie", "cookie_value")
	var set_cookie_resp = await T.wait_for_completed(self, pending, set_cookie_id)
	if not T.require_ok_response(self, set_cookie_resp, "cookie_set"):
		return -1

	var get_cookie_id = session.cookie_get("session_cookie")
	var get_cookie_resp = await T.wait_for_completed(self, pending, get_cookie_id)
	if not T.require_ok_response(self, get_cookie_resp, "cookie_get"):
		return -1
	var get_cookie_value: Variant = T.parse_json_or_null(String(get_cookie_resp.result_json))
	if not T.require_true(self, get_cookie_value is Dictionary, "cookie_get should return dictionary"):
		return -1
	if not T.require_eq(self, String((get_cookie_value as Dictionary).get("value", "")), "cookie_value", "cookie value mismatch"):
		return -1

	var list_cookie_id = session.cookie_list("127.0.0.1")
	var list_cookie_resp = await T.wait_for_completed(self, pending, list_cookie_id)
	if not T.require_ok_response(self, list_cookie_resp, "cookie_list"):
		return -1
	var cookie_list_value: Variant = T.parse_json_or_null(String(list_cookie_resp.result_json))
	if not T.require_true(self, cookie_list_value is Array, "cookie_list should return array"):
		return -1
	if not T.require_true(self, (cookie_list_value as Array).size() >= 1, "cookie_list should contain at least one cookie"):
		return -1

	var delete_cookie_id = session.cookie_delete("session_cookie")
	var delete_cookie_resp = await T.wait_for_completed(self, pending, delete_cookie_id)
	if not T.require_ok_response(self, delete_cookie_resp, "cookie_delete"):
		return -1

	var clear_cookie_id = session.cookie_clear()
	var clear_cookie_resp = await T.wait_for_completed(self, pending, clear_cookie_id)
	if not T.require_ok_response(self, clear_cookie_resp, "cookie_clear"):
		return -1

	var ls_set_id = session.localstorage_set("ls_key", "ls_value")
	var ls_set_resp = await T.wait_for_completed(self, pending, ls_set_id)
	if not T.require_ok_response(self, ls_set_resp, "localstorage_set"):
		return -1

	var ls_get_id = session.localstorage_get("ls_key")
	var ls_get_resp = await T.wait_for_completed(self, pending, ls_get_id)
	if not T.require_ok_response(self, ls_get_resp, "localstorage_get"):
		return -1
	var ls_get_value: Variant = T.parse_json_or_null(String(ls_get_resp.result_json))
	if not T.require_true(self, ls_get_value is Dictionary, "localstorage_get should return dictionary"):
		return -1
	if not T.require_eq(self, String((ls_get_value as Dictionary).get("value", "")), "ls_value", "localstorage value mismatch"):
		return -1

	var ls_list_id = session.localstorage_list()
	var ls_list_resp = await T.wait_for_completed(self, pending, ls_list_id)
	if not T.require_ok_response(self, ls_list_resp, "localstorage_list"):
		return -1
	var ls_list_value: Variant = T.parse_json_or_null(String(ls_list_resp.result_json))
	if not T.require_true(self, ls_list_value is Array, "localstorage_list should return array"):
		return -1

	var ls_delete_id = session.localstorage_delete("ls_key")
	var ls_delete_resp = await T.wait_for_completed(self, pending, ls_delete_id)
	if not T.require_ok_response(self, ls_delete_resp, "localstorage_delete"):
		return -1

	var ls_clear_id = session.localstorage_clear()
	var ls_clear_resp = await T.wait_for_completed(self, pending, ls_clear_id)
	if not T.require_ok_response(self, ls_clear_resp, "localstorage_clear"):
		return -1

	var ss_set_id = session.sessionstorage_set("ss_key", "ss_value")
	var ss_set_resp = await T.wait_for_completed(self, pending, ss_set_id)
	if not T.require_ok_response(self, ss_set_resp, "sessionstorage_set"):
		return -1

	var ss_get_id = session.sessionstorage_get("ss_key")
	var ss_get_resp = await T.wait_for_completed(self, pending, ss_get_id)
	if not T.require_ok_response(self, ss_get_resp, "sessionstorage_get"):
		return -1
	var ss_get_value: Variant = T.parse_json_or_null(String(ss_get_resp.result_json))
	if not T.require_true(self, ss_get_value is Dictionary, "sessionstorage_get should return dictionary"):
		return -1
	if not T.require_eq(self, String((ss_get_value as Dictionary).get("value", "")), "ss_value", "sessionstorage value mismatch"):
		return -1

	var ss_list_id = session.sessionstorage_list()
	var ss_list_resp = await T.wait_for_completed(self, pending, ss_list_id)
	if not T.require_ok_response(self, ss_list_resp, "sessionstorage_list"):
		return -1
	var ss_list_value: Variant = T.parse_json_or_null(String(ss_list_resp.result_json))
	if not T.require_true(self, ss_list_value is Array, "sessionstorage_list should return array"):
		return -1

	var ss_delete_id = session.sessionstorage_delete("ss_key")
	var ss_delete_resp = await T.wait_for_completed(self, pending, ss_delete_id)
	if not T.require_ok_response(self, ss_delete_resp, "sessionstorage_delete"):
		return -1

	var ss_clear_id = session.sessionstorage_clear()
	var ss_clear_resp = await T.wait_for_completed(self, pending, ss_clear_id)
	if not T.require_ok_response(self, ss_clear_resp, "sessionstorage_clear"):
		return -1

	var state_path = "%s/state.json" % output_base
	var state_save_id = session.state_save(state_path)
	var state_save_resp = await T.wait_for_completed(self, pending, state_save_id)
	if not T.require_ok_response(self, state_save_resp, "state_save"):
		return -1
	var state_file = T.read_text_file(state_path)
	if not T.require_true(self, bool(state_file.ok), "state_save output missing"):
		return -1
	var state_value: Variant = T.parse_json_or_null(String(state_file.text))
	if not T.require_true(self, state_value is Dictionary, "state_save payload should be dictionary"):
		return -1
	if not T.require_eq(self, String((state_value as Dictionary).get("schema", "")), "gwry-session-state-v1", "state schema mismatch"):
		return -1

	var clear_ls_for_restore_id = session.localstorage_clear()
	var clear_ls_for_restore_resp = await T.wait_for_completed(self, pending, clear_ls_for_restore_id)
	if not T.require_ok_response(self, clear_ls_for_restore_resp, "localstorage_clear before restore"):
		return -1

	var state_load_id = session.state_load(state_path)
	var state_load_resp = await T.wait_for_completed(self, pending, state_load_id)
	if not T.require_ok_response(self, state_load_resp, "state_load"):
		return -1

	var restored_ls_id = session.localstorage_get("ls_key")
	var restored_ls_resp = await T.wait_for_completed(self, pending, restored_ls_id)
	if not T.require_ok_response(self, restored_ls_resp, "localstorage_get after state_load"):
		return -1
	var restored_ls_value: Variant = T.parse_json_or_null(String(restored_ls_resp.result_json))
	if not T.require_true(self, restored_ls_value is Dictionary, "restored localstorage should return dictionary"):
		return -1
	if not T.require_eq(self, String((restored_ls_value as Dictionary).get("value", "")), "ls_value", "restored localstorage mismatch"):
		return -1

	var tab_list_initial_id = session.tab_list()
	var tab_list_initial_resp = await T.wait_for_completed(self, pending, tab_list_initial_id)
	if not T.require_ok_response(self, tab_list_initial_resp, "tab_list initial"):
		return -1
	var tab_list_initial_value: Variant = T.parse_json_or_null(String(tab_list_initial_resp.result_json))
	if not T.require_true(self, tab_list_initial_value is Dictionary, "tab_list should return dictionary"):
		return -1
	if not T.require_true(self, int((tab_list_initial_value as Dictionary).get("tab_count", 0)) >= 1, "initial tab count should be >=1"):
		return -1

	var tab_new_id = session.tab_new(test_url)
	var tab_new_resp = await T.wait_for_completed(self, pending, tab_new_id)
	if not T.require_ok_response(self, tab_new_resp, "tab_new"):
		return -1

	var tab_list_after_new_id = session.tab_list()
	var tab_list_after_new_resp = await T.wait_for_completed(self, pending, tab_list_after_new_id)
	if not T.require_ok_response(self, tab_list_after_new_resp, "tab_list after new"):
		return -1
	var tab_after_new_value: Variant = T.parse_json_or_null(String(tab_list_after_new_resp.result_json))
	if not T.require_true(self, tab_after_new_value is Dictionary, "tab_list after new should return dictionary"):
		return -1
	if not T.require_true(self, int((tab_after_new_value as Dictionary).get("tab_count", 0)) >= 2, "tab count should grow after tab_new"):
		return -1

	var tab_select_first_id = session.tab_select(0)
	var tab_select_first_resp = await T.wait_for_completed(self, pending, tab_select_first_id)
	if not T.require_ok_response(self, tab_select_first_resp, "tab_select"):
		return -1

	var tab_close_id = session.tab_close(-1)
	var tab_close_resp = await T.wait_for_completed(self, pending, tab_close_id)
	if not T.require_ok_response(self, tab_close_resp, "tab_close"):
		return -1

	var tab_list_final_id = session.tab_list()
	var tab_list_final_resp = await T.wait_for_completed(self, pending, tab_list_final_id)
	if not T.require_ok_response(self, tab_list_final_resp, "tab_list final"):
		return -1
	var tab_final_value: Variant = T.parse_json_or_null(String(tab_list_final_resp.result_json))
	if not T.require_true(self, tab_final_value is Dictionary, "tab_list final should return dictionary"):
		return -1
	if not T.require_true(self, int((tab_final_value as Dictionary).get("tab_count", 0)) >= 1, "final tab count should stay >=1"):
		return -1

	var state_save_empty_id = session.state_save("")
	var state_save_empty_resp = await T.wait_for_completed(self, pending, state_save_empty_id)
	if not T.require_error_response(self, state_save_empty_resp, "state_save empty", "state_save_filename_empty"):
		return -1

	var state_load_missing_id = session.state_load("user://test_outputs/runtime/not_exists.json")
	var state_load_missing_resp = await T.wait_for_completed(self, pending, state_load_missing_id)
	if not T.require_error_response(self, state_load_missing_resp, "state_load missing", "state_load_file_not_found"):
		return -1

	return 0


