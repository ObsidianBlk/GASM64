extends Node


# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------
signal segment_created(seg_name, addr, size)
signal segment_dropped(seg_name)
signal segment_changed(seg_name, addr, size)
signal segment_overlap(sega_name, segb_name, from_addr, size)


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

func _EmitOverlaps(seg_name : String) -> void:
	var overlaps = get_segment_overlaps(seg_name)
	if overlaps.size() > 0:
		for overlap in overlaps:
			emit_signal("segment_overlap", overlap.segA, overlap.segB, overlap.start, overlap.size)

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
		_EmitOverlaps(seg_name)


func drop_segment(seg_name : String) -> void:
	if seg_name in _SEG:
		if not _SEG[seg_name].locked:
			_SEG.erase(seg_name)
			emit_signal("segment_dropped", seg_name)

func segments_overlap(segA : String, segB : String):
	if segA != segB:
		var bytes = _SEG[segA].bytes
		var startA = _SEG[segA].start
		var endA = (startA + bytes) - 1
		
		bytes = _SEG[segB].bytes
		var startB = _SEG[segB].start
		var endB = (startB + bytes) - 1
		
		if startA <= endB and endA >= startB:
			var start = startA if startA >= startB else startB
			var end = endA if endA <= endB else endB
			return {"start": start, "size": (end - start)}
	return null

func get_segment_overlaps(seg_name : String) -> Array:
	var overlaps = []
	
	for seg in _SEG:
		if seg != seg_name:
			var overlap = segments_overlap(seg_name, seg)
			if overlap != null:
				overlaps.append({
					"segA": seg_name,
					"segB": seg,
					"start": overlap.start,
					"size": overlap.size
				})
	return overlaps

# -------------------------------------------------------------------------
# Handler Methods
# -------------------------------------------------------------------------


