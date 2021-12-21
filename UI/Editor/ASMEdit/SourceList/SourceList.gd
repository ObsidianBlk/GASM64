extends "res://Theme/Scripts/Theme_PanelContainer.gd"
tool


# -------------------------------------------------------------------------
# Consts and Signals
# -------------------------------------------------------------------------
signal selected_source(source_name, source_type)

const SOURCE_LIST_ITEM = preload("res://UI/Editor/ASMEdit/SourceList/SourceListItem.tscn")
const RESNAMEDIALOG = preload("res://UI/Editor/ResNameDialog/ResNameDialog.tscn")

# -------------------------------------------------------------------------
# Export Variables
# -------------------------------------------------------------------------


# -------------------------------------------------------------------------
# Variables
# -------------------------------------------------------------------------
var _project : Project = null
var _resource_dialog_node : WindowDialog = null

# -------------------------------------------------------------------------
# Onready Variables
# -------------------------------------------------------------------------
onready var list_node : VBoxContainer = get_node("VBC/ScrollContainer/List")
onready var resourcefilter_node : OptionButton = get_node("VBC/Resources/ResourceFilter")
onready var createbtn_node : Button = get_node("VBC/Resources/Create")

# -------------------------------------------------------------------------
# Override Methods
# -------------------------------------------------------------------------
func _ready() -> void:
	GASM_Project.connect("project_loaded", self, "_on_project_loaded")
	
	if has_icon("Add", "EditorIcons"):
		createbtn_node.icon = get_icon("Add", "EditorIcons")
	createbtn_node.connect("pressed", self, "_on_create_resource")
	
	var first_item = true
	for key in GASM_Project.RESOURCE_TYPE.keys():
		resourcefilter_node.add_item(key, GASM_Project.RESOURCE_TYPE[key])
		if first_item:
			resourcefilter_node.select(GASM_Project.RESOURCE_TYPE[key])
			first_item = false
	
	_on_project_loaded()

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

func _CreateListItem(source_name : String, source_type : int) -> void:
	if not _HasListItem(source_name):
		var source_item = SOURCE_LIST_ITEM.instance()
		source_item.source_name = source_name
		source_item.source_type = source_type
		list_node.add_child(source_item)
		source_item.connect("selected", self, "_on_source_item_selected")

func _RemoveListItem(source_name : String) -> void:
	var list_item = _GetListItem(source_name)
	if list_item:
		list_node.remove_child(list_item)
		list_item.queue_free()

func _UpdateProjectResource() -> void:
	if not _project:
		return
	
	list_node.clear()
	var resources = _project.get_resource_list()
	for resource in resources:
		var stype = resourcefilter_node.get_selected_id()
		if resource.type == stype:
			_CreateListItem(resource.name, resource.type)


# -------------------------------------------------------------------------
# Public Methods
# -------------------------------------------------------------------------
#func add_source(source_name : String) -> void:
#	_CreateListItem(source_name)

# -------------------------------------------------------------------------
# Handler Methods
# -------------------------------------------------------------------------

func _on_project_loaded() -> void:
	var proj = GASM_Project.get_project()
	if proj:
		_project = proj

func _on_create_resource() -> void:
	if not _project:
		return
	
	if _resource_dialog_node == null:
		_resource_dialog_node = RESNAMEDIALOG.instance()
		add_child(_resource_dialog_node)
		var res_type : int = resourcefilter_node.get_selected_id()
		var res_type_name : String = resourcefilter_node.get_item_text(res_type)
		_resource_dialog_node.window_title = "Create %s" % [res_type_name]
		_resource_dialog_node.connect("accepted", self, "_on_new_resource", [res_type])
		_resource_dialog_node.connect("canceled", self, "_on_cancel_create_resource")
		_resource_dialog_node.popup_centered()

func _on_cancel_create_resource() -> void:
	if _resource_dialog_node != null:
		remove_child(_resource_dialog_node)
		_resource_dialog_node.queue_free()
		_resource_dialog_node = null

func _on_new_resource(res_name : String, res_type : int) -> void:
	if not _project:
		return

	match res_type:
		Project.RESOURCE_TYPE.ASSEMBLY:
			_project.add_assembly_resource(res_name)
			_CreateListItem(res_name, res_type)
	_on_cancel_create_resource()

func _on_source_item_selected(source_name : String, source_type : int) -> void:
	for child in list_node.get_children():
		if child.has_method("is_selected") and child.is_selected() and child.source_name != source_name and child.source_type == source_type:
			child.select(false)
	emit_signal("selected_source", source_name, source_type)

