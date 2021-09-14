extends MenuButton

signal memmon(show)

var popup : PopupMenu = null

func _ready() -> void:
	popup = get_popup()
	popup.add_check_item("Memory Monitor", 0)
	popup.connect("id_pressed", self, "_on_memmon_pressed")


func _on_memmon_pressed(id : int) -> void:
	var idx = popup.get_item_index(id)
	if popup.is_item_checked(idx):
		popup.set_item_checked(idx, false)
		emit_signal("memmon", false)
	else:
		popup.set_item_checked(idx, true)
		emit_signal("memmon", true)
