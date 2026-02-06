extends Control
class_name WryView

signal completed(request_id: int, ok: bool, result_json: String, error: String)

@export var auto_start: bool = true
@export var initial_url: String = ""
@export var initial_timeout_ms: int = 10_000

var _browser: WryBrowser
var _started: bool = false


func _ready() -> void:
	_browser = WryBrowser.new()
	add_child(_browser)
	_browser.completed.connect(func(id: int, ok: bool, result_json: String, error: String) -> void:
		completed.emit(id, ok, result_json, error)
	)

	set_process(true)

	if auto_start:
		_try_start()
		if initial_url != "":
			goto(initial_url, initial_timeout_ms)


func _process(_delta: float) -> void:
	if _started:
		var rect := get_global_rect()
		_browser.set_view_rect(int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y))


func _exit_tree() -> void:
	if is_instance_valid(_browser):
		_browser.stop()


func _try_start() -> void:
	if _started:
		return

	var rect := get_global_rect()
	_started = _browser.start_view(
		int(rect.position.x),
		int(rect.position.y),
		max(1, int(rect.size.x)),
		max(1, int(rect.size.y))
	)


func goto(url: String, timeout_ms: int = 10_000) -> int:
	if not _started:
		_try_start()
	return _browser.goto(url, timeout_ms)


func eval(js: String, timeout_ms: int = 5_000) -> int:
	if not _started:
		_try_start()
	return _browser.eval(js, timeout_ms)


func click(selector: String, timeout_ms: int = 5_000) -> int:
	if not _started:
		_try_start()
	return _browser.click(selector, timeout_ms)


func fill(selector: String, text: String, timeout_ms: int = 5_000) -> int:
	if not _started:
		_try_start()
	return _browser.fill(selector, text, timeout_ms)


func wait_for_selector(selector: String, timeout_ms: int = 5_000) -> int:
	if not _started:
		_try_start()
	return _browser.wait_for_selector(selector, timeout_ms)


func stop() -> void:
	_started = false
	if is_instance_valid(_browser):
		_browser.stop()
