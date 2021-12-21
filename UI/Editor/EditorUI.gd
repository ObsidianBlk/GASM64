extends Control

# -------------------------------------------------------------------------
# Export Variables
# -------------------------------------------------------------------------
export var bus_node_path : NodePath = ""			setget set_bus_node_path
export var cpu_node_path : NodePath = ""			setget set_cpu_node_path
export (int, 1, 30) var memory_monitor_ups = 10		setget set_memory_monito_ups

# -------------------------------------------------------------------------
# Variables
# -------------------------------------------------------------------------


# -------------------------------------------------------------------------
# Onready Variables
# -------------------------------------------------------------------------
onready var mem_monitor_node = get_node("Toolset/Sidebar/Monitor")

onready var projectscreen_node = get_node("ProjectScreen")
onready var toolset_node = get_node("Toolset")
onready var sourcelist_node = get_node("Toolset/Sidebar/Sources")

onready var toolset = {
	asmedit_node = get_node("Toolset/ASMEdit")
}


# -------------------------------------------------------------------------
# Setters / Getters
# -------------------------------------------------------------------------
func set_bus_node_path(path : NodePath) -> void:
	bus_node_path = path
	var node : Node = get_node(path)
	if mem_monitor_node and node:
		path = mem_monitor_node.get_path_to(node)
		mem_monitor_node.bus_node_path = path

func set_cpu_node_path(path : NodePath) -> void:
	cpu_node_path = path
	var node : Node = get_node(path)
	if mem_monitor_node and node:
		path = mem_monitor_node.get_path_to(node)
		mem_monitor_node.cpu_node_path = path

func set_memory_monito_ups(ups : int) -> void:
	memory_monitor_ups = ups
	if mem_monitor_node:
		mem_monitor_node.updates_per_second = memory_monitor_ups


# -------------------------------------------------------------------------
# Override Methods
# -------------------------------------------------------------------------
func _ready() -> void:
	set_bus_node_path(bus_node_path)
	set_cpu_node_path(cpu_node_path)
	set_memory_monito_ups(memory_monitor_ups)
	
	projectscreen_node.connect("edit_project", self, "_on_edit_project")
	sourcelist_node.connect("selected_source", self, "_on_selected_source")


# -------------------------------------------------------------------------
# Private Methods
# -------------------------------------------------------------------------
func _HideAllTools() -> void:
	for tool_node in toolset:
		tool_node.visible = false

func _ShowTool(tool_name : String) -> void:
	if tool_name in toolset:
		if not toolset[tool_name].visible:
			_HideAllTools()
			toolset[tool_name].visible = true

# -------------------------------------------------------------------------
# Public Methods
# -------------------------------------------------------------------------


# -------------------------------------------------------------------------
# Handler Methods
# -------------------------------------------------------------------------

func _on_edit_project() -> void:
	projectscreen_node.visible = false
	toolset_node.visible = true


func _on_selected_source(source_name, source_type) -> void:
	var proj : Project = GASM_Project.get_project()
	if proj:
		if proj.has_resource(source_type, source_name):
			var res_info = proj.get_resource(source_type, source_name)
			match source_type:
				Project.RESOURCE_TYPE.ASSEMBLY:
					_ShowTool("asmedit_node")
					toolset.asmedit_node.set_source(source_name)
