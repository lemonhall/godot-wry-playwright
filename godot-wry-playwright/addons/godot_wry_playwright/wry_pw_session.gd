extends Node
class_name WryPwSession

signal completed(request_id: int, ok: bool, result_json: String, error: String)

@export var auto_start: bool = true
@export var default_timeout_ms: int = 5_000
const _M31_LEGACY_ERROR_MARKERS := ["snapshot_filename_empty"]

var _browser: WryBrowser
var _started: bool = false
var _view_mode: bool = false
var _view_x: int = 0
var _view_y: int = 0
var _view_w: int = 1280
var _view_h: int = 720
var _snapshot_save_map: Dictionary = {}
var _tab_urls: Array[String] = [""]
var _active_tab_index: int = 0
var _pending_tab_nav: Dictionary = {}
var _next_local_request_id: int = -1


func _ready() -> void:
	_browser = WryBrowser.new()
	add_child(_browser)
	_browser.completed.connect(_on_browser_completed)

	if auto_start:
		_ensure_started()


func _on_browser_completed(request_id: int, ok: bool, result_json: String, error: String) -> void:
	if _pending_tab_nav.has(request_id):
		var tab_index := int(_pending_tab_nav.get(request_id, _active_tab_index))
		_pending_tab_nav.erase(request_id)
		if ok:
			_update_tab_url_for_index_from_result(tab_index, result_json)

	if _snapshot_save_map.has(request_id):
		var save_spec: Variant = _snapshot_save_map.get(request_id, "")
		_snapshot_save_map.erase(request_id)
		if ok:
			var raw_path := ""
			var tag := "snapshot"

			if save_spec is Dictionary:
				var save_info: Dictionary = save_spec
				raw_path = String(save_info.get("path", ""))
				tag = String(save_info.get("tag", "snapshot"))
			else:
				raw_path = String(save_spec)

			var save_error := _save_text_to_file(raw_path, result_json, tag)
			if save_error != "":
				completed.emit(request_id, false, "null", save_error)
				return

	completed.emit(request_id, ok, result_json, error)


func _exit_tree() -> void:
	if is_instance_valid(_browser):
		_browser.stop()


func _start_view_mode(x: int, y: int, width: int, height: int) -> bool:
	var w := max(1, width)
	var h := max(1, height)
	var started_ok := _browser.start_view(x, y, w, h)
	if not started_ok:
		return false

	_started = true
	_view_mode = true
	_view_x = x
	_view_y = y
	_view_w = w
	_view_h = h
	return true


func _ensure_started_with_options(options: Dictionary = {}) -> bool:
	if _started:
		return true

	var rect_data := options.get("view_rect", null)
	if rect_data is Dictionary:
		var view_rect: Dictionary = rect_data
		var x := int(view_rect.get("x", _view_x))
		var y := int(view_rect.get("y", _view_y))
		var width := int(view_rect.get("width", _view_w))
		var height := int(view_rect.get("height", _view_h))
		return _start_view_mode(x, y, width, height)

	if options.has("x") or options.has("y") or options.has("width") or options.has("height"):
		return _start_view_mode(
			int(options.get("x", _view_x)),
			int(options.get("y", _view_y)),
			int(options.get("width", _view_w)),
			int(options.get("height", _view_h))
		)

	_started = _browser.start()
	_view_mode = false
	return _started


func _ensure_started() -> bool:
	return _ensure_started_with_options({})


func _next_local_id() -> int:
	var request_id := _next_local_request_id
	_next_local_request_id -= 1
	return request_id


func _emit_local_completed(request_id: int, ok: bool, result_json: String, error: String) -> void:
	completed.emit(request_id, ok, result_json, error)


func _local_success(result_value: Variant = true) -> int:
	var request_id := _next_local_id()
	call_deferred("_emit_local_completed", request_id, true, JSON.stringify(result_value), "")
	return request_id


func _local_error(error_message: String) -> int:
	var request_id := _next_local_id()
	call_deferred("_emit_local_completed", request_id, false, "null", error_message)
	return request_id


func _normalize_output_path(path: String) -> String:
	var normalized := path.strip_edges()
	if normalized == "":
		return ""

	if normalized.begins_with("res://") or normalized.begins_with("user://"):
		return ProjectSettings.globalize_path(normalized)

	if normalized.is_absolute_path():
		return normalized

	return ProjectSettings.globalize_path("user://" + normalized)


func _save_snapshot_to_file(target_path: String, result_json: String) -> String:
	return _save_text_to_file(target_path, result_json, "snapshot")


func _save_text_to_file(target_path: String, content_text: String, error_tag: String) -> String:
	var output_path := _normalize_output_path(target_path)
	if output_path == "":
		return "%s_filename_empty" % error_tag

	var dir_path := output_path.get_base_dir()
	if dir_path != "":
		var mk_err := DirAccess.make_dir_recursive_absolute(dir_path)
		if mk_err != OK and mk_err != ERR_ALREADY_EXISTS:
			return "%s_mkdir_error:%s:%d" % [error_tag, dir_path, mk_err]

	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return "%s_open_error:%s" % [error_tag, output_path]

	file.store_string(content_text + "\n")
	return ""


func _read_text_from_file(source_path: String, error_tag: String) -> Dictionary:
	var output_path := _normalize_output_path(source_path)
	if output_path == "":
		return {"ok": false, "error": "%s_filename_empty" % error_tag}

	if not FileAccess.file_exists(output_path):
		return {"ok": false, "error": "%s_file_not_found:%s" % [error_tag, output_path]}

	var file := FileAccess.open(output_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "%s_open_error:%s" % [error_tag, output_path]}

	return {"ok": true, "path": output_path, "text": file.get_as_text()}


func _parse_json_text(source_text: String, error_tag: String) -> Dictionary:
	var parser := JSON.new()
	var parse_result := parser.parse(source_text)
	if parse_result != OK:
		return {"ok": false, "error": "%s_invalid_json" % error_tag}

	return {"ok": true, "value": parser.data}


func _parse_result_json(result_json: String) -> Variant:
	var parser := JSON.new()
	if parser.parse(result_json) != OK:
		return null
	return parser.data


func _update_tab_url_for_index_from_result(tab_index: int, result_json: String) -> void:
	_ensure_tab_state()
	if tab_index < 0 or tab_index >= _tab_urls.size():
		return

	var parsed: Variant = _parse_result_json(result_json)
	if parsed is String:
		_tab_urls[tab_index] = String(parsed)
		return

	if parsed is Dictionary:
		var data: Dictionary = parsed
		if data.has("url"):
			_tab_urls[tab_index] = String(data.get("url", ""))


func _ensure_tab_state() -> void:
	if _tab_urls.is_empty():
		_tab_urls.append("")
		_active_tab_index = 0

	_active_tab_index = clampi(_active_tab_index, 0, _tab_urls.size() - 1)


func _build_tab_result() -> Dictionary:
	_ensure_tab_state()
	var tabs: Array = []
	for idx in range(_tab_urls.size()):
		tabs.append({
			"index": idx,
			"url": _tab_urls[idx],
			"active": idx == _active_tab_index,
		})

	return {
		"active_index": _active_tab_index,
		"tab_count": _tab_urls.size(),
		"tabs": tabs,
	}


func _set_tab_url_for_active(url: String) -> void:
	_ensure_tab_state()
	_tab_urls[_active_tab_index] = url


func _navigate_active_tab(timeout_ms: int) -> int:
	_ensure_tab_state()
	var url := _tab_urls[_active_tab_index]
	if url == "":
		return _local_success(_build_tab_result())

	if not _ensure_started():
		return _local_error("start_error")

	var request_id := _browser.goto(url, max(0, _timeout_value(timeout_ms)))
	if request_id > 0:
		_pending_tab_nav[request_id] = _active_tab_index
	return request_id


func _storage_area_js(area_name: String) -> String:
	return "window.%s" % area_name


func _storage_list_script(area_name: String) -> String:
	return """
	const store = %s;
	if (!store) {
	  throw new Error("storage_unavailable");
	}
	const items = [];
	for (let i = 0; i < store.length; i += 1) {
	  const key = store.key(i);
	  if (key == null) {
	    continue;
	  }
	  items.push({
	    key: String(key),
	    value: String(store.getItem(key) ?? ""),
	  });
	}
	return items;
	""" % _storage_area_js(area_name)


func _storage_get_script(area_name: String) -> String:
	return """
	const store = %s;
	if (!store) {
	  throw new Error("storage_unavailable");
	}
	const key = String(payload.key ?? "");
	return {
	  key,
	  value: store.getItem(key),
	};
	""" % _storage_area_js(area_name)


func _storage_set_script(area_name: String) -> String:
	return """
	const store = %s;
	if (!store) {
	  throw new Error("storage_unavailable");
	}
	const key = String(payload.key ?? "");
	const value = String(payload.value ?? "");
	store.setItem(key, value);
	return {
	  key,
	  value: String(store.getItem(key) ?? ""),
	};
	""" % _storage_area_js(area_name)


func _storage_delete_script(area_name: String) -> String:
	return """
	const store = %s;
	if (!store) {
	  throw new Error("storage_unavailable");
	}
	const key = String(payload.key ?? "");
	const existed = store.getItem(key) !== null;
	store.removeItem(key);
	return {
	  key,
	  deleted: existed,
	};
	""" % _storage_area_js(area_name)


func _storage_clear_script(area_name: String) -> String:
	return """
	const store = %s;
	if (!store) {
	  throw new Error("storage_unavailable");
	}
	const count = store.length;
	store.clear();
	return {
	  cleared: true,
	  count,
	};
	""" % _storage_area_js(area_name)


func _storage_list(area_name: String, timeout_ms: int = -1) -> int:
	return _eval_with_payload(_storage_list_script(area_name), {}, timeout_ms)


func _storage_get(area_name: String, key: String, timeout_ms: int = -1) -> int:
	return _eval_with_payload(_storage_get_script(area_name), {"key": key}, timeout_ms)


func _storage_set(area_name: String, key: String, value: String, timeout_ms: int = -1) -> int:
	return _eval_with_payload(_storage_set_script(area_name), {"key": key, "value": value}, timeout_ms)


func _storage_delete(area_name: String, key: String, timeout_ms: int = -1) -> int:
	return _eval_with_payload(_storage_delete_script(area_name), {"key": key}, timeout_ms)


func _storage_clear(area_name: String, timeout_ms: int = -1) -> int:
	return _eval_with_payload(_storage_clear_script(area_name), {}, timeout_ms)


func _resolve_local_file_path(file_path: String) -> String:
	if file_path.begins_with("res://") or file_path.begins_with("user://"):
		return ProjectSettings.globalize_path(file_path)
	return file_path


func _mime_from_extension(file_path: String) -> String:
	match file_path.get_extension().to_lower():
		"txt":
			return "text/plain"
		"json":
			return "application/json"
		"html", "htm":
			return "text/html"
		"png":
			return "image/png"
		"jpg", "jpeg":
			return "image/jpeg"
		"webp":
			return "image/webp"
		"gif":
			return "image/gif"
		"svg":
			return "image/svg+xml"
		"pdf":
			return "application/pdf"
		"csv":
			return "text/csv"
		"zip":
			return "application/zip"
		_:
			return "application/octet-stream"


func _file_to_upload_entry(file_path: String) -> Dictionary:
	var resolved := _resolve_local_file_path(file_path)
	if not FileAccess.file_exists(resolved):
		return {"ok": false, "error": "upload_file_not_found:%s" % file_path}

	var file := FileAccess.open(resolved, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "upload_open_error:%s" % file_path}

	var bytes := file.get_buffer(file.get_length())
	return {
		"ok": true,
		"name": resolved.get_file(),
		"mime": _mime_from_extension(resolved),
		"base64": Marshalls.raw_to_base64(bytes),
	}


func _collect_upload_paths(file: Variant) -> Array[String]:
	var paths: Array[String] = []

	if file is String:
		var one := String(file)
		if one != "":
			paths.append(one)
		return paths

	if file is PackedStringArray:
		for entry in file:
			var one := String(entry)
			if one != "":
				paths.append(one)
		return paths

	if file is Array:
		for entry in file:
			var one := String(entry)
			if one != "":
				paths.append(one)

	return paths


func _timeout_value(timeout_ms: int) -> int:
	if timeout_ms >= 0:
		return timeout_ms
	return default_timeout_ms


func _button_index(button_name: String) -> int:
	match button_name.to_lower():
		"left":
			return 0
		"middle":
			return 1
		"right":
			return 2
		_:
			return 0


func _run_eval(script: String, timeout_ms: int = -1) -> int:
	if not _ensure_started():
		return _local_error("start_error")
	return _browser.eval(script, max(0, _timeout_value(timeout_ms)))


func _eval_with_payload(js_body: String, payload: Dictionary, timeout_ms: int = -1) -> int:
	var payload_json := JSON.stringify(payload)
	var script := "(() => { const payload = %s; %s })()" % [payload_json, js_body]
	return _run_eval(script, timeout_ms)


func open(url: String, options: Dictionary = {}) -> int:
	var timeout_ms := int(options.get("timeout_ms", 10_000))
	if not _ensure_started_with_options(options):
		return _local_error("start_error")

	_set_tab_url_for_active(url)
	var request_id := _browser.goto(url, max(0, timeout_ms))
	if request_id > 0:
		_pending_tab_nav[request_id] = _active_tab_index
	return request_id


func close() -> int:
	_started = false
	_view_mode = false
	_pending_tab_nav.clear()
	if is_instance_valid(_browser):
		_browser.stop()
	return _local_success(true)


func type_text(text: String, timeout_ms: int = -1) -> int:
	return _eval_with_payload(
		"""
		const active = document.activeElement;
		if (!active) {
		  throw new Error("no_active_element");
		}
		const inputText = String(payload.text ?? "");
		if (typeof active.value === "string") {
		  active.value += inputText;
		  active.dispatchEvent(new Event("input", { bubbles: true }));
		  active.dispatchEvent(new Event("change", { bubbles: true }));
		  return true;
		}
		if (active.isContentEditable) {
		  document.execCommand("insertText", false, inputText);
		  return true;
		}
		throw new Error("active_element_not_editable");
		""",
		{"text": text},
		timeout_ms
	)


func click(ref: String, button: String = "left", timeout_ms: int = -1) -> int:
	if button.to_lower() == "left":
		if not _ensure_started():
			return _local_error("start_error")
		return _browser.click(ref, max(0, _timeout_value(timeout_ms)))

	return _eval_with_payload(
		"""
		const element = document.querySelector(payload.ref);
		if (!element) {
		  throw new Error("not_found");
		}
		element.dispatchEvent(new MouseEvent("click", {
		  bubbles: true,
		  cancelable: true,
		  button: Number(payload.button),
		}));
		return true;
		""",
		{"ref": ref, "button": _button_index(button)},
		timeout_ms
	)


func dblclick(ref: String, button: String = "left", timeout_ms: int = -1) -> int:
	return _eval_with_payload(
		"""
		const element = document.querySelector(payload.ref);
		if (!element) {
		  throw new Error("not_found");
		}
		element.dispatchEvent(new MouseEvent("dblclick", {
		  bubbles: true,
		  cancelable: true,
		  button: Number(payload.button),
		}));
		return true;
		""",
		{"ref": ref, "button": _button_index(button)},
		timeout_ms
	)


func fill(ref: String, text: String, timeout_ms: int = -1) -> int:
	if not _ensure_started():
		return _local_error("start_error")
	return _browser.fill(ref, text, max(0, _timeout_value(timeout_ms)))


func drag(start_ref: String, end_ref: String, timeout_ms: int = -1) -> int:
	return _eval_with_payload(
		"""
		const source = document.querySelector(payload.start_ref);
		const target = document.querySelector(payload.end_ref);
		if (!source || !target) {
		  throw new Error("not_found");
		}
		source.dispatchEvent(new DragEvent("dragstart", { bubbles: true }));
		target.dispatchEvent(new DragEvent("dragover", { bubbles: true, cancelable: true }));
		target.dispatchEvent(new DragEvent("drop", { bubbles: true }));
		source.dispatchEvent(new DragEvent("dragend", { bubbles: true }));
		return true;
		""",
		{"start_ref": start_ref, "end_ref": end_ref},
		timeout_ms
	)


func hover(ref: String, timeout_ms: int = -1) -> int:
	return _eval_with_payload(
		"""
		const element = document.querySelector(payload.ref);
		if (!element) {
		  throw new Error("not_found");
		}
		element.dispatchEvent(new MouseEvent("mouseover", { bubbles: true }));
		element.dispatchEvent(new MouseEvent("mouseenter", { bubbles: true }));
		element.dispatchEvent(new MouseEvent("mousemove", { bubbles: true }));
		return true;
		""",
		{"ref": ref},
		timeout_ms
	)


func select(ref: String, value: String, timeout_ms: int = -1) -> int:
	return _eval_with_payload(
		"""
		const element = document.querySelector(payload.ref);
		if (!element) {
		  throw new Error("not_found");
		}
		element.value = String(payload.value ?? "");
		element.dispatchEvent(new Event("input", { bubbles: true }));
		element.dispatchEvent(new Event("change", { bubbles: true }));
		return true;
		""",
		{"ref": ref, "value": value},
		timeout_ms
	)


func upload(file: Variant, timeout_ms: int = -1, ref: String = "") -> int:
	var file_paths := _collect_upload_paths(file)
	if file_paths.is_empty():
		return _local_error("upload_empty")

	var entries: Array = []
	for file_path in file_paths:
		var entry := _file_to_upload_entry(file_path)
		if not bool(entry.get("ok", false)):
			return _local_error(String(entry.get("error", "upload_unknown_error")))
		entry.erase("ok")
		entries.append(entry)

	return _eval_with_payload(
		"""
		const files = Array.isArray(payload.files) ? payload.files : [];
		if (files.length === 0) {
		  throw new Error("upload_empty");
		}

		let target = null;
		if (payload.ref && String(payload.ref) !== "") {
		  target = document.querySelector(String(payload.ref));
		} else {
		  target = document.activeElement;
		}

		if (!target || String(target.tagName || "").toLowerCase() !== "input" || String(target.type || "").toLowerCase() !== "file") {
		  throw new Error("upload_target_not_file_input");
		}

		if (typeof DataTransfer !== "function") {
		  throw new Error("upload_datatransfer_unavailable");
		}

		const transfer = new DataTransfer();
		for (const spec of files) {
		  const binary = atob(String(spec.base64 || ""));
		  const bytes = new Uint8Array(binary.length);
		  for (let i = 0; i < binary.length; i += 1) {
		    bytes[i] = binary.charCodeAt(i);
		  }
		  const fileObj = new File(
		    [bytes],
		    String(spec.name || "upload.bin"),
		    { type: String(spec.mime || "application/octet-stream") }
		  );
		  transfer.items.add(fileObj);
		}

		target.files = transfer.files;
		target.dispatchEvent(new Event("input", { bubbles: true }));
		target.dispatchEvent(new Event("change", { bubbles: true }));

		return {
		  count: transfer.files.length,
		  names: Array.from(transfer.files).map((item) => item.name),
		};
		""",
		{"ref": ref, "files": entries},
		timeout_ms
	)


func check(ref: String, timeout_ms: int = -1) -> int:
	return _eval_with_payload(
		"""
		const element = document.querySelector(payload.ref);
		if (!element) {
		  throw new Error("not_found");
		}
		element.checked = true;
		element.dispatchEvent(new Event("input", { bubbles: true }));
		element.dispatchEvent(new Event("change", { bubbles: true }));
		return true;
		""",
		{"ref": ref},
		timeout_ms
	)


func uncheck(ref: String, timeout_ms: int = -1) -> int:
	return _eval_with_payload(
		"""
		const element = document.querySelector(payload.ref);
		if (!element) {
		  throw new Error("not_found");
		}
		element.checked = false;
		element.dispatchEvent(new Event("input", { bubbles: true }));
		element.dispatchEvent(new Event("change", { bubbles: true }));
		return true;
		""",
		{"ref": ref},
		timeout_ms
	)


func _snapshot_eval_script() -> String:
	return """
	(() => {
	  const candidates = Array.from(document.querySelectorAll("a,button,input,textarea,select,[role],h1,h2,h3,p"));
	  return candidates.slice(0, 300).map((element, index) => {
	    const ref = `gwry_ref_${index + 1}`;
	    element.setAttribute("data-gwry-ref", ref);
	    return {
	      ref,
	      tag: String(element.tagName || "").toLowerCase(),
	      text: String((element.innerText || element.value || "")).slice(0, 120),
	    };
	  });
	})()
	"""


func snapshot(filename: String = "", timeout_ms: int = -1) -> int:
	var request_id := _run_eval(_snapshot_eval_script(), timeout_ms)
	if filename != "" and request_id > 0:
		_snapshot_save_map[request_id] = filename
	return request_id


func eval(func_or_expr: String, ref: String = "", timeout_ms: int = -1) -> int:
	if ref == "":
		return _run_eval(func_or_expr, timeout_ms)

	return _eval_with_payload(
		"""
		const element = document.querySelector(payload.ref);
		if (!element) {
		  throw new Error("not_found");
		}
		const candidate = (0, eval)(String(payload.func_or_expr));
		if (typeof candidate !== "function") {
		  throw new Error("eval_ref_requires_function");
		}
		return candidate(element);
		""",
		{"ref": ref, "func_or_expr": func_or_expr},
		timeout_ms
	)


func _set_dialog_mode(mode: String, prompt_text: String, timeout_ms: int = -1) -> int:
	return _eval_with_payload(
		"""
		const mode = String(payload.mode ?? "dismiss");
		const promptText = String(payload.prompt_text ?? "");

		if (!window.__gwry_dialog) {
		  window.__gwry_dialog = {
		    mode: "dismiss",
		    promptText: "",
		    last: null,
		  };

		  const original = {
		    alert: typeof window.alert === "function" ? window.alert.bind(window) : null,
		    confirm: typeof window.confirm === "function" ? window.confirm.bind(window) : null,
		    prompt: typeof window.prompt === "function" ? window.prompt.bind(window) : null,
		  };
		  window.__gwry_dialog.original = original;

		  window.alert = function(message) {
		    window.__gwry_dialog.last = {
		      type: "alert",
		      message: String(message ?? ""),
		    };
		    return undefined;
		  };

		  window.confirm = function(message) {
		    window.__gwry_dialog.last = {
		      type: "confirm",
		      message: String(message ?? ""),
		    };
		    return window.__gwry_dialog.mode === "accept";
		  };

		  window.prompt = function(message, defaultValue) {
		    window.__gwry_dialog.last = {
		      type: "prompt",
		      message: String(message ?? ""),
		      default_value: defaultValue == null ? null : String(defaultValue),
		    };
		    if (window.__gwry_dialog.mode === "accept") {
		      if (window.__gwry_dialog.promptText !== "") {
		        return window.__gwry_dialog.promptText;
		      }
		      return defaultValue == null ? "" : String(defaultValue);
		    }
		    return null;
		  };
		}

		window.__gwry_dialog.mode = mode;
		window.__gwry_dialog.promptText = promptText;
		return {
		  mode: window.__gwry_dialog.mode,
		  promptText: window.__gwry_dialog.promptText,
		};
		""",
		{"mode": mode, "prompt_text": prompt_text},
		timeout_ms
	)


func dialog_accept(prompt: String = "", timeout_ms: int = -1) -> int:
	return _set_dialog_mode("accept", prompt, timeout_ms)


func dialog_dismiss(timeout_ms: int = -1) -> int:
	return _set_dialog_mode("dismiss", "", timeout_ms)


func resize(width: int, height: int, _timeout_ms: int = -1) -> int:
	var w := max(1, width)
	var h := max(1, height)

	if not _started:
		if not _start_view_mode(_view_x, _view_y, w, h):
			return _local_error("start_view_error")
		return _local_success({"mode": "view", "x": _view_x, "y": _view_y, "width": _view_w, "height": _view_h})

	if not _view_mode:
		return _local_error("resize_requires_view_mode")

	_view_w = w
	_view_h = h
	_browser.set_view_rect(_view_x, _view_y, _view_w, _view_h)
	return _local_success({"mode": "view", "x": _view_x, "y": _view_y, "width": _view_w, "height": _view_h})


func go_back(timeout_ms: int = -1) -> int:
	return _run_eval("history.back(); true", timeout_ms)


func go_forward(timeout_ms: int = -1) -> int:
	return _run_eval("history.forward(); true", timeout_ms)


func reload(timeout_ms: int = -1) -> int:
	return _run_eval("location.reload(); true", timeout_ms)


func press(key: String, timeout_ms: int = -1) -> int:
	return _eval_with_payload(
		"""
		const target = document.activeElement || document.body;
		const key = String(payload.key ?? "");
		target.dispatchEvent(new KeyboardEvent("keydown", { bubbles: true, key }));
		target.dispatchEvent(new KeyboardEvent("keypress", { bubbles: true, key }));
		target.dispatchEvent(new KeyboardEvent("keyup", { bubbles: true, key }));
		return true;
		""",
		{"key": key},
		timeout_ms
	)


func keydown(key: String, timeout_ms: int = -1) -> int:
	return _eval_with_payload(
		"""
		const target = document.activeElement || document.body;
		target.dispatchEvent(new KeyboardEvent("keydown", {
		  bubbles: true,
		  key: String(payload.key ?? ""),
		}));
		return true;
		""",
		{"key": key},
		timeout_ms
	)


func keyup(key: String, timeout_ms: int = -1) -> int:
	return _eval_with_payload(
		"""
		const target = document.activeElement || document.body;
		target.dispatchEvent(new KeyboardEvent("keyup", {
		  bubbles: true,
		  key: String(payload.key ?? ""),
		}));
		return true;
		""",
		{"key": key},
		timeout_ms
	)


func mouse_move(x: float, y: float, timeout_ms: int = -1) -> int:
	return _eval_with_payload(
		"""
		const x = Number(payload.x);
		const y = Number(payload.y);
		const target = document.elementFromPoint(x, y) || document.body;
		target.dispatchEvent(new MouseEvent("mousemove", {
		  bubbles: true,
		  clientX: x,
		  clientY: y,
		}));
		return true;
		""",
		{"x": x, "y": y},
		timeout_ms
	)


func mouse_down(button: String = "left", timeout_ms: int = -1) -> int:
	return _eval_with_payload(
		"""
		const target = document.activeElement || document.body;
		target.dispatchEvent(new MouseEvent("mousedown", {
		  bubbles: true,
		  button: Number(payload.button),
		}));
		return true;
		""",
		{"button": _button_index(button)},
		timeout_ms
	)


func mouse_up(button: String = "left", timeout_ms: int = -1) -> int:
	return _eval_with_payload(
		"""
		const target = document.activeElement || document.body;
		target.dispatchEvent(new MouseEvent("mouseup", {
		  bubbles: true,
		  button: Number(payload.button),
		}));
		return true;
		""",
		{"button": _button_index(button)},
		timeout_ms
	)


func mouse_wheel(delta_x: float, delta_y: float, timeout_ms: int = -1) -> int:
	return _eval_with_payload(
		"""
		const target = document.activeElement || document.body;
		target.dispatchEvent(new WheelEvent("wheel", {
		  bubbles: true,
		  deltaX: Number(payload.delta_x),
		  deltaY: Number(payload.delta_y),
		}));
		return true;
		""",
		{"delta_x": delta_x, "delta_y": delta_y},
		timeout_ms
	)


func screenshot(ref: String = "", filename: String = "") -> int:
	var request_id := _eval_with_payload(
		"""
		const target = payload.ref ? document.querySelector(String(payload.ref)) : document.documentElement;
		if (!target) {
		  throw new Error("not_found");
		}

		const rect = target.getBoundingClientRect();
		const width = Math.max(1, Math.ceil(rect.width || target.clientWidth || window.innerWidth || 1));
		const height = Math.max(1, Math.ceil(rect.height || target.clientHeight || window.innerHeight || 1));
		const xml = new XMLSerializer().serializeToString(target.cloneNode(true));
		const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}"><foreignObject x="0" y="0" width="100%" height="100%">${xml}</foreignObject></svg>`;
		const dataUrl = "data:image/svg+xml;base64," + btoa(unescape(encodeURIComponent(svg)));
		return {
		  format: "svg_data_url",
		  data_url: dataUrl,
		  width,
		  height,
		};
		""",
		{"ref": ref},
		default_timeout_ms
	)

	if filename != "" and request_id > 0:
		_snapshot_save_map[request_id] = {"path": filename, "tag": "screenshot"}
	return request_id


func pdf(filename: String = "page.pdf") -> int:
	if filename.strip_edges() == "":
		return _local_error("pdf_filename_empty")

	var request_id := _run_eval(
		"""
		(() => {
		  return {
		    format: "html_json",
		    url: location.href,
		    title: document.title || "",
		    html: document.documentElement ? document.documentElement.outerHTML : "",
		  };
		})()
		""",
		default_timeout_ms
	)
	if request_id > 0:
		_snapshot_save_map[request_id] = {"path": filename, "tag": "pdf"}
	return request_id


func tab_list() -> int:
	return _local_success(_build_tab_result())


func tab_new(url: String = "", timeout_ms: int = -1) -> int:
	_ensure_tab_state()
	_tab_urls.append(url)
	_active_tab_index = _tab_urls.size() - 1

	if url == "":
		return _local_success(_build_tab_result())

	return _navigate_active_tab(timeout_ms)


func tab_close(index: int = -1, timeout_ms: int = -1) -> int:
	_ensure_tab_state()
	var close_index := _active_tab_index
	if index >= 0:
		close_index = index

	if close_index < 0 or close_index >= _tab_urls.size():
		return _local_error("tab_index_out_of_range")

	_tab_urls.remove_at(close_index)
	if _tab_urls.is_empty():
		_tab_urls.append("")
		_active_tab_index = 0
		return _local_success(_build_tab_result())

	if _active_tab_index >= close_index:
		_active_tab_index = max(0, _active_tab_index - 1)

	_active_tab_index = clampi(_active_tab_index, 0, _tab_urls.size() - 1)
	return _navigate_active_tab(timeout_ms)


func tab_select(index: int, timeout_ms: int = -1) -> int:
	_ensure_tab_state()
	if index < 0 or index >= _tab_urls.size():
		return _local_error("tab_index_out_of_range")

	_active_tab_index = index
	return _navigate_active_tab(timeout_ms)


func state_save(filename: String = "state.json") -> int:
	if filename.strip_edges() == "":
		return _local_error("state_save_filename_empty")

	var request_id := _eval_with_payload(
		"""
		const readStorage = (store) => {
		  const out = {};
		  if (!store) {
		    return out;
		  }
		  for (let i = 0; i < store.length; i += 1) {
		    const key = store.key(i);
		    if (key == null) {
		      continue;
		    }
		    out[String(key)] = String(store.getItem(key) ?? "");
		  }
		  return out;
		};

		return {
		  schema: "gwry-session-state-v1",
		  saved_at_ms: Date.now(),
		  url: location.href,
		  title: document.title || "",
		  cookies: String(document.cookie || ""),
		  local_storage: readStorage(window.localStorage),
		  session_storage: readStorage(window.sessionStorage),
		  tabs: payload.tabs,
		  active_index: Number(payload.active_index || 0),
		};
		""",
		{"tabs": _tab_urls, "active_index": _active_tab_index},
		default_timeout_ms
	)

	if request_id > 0:
		_snapshot_save_map[request_id] = {"path": filename, "tag": "state_save"}
	return request_id


func state_load(filename: String) -> int:
	var file_result := _read_text_from_file(filename, "state_load")
	if not bool(file_result.get("ok", false)):
		return _local_error(String(file_result.get("error", "state_load_read_error")))

	var parse_result := _parse_json_text(String(file_result.get("text", "")), "state_load")
	if not bool(parse_result.get("ok", false)):
		return _local_error(String(parse_result.get("error", "state_load_invalid_json")))

	var state_value: Variant = parse_result.get("value", {})
	if not (state_value is Dictionary):
		return _local_error("state_load_invalid_payload")

	var state: Dictionary = state_value
	var restored_tabs: Array[String] = []
	if state.get("tabs", null) is Array:
		for entry in state.get("tabs", []):
			restored_tabs.append(String(entry))

	if restored_tabs.is_empty():
		restored_tabs.append(String(state.get("url", "")))

	_tab_urls = restored_tabs
	_active_tab_index = clampi(int(state.get("active_index", 0)), 0, _tab_urls.size() - 1)

	var apply_state: Dictionary = state.duplicate(true)
	if not apply_state.has("url"):
		apply_state["url"] = _tab_urls[_active_tab_index]

	return _eval_with_payload(
		"""
		const state = (payload.state && typeof payload.state === "object") ? payload.state : {};

		if (state.local_storage && typeof state.local_storage === "object" && window.localStorage) {
		  window.localStorage.clear();
		  for (const [key, value] of Object.entries(state.local_storage)) {
		    window.localStorage.setItem(String(key), String(value));
		  }
		}

		if (state.session_storage && typeof state.session_storage === "object" && window.sessionStorage) {
		  window.sessionStorage.clear();
		  for (const [key, value] of Object.entries(state.session_storage)) {
		    window.sessionStorage.setItem(String(key), String(value));
		  }
		}

		if (typeof state.cookies === "string" && state.cookies.trim() !== "") {
		  const cookiePairs = state.cookies.split(";");
		  for (const raw of cookiePairs) {
		    const pair = String(raw || "").trim();
		    if (pair !== "") {
		      document.cookie = pair;
		    }
		  }
		}

		const result = {
		  applied: true,
		  navigated: false,
		  url: location.href,
		};

		if (typeof state.url === "string" && state.url !== "" && state.url !== location.href) {
		  result.navigated = true;
		  result.url = state.url;
		  location.href = state.url;
		}

		return result;
		""",
		{"state": apply_state},
		default_timeout_ms
	)


func cookie_list(domain: String = "") -> int:
	return _eval_with_payload(
		"""
		const all = String(document.cookie || "");
		if (all === "") {
		  return [];
		}
		return all.split(";").map((entry) => {
		  const trimmed = String(entry || "").trim();
		  const eqIndex = trimmed.indexOf("=");
		  const name = eqIndex >= 0 ? trimmed.slice(0, eqIndex).trim() : trimmed;
		  const value = eqIndex >= 0 ? trimmed.slice(eqIndex + 1) : "";
		  return {
		    name,
		    value,
		    domain: payload.domain || location.hostname || "",
		  };
		});
		""",
		{"domain": domain},
		default_timeout_ms
	)


func cookie_get(name: String) -> int:
	return _eval_with_payload(
		"""
		const lookup = String(payload.name || "");
		const all = String(document.cookie || "");
		for (const entry of all.split(";")) {
		  const trimmed = String(entry || "").trim();
		  const eqIndex = trimmed.indexOf("=");
		  const key = eqIndex >= 0 ? trimmed.slice(0, eqIndex).trim() : trimmed;
		  if (key === lookup) {
		    return {
		      name: key,
		      value: eqIndex >= 0 ? trimmed.slice(eqIndex + 1) : "",
		    };
		  }
		}
		return null;
		""",
		{"name": name},
		default_timeout_ms
	)


func cookie_set(name: String, value: String) -> int:
	return _eval_with_payload(
		"""
		const name = String(payload.name || "");
		if (name === "") {
		  throw new Error("cookie_name_empty");
		}
		const value = String(payload.value || "");
		document.cookie = `${name}=${value}; path=/`;
		return {
		  name,
		  value,
		};
		""",
		{"name": name, "value": value},
		default_timeout_ms
	)


func cookie_delete(name: String) -> int:
	return _eval_with_payload(
		"""
		const name = String(payload.name || "");
		if (name === "") {
		  throw new Error("cookie_name_empty");
		}
		document.cookie = `${name}=; Max-Age=0; path=/`;
		return {
		  name,
		  deleted: true,
		};
		""",
		{"name": name},
		default_timeout_ms
	)


func cookie_clear() -> int:
	return _run_eval(
		"""
		(() => {
		  const all = String(document.cookie || "");
		  let count = 0;
		  for (const entry of all.split(";")) {
		    const trimmed = String(entry || "").trim();
		    if (trimmed === "") {
		      continue;
		    }
		    const eqIndex = trimmed.indexOf("=");
		    const key = eqIndex >= 0 ? trimmed.slice(0, eqIndex).trim() : trimmed;
		    if (key !== "") {
		      document.cookie = `${key}=; Max-Age=0; path=/`;
		      count += 1;
		    }
		  }
		  return { cleared: true, count };
		})()
		""",
		default_timeout_ms
	)


func localstorage_list() -> int:
	return _storage_list("localStorage", default_timeout_ms)


func localstorage_get(key: String) -> int:
	return _storage_get("localStorage", key, default_timeout_ms)


func localstorage_set(key: String, value: String) -> int:
	return _storage_set("localStorage", key, value, default_timeout_ms)


func localstorage_delete(key: String) -> int:
	return _storage_delete("localStorage", key, default_timeout_ms)


func localstorage_clear() -> int:
	return _storage_clear("localStorage", default_timeout_ms)


func sessionstorage_list() -> int:
	return _storage_list("sessionStorage", default_timeout_ms)


func sessionstorage_get(key: String) -> int:
	return _storage_get("sessionStorage", key, default_timeout_ms)


func sessionstorage_set(key: String, value: String) -> int:
	return _storage_set("sessionStorage", key, value, default_timeout_ms)


func sessionstorage_delete(key: String) -> int:
	return _storage_delete("sessionStorage", key, default_timeout_ms)


func sessionstorage_clear() -> int:
	return _storage_clear("sessionStorage", default_timeout_ms)
