extends Reference
class_name Project


# -------------------------------------------------------------------------
# Constants and ENUMs
# -------------------------------------------------------------------------
const FILE_VERSION = [0, 1]

enum RESOURCE_TYPE {ASSEMBLY}

# -------------------------------------------------------------------------
# Variables
# -------------------------------------------------------------------------
var _project_id = ""
var _project_name = "Project"
var _data = {}
var _errors = []

# -------------------------------------------------------------------------
# Override Methods
# -------------------------------------------------------------------------
func _init(id : String = "") -> void:
	if id == "":
		if id.length() == 24 and id.is_valid_hex_number() :
			_project_id = id
	if id == "":
		id = Utils.uuidv4(true)


# -------------------------------------------------------------------------
# Private Utility Methods
# -------------------------------------------------------------------------
func _StoreError(func_name : String, msg : String) -> void:
	_errors.append({
		"msg": msg,
		"func": func_name
	})

func _Reset() -> void:
	_errors = []
	_data = {}

func _ClearCurrentAssemblyMain() -> void:
	if RESOURCE_TYPE.ASSEMBLY in _data:
		var asm = _data[RESOURCE_TYPE.ASSEMBLY]
		for resource in asm:
			if asm[resource].main == true:
				asm[resource].main = false
				break

func _GetOwnedResources(resid : int) -> Array:
	var resources = []
	if resid in _data:
		var res = _data[resid].keys()
		for key in res:
			if _data[resid][key].alive == true and _data[resid][key].ref == "":
				resources.append(key)
	return resources

# -------------------------------------------------------------------------
# Private Save/Load Helper Methods
# -------------------------------------------------------------------------
func _LoadProjectHeader(file : File, func_name : String):
	var magic = file.get_buffer(4).get_string_from_utf8()
	if magic != "GPROJ":
		_StoreError(func_name, "File missing magic string 'GPROJ'.")
		file.close()
		return false
	
	var version = file.get_buffer(2)
	if version[0] != 0:
		_StoreError(func_name, "Unknown major version number {v1}.".format({"v1": version[0]}))
		file.close()
		return false
	
	if version[1] != 1:
		_StoreError(func_name, "Minor version number {v2} is unknown.".format({"v2": version[1]}))
		file.close()
		return false
	
	var size = file.get_16()
	var project_id = file.get_buffer(size).get_string_from_utf8()
	size = file.get_16()
	var project_name = file.get_buffer(size).get_string_from_utf8()

	return {"project_id":project_id, "project_name": project_name, "version": version}

func _GetResourcechunkInfo(buffer : PoolByteArray, offset : int):
	if offset >= 0 and offset < buffer.size() - 4:
		var chunk_size = _BufferToInt(buffer, offset, 4)
		offset += 4
		if offset + chunk_size > buffer.size():
			_StoreError("_GetResourceBlockInfo", "Read Chunk size exceeds buffer bounds.")
			return null
		var size = _BufferToInt(buffer, offset, 2)
		offset += 2
		var res_name = _BufferToString(buffer, offset, size)
		offset += size
		var isRef = buffer[offset] == 1
		return {"chunk_size":chunk_size, "resource_name": res_name, "isRef":isRef}
	else:
		_StoreError("_GetResourceBlockInfo", "Offset is out of bounds.")
	return null

func _IntToBuffer(val : int, bytes : int) -> PoolByteArray:
	var buffer = []
	for i in range(0, bytes):
		var chunk = val >> (((bytes - 1) - i) * 8)
		buffer.append(chunk & 0xFF)
	return PoolByteArray(buffer)


func _SubBuffer(buffer : PoolByteArray, sidx : int, eidx : int) -> PoolByteArray:
	if not (sidx >= 0 and sidx < buffer.size() and eidx >= 0 and eidx < buffer.size() and sidx >= eidx):
		_StoreError("_SubBuffer", "Buffer offset out of bounds.")
		return PoolByteArray([])
	return buffer.subarray(sidx, eidx)

func _BufferToInt(buffer : PoolByteArray, offset : int, bytes : int) -> int:
	if offset >= 0 and offset < buffer.size() and offset + bytes <= buffer.size():
		var sub : PoolByteArray = _SubBuffer(buffer, offset, offset + (bytes - 1))
		if _errors.size() <= 0:
			var val = 0
			for i in range(0, bytes):
				val = val | (sub[i] << (((bytes - 1) - i) * 8))
			return val
	else:
		_StoreError("_BufferToInt", "Buffer offset with range out of bounds.")
	return -1

func _BufferToString(buffer : PoolByteArray, offset : int, bytes : int, decompressed_size : int = 0) -> String:
	if offset >= 0 and offset < buffer.size() and offset + bytes <= buffer.size():
		var sub = buffer.subarray(offset, offset+(bytes - 1))
		if decompressed_size > 0:
			sub = sub.decompress(decompressed_size, File.COMPRESSION_GZIP)
		return sub.get_string_from_utf8()
	return "";

func _ProcessIndexBuffer(index : PoolByteArray) -> Array:
	var arr = []
	
	var entries : int = int(floor(index.size() / 6))
	if entries * 6 != index.size():
		_StoreError("_ProcessIndexBuffer", "Index data does not align to entry size.")
		return arr
	
	for e in range(0, entries):
		var idx = e * 6
		var resid = index[idx]
		var count = index[idx + 1]
		var offset = (index[idx + 2] << 24) | (index[idx + 3] << 16) | (index[idx + 4] << 8) | index[idx + 5]
		arr.append({
			"resid": resid,
			"count": count,
			"offset": offset
		})
	
	return arr

func _ProcessAssemblyBuffer(buffer : PoolByteArray, offset : int, count : int) -> bool:
	if offset >= 0 and offset < buffer.size():
		var index = 0
		for _i in range(0, count):
			var block_size = _BufferToInt(buffer, offset + index, 4)
			if _errors.size() > 0:
				return false
			index += 4
			
			if offset + block_size > buffer.size():
				_StoreError("_ProcessAssemblyBuffer", "Given block size exceeds available block data.")
				return false
			
			var size = _BufferToInt(buffer, offset + index, 2)
			var res_name = _BufferToString(buffer, offset + index + 2, size)
			index += 2 + size
			
			var isRef = buffer[offset + index]
			index += 1
			if isRef:
				size = _BufferToInt(buffer, offset + index, 2)
				index += 2
				var ref = _BufferToString(buffer, offset + index, size)
				add_assembly_resource(res_name, {"reference_project_id": ref})
			else:
				var src_size = _BufferToInt(buffer, offset + index, 2)
				index += 2
				
				size = _BufferToInt(buffer, offset + index, 2)
				var source = _BufferToString(buffer, offset + index + 2, size, src_size)
				index += 2 + size
				
				var main = buffer[offset + index] == 1
				index += 1
				
				add_assembly_resource(res_name, {"source":source, "is_main":main})
		return true
	else:
		_StoreError("_ProcessAssemblyBuffer", "Offset outside of buffer boundry.")
	return false


# -------------------------------------------------------------------------
# Public Methods
# -------------------------------------------------------------------------
func error_count() -> int:
	return _errors.size()

func get_error(idx : int):
	if idx >= 0 and idx < _errors.size():
		return _errors[idx]
	return null

func set_project_name(proj_name : String) -> void:
	_project_name = proj_name

func get_project_name() -> String:
	return _project_name

func get_resource_names(resource_type : int) -> Array:
	if resource_type in _data:
		return _data[resource_type].keys()
	return []

func add_assembly_resource(resource_name : String, options : Dictionary = {}) -> void:
	if not RESOURCE_TYPE.ASSEMBLY in _data:
		_data[RESOURCE_TYPE.ASSEMBLY] = {}
	var asm = _data[RESOURCE_TYPE.ASSEMBLY]
	
	var ref = "" if not ("reference_project_id" in options) else options.reference_project_id
	if ref != "":
		var res = ref.split("@")
		if res.size() != 2:
			_StoreError("add_assembly_resource", "Reference string malformed.")
			return;
		if res[0].size() != 24:
			_StoreError("add_assembly_resource", "Reference project ID invalid.")
			return
		# TODO: Verify res[0] is a large hex value.
		# TODO: Verify res[1] is a valid resource_name
		# TODO: Verify res[0] project exists.
	# TODO: Verify resource existance.
	
	var source = ""
	var assembler = null
	var is_main = false
	
	if ref == "":
		source = "" if not ("source" in options) else options.source
		assembler = null if not ("assembler" in options) else options.assembler
		if assembler != null and not assembler is Assembler:
			_StoreError("add_assembly_resource", "Invalid object type given for Assembler.")
			return
	
		if ref == "" and "is_main" in options:
			is_main = options.is_main == true
	 
	if not (resource_name in asm):
		asm[resource_name] = {
			"ref": ref,
			"source": source,
			"assembler": assembler,
			"main": is_main,
			"alive": true
		}


func drop_assembly_resource(resource_name : String) -> void:
	if RESOURCE_TYPE.ASSEMBLY in _data:
		var asm = _data[RESOURCE_TYPE.ASSEMBLY]
		for resource in asm:
			if resource == resource_name:
				asm[resource_name].alive = false

func get_assembly_resource(resource_name : String) -> Dictionary:
	if RESOURCE_TYPE.ASSEMBLY in _data:
		var asm = _data[RESOURCE_TYPE.ASSEMBLY]
		if resource_name in asm:
			if asm[resource_name].alive:
				# TODO: If Reg has a value, load that reference project to get the data.
				return {
					"text": asm[resource_name].text,
					"assembler": asm[resource_name].assembler,
					"main": asm[resource_name].main
				}
	return {"text":"", "assembler":null, "main":false}


func set_assembly_resource_main(resource_name : String, is_main : bool = true) -> void:
	if RESOURCE_TYPE.ASSEMBLY in _data:
		var asm = _data[RESOURCE_TYPE.ASSEMBLY]
		if resource_name in asm:
			if asm[resource_name].ref == "":
				if is_main:
					if asm[resource_name].main != true:
						_ClearCurrentAssemblyMain()
						asm[resource_name].main = true
				else:
					asm[resource_name].main = false

func set_assembly_resource_source(resource_name : String, src : String) -> void:
	if RESOURCE_TYPE.ASSEMBLY in _data:
		var asm = _data[RESOURCE_TYPE.ASSEMBLY]
		if resource_name in asm:
			asm[resource_name].source = src



# -------------------------------------------------------------------------
# Public Save/Load Methods
# -------------------------------------------------------------------------

func generate_index_block_buffers() -> Dictionary:
	var index = PoolByteArray()
	var blocks = PoolByteArray()
	
	var offset = 0
	for resid in _data.keys():
		var resources = _GetOwnedResources(resid)
		if resources.size() <= 0:
			continue
		
		index.append(resid)
		index.append(resources.size())
		index.append_array(_IntToBuffer(offset, 4))
		var block = PoolByteArray()
		
		for res_name in resources:
			match resid:
				RESOURCE_TYPE.ASSEMBLY:
					var buffer = res_name.to_utf8()
					var size = buffer.size()
					# TODO: Do I really think the "Resource name" is going to need more than a BYTE
					# to store it's length?!
					block.append_array(_IntToBuffer(size, 2))
					block.append_array(buffer)
					
					if _data[resid][res_name].ref != "":
						block.append(1) # This identifies this block as a "reference" resource.
						buffer = _data[resid][res_name].ref.to_utf8()
						size = buffer.size()
						block.append_array(_IntToBuffer(size, 2))
						block.append_array(buffer)
					else:
						block.append(0) # This identifies this block as a "local" resource.
						buffer = _data[resid][res_name].source.to_utf8()
						size = buffer.size()
						block.append_array(_IntToBuffer(size, 2))
						
						buffer = buffer.compress(File.COMPRESSION_GZIP)
						size = buffer.size()
						block.append_array(_IntToBuffer(size, 2))
						block.append_array(buffer)
						
						# TODO: Do I want to save the Parser AST tree as well?
						# For now... I'll just rebuild the source.
						
						block.append(
							1 if _data[resid][res_name].main else 0
						)
		offset += block.size() + 4
		blocks.append_array(_IntToBuffer(block.size(), 4))
		blocks.append_array(block)
	return {"index":index, "blocks":blocks}


func save(path : String) -> bool:
	var file = File.new()
	if file.open("user://" + path, File.WRITE) == OK:
		
		file.store_buffer("GPRJ".to_utf8())
		file.store_buffer(PoolByteArray(FILE_VERSION))
		
		var size = 0
		var buffer = _project_id.to_utf8()
		file.store_16(buffer.size())
		file.store_buffer(buffer)
		
		buffer = _project_name.to_utf8()
		file.store_16(buffer.size())
		file.store_buffer(buffer)
		
		buffer = generate_index_block_buffers()
		
		file.store_32(buffer.index.size())
		file.store_64(buffer.blocks.size())
		file.store_buffer(buffer.index)
		file.store_buffer(buffer.blocks)
		
		file.close()
		return true
	return false


func load(path : String) -> bool:
	var file = File.new()
	if file.open("user://" + path, File.READ) == OK:
		_Reset()
		var header = _LoadProjectHeader(file, "load")
		if header == null:
			file.close()
			return false
		
		_project_id = header.project_id
		_project_name = header.project_name
		
		var idx_block_size = file.get_32()
		var res_block_size = file.get_64()
		
		var index = _ProcessIndexBuffer(file.get_buffer(idx_block_size))
		if _errors.size() > 0:
			# Not storing an error. It's assumed _ProcessIndexBuffer did that... hence the if statement we're in.
			file.close()
			return false
		
		var blocks = file.get_buffer(res_block_size)
		file.close()
		
		for entry in index:
			match entry.resid:
				RESOURCE_TYPE.ASSEMBLY:
					if not _ProcessAssemblyBuffer(blocks, entry.offset, entry.count):
						return false
		
		return true
	return false


func load_info(path : String, only_header : bool = false):
	var info = null
	var file = File.new()
	if file.open("user://" + path, File.READ) == OK:
		info = _LoadProjectHeader(file, "load_header")
		if info == null or only_header:
			file.close()
			return null if info == null else info
		
		info["resources"] = {}
		var idx_block_size = file.get_32()
		var res_block_size = file.get_64()
		
		var index = _ProcessIndexBuffer(file.get_buffer(idx_block_size))
		if _errors.size() > 0:
			# Not storing an error. It's assumed _ProcessIndexBuffer did that... hence the if statement we're in.
			file.close()
			return null
		
		var blocks = file.get_buffer(res_block_size)
		file.close()
		
		for entry in index:
			info.resources[entry.resid] = []
			var idx = 0
			for _i in range(0, entry.count):
				var resource = _GetResourcechunkInfo(blocks, entry.offset + idx)
				if resource != null:
					idx += resource.chunk_size
					resource.erase("chunk_size")
					info.resources[entry.resid].append(resource)
				else:
					return null
	return info


