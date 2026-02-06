extends Control

@onready var view: WryView = %WryView

var _goto_id: int = -1
var _eval_id: int = -1


func _ready() -> void:
	view.completed.connect(_on_completed)
	_goto_id = view.goto("https://www.baidu.com/", 10_000)


func _on_completed(request_id: int, ok: bool, result_json: String, error: String) -> void:
	print("completed id=", request_id, " ok=", ok, " result_json=", result_json, " error=", error)

	if request_id == _goto_id and ok:
		_eval_id = view.eval("() => document.title", 5_000)
	elif request_id == _eval_id and ok:
		print("document.title (JSON) => ", result_json)
