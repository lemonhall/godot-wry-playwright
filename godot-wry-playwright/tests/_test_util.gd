extends RefCounted


const SESSION_SCRIPT := preload("res://addons/godot_wry_playwright/wry_pw_session.gd")


static func fail_and_quit(tree: SceneTree, message: String) -> void:
	push_error(message)
	print("TEST_FAIL: %s" % message)
	tree.quit(1)


static func pass_and_quit(tree: SceneTree) -> void:
	print("TEST_PASS")
	tree.quit(0)


static func require_true(tree: SceneTree, condition: bool, message: String) -> bool:
	if condition:
		return true

	fail_and_quit(tree, message)
	return false


static func require_eq(tree: SceneTree, actual: Variant, expected: Variant, message: String) -> bool:
	if actual == expected:
		return true

	var detail = "%s (actual=%s expected=%s)" % [message, str(actual), str(expected)]
	fail_and_quit(tree, detail)
	return false


static func parse_json_or_null(raw_json: String) -> Variant:
	var parser = JSON.new()
	if parser.parse(raw_json) != OK:
		return null
	return parser.data


static func create_session(tree: SceneTree, pending: Dictionary, auto_start: bool = false) -> Node:
	var session = SESSION_SCRIPT.new()
	session.auto_start = auto_start
	tree.get_root().add_child(session)
	session.completed.connect(func(request_id: int, ok: bool, result_json: String, error: String) -> void:
		pending[request_id] = {
			"ok": ok,
			"result_json": result_json,
			"error": error,
		}
	)
	return session


static func wait_for_completed(tree: SceneTree, pending: Dictionary, request_id: int, timeout_ms: int = 10_000) -> Dictionary:
	var deadline = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() <= deadline:
		if pending.has(request_id):
			var response: Dictionary = pending[request_id]
			pending.erase(request_id)
			return response
		await tree.process_frame

	return {
		"ok": false,
		"result_json": "null",
		"error": "timeout_wait_completed:%d" % request_id,
	}


static func require_ok_response(tree: SceneTree, response: Dictionary, label: String) -> bool:
	if bool(response.get("ok", false)):
		return true

	var error_text = String(response.get("error", "unknown_error"))
	fail_and_quit(tree, "%s failed: %s" % [label, error_text])
	return false


static func require_error_response(tree: SceneTree, response: Dictionary, label: String, contains: String = "") -> bool:
	if bool(response.get("ok", false)):
		fail_and_quit(tree, "%s expected error but got ok" % label)
		return false

	var error_text = String(response.get("error", ""))
	if contains != "" and not error_text.contains(contains):
		fail_and_quit(tree, "%s error mismatch: %s" % [label, error_text])
		return false

	return true


static func read_text_file(path: String) -> Dictionary:
	var normalized_path = path
	if path.begins_with("res://") or path.begins_with("user://"):
		normalized_path = ProjectSettings.globalize_path(path)

	if not FileAccess.file_exists(normalized_path):
		return {
			"ok": false,
			"error": "file_not_found:%s" % normalized_path,
		}

	var file = FileAccess.open(normalized_path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"error": "open_failed:%s" % normalized_path,
		}

	return {
		"ok": true,
		"path": normalized_path,
		"text": file.get_as_text(),
	}


