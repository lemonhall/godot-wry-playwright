extends Node

var _browser
var _goto_id: int = -1
var _eval_id: int = -1

func _ready() -> void:
	_browser = WryBrowser.new()
	add_child(_browser)
	_browser.completed.connect(_on_completed)

	var ok: bool = _browser.start()
	print("browser.start() => ", ok)

	_goto_id = _browser.goto("https://example.com", 10_000)
	print("goto id => ", _goto_id)


func _on_completed(request_id: int, ok: bool, result_json: String, error: String) -> void:
	print("completed id=", request_id, " ok=", ok, " result_json=", result_json, " error=", error)

	if request_id == _goto_id and ok:
		_eval_id = _browser.eval("() => document.title", 5_000)
		print("eval id => ", _eval_id)
	elif request_id == _eval_id and ok:
		print("document.title (JSON) => ", result_json)
