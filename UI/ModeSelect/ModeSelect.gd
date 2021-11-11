extends Container

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------
signal mode_change(mode)

# -------------------------------------------------------------------------
# Variables
# -------------------------------------------------------------------------
var button_group : ButtonGroup = null

# -------------------------------------------------------------------------
# Onready Variables
# -------------------------------------------------------------------------
onready var gamemode_node : ToolButton = get_node("GameMode")
onready var editormode_node : ToolButton = get_node("EditorMode")

# -------------------------------------------------------------------------
# Override Methods
# -------------------------------------------------------------------------
func _ready() -> void:
	button_group = ButtonGroup.new()
	gamemode_node.group = button_group
	editormode_node.group = button_group
	
	button_group.connect("pressed", self, "_on_mode_change")

# -------------------------------------------------------------------------
# Private Methods
# -------------------------------------------------------------------------



# -------------------------------------------------------------------------
# Public Methods
# -------------------------------------------------------------------------


# -------------------------------------------------------------------------
# Handler Methods
# -------------------------------------------------------------------------
func _on_mode_change(btn : Object) -> void:
	if btn == gamemode_node:
		emit_signal("mode_change", "game")
	elif btn == editormode_node:
		emit_signal("mode_change", "editor")

