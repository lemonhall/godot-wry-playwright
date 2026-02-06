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
	if not T.require_ok_response(self, open_resp, "open"):
		return

	if not await _run_core_assertions(session, pending, test_url):
		return

	var close_id = session.close()
	var close_resp = await T.wait_for_completed(self, pending, close_id)
	if not T.require_ok_response(self, close_resp, "close"):
		return

	T.pass_and_quit(self)


func _run_core_assertions(session: Node, pending: Dictionary, test_url: String) -> bool:
	var eval_title_id = session.eval("() => document.title")
	var eval_title_resp = await T.wait_for_completed(self, pending, eval_title_id)
	if not T.require_ok_response(self, eval_title_resp, "eval title"):
		return false
	if not T.require_eq(self, T.parse_json_or_null(String(eval_title_resp.result_json)), "GWry Session Fixture", "title mismatch"):
		return false

	var wait_ok_id = session.eval(
		"""
		() => new Promise((resolve) => {
		  const start = Date.now();
		  const check = () => {
		    if (document.querySelector('#late_node')) {
		      resolve(true);
		      return;
		    }
		    if (Date.now() - start > 4000) {
		      resolve(false);
		      return;
		    }
		    requestAnimationFrame(check);
		  };
		  check();
		})
		"""
	)
	var wait_ok_resp = await T.wait_for_completed(self, pending, wait_ok_id)
	if not T.require_ok_response(self, wait_ok_resp, "wait late node"):
		return false
	if not T.require_eq(self, T.parse_json_or_null(String(wait_ok_resp.result_json)), true, "late node should appear"):
		return false

	var type_id = session.type_text("hello")
	var type_resp = await T.wait_for_completed(self, pending, type_id)
	var type_without_focus_error := String(type_resp.get("error", ""))
	var type_without_focus_ok := (
		type_without_focus_error.contains("no_active_element")
		or type_without_focus_error.contains("active_element_not_editable")
	)
	if not T.require_true(self, type_without_focus_ok, "type without focus error mismatch: %s" % type_without_focus_error):
		return false

	var focus_id = session.eval("() => { const el = document.querySelector('#text_input'); el.focus(); return true; }")
	var focus_resp = await T.wait_for_completed(self, pending, focus_id)
	if not T.require_ok_response(self, focus_resp, "focus input"):
		return false

	var fill_id = session.fill("#text_input", "filled")
	var fill_resp = await T.wait_for_completed(self, pending, fill_id)
	if not T.require_ok_response(self, fill_resp, "fill"):
		return false

	var type_ok_id = session.type_text("-extra")
	var type_ok_resp = await T.wait_for_completed(self, pending, type_ok_id)
	if not T.require_ok_response(self, type_ok_resp, "type with focus"):
		return false

	var click_submit_id = session.click("#submit_btn")
	var click_submit_resp = await T.wait_for_completed(self, pending, click_submit_id)
	if not T.require_ok_response(self, click_submit_resp, "click submit"):
		return false

	var status_id = session.eval("() => document.querySelector('#status').textContent")
	var status_resp = await T.wait_for_completed(self, pending, status_id)
	if not T.require_ok_response(self, status_resp, "status text"):
		return false
	if not T.require_eq(self, T.parse_json_or_null(String(status_resp.result_json)), "submitted:filled-extra", "submit status mismatch"):
		return false

	var dbl_id = session.dblclick("#submit_btn")
	var dbl_resp = await T.wait_for_completed(self, pending, dbl_id)
	if not T.require_ok_response(self, dbl_resp, "dblclick"):
		return false

	var hover_id = session.hover("#hover_target")
	var hover_resp = await T.wait_for_completed(self, pending, hover_id)
	if not T.require_ok_response(self, hover_resp, "hover"):
		return false

	var select_id = session.select("#color_select", "blue")
	var select_resp = await T.wait_for_completed(self, pending, select_id)
	if not T.require_ok_response(self, select_resp, "select"):
		return false

	var select_text_id = session.eval("() => document.querySelector('#select_status').textContent")
	var select_text_resp = await T.wait_for_completed(self, pending, select_text_id)
	if not T.require_ok_response(self, select_text_resp, "select status"):
		return false
	if not T.require_eq(self, T.parse_json_or_null(String(select_text_resp.result_json)), "blue", "select status mismatch"):
		return false

	var check_id = session.check("#check_input")
	var check_resp = await T.wait_for_completed(self, pending, check_id)
	if not T.require_ok_response(self, check_resp, "check"):
		return false

	var check_text_id = session.eval("() => document.querySelector('#check_status').textContent")
	var check_text_resp = await T.wait_for_completed(self, pending, check_text_id)
	if not T.require_ok_response(self, check_text_resp, "check status"):
		return false
	if not T.require_eq(self, T.parse_json_or_null(String(check_text_resp.result_json)), "checked", "check status mismatch"):
		return false

	var uncheck_id = session.uncheck("#check_input")
	var uncheck_resp = await T.wait_for_completed(self, pending, uncheck_id)
	if not T.require_ok_response(self, uncheck_resp, "uncheck"):
		return false

	var uncheck_text_id = session.eval("() => document.querySelector('#check_status').textContent")
	var uncheck_text_resp = await T.wait_for_completed(self, pending, uncheck_text_id)
	if not T.require_ok_response(self, uncheck_text_resp, "uncheck status"):
		return false
	if not T.require_eq(self, T.parse_json_or_null(String(uncheck_text_resp.result_json)), "unchecked", "uncheck status mismatch"):
		return false

	var dialog_accept_id = session.dialog_accept("typed-from-dialog")
	var dialog_accept_resp = await T.wait_for_completed(self, pending, dialog_accept_id)
	if not T.require_ok_response(self, dialog_accept_resp, "dialog_accept"):
		return false

	var prompt_ok_id = session.eval("() => prompt('name', 'fallback')")
	var prompt_ok_resp = await T.wait_for_completed(self, pending, prompt_ok_id)
	if not T.require_ok_response(self, prompt_ok_resp, "prompt accept"):
		return false
	if not T.require_eq(self, T.parse_json_or_null(String(prompt_ok_resp.result_json)), "typed-from-dialog", "prompt accept result mismatch"):
		return false

	var dialog_dismiss_id = session.dialog_dismiss()
	var dialog_dismiss_resp = await T.wait_for_completed(self, pending, dialog_dismiss_id)
	if not T.require_ok_response(self, dialog_dismiss_resp, "dialog_dismiss"):
		return false

	var prompt_dismiss_id = session.eval("() => prompt('name', 'fallback')")
	var prompt_dismiss_resp = await T.wait_for_completed(self, pending, prompt_dismiss_id)
	if not T.require_ok_response(self, prompt_dismiss_resp, "prompt dismiss"):
		return false
	if not T.require_eq(self, T.parse_json_or_null(String(prompt_dismiss_resp.result_json)), null, "prompt dismiss should return null"):
		return false

	var focus_again_id = session.eval("() => { const el = document.querySelector('#text_input'); el.focus(); return true; }")
	var focus_again_resp = await T.wait_for_completed(self, pending, focus_again_id)
	if not T.require_ok_response(self, focus_again_resp, "focus again"):
		return false

	var keydown_id = session.keydown("K")
	var keydown_resp = await T.wait_for_completed(self, pending, keydown_id)
	if not T.require_ok_response(self, keydown_resp, "keydown"):
		return false

	var keyup_id = session.keyup("K")
	var keyup_resp = await T.wait_for_completed(self, pending, keyup_id)
	if not T.require_ok_response(self, keyup_resp, "keyup"):
		return false

	var press_id = session.press("Z")
	var press_resp = await T.wait_for_completed(self, pending, press_id)
	if not T.require_ok_response(self, press_resp, "press"):
		return false

	var mouse_move_id = session.mouse_move(20.0, 20.0)
	var mouse_move_resp = await T.wait_for_completed(self, pending, mouse_move_id)
	if not T.require_ok_response(self, mouse_move_resp, "mouse_move"):
		return false

	var mouse_down_id = session.mouse_down("left")
	var mouse_down_resp = await T.wait_for_completed(self, pending, mouse_down_id)
	if not T.require_ok_response(self, mouse_down_resp, "mouse_down"):
		return false

	var mouse_up_id = session.mouse_up("left")
	var mouse_up_resp = await T.wait_for_completed(self, pending, mouse_up_id)
	if not T.require_ok_response(self, mouse_up_resp, "mouse_up"):
		return false

	var mouse_wheel_id = session.mouse_wheel(0.0, 1.0)
	var mouse_wheel_resp = await T.wait_for_completed(self, pending, mouse_wheel_id)
	if not T.require_ok_response(self, mouse_wheel_resp, "mouse_wheel"):
		return false

	var drag_id = session.drag("#hover_target", "#mouse_area")
	var drag_resp = await T.wait_for_completed(self, pending, drag_id)
	if not T.require_ok_response(self, drag_resp, "drag"):
		return false

	var last_key_id = session.eval("() => window.__fixture.last_key")
	var last_key_resp = await T.wait_for_completed(self, pending, last_key_id)
	if not T.require_ok_response(self, last_key_resp, "last key"):
		return false
	if not T.require_eq(self, T.parse_json_or_null(String(last_key_resp.result_json)), "Z", "last key mismatch"):
		return false

	var event_count_id = session.eval(
		"""
		() => (
		  window.__fixture.keydown_count +
		  window.__fixture.keyup_count +
		  window.__fixture.keypress_count +
		  window.__fixture.mousemove_count +
		  window.__fixture.mousedown_count +
		  window.__fixture.mouseup_count +
		  window.__fixture.wheel_count
		)
		"""
	)
	var event_count_resp = await T.wait_for_completed(self, pending, event_count_id)
	if not T.require_ok_response(self, event_count_resp, "event count"):
		return false
	var event_count = int(T.parse_json_or_null(String(event_count_resp.result_json)))
	if not T.require_true(self, event_count >= 4, "input events should be recorded"):
		return false

	var open_js_id = session.eval("() => window.location.href")
	var open_js_resp = await T.wait_for_completed(self, pending, open_js_id)
	if not T.require_ok_response(self, open_js_resp, "location before nav"):
		return false

	var go_back_id = session.go_back()
	var go_back_resp = await T.wait_for_completed(self, pending, go_back_id)
	if not T.require_ok_response(self, go_back_resp, "go_back"):
		return false

	var go_forward_id = session.go_forward()
	var go_forward_resp = await T.wait_for_completed(self, pending, go_forward_id)
	if not T.require_ok_response(self, go_forward_resp, "go_forward"):
		return false

	var reload_id = session.reload()
	var reload_resp = await T.wait_for_completed(self, pending, reload_id)
	if not T.require_ok_response(self, reload_resp, "reload"):
		return false

	var open_same_id = session.open(test_url, {"timeout_ms": 10_000})
	var open_same_resp = await T.wait_for_completed(self, pending, open_same_id)
	if not T.require_ok_response(self, open_same_resp, "open same url"):
		return false

	var resize_before_close_id = session.resize(640, 360)
	var resize_before_close_resp = await T.wait_for_completed(self, pending, resize_before_close_id)
	if not T.require_error_response(self, resize_before_close_resp, "resize without view", "resize_requires_view_mode"):
		return false

	return true


