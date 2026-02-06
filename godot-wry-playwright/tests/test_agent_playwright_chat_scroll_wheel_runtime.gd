extends SceneTree

const T := preload("res://tests/_test_util.gd")


func _init() -> void:
	await process_frame

	var packed := load("res://demo/agent_playwright.tscn")
	if not T.require_true(self, packed is PackedScene, "agent_playwright.tscn should load"):
		return

	var scene := (packed as PackedScene).instantiate()
	scene.set("agent_enabled", false)
	scene.set("browser_enabled", false)
	get_root().add_child(scene)
	await process_frame

	var chat_output := scene.get_node_or_null("ChatOverlay/Panel/VBox/ChatOutput") as RichTextLabel
	if not T.require_true(self, chat_output != null, "ChatOutput should exist"):
		return

	for i in range(120):
		chat_output.append_text("line_%d\n" % i)
	await process_frame

	var scroll_bar := chat_output.get_v_scroll_bar()
	if not T.require_true(self, scroll_bar != null, "ChatOutput scrollbar should exist"):
		return

	scroll_bar.value = scroll_bar.max_value
	await process_frame
	var before := float(scroll_bar.value)

	var panel := scene.get_node_or_null("ChatOverlay/Panel") as Control
	if not T.require_true(self, panel != null, "chat panel should exist"):
		return
	var center := panel.get_global_rect().get_center()

	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	wheel_up.position = center
	wheel_up.global_position = center
	scene.call("_unhandled_input", wheel_up)
	await process_frame

	var after := float(scroll_bar.value)
	if not T.require_true(self, after < before, "wheel on chat panel should scroll chat up"):
		return

	get_root().remove_child(scene)
	scene.free()
	await process_frame

	T.pass_and_quit(self)

