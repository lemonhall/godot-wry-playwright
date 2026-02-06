extends SceneTree

const T := preload("res://tests/_test_util.gd")


class MockOpenAgentic:
	extends Node

	var save_id: String = ""
	var system_prompt: String = ""
	var _tool_calls: Array[Dictionary] = []

	func set_save_id(id: String) -> void:
		save_id = id

	func configure_proxy_openai_responses(_base_url: String, _model_name: String, _auth_header: String = "", _auth_token: String = "", _is_bearer: bool = true) -> void:
		pass

	func set_approver(_approver: Callable) -> void:
		pass

	func register_tool(tool) -> void:
		if tool == null:
			return
		_tool_calls.append({"name": String(tool.name)})

	func run_npc_turn(_npc_id: String, user_text: String, on_event: Callable) -> void:
		if on_event == null or on_event.is_null():
			return

		on_event.call({"type": "tool.use", "name": "browser_title"})
		on_event.call({"type": "tool.result", "is_error": false, "output": {"ok": true, "title": "GWry Session Fixture"}})

		var text := "Ack: %s" % user_text
		on_event.call({"type": "assistant.delta", "text_delta": text.substr(0, 4)})
		on_event.call({"type": "assistant.delta", "text_delta": text.substr(4)})
		on_event.call({"type": "assistant.message", "text": text})
		on_event.call({"type": "result", "final_text": text, "stop_reason": "end"})


func _init() -> void:
	await process_frame

	var packed := load("res://demo/agent_playwright.tscn")
	if not T.require_true(self, packed is PackedScene, "agent_playwright.tscn should load"):
		return

	var mock := MockOpenAgentic.new()
	mock.name = "OpenAgentic"
	get_root().add_child(mock)

	var scene := (packed as PackedScene).instantiate()
	scene.set("agent_enabled", true)
	scene.set("browser_enabled", false)
	scene.set("auto_navigate_on_ready", false)
	scene.set("agent_proxy_base_url", "http://127.0.0.1:8787/v1")
	scene.set("agent_model", "gpt-4.1-mini")
	get_root().add_child(scene)

	await process_frame

	var input := scene.get_node_or_null("ChatOverlay/Panel/VBox/InputRow/ChatInput") as LineEdit
	var output := scene.get_node_or_null("ChatOverlay/Panel/VBox/ChatOutput") as RichTextLabel
	var status := scene.get_node_or_null("ChatOverlay/Panel/VBox/ChatStatusLabel") as Label
	var send := scene.get_node_or_null("ChatOverlay/Panel/VBox/InputRow/ChatSendButton") as Button

	if not T.require_true(self, input != null and output != null and status != null and send != null, "chat nodes should exist"):
		return

	input.text = "open page and check title"
	send.emit_signal("pressed")

	var deadline := Time.get_ticks_msec() + 4_000
	while Time.get_ticks_msec() <= deadline:
		if String(status.text).contains("Agent done"):
			break
		await process_frame

	if not T.require_true(self, String(status.text).contains("Agent done"), "chat turn should finish"):
		return
	await process_frame

	var transcript := _rich_text(output)
	print("CHAT_TRANSCRIPT=", transcript)
	if not T.require_true(self, transcript.contains("[user] open page and check title"), "should include user line"):
		return
	if not T.require_true(self, transcript.contains("[tool] use browser_title"), "should include tool.use"):
		return
	if not T.require_true(self, transcript.contains("[tool] result"), "should include tool.result"):
		return
	if not T.require_true(self, transcript.contains("[assistant] Ack: open page and check title"), "should include assistant stream output"):
		return

	if not T.require_true(self, not send.disabled, "send button should be enabled after turn"):
		return
	if not T.require_true(self, input.editable, "input should be editable after turn"):
		return

	get_root().remove_child(scene)
	scene.free()
	get_root().remove_child(mock)
	mock.free()
	await process_frame

	T.pass_and_quit(self)


func _rich_text(label: RichTextLabel) -> String:
	if label == null:
		return ""
	if label.has_method("get_parsed_text"):
		return String(label.call("get_parsed_text"))
	return String(label.text)
