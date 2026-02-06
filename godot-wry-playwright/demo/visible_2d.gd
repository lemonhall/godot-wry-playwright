extends Control

var _browser
var _goto_id: int = -1
var _eval_id: int = -1

@onready var holder: Control = %BrowserHolder

func _ready() -> void:
	_browser = WryBrowser.new()
	add_child(_browser)
	_browser.completed.connect(_on_completed)

	var rect := holder.get_global_rect()
	var ok: bool = _browser.start_view(int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y))
	print("browser.start_view() => ", ok)

	_goto_id = _browser.goto("https://example.com", 10_000)


func _process(_delta: float) -> void:
	var rect := holder.get_global_rect()
	_browser.set_view_rect(int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y))


func _on_completed(request_id: int, ok: bool, result_json: String, error: String) -> void:
	print("completed id=", request_id, " ok=", ok, " result_json=", result_json, " error=", error)

	if request_id == _goto_id and ok:
		_eval_id = _browser.eval("() => document.title", 5_000)
	elif request_id == _eval_id and ok:
		print("document.title (JSON) => ", result_json)
