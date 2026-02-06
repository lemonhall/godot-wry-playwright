extends Node3D

@onready var screen: MeshInstance3D = %WebScreen
@onready var camera_3d: Camera3D = %Camera3D

var _browser: WryTextureBrowser
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

const CAPTURE_W := 1024
const CAPTURE_H := 768
const CAPTURE_FPS := 3
const FREEZE_AFTER_FIRST_FRAME := true
const TARGET_URL := "https://www.baidu.com/"

const REVEAL_SPEED := 0.45 # ~2.2s to full reveal (visual simulation)
const ORBIT_SENS := 0.008
const PAN_SENS := 0.002
const ZOOM_STEP := 0.55
const MIN_DIST := 2.0
const MAX_DIST := 12.0


func _ready() -> void:
	if not InputMap.has_action("reload_page"):
		InputMap.add_action("reload_page")
	var key_5 := InputEventKey.new()
	key_5.keycode = KEY_5
	if not InputMap.action_has_event("reload_page", key_5):
		InputMap.action_add_event("reload_page", key_5)

	_update_camera_transform()

	_browser = WryTextureBrowser.new()
	add_child(_browser)

	_browser.completed.connect(func(id: int, completed_ok: bool, result_json: String, error: String) -> void:
		print("completed id=", id, " ok=", completed_ok, " result_json=", result_json, " error=", error)
		if id > 0 and completed_ok:
			_begin_navigation_cycle()
	)
	_browser.frame_png.connect(_on_frame_png)

	var started := _browser.start_texture(CAPTURE_W, CAPTURE_H, CAPTURE_FPS)
	print("browser.start_texture => ", started)

	_begin_navigation_cycle()
	_browser.goto(TARGET_URL, 10_000)


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

	# Start a reveal only on the first frame, or after the previous reveal finished.
	# Otherwise we'd keep resetting on every capture tick and might look "blank".
	if _reveal >= 1.0 or _frame_count == 1:
		_reveal = 0.0
		_set_reveal(_reveal)

	if FREEZE_AFTER_FIRST_FRAME and _frame_count == 1:
		_frozen_after_first_frame = true
		print("frame capture frozen after first frame")


func _begin_navigation_cycle() -> void:
	_frozen_after_first_frame = false
	_frame_count = 0
	_reveal = 1.0
	_set_reveal(_reveal)


func _reload_page() -> void:
	if _browser == null:
		return
	print("reload_page key=5")
	_begin_navigation_cycle()
	_browser.goto(TARGET_URL, 10_000)


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
