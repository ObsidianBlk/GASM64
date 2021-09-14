extends MenuButton


signal quit


func _ready() -> void:
	var popup : PopupMenu = get_popup()
	popup.add_item("Quit", 0)
	popup.connect("id_pressed", self, "_on_quit_pressed")


func _on_quit_pressed(id : int) -> void:
	if id == 0:
		emit_signal("quit")
