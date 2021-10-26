extends Reference
class_name Segments


# -------------------------------------------------------------------------
# Variables
# -------------------------------------------------------------------------
var _segments = {}
var _active_segment = ""

# -------------------------------------------------------------------------
# Override Methods
# -------------------------------------------------------------------------
func _init():
	_init_default_segments()

# -------------------------------------------------------------------------
# Private Methods
# -------------------------------------------------------------------------
func _init_default_segments() -> void:
	if not _segments.empty():
		_segments.clear()
	
	for seg_name in GASM_Segment.get_default_segment_names():
		var seg = GASM_Segment.get_segment(seg_name)
		if seg.start >= 0 and seg.start <= 0xFF00:
			add_segment(seg_name, seg.start, seg.bytes)
		else:
			print("WARNING: 'Default' segment '", seg_name, "' has invalid starting address.")


# -------------------------------------------------------------------------
# Public Methods
# -------------------------------------------------------------------------
func reset() -> void:
	_init_default_segments()


func add_segment(seg_name : String, start : int, bytes : int, auto_activate : bool = false) -> void:
	if not seg_name in _segments:
		_segments[seg_name] = {"start": start, "bytes": bytes, "data": [], "PC": 0}
		if _active_segment == "" or auto_activate:
			_active_segment = seg_name


func process_counter(offset_only : bool = false) -> int:
	if offset_only:
		return _segments[_active_segment].PC
	return _segments[_active_segment].start + _segments[_active_segment].PC


func move_process_counter(amount : int = 1) -> void:
	if amount > 0:
		_segments[_active_segment].PC += amount


func set_activate_segment(seg_name : String) -> void:
	if seg_name in _segments:
		_active_segment = seg_name


func get_active_segment() -> String:
	return _active_segment


func push_data_line(data : Array, owner_id : int, line : int, col : int) -> void:
	if data.size() > 0:
		_segments[_active_segment].data.append({
			"offset": _segments[_active_segment].PC,
			"data": data,
			"owner_id": owner_id,
			"line": line,
			"col": col
		})
		var last = _segments[_active_segment].PC
		_segments[_active_segment].PC += data.size()
		print("Last PC: ", last, " | Current PC: ", _segments[_active_segment].PC)


func find_line_in_segment(seg_name : String, owner_id : int, idx : int) -> Dictionary:
	if seg_name in _segments:
		for e in _segments[seg_name].data:
			if e is Dictionary and e.owner_id == owner_id and e.line == idx:
				print(e)
				return {
					"addr": _segments[seg_name].start + e.offset,
					"line": idx,
					"data": PoolByteArray(e.data)
				}
	return {"addr": -1, "line": 0, "data": null}


func find_line_in_segments(owner_id : int, idx : int) -> Dictionary:
	for seg_name in _segments:
		var line = find_line_in_segment(seg_name, owner_id, idx)
		if line.data != null:
			return line
	return {"addr": -1, "line": 0, "data": null}


func get_lines(owner_id : int, start : int, end :int) -> Array:
	var lines = []
	if start >= 0 and end >= start:
		for i in range(start, end + 1):
			var line = find_line_in_segments(owner_id, i)
			if line.data != null:
				lines.append(line)
	return lines

