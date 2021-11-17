extends "res://Theme/Scripts/Theme_PanelContainer.gd"
tool


# -------------------------------------------------------------------------
# Consts and Signals
# -------------------------------------------------------------------------
signal selected_source(source_name)

const SOURCE_LIST_ITEM = preload("res://UI/ASMEdit/SourceList/SourceListItem.tscn")

# -------------------------------------------------------------------------
# Export Variables
# -------------------------------------------------------------------------


# -------------------------------------------------------------------------
# Variables
# -------------------------------------------------------------------------


# -------------------------------------------------------------------------
# Onready Variables
# -------------------------------------------------------------------------
onready var list_node : VBoxContainer = get_node("ScrollContainer/List")

# -------------------------------------------------------------------------
# Override Methods
# -------------------------------------------------------------------------


# -------------------------------------------------------------------------
# Private Methods
# -------------------------------------------------------------------------

func _GetListItem(source_name : String) -> Node:
	for child in list_node.get_children():
		if "source_name" in child and child.source_name == source_name:
			return child
	return null

func _HasListItem(source_name : String) -> bool:
	return _GetListItem(source_name) != null

func _CreateListItem(source_name : String) -> void:
	if not _HasListItem(source_name):
		var source_item = SOURCE_LIST_ITEM.instance()
		source_item.source_name = source_name
		list_node.add_child(source_item)
		source_item.connect("selected", self, "_on_source_item_selected")

func _RemoveListItem(source_name : String) -> void:
	var list_item = _GetListItem(source_name)
	if list_item:
		list_node.remove_child(list_item)
		list_item.queue_free()


# -------------------------------------------------------------------------
# Public Methods
# -------------------------------------------------------------------------
func add_source(source_name : String) -> void:
	_CreateListItem(source_name)

# -------------------------------------------------------------------------
# Handler Methods
# -------------------------------------------------------------------------

func _on_new_source(source_name : String) -> void:
	_CreateListItem(source_name)

func _on_source_item_selected(source_name : String) -> void:
	for child in list_node.get_children():
		if child.has_method("is_selected") and child.is_selected() and child.source_name != source_name:
			child.select(false)

