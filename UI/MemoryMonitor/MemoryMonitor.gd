extends Control


# --------------------------------------------------------------------------
# Export Variables
# --------------------------------------------------------------------------
export var bus_node_path : NodePath = ""			setget set_bus_node_path
export (int, 1, 30) var updates_per_second = 10		setget set_updates_per_second

# --------------------------------------------------------------------------
# Variables
# --------------------------------------------------------------------------

var _bus : Bus = null
var _pageOffset : int = 0

var _utime = 0
var _utime_interval = 0

# --------------------------------------------------------------------------
# Onready Variables
# --------------------------------------------------------------------------
onready var PD1_node = get_node("VBC/HBC/PDContainer/VBC/PD1")
onready var PD2_node = get_node("VBC/HBC/PDContainer/VBC/PD2")

# --------------------------------------------------------------------------
# Setters / Getters
# --------------------------------------------------------------------------
func set_bus_node_path(p : NodePath) -> void:
	bus_node_path = p
	if bus_node_path != "":
		var bus = get_node(p)
		if bus is Bus:
			_bus = bus
	else:
		_bus = null


func set_updates_per_second(u : int) -> void:
	if u > 0 and u <= 30:
		updates_per_second = u
		_utime_interval = 1.0 / float(updates_per_second)

# --------------------------------------------------------------------------
# Override Methods
# --------------------------------------------------------------------------

func _ready() -> void:
	if bus_node_path != "" and _bus == null:
		set_bus_node_path(bus_node_path)

func _process(delta : float) -> void:
	_utime += delta
	if _utime >= _utime_interval:
		_utime -= _utime_interval
		_UpdateMonitor()
		

# --------------------------------------------------------------------------
# Private Methods
# --------------------------------------------------------------------------

func _UpdateMonitor() -> void:
	if not (_bus and PD1_node and PD2_node):
		return
	_UpdatePageDisplays()


func _UpdatePageDisplays() -> void:
	PD1_node.set_page(_pageOffset)
	PD1_node.set_data(_bus.page_dump(_pageOffset))
		
	PD2_node.set_page(_pageOffset+1)
	PD2_node.set_data(_bus.page_dump(_pageOffset+1))


# --------------------------------------------------------------------------
# Handler Methods
# --------------------------------------------------------------------------

func _on_PDSlider_value_changed(value):
	_pageOffset = 253 - int(value)
	if not (_bus and PD1_node and PD2_node):
		_UpdatePageDisplays()
