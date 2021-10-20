extends Node


# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------
signal segment_created(seg_name, addr, size)
signal segment_dropped(seg_name)
signal segment_changed(seg_name, addr, size)


# -------------------------------------------------------------------------
# Variables
# -------------------------------------------------------------------------

var _SEG : Dictionary = {
	"ZEROPAGE": {"start":0x0000, "size":1, "locked": true, "changable": false},
	"CODE": {"start":0x2000, "size":80, "locked": true, "changable": true},
	"DATA": {"start":0x7000, "size":40, "locked": true, "changable": true},
	"BSS": {"start":0x9800, "size":80, "locked": true, "changable": true}
}


var rx_varname : RegEx= null

# -------------------------------------------------------------------------
# Override Methods
# -------------------------------------------------------------------------
func _ready() -> void:
	rx_varname = RegEx.new()
	rx_varname.compile("^[a-zA-Z_$][a-zA-Z_$0-9]*$")


# -------------------------------------------------------------------------
# Private Methods
# -------------------------------------------------------------------------
func _SegmentNameValid(seg_name : String) -> bool:
	return rx_varname.search(seg_name) != null


# -------------------------------------------------------------------------
# Public Methods
# -------------------------------------------------------------------------
func get_segment_names() -> Array:
	return _SEG.keys()

func get_default_segment_names() -> Array:
	return ["ZEROPAGE", "CODE", "DATA", "BSS"]

func get_segment(seg_name : String) -> Dictionary:
	if seg_name in _SEG:
		return {
			"start": _SEG[seg_name].start,
			"size": _SEG[seg_name].size,
			"bytes": _SEG[seg_name].size * 256
		}
	return {"start": -1, "size": -1, "bytes": -1}

func get_segment_bytes(seg_name : String) -> int:
	return get_segment(seg_name).bytes


func set_segment(seg_name : String, start_page : int, size : int) -> void:
	if not _SegmentNameValid(seg_name):
		print("ERROR: Invalid segment name '", seg_name, "'.")
		return
	if start_page < 0 or start_page > 0xFF:
		print("ERROR: Starting page is out of bounds")
		return
	if size < 0 or (start_page << 8) + (size * 256) > 0xFFFF:
		print("ERROR: Size is invalid or outside maximum memory range.")
		return
	
	var added = false
	if not seg_name in _SEG:
		_SEG[seg_name] = {"start":0x0000, "size":1, "locked": false, "changable": true}
		added = true
	
	if _SEG[seg_name].changable:
		_SEG[seg_name].start = (start_page << 8)
		_SEG[seg_name].size = size
		if added:
			emit_signal("segment_created", seg_name, _SEG[seg_name].start, _SEG[seg_name].size)
		else:
			emit_signal("segment_changed", seg_name, _SEG[seg_name].start, _SEG[seg_name].size)


func drop_segment(seg_name : String) -> void:
	if seg_name in _SEG:
		if not _SEG[seg_name].locked:
			_SEG.erase(seg_name)
			emit_signal("segment_dropped", seg_name)


# -------------------------------------------------------------------------
# Handler Methods
# -------------------------------------------------------------------------


