extends Control

@onready var browser_host: Control = %BrowserHost

var _session: WryPwSession
var _last_view_size: Vector2i = Vector2i.ZERO

var _goto_id: int = -1
var _eval_id: int = -1


func _ready() -> void:
	_session = WryPwSession.new()
	_session.auto_start = false
	add_child(_session)
	_session.completed.connect(_on_completed)
	set_process(true)

	var rect := browser_host.get_global_rect()
	_last_view_size = Vector2i(int(rect.size.x), int(rect.size.y))
	_goto_id = _session.open("https://www.baidu.com/", {
		"timeout_ms": 10_000,
		"view_rect": {
			"x": int(rect.position.x),
			"y": int(rect.position.y),
			"width": max(1, _last_view_size.x),
			"height": max(1, _last_view_size.y),
		},
	})


func _process(_delta: float) -> void:
	if _session == null:
		return

	var rect := browser_host.get_global_rect()
	var current_size := Vector2i(int(rect.size.x), int(rect.size.y))
	if current_size != _last_view_size:
		_last_view_size = current_size
		_session.resize(max(1, current_size.x), max(1, current_size.y))


func _on_completed(request_id: int, ok: bool, result_json: String, error: String) -> void:
	print("completed id=", request_id, " ok=", ok, " result_json=", result_json, " error=", error)

	if request_id == _goto_id and ok:
		_eval_id = _session.eval("() => document.title", "", 5_000)
	elif request_id == _goto_id and not ok and String(error).contains("webview_not_started"):
		var rect := browser_host.get_global_rect()
		_goto_id = _session.open("https://www.baidu.com/", {
			"timeout_ms": 10_000,
			"view_rect": {
				"x": int(rect.position.x),
				"y": int(rect.position.y),
				"width": max(1, int(rect.size.x)),
				"height": max(1, int(rect.size.y)),
			},
		})
	elif request_id == _eval_id and ok:
		print("document.title (JSON) => ", result_json)
