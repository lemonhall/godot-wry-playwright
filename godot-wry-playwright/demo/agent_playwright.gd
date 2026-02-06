extends Node3D

const OPEN_AGENTIC_SCRIPT := preload("res://addons/openagentic/OpenAgentic.gd")
const OA_TOOL_SCRIPT := preload("res://addons/openagentic/core/OATool.gd")

@onready var screen: MeshInstance3D = %WebScreen
@onready var camera_3d: Camera3D = %Camera3D
@onready var chat_status_label: Label = %ChatStatusLabel
@onready var chat_output: RichTextLabel = %ChatOutput
@onready var chat_input: LineEdit = %ChatInput
@onready var chat_send_button: Button = %ChatSendButton
@onready var chat_clear_button: Button = %ChatClearButton
@onready var chat_panel: Control = $ChatOverlay/Panel

@export_group("Browser")
@export var capture_width: int = 1024
@export var capture_height: int = 768
@export var capture_fps: int = 3
@export var freeze_after_first_frame: bool = true
@export var target_url: String = "https://www.baidu.com/"
@export var auto_navigate_on_ready: bool = true
@export var browser_enabled: bool = true

@export_group("Agent")
@export var agent_enabled: bool = true
@export var agent_save_id: String = "agent_playwright_demo"
@export var agent_npc_id: String = "browser_operator"
@export var agent_proxy_base_url: String = "http://127.0.0.1:8787/v1"
@export var agent_model: String = "gpt-5.2"
@export var agent_auth_header: String = ""
@export var agent_auth_token: String = ""
@export var agent_auth_is_bearer: bool = true
@export var agent_auto_allow_tools: bool = true
@export_multiline var agent_system_prompt: String = "You control the in-scene browser. Prefer browser_open, browser_click, browser_fill, browser_title, browser_eval. Keep replies concise and action-oriented."

var _tool_session: WryPwSession = null
var _tool_session_pending: Dictionary = {}
var _tex: ImageTexture
var _reveal: float = 1.0
var _frame_count: int = 0
var _frozen_after_first_frame: bool = false
var _is_orbiting: bool = false
var _is_panning: bool = false
var _orbit_yaw: float = 0.0
var _orbit_pitch: float = deg_to_rad(-12.0)
var _camera_distance: float = 5.4
var _camera_target: Vector3 = Vector3(0.0, 1.45, 0.35)

var _openagentic: Node = null
var _agent_ready: bool = false
var _agent_busy: bool = false
var _agent_tools_registered: bool = false
var _assistant_streaming: bool = false
var _assistant_had_delta: bool = false
var _agent_turn_done: bool = false

const REVEAL_SPEED := 0.45
const ORBIT_SENS := 0.008
const PAN_SENS := 0.002
const ZOOM_STEP := 0.55
const MIN_DIST := 2.0
const MAX_DIST := 12.0
const TOOL_TIMEOUT_DEFAULT_MS := 10_000
const TOOL_TIMEOUT_MAX_MS := 45_000


func _ready() -> void:
	_setup_input_actions()
	_update_camera_transform()
	_setup_tool_session_driver()
	if browser_enabled:
		_setup_browser()
	_setup_chat_ui()
	if agent_enabled:
		_setup_agent()
	else:
		_set_status("Agent disabled for this scene.", false)


func _setup_input_actions() -> void:
	if not InputMap.has_action("reload_page"):
		InputMap.add_action("reload_page")
	var key_5 := InputEventKey.new()
	key_5.keycode = KEY_5
	if not InputMap.action_has_event("reload_page", key_5):
		InputMap.action_add_event("reload_page", key_5)


func _setup_browser() -> void:
	if _tool_session == null:
		return
	_begin_navigation_cycle()
	if auto_navigate_on_ready:
		_tool_session.open(target_url, _session_open_options(10_000))


func _session_open_options(timeout_ms: int) -> Dictionary:
	return {
		"timeout_ms": timeout_ms,
		"texture": {
			"width": capture_width,
			"height": capture_height,
			"fps": capture_fps,
		},
	}


func _setup_tool_session_driver() -> void:
	if _tool_session != null:
		return
	_tool_session = WryPwSession.new()
	_tool_session.auto_start = false
	add_child(_tool_session)
	_tool_session.completed.connect(_on_tool_session_completed)
	_tool_session.frame_png.connect(_on_frame_png)


func _on_tool_session_completed(request_id: int, ok: bool, result_json: String, error: String) -> void:
	_tool_session_pending[request_id] = {
		"ok": ok,
		"result_json": result_json,
		"error": error,
	}


func _await_tool_session_request(request_id: int, timeout_ms: int) -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + int(max(200, timeout_ms))
	while Time.get_ticks_msec() <= deadline:
		if _tool_session_pending.has(request_id):
			var response: Dictionary = _tool_session_pending[request_id]
			_tool_session_pending.erase(request_id)
			return response
		await get_tree().process_frame

	return {
		"ok": false,
		"result_json": "null",
		"error": "timeout_wait_tool_session_completed:%d" % request_id,
	}

func _setup_chat_ui() -> void:
	chat_send_button.pressed.connect(_on_chat_send_pressed)
	chat_clear_button.pressed.connect(_on_chat_clear_pressed)
	chat_input.text_submitted.connect(_on_chat_text_submitted)
	chat_output.bbcode_enabled = false
	_set_agent_busy(false)
	_set_status("Initializing agent...", false)


func _on_chat_clear_pressed() -> void:
	chat_output.clear()
	if _openagentic != null and _openagentic.has_method("clear_npc_conversation"):
		var result: Variant = _openagentic.call("clear_npc_conversation", agent_npc_id)
		if typeof(result) == TYPE_DICTIONARY and bool((result as Dictionary).get("ok", false)):
			_set_status("Chat and agent session cleared.", false)
			return
		var err := "unknown_error"
		if typeof(result) == TYPE_DICTIONARY:
			err = String((result as Dictionary).get("error", err))
		_set_status("Chat cleared, session clear failed: %s" % err, true)
		return
	_set_status("Chat cleared. Agent session clear API unavailable.", true)


func _setup_agent() -> void:
	_openagentic = get_node_or_null("/root/OpenAgentic")
	if _openagentic == null:
		_openagentic = OPEN_AGENTIC_SCRIPT.new()
		_openagentic.name = "OpenAgenticLocal"
		add_child(_openagentic)

	if _openagentic == null:
		_agent_ready = false
		_set_status("OpenAgentic unavailable.", true)
		return

	if not _openagentic.has_method("set_save_id") or not _openagentic.has_method("configure_proxy_openai_responses") or not _openagentic.has_method("run_npc_turn"):
		_agent_ready = false
		_set_status("OpenAgentic API mismatch.", true)
		return

	_openagentic.call("set_save_id", agent_save_id)
	_openagentic.call("set_approver", Callable(self, "_approve_tool_use"))

	if agent_system_prompt.strip_edges() != "":
		_openagentic.set("system_prompt", agent_system_prompt)

	_register_agent_tools()

	var base_url := agent_proxy_base_url.strip_edges()
	var model_name := agent_model.strip_edges()
	if base_url == "" or model_name == "":
		_agent_ready = false
		_set_status("Set proxy base URL and model in Inspector.", true)
		return

	var auth_header := agent_auth_header.strip_edges()
	if auth_header == "" and agent_auth_token.strip_edges() != "":
		auth_header = "authorization"

	_openagentic.call(
		"configure_proxy_openai_responses",
		base_url,
		model_name,
		auth_header,
		agent_auth_token,
		agent_auth_is_bearer
	)

	_agent_ready = true
	_set_status("Agent ready. Enter message to control browser.", false)


func _register_agent_tools() -> void:
	if _openagentic == null or _agent_tools_registered:
		return

	_openagentic.call(
		"register_tool",
		OA_TOOL_SCRIPT.new(
			"browser_open",
			"Open URL in the in-scene browser.",
			Callable(self, "_tool_browser_open"),
			{
				"type": "object",
				"properties": {
					"url": {"type": "string"},
					"timeout_ms": {"type": ["integer", "number"]},
				},
				"required": ["url"],
			},
			true
		)
	)

	_openagentic.call(
		"register_tool",
		OA_TOOL_SCRIPT.new(
			"browser_eval",
			"Run JavaScript in the current page and return value.",
			Callable(self, "_tool_browser_eval"),
			{
				"type": "object",
				"properties": {
					"script": {"type": "string"},
					"timeout_ms": {"type": ["integer", "number"]},
				},
				"required": ["script"],
			},
			true
		)
	)

	_openagentic.call(
		"register_tool",
		OA_TOOL_SCRIPT.new(
			"browser_click",
			"Click the first element matching selector.",
			Callable(self, "_tool_browser_click"),
			{
				"type": "object",
				"properties": {
					"selector": {"type": "string"},
					"timeout_ms": {"type": ["integer", "number"]},
				},
				"required": ["selector"],
			},
			true
		)
	)

	_openagentic.call(
		"register_tool",
		OA_TOOL_SCRIPT.new(
			"browser_fill",
			"Fill text into first element matching selector.",
			Callable(self, "_tool_browser_fill"),
			{
				"type": "object",
				"properties": {
					"selector": {"type": "string"},
					"text": {"type": "string"},
					"timeout_ms": {"type": ["integer", "number"]},
				},
				"required": ["selector", "text"],
			},
			true
		)
	)

	_openagentic.call(
		"register_tool",
		OA_TOOL_SCRIPT.new(
			"browser_title",
			"Get document title of current page.",
			Callable(self, "_tool_browser_title"),
			{
				"type": "object",
				"properties": {
					"timeout_ms": {"type": ["integer", "number"]},
				},
			},
			true
		)
	)

	_agent_tools_registered = true


func _approve_tool_use(_question: Dictionary, _ctx: Dictionary) -> bool:
	return agent_auto_allow_tools


func _on_chat_text_submitted(text: String) -> void:
	await _send_chat_text(text)


func _on_chat_send_pressed() -> void:
	await _send_chat_text(chat_input.text)


func _send_chat_text(raw_text: String) -> void:
	if _agent_busy:
		return

	var user_text := raw_text.strip_edges()
	if user_text == "":
		return

	if not _agent_ready:
		_set_status("Agent not ready. Check proxy/model settings.", true)
		return

	if _openagentic == null:
		_set_status("OpenAgentic missing.", true)
		return

	chat_input.clear()
	_append_chat_line("user", user_text)
	_set_agent_busy(true)
	_set_status("Agent running...", false)
	_agent_turn_done = false

	var turn_call_result: Variant = _openagentic.call("run_npc_turn", agent_npc_id, user_text, Callable(self, "_on_agent_event"))
	if typeof(turn_call_result) == TYPE_OBJECT and turn_call_result != null and turn_call_result.has_method("resume"):
		await turn_call_result

	var wait_deadline := Time.get_ticks_msec() + 180_000
	while not _agent_turn_done and Time.get_ticks_msec() <= wait_deadline:
		await get_tree().process_frame

	if not _agent_turn_done:
		_set_status("Agent turn timeout (180s).", true)

	_finalize_assistant_stream_if_needed()
	_assistant_had_delta = false
	_set_agent_busy(false)
	if _agent_turn_done:
		_set_status("Agent done.", false)


func _on_agent_event(ev: Dictionary) -> void:
	var event_type := String(ev.get("type", "")).strip_edges()
	if event_type == "assistant.delta":
		var delta := String(ev.get("text_delta", ""))
		if delta != "":
			_append_assistant_delta(delta)
		return

	if event_type == "assistant.message":
		var msg := String(ev.get("text", ""))
		if _assistant_had_delta:
			_assistant_had_delta = false
			_finalize_assistant_stream_if_needed()
			return
		if msg != "":
			_append_chat_line("assistant", msg)
		return

	if event_type == "tool.use":
		var tool_name := String(ev.get("name", ""))
		_append_chat_line("tool", "use %s" % tool_name)
		return

	if event_type == "tool.result":
		var is_error := bool(ev.get("is_error", false))
		var tool_output: Variant = ev.get("output", null)
		var out_text := JSON.stringify(tool_output)
		if out_text.length() > 280:
			out_text = out_text.substr(0, 280) + "..."
		if is_error:
			_append_chat_line("tool", "error %s" % String(ev.get("error_message", "tool_error")))
		else:
			_append_chat_line("tool", "result %s" % out_text)
		return

	if event_type == "result":
		_agent_turn_done = true
		if String(ev.get("error", "")) != "":
			_set_status("Result error: %s" % String(ev.get("error", "")), true)
		return


func _append_chat_line(role: String, text: String) -> void:
	chat_output.append_text("[%s] %s\n" % [role, text])
	_scroll_chat_to_end()


func _append_assistant_delta(delta: String) -> void:
	if not _assistant_streaming:
		chat_output.append_text("[assistant] ")
		_assistant_streaming = true
	chat_output.append_text(delta)
	_assistant_had_delta = true
	_scroll_chat_to_end()


func _finalize_assistant_stream_if_needed() -> void:
	if _assistant_streaming:
		chat_output.append_text("\n")
		_assistant_streaming = false
		_scroll_chat_to_end()


func _set_agent_busy(is_busy: bool) -> void:
	_agent_busy = is_busy
	chat_send_button.disabled = is_busy
	chat_input.editable = not is_busy


func _set_status(text: String, is_error: bool) -> void:
	if is_error:
		chat_status_label.text = "Status: ERROR - %s" % text
	else:
		chat_status_label.text = "Status: %s" % text


func _scroll_chat_to_end() -> void:
	var line_count := chat_output.get_line_count()
	chat_output.scroll_to_line(max(0, line_count - 1))


func _tool_timeout(input: Dictionary, fallback_ms: int = TOOL_TIMEOUT_DEFAULT_MS) -> int:
	var timeout_value: int = fallback_ms
	var raw: Variant = input.get("timeout_ms", fallback_ms)
	if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT:
		timeout_value = int(raw)
	if timeout_value <= 0:
		timeout_value = fallback_ms
	return min(timeout_value, TOOL_TIMEOUT_MAX_MS)


func _tool_browser_open(input: Dictionary, _ctx: Dictionary) -> Variant:
	if _tool_session == null:
		return {"ok": false, "error": "tool_session_not_ready"}

	var url := String(input.get("url", "")).strip_edges()
	if url == "":
		return {"ok": false, "error": "missing_url"}

	var timeout_ms := _tool_timeout(input, TOOL_TIMEOUT_DEFAULT_MS)
	_begin_navigation_cycle()
	var request_id := _tool_session.open(url, _session_open_options(timeout_ms))
	var response: Dictionary = await _await_tool_session_request(request_id, timeout_ms + 2_000)
	if not bool(response.get("ok", false)):
		return {
			"ok": false,
			"request_id": request_id,
			"error": String(response.get("error", "open_failed")),
		}

	return {
		"ok": true,
		"request_id": request_id,
		"url": url,
		"result": _parse_json_value(String(response.get("result_json", "null")), false),
	}


func _tool_browser_eval(input: Dictionary, _ctx: Dictionary) -> Variant:
	var script := String(input.get("script", "")).strip_edges()
	if script == "":
		return {"ok": false, "error": "missing_script"}
	var timeout_ms := _tool_timeout(input, TOOL_TIMEOUT_DEFAULT_MS)
	return await _execute_browser_eval(script, timeout_ms)


func _tool_browser_click(input: Dictionary, _ctx: Dictionary) -> Variant:
	var selector := String(input.get("selector", "")).strip_edges()
	if selector == "":
		return {"ok": false, "error": "missing_selector"}

	var timeout_ms := _tool_timeout(input, TOOL_TIMEOUT_DEFAULT_MS)
	var js := (
		"(() => {"
		+ "const selector = %s;"
		+ "const el = document.querySelector(selector);"
		+ "if (!el) { return { ok:false, error:'selector_not_found', selector:selector }; }"
		+ "el.click();"
		+ "return { ok:true, selector:selector };"
		+ "})()"
	) % [_js_string(selector)]

	var response: Dictionary = await _execute_browser_eval(js, timeout_ms)
	if not bool(response.get("ok", false)):
		return response

	var value: Variant = response.get("value", null)
	if value is Dictionary and not bool((value as Dictionary).get("ok", false)):
		var data: Dictionary = value
		return {"ok": false, "error": String(data.get("error", "click_failed")), "selector": selector}

	return {"ok": true, "selector": selector, "request_id": int(response.get("request_id", -1))}


func _tool_browser_fill(input: Dictionary, _ctx: Dictionary) -> Variant:
	var selector := String(input.get("selector", "")).strip_edges()
	var text := String(input.get("text", ""))
	if selector == "":
		return {"ok": false, "error": "missing_selector"}

	var timeout_ms := _tool_timeout(input, TOOL_TIMEOUT_DEFAULT_MS)
	var js := (
		"(() => {"
		+ "const selector = %s;"
		+ "const value = %s;"
		+ "const el = document.querySelector(selector);"
		+ "if (!el) { return { ok:false, error:'selector_not_found', selector:selector }; }"
		+ "el.focus();"
		+ "if ('value' in el) { el.value = value; } else { el.textContent = value; }"
		+ "el.dispatchEvent(new Event('input', { bubbles:true }));"
		+ "el.dispatchEvent(new Event('change', { bubbles:true }));"
		+ "return { ok:true, selector:selector, text:value.length };"
		+ "})()"
	) % [_js_string(selector), _js_string(text)]

	var response: Dictionary = await _execute_browser_eval(js, timeout_ms)
	if not bool(response.get("ok", false)):
		return response

	var value: Variant = response.get("value", null)
	if value is Dictionary and not bool((value as Dictionary).get("ok", false)):
		var data: Dictionary = value
		return {"ok": false, "error": String(data.get("error", "fill_failed")), "selector": selector}

	return {"ok": true, "selector": selector, "length": text.length(), "request_id": int(response.get("request_id", -1))}


func _tool_browser_title(input: Dictionary, _ctx: Dictionary) -> Variant:
	var timeout_ms := _tool_timeout(input, TOOL_TIMEOUT_DEFAULT_MS)
	var response: Dictionary = await _execute_browser_eval("() => document.title", timeout_ms)
	if not bool(response.get("ok", false)):
		return response

	return {
		"ok": true,
		"title": response.get("value", ""),
		"request_id": int(response.get("request_id", -1)),
	}


func _execute_browser_eval(script: String, timeout_ms: int) -> Dictionary:
	if _tool_session == null:
		return {"ok": false, "error": "tool_session_not_ready"}

	var request_id := _tool_session.eval(script, "", timeout_ms)
	var response: Dictionary = await _await_tool_session_request(request_id, timeout_ms + 1_500)
	if not bool(response.get("ok", false)):
		return {
			"ok": false,
			"request_id": request_id,
			"error": String(response.get("error", "eval_failed")),
		}

	return {
		"ok": true,
		"request_id": request_id,
		"value": _parse_json_value(String(response.get("result_json", "null")), false),
	}


func _parse_json_value(raw_json: String, fallback_to_null: bool = true) -> Variant:
	var parser := JSON.new()
	if parser.parse(raw_json) != OK:
		if fallback_to_null:
			return null
		return raw_json
	return parser.data


func _js_string(value: String) -> String:
	return JSON.stringify(value)


func _is_chat_panel_point(mouse_pos: Vector2) -> bool:
	if chat_panel == null or not chat_panel.visible:
		return false
	return chat_panel.get_global_rect().has_point(mouse_pos)


func _scroll_chat_output_with_wheel(button_index: int) -> bool:
	if chat_output == null:
		return false
	var scroll_bar: VScrollBar = chat_output.get_v_scroll_bar()
	if scroll_bar == null:
		return false
	var step: float = max(24.0, float(scroll_bar.page) * 0.15)
	if button_index == MOUSE_BUTTON_WHEEL_UP:
		scroll_bar.value = max(scroll_bar.min_value, scroll_bar.value - step)
		return true
	if button_index == MOUSE_BUTTON_WHEEL_DOWN:
		scroll_bar.value = min(scroll_bar.max_value, scroll_bar.value + step)
		return true
	return false


func _handle_chat_panel_wheel(event: InputEventMouseButton) -> bool:
	if event == null or not event.pressed:
		return false
	if event.button_index != MOUSE_BUTTON_WHEEL_UP and event.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return false
	if not _is_chat_panel_point(event.position):
		return false
	return _scroll_chat_output_with_wheel(event.button_index)


func _process(delta: float) -> void:
	if _reveal < 1.0:
		_reveal = min(1.0, _reveal + delta * REVEAL_SPEED)
		_set_reveal(_reveal)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reload_page"):
		_reload_page()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_5:
		_reload_page()
		return

	if event is InputEventMouseButton:
		if _handle_chat_panel_wheel(event):
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_is_orbiting = event.pressed
			if event.pressed:
				_is_panning = false
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = event.pressed
			if event.pressed:
				_is_orbiting = false
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = max(MIN_DIST, _camera_distance - ZOOM_STEP)
			_update_camera_transform()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = min(MAX_DIST, _camera_distance + ZOOM_STEP)
			_update_camera_transform()

	if event is InputEventMouseMotion:
		if _is_orbiting:
			_orbit_yaw -= event.relative.x * ORBIT_SENS
			_orbit_pitch = clamp(_orbit_pitch - event.relative.y * ORBIT_SENS, deg_to_rad(-80.0), deg_to_rad(25.0))
			_update_camera_transform()
		elif _is_panning:
			var right := camera_3d.global_transform.basis.x
			var up := camera_3d.global_transform.basis.y
			_camera_target += (-right * event.relative.x + up * event.relative.y) * PAN_SENS * _camera_distance
			_update_camera_transform()


func _on_frame_png(png_bytes: PackedByteArray) -> void:
	if _frozen_after_first_frame:
		return

	_frame_count += 1
	if _frame_count == 1 or (_frame_count % 30) == 0:
		print("frame_png bytes=", png_bytes.size(), " count=", _frame_count)

	var img := Image.new()
	var err := img.load_png_from_buffer(png_bytes)
	if err != OK:
		print("load_png_from_buffer failed: ", err)
		return

	if _tex == null:
		_tex = ImageTexture.create_from_image(img)
	else:
		_tex.update(img)

	var mat := _screen_material()
	if mat == null:
		return
	mat.set_shader_parameter("web_tex", _tex)

	if _reveal >= 1.0 or _frame_count == 1:
		_reveal = 0.0
		_set_reveal(_reveal)

	if freeze_after_first_frame and _frame_count == 1:
		_frozen_after_first_frame = true
		print("frame capture frozen after first frame")


func _begin_navigation_cycle() -> void:
	_frozen_after_first_frame = false
	_frame_count = 0
	_reveal = 1.0
	_set_reveal(_reveal)


func _reload_page() -> void:
	if _tool_session == null:
		return
	print("reload_page key=5")
	_begin_navigation_cycle()
	_tool_session.open(target_url, _session_open_options(10_000))


func _set_reveal(v: float) -> void:
	var mat := _screen_material()
	if mat == null:
		return
	mat.set_shader_parameter("reveal", v)


func _update_camera_transform() -> void:
	var orbit_basis := Basis.from_euler(Vector3(_orbit_pitch, _orbit_yaw, 0.0))
	var offset := orbit_basis * Vector3(0.0, 0.0, _camera_distance)
	camera_3d.global_position = _camera_target + offset
	camera_3d.look_at(_camera_target, Vector3.UP)


func _screen_material() -> ShaderMaterial:
	var mat := screen.get_active_material(0) as ShaderMaterial
	if mat == null:
		push_warning("WebScreen material is not a ShaderMaterial")
	return mat
