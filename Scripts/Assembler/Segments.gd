extends Reference
class_name Segments

# TODO: Segment PC start values should be adjusted by an assembler.


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

func get_segment_names() -> Array:
	return _segments.keys()

func get_segment_info(seg_name : String) -> Dictionary:
	if seg_name in _segments:
		return {"start":_segments[seg_name].start, "bytes":_segments[seg_name].bytes}
	return {}

func get_segment_start_address(seg_name : String) -> int:
	if seg_name in _segments:
		return _segments[seg_name].start
	return 0

func get_segment_byte_size(seg_name : String) -> int:
	if seg_name in _segments:
		return _segments[seg_name].bytes
	return 0

func get_segment_byte_count(seg_name : String) -> int:
	if seg_name in _segments:
		return _segments[seg_name].PC
	return 0


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


func push_assembler_segments(seg : Segments, line : int, col : int) -> void:
	var seg_names : Array = seg.get_segment_names()
	for seg_name in seg_names:
		var process = true
		
		if not seg_name in _segments:
			var seg_info = seg.get_segment_info(seg_name)
			if seg_info.empty():
				process = false
			else:
				add_segment(seg_name, seg_info.start, seg_info.bytes)
		
		if process:
			_segments[seg_name].data.append({
				"offset": _segments[seg_name].PC,
				"segment": seg,
				"line": line,
				"col": col,
			})
			_segments[seg_name].PC += seg.get_segment_byte_count(seg_name)


func push_data_line(data : Array, line : int, col : int) -> void:
	if data.size() > 0:
		_segments[_active_segment].data.append({
			"offset": _segments[_active_segment].PC,
			"data": data,
			"line": line,
			"col": col,
		})
		_segments[_active_segment].PC += data.size()


func get_initial_bytes(seg_name : String, entry_count : int) -> Array:
	var data : Array = []
	if seg_name in _segments:
		for e in range(entry_count):
			if e < _segments[seg_name].data.size():
				if "data" in _segments[seg_name].data[e]:
					data.append_array(_segments[seg_name].data[e].data)
				elif "segment" in _segments[seg_name].data[e]:
					data.append_array(_segments[seg_name].data[e].segment /
							.get_initial_bytes(seg_name, 2))
	return data


func find_line_in_segment(seg_name : String, idx : int) -> Dictionary:
	if seg_name in _segments:
		for e in _segments[seg_name].data:
			if e is Dictionary and e.line == idx:
				var data : Array
				if "data" in e:
					data = e.data
				else:
					data = e.segment.get_initial_bytes(seg_name, 2)
				
				return {
					"addr": _segments[seg_name].start + e.offset,
					"line": idx,
					"data": PoolByteArray(data)
				}
	return {"addr": -1, "line": 0, "data": null}


func find_line_in_segments(idx : int) -> Dictionary:
	for seg_name in _segments:
		var line = find_line_in_segment(seg_name, idx)
		if line.data != null:
			return line
	return {"addr": -1, "line": 0, "data": null}


func get_lines(start : int, end :int) -> Array:
	var lines = []
	if start >= 0 and end >= start:
		for i in range(start, end + 1):
			var line = find_line_in_segments(i)
			if line.data != null:
				lines.append(line)
	return lines

