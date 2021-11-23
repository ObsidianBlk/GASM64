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


# -------------------------------------------------------------------------
# Private Methods
# -------------------------------------------------------------------------



# -------------------------------------------------------------------------
# Public Methods
# -------------------------------------------------------------------------


# -------------------------------------------------------------------------
# Handler Methods
# -------------------------------------------------------------------------

func _on_edit_project():
	projectscreen_node.visible = false
	toolset_node.visible = true
