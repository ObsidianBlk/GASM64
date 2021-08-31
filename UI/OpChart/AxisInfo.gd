extends PanelContainer



enum AXISMODE {CORNER=0, XAXIS=1, YAXIS=2}

export (AXISMODE) var axis_mode = AXISMODE.CORNER		setget set_axis_mode
export var text : String = ""							setget set_text


var style_corner = preload("res://UI/OpChart/AxisCornerPanelStyle.tres")
var style_xaxis = preload("res://UI/OpChart/AxisXPanelStyle.tres")
var style_yaxis = preload("res://UI/OpChart/AxisYPanelStyle.tres")

onready var text_node = get_node("Label")


func set_text(t : String) -> void:
	text = t
	if text_node:
		text_node.text = text

func set_axis_mode(m : int) -> void:
	if m >= 0 and m < 3:
		axis_mode = m
		match axis_mode:
			AXISMODE.CORNER:
				set("custom_styles/panel", style_corner)
			AXISMODE.XAXIS:
				set("custom_styles/panel", style_xaxis)
			AXISMODE.YAXIS:
				set("custom_styles/panel", style_yaxis)

func _ready() -> void:
	set_axis_mode(axis_mode)
	set_text(text)
