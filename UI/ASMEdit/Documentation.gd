extends Control

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
const OP_COLOR = Color(1.0, 0.0, 0.0)
const MODE_COLOR = Color(0.0, 1.0, 0.0)

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
var category_list = null
var category_selidx = -1
# ---------------------------------------------------------------------------
# OnReady Variables
# ---------------------------------------------------------------------------
onready var display_node : TextEdit = $Display
onready var filtercat_node : OptionButton = $FilterBox/MC/FilterList/FilterCategory/Options

# ---------------------------------------------------------------------------
# Override Methods
# ---------------------------------------------------------------------------
func _ready() -> void:
	# -- Setting "Keyword" colors for the display...
	var ops = GASM.get_ops()
	for i in range(0, ops.size()):
		display_node.add_keyword_color(ops[i], OP_COLOR)

	for i in range(0, GASM.MODE_NAMES.size()):
		display_node.add_keyword_color(GASM.MODE_NAMES[i], MODE_COLOR)
	
	# -- Filling the category dropdown list...
	filtercat_node.add_item("All Categories", -1)
	category_list = GASM.get_categories()
	if category_list.size() > 0:
		for i in range(0, category_list.size()):
			filtercat_node.add_item(category_list[i], i)
	else:
		category_list = null
	
	_update_docs()

# ---------------------------------------------------------------------------
# Private Methods
# ---------------------------------------------------------------------------

func _update_docs() -> void:
	var oplist : Array = []
	if category_selidx < 0 or category_list == null:
		oplist = GASM.get_ops()
	else:
		oplist = GASM.get_ops_from_category(category_list[category_selidx])
	
	# -- Start Doc Rendering...
	var text : String = ""
	for op_name in oplist:
		var op : Dictionary = GASM.get_op_info(op_name)
		var op_text = "%s\n\tName: %s\n\tCategory: %s\n\tDescription: %s\n\tAffected Flags:%s\n%s"
		var mode_text : String = ""
		for mode in op.modes:
			op.modes[mode].name = mode
			var t = "\t{name}\n\t\tHex: {opcode}\n\t\tBytes: {bytes}\n\t\tCycles: {cycles}".format(op.modes[mode])
			if op.modes[mode].success > 0:
				t += "\n\t\t\tOn Success +%d cycles" % [op.modes[mode].success]
			if op.modes[mode].pagecross > 0:
				t += "\n\t\t\tAdd +%d cycles when crossing page boundry" % [op.modes[mode].pagecross]
			mode_text += t + "\n\n"
		text += op_text % [op_name, op.name, op.category, op.description, op.flags, mode_text]
	display_node.text = text

# ---------------------------------------------------------------------------
# Public Methods
# ---------------------------------------------------------------------------



# ---------------------------------------------------------------------------
# Handler Methods
# ---------------------------------------------------------------------------

func _on_Category_item_selected(index : int) -> void:
	category_selidx = index
	if category_list == null or index < 0 or index >= category_list.size():
		category_selidx = -1
	_update_docs()
