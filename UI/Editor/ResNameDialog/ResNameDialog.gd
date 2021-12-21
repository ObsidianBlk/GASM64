extends WindowDialog

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------
signal accepted(res_name)
signal canceled()

# -------------------------------------------------------------------------
# Export Variables
# -------------------------------------------------------------------------


# -------------------------------------------------------------------------
# Variables
# -------------------------------------------------------------------------


# -------------------------------------------------------------------------
# Onready Variables
# -------------------------------------------------------------------------
onready var accept_btn_node : Button = get_node("MC/VBC/Buttons/Accept")
onready var cancel_btn_node : Button = get_node("MC/VBC/Buttons/Cancel")
onready var resname_node : LineEdit = get_node("MC/VBC/ResourceName/LineEdit")

# -------------------------------------------------------------------------
# Override Methods
# -------------------------------------------------------------------------
func _ready() -> void:
	accept_btn_node.connect("pressed", self, "_on_accepted")
	cancel_btn_node.connect("pressed", self, "_on_canceled")

# -------------------------------------------------------------------------
# Private Methods
# -------------------------------------------------------------------------

func _Strip(v : String) -> String:
	return v.lstrip(" \t").rstrip(" \t")


# -------------------------------------------------------------------------
# Public Methods
# -------------------------------------------------------------------------


# -------------------------------------------------------------------------
# Handler Methods
# -------------------------------------------------------------------------
func _on_accepted() -> void:
	if resname_node.text != "":
		var resname = _Strip(resname_node.text)
		if resname != "":
			emit_signal("accepted", resname)


func _on_canceled() -> void:
	emit_signal("cancel")

