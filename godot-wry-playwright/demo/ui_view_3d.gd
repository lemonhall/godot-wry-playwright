extends Node3D

@onready var view: WryView = %WryView


func _ready() -> void:
	view.completed.connect(func(id: int, ok: bool, result_json: String, error: String) -> void:
		print("completed id=", id, " ok=", ok, " result_json=", result_json, " error=", error)
	)
	view.goto("https://example.com", 10_000)

