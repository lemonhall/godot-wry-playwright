extends Node3D

var _browser

@onready var holder: Control = %BrowserHolder

func _ready() -> void:
	_browser = WryBrowser.new()
	add_child(_browser)
	_browser.completed.connect(func(id: int, ok: bool, result_json: String, error: String) -> void:
		print("completed id=", id, " ok=", ok, " result_json=", result_json, " error=", error)
	)

	var rect := holder.get_global_rect()
	_browser.start_view(int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y))
	_browser.goto("https://example.com", 10_000)


func _process(_delta: float) -> void:
	var rect := holder.get_global_rect()
	_browser.set_view_rect(int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y))
