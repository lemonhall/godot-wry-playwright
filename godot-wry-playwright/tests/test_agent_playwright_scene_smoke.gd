extends SceneTree

const T := preload("res://tests/_test_util.gd")


func _init() -> void:
	await process_frame

	var packed := load("res://demo/agent_playwright.tscn")
	if not T.require_true(self, packed is PackedScene, "agent_playwright.tscn should load"):
		return

	var root := (packed as PackedScene).instantiate()
	if not T.require_true(self, root is Node3D, "agent_playwright root should be Node3D"):
		return

	get_root().add_child(root)
	await process_frame

	if not T.require_true(self, root.get_node_or_null("Camera3D") != null, "Camera3D should exist"):
		return
	if not T.require_true(self, root.get_node_or_null("ComputerRoot/WebScreen") != null, "WebScreen should exist"):
		return
	if not T.require_true(self, root.get_node_or_null("ChatOverlay/Panel/VBox/ChatOutput") != null, "ChatOutput should exist"):
		return
	if not T.require_true(self, root.get_node_or_null("ChatOverlay/Panel/VBox/InputRow/ChatInput") != null, "ChatInput should exist"):
		return
	if not T.require_true(self, root.get_node_or_null("ChatOverlay/Panel/VBox/InputRow/ChatSendButton") != null, "ChatSendButton should exist"):
		return

	get_root().remove_child(root)
	root.free()
	await process_frame

	T.pass_and_quit(self)
