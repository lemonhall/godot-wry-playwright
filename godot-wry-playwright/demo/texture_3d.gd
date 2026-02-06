extends Node3D

@onready var screen: MeshInstance3D = %Screen

var _browser: WryTextureBrowser
var _tex: ImageTexture
var _reveal: float = 1.0
var _frame_count: int = 0
var _frozen_after_first_frame: bool = false

const CAPTURE_W := 1024
const CAPTURE_H := 768
const CAPTURE_FPS := 3
const FREEZE_AFTER_FIRST_FRAME := true

const REVEAL_SPEED := 0.45 # ~2.2s to full reveal (visual simulation)


func _ready() -> void:
	_browser = WryTextureBrowser.new()
	add_child(_browser)

	_browser.completed.connect(func(id: int, ok: bool, result_json: String, error: String) -> void:
		print("completed id=", id, " ok=", ok, " result_json=", result_json, " error=", error)
	)
	_browser.frame_png.connect(_on_frame_png)

	var ok := _browser.start_texture(CAPTURE_W, CAPTURE_H, CAPTURE_FPS)
	print("browser.start_texture => ", ok)

	_browser.goto("https://example.com", 10_000)


func _process(delta: float) -> void:
	if _reveal < 1.0:
		_reveal = min(1.0, _reveal + delta * REVEAL_SPEED)
		_set_reveal(_reveal)


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

	var mat := screen.get_active_material(0) as ShaderMaterial
	mat.set_shader_parameter("web_tex", _tex)

	# Start a reveal only on the first frame, or after the previous reveal finished.
	# Otherwise we'd keep resetting on every capture tick and might look "blank".
	if _reveal >= 1.0 or _frame_count == 1:
		_reveal = 0.0
		_set_reveal(_reveal)

	if FREEZE_AFTER_FIRST_FRAME and _frame_count == 1:
		_frozen_after_first_frame = true
		print("frame capture frozen after first frame")
		_browser.call_deferred("stop")


func _set_reveal(v: float) -> void:
	var mat := screen.get_active_material(0) as ShaderMaterial
	mat.set_shader_parameter("reveal", v)
