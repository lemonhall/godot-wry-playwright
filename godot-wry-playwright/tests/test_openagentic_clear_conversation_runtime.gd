extends SceneTree

const T := preload("res://tests/_test_util.gd")
const OPEN_AGENTIC_SCRIPT := preload("res://addons/openagentic/OpenAgentic.gd")
const OA_PATHS := preload("res://addons/openagentic/core/OAPaths.gd")


func _init() -> void:
	await process_frame

	var save_id := "test_clear_conv_%d" % Time.get_unix_time_from_system()
	var npc_id := "npc_clear_case"

	var oa := OPEN_AGENTIC_SCRIPT.new()
	oa.set_save_id(save_id)
	get_root().add_child(oa)

	if not oa.has_method("clear_npc_conversation"):
		T.fail_and_quit(self, "OpenAgentic.clear_npc_conversation should exist")
		return

	var events_path := OA_PATHS.npc_events_path(save_id, npc_id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OA_PATHS.npc_session_dir(save_id, npc_id)))
	var seed_file := FileAccess.open(events_path, FileAccess.WRITE)
	if seed_file == null:
		T.fail_and_quit(self, "failed to seed events file")
		return
	seed_file.store_string("{\"seq\":1,\"type\":\"test\"}\n")
	seed_file.close()

	var before := T.read_text_file(events_path)
	if not T.require_true(self, bool(before.get("ok", false)), "seeded events file should be readable"):
		return
	if not T.require_true(self, String(before.get("text", "")).strip_edges() != "", "events file should be non-empty before clear"):
		return

	var result: Dictionary = oa.call("clear_npc_conversation", npc_id)
	if not T.require_true(self, bool(result.get("ok", false)), "clear_npc_conversation should succeed"):
		return

	var after := T.read_text_file(events_path)
	if not T.require_true(self, bool(after.get("ok", false)), "events file should still be readable after clear"):
		return
	if not T.require_eq(self, String(after.get("text", "")), "", "events file should be empty after clear"):
		return

	get_root().remove_child(oa)
	oa.free()
	await process_frame

	T.pass_and_quit(self)

