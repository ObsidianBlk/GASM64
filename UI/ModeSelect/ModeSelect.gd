extends Container
tool

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------
signal mode_change(mode)


# -------------------------------------------------------------------------
# Export Variables
# -------------------------------------------------------------------------
export (String, "game", "editor") var initial_mode = "game"
export var game_mode_icon : String = "World"		setget set_game_mode_icon
export var editor_mode_icon : String = "Edit"		setget set_editor_mode_icon

# -------------------------------------------------------------------------
# Variables
# -------------------------------------------------------------------------
var button_group : ButtonGroup = null
var node_visible : bool = true
var num_available : int = 0
var available_modes : Dictionary = {
	"game": {"node":null, "enabled":true},
	"editor": {"node":null, "enabled":true}
}


# -------------------------------------------------------------------------
# Onready Variables
# -------------------------------------------------------------------------
onready var gamemode_node : ToolButton = get_node("GameMode")
onready var editormode_node : ToolButton = get_node("EditorMode")

# -------------------------------------------------------------------------
# Setter / Getter
# -------------------------------------------------------------------------
func set_visible(v : bool) -> void:
	node_visible = v
	_UpdateVisibility()

func set_game_mode_icon(ico : String) -> void:
	game_mode_icon = ico
	if gamemode_node:
		gamemode_node.icon = get_icon(game_mode_icon, "EditorIcons")

func set_editor_mode_icon(ico : String) -> void:
	editor_mode_icon = ico
	if editormode_node:
		editormode_node.icon = get_icon(editor_mode_icon, "EditorIcons")

# -------------------------------------------------------------------------
# Override Methods
# -------------------------------------------------------------------------
func _ready() -> void:
	set_game_mode_icon(game_mode_icon)
	set_editor_mode_icon(editor_mode_icon)
	button_group = ButtonGroup.new()
	gamemode_node.group = button_group
	editormode_node.group = button_group
	
	button_group.connect("pressed", self, "_on_mode_change")
	
	available_modes["game"].node = gamemode_node
	available_modes["editor"].node = editormode_node
	if not Engine.editor_hint:
		call_deferred("_EmitInitialChoice")

# -------------------------------------------------------------------------
# Private Methods
# -------------------------------------------------------------------------
func _EmitInitialChoice() -> void:
	available_modes[initial_mode].node.pressed = true


func _UpdateVisibility() -> void:
	.set_visible(node_visible == true and num_available > 1)


func _UpdateAvailableModes() -> void:
	num_available = 0
	var switch_mode = false
	for mode in available_modes:
		var modedef = available_modes[mode]
		num_available += 1 if modedef.enabled == true else 0
		if modedef.enabled == false and modedef.node.pressed == true:
			switch_mode = true
		modedef.node.visible = modedef.enabled
		
	if switch_mode:
		for mode in available_modes:
			if available_modes[mode].enabled == true:
				available_modes[mode].node.pressed = true
	_UpdateVisibility()


func _UpdateButtonNodeColor(btn : ToolButton) -> void:
	if btn.pressed:
		btn.self_modulate = btn.get_color("font_color_pressed")
	else:
		btn.self_modulate = btn.get_color("font_color")


func _UpdateButtonColors() -> void:
	_UpdateButtonNodeColor(gamemode_node)
	_UpdateButtonNodeColor(editormode_node)

# -------------------------------------------------------------------------
# Public Methods
# -------------------------------------------------------------------------
func enable_mode(mode : String, enable : bool = true) -> void:
	if mode in available_modes:
		available_modes[mode].enabled = enable
		_UpdateAvailableModes()


# -------------------------------------------------------------------------
# Handler Methods
# -------------------------------------------------------------------------
func _on_mode_change(btn : Object) -> void:
	_UpdateButtonColors()
	if btn == gamemode_node:
		emit_signal("mode_change", "game")
	elif btn == editormode_node:
		emit_signal("mode_change", "editor")


