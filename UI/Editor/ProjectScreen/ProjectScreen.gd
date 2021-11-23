extends "res://Theme/Scripts/Theme_PanelContainer.gd"

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------
signal quit()
signal edit_project()


# -------------------------------------------------------------------------
# Export Variables
# -------------------------------------------------------------------------


# -------------------------------------------------------------------------
# Variables
# -------------------------------------------------------------------------
var selected_project_idx : int = -1

# -------------------------------------------------------------------------
# Onready Variables
# -------------------------------------------------------------------------
onready var projectnameline_node : LineEdit = get_node("HBC/LeftControls/ProjectName/Line")
onready var projectlist_node : ItemList = get_node("HBC/LeftControls/ProjectList")

onready var btn_create_node : Button = get_node("HBC/MarginContainer/Buttons/Create")
onready var btn_edit_node : Button = get_node("HBC/MarginContainer/Buttons/Edit")
onready var btn_remove_node : Button = get_node("HBC/MarginContainer/Buttons/Remove")
onready var btn_quit_node : Button = get_node("HBC/MarginContainer/Buttons/Quit")

# -------------------------------------------------------------------------
# Override Methods
# -------------------------------------------------------------------------
func _ready() -> void:
	GASM_Project.connect("project_added", self, "_on_project_added")
	GASM_Project.connect("project_removed", self, "_on_project_removed")
	
	btn_create_node.connect("pressed", self, "_on_create_new_project")
	btn_edit_node.connect("pressed", self, "_on_edit_project")
	btn_remove_node.connect("pressed", self, "_on_remove_project")
	btn_quit_node.connect("pressed", self, "_on_quit")
	
	projectnameline_node.connect("text_changed", self, "_on_projnameline_text_changed")
	
	projectlist_node.connect("item_selected", self, "_on_project_selected")
	
	var projects = GASM_Project.get_available_projects()
	for i in range(projects.size()):
		var proj = projects[i]
		projectlist_node.add_item(proj.name)
		projectlist_node.set_item_metadata(i, proj.id)

# -------------------------------------------------------------------------
# Private Methods
# -------------------------------------------------------------------------
func _UpdateProjectSelected() -> void:
	if selected_project_idx >= 0:
		btn_edit_node.disabled = false
		btn_remove_node.disabled = false
	else:
		btn_edit_node.disabled = true
		btn_remove_node.disabled = true


# -------------------------------------------------------------------------
# Public Methods
# -------------------------------------------------------------------------


# -------------------------------------------------------------------------
# Handler Methods
# -------------------------------------------------------------------------
func _on_project_added(id : String, project_name : String) -> void:
	var idx = projectlist_node.get_item_count()
	projectlist_node.add_item(project_name)
	projectlist_node.set_item_metadata(idx, id)


func _on_project_removed(id : String) -> void:
	for idx in range(projectlist_node.get_item_count()):
		var item_id = projectlist_node.get_item_metadata(idx)
		if item_id == id:
			projectlist_node.remove_item(idx)
			if idx == selected_project_idx:
				selected_project_idx = -1
				_UpdateProjectSelected()
			return

func _on_project_selected(idx : int) -> void:
	selected_project_idx = idx
	_UpdateProjectSelected()

func _on_projnameline_text_changed(txt : String) -> void:
	if txt == "":
		btn_create_node.disabled = true
	else:
		btn_create_node.disabled = false


func _on_create_new_project() -> void:
	if projectnameline_node.text != "":
		if GASM_Project.new_project(projectnameline_node.text, true):
			projectnameline_node.text = ""
			btn_create_node.disabled = true

func _on_remove_project() -> void:
	if selected_project_idx >= 0:
		var proj_id = projectlist_node.get_item_metadata(selected_project_idx)
		GASM_Project.delete_project(proj_id)

func _on_edit_project() -> void:
	if selected_project_idx >= 0:
		var proj_id = projectlist_node.get_item_metadata(selected_project_idx)
		if GASM_Project.load_project(proj_id):
			emit_signal("edit_project")

func _on_quit() -> void:
	emit_signal("quit")
