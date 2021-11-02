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
var _project_name = "Project"
var _data = {}
var _errors = []

# -------------------------------------------------------------------------
# Override Methods
# -------------------------------------------------------------------------
func _init(src : String) -> void:
	pass


# -------------------------------------------------------------------------
# Private Utility Methods
# -------------------------------------------------------------------------
func _StoreError(func_name : String, msg : String) -> void:
	_errors.append({
		"msg": msg,
		"func": func_name
	})

func _Reset() -> void:
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
			# TODO: Need to check if index is out of bounds at any point!!!
			
			var size = buffer[offset + index] << 8 | buffer[offset + index + 1]
			var res_name = buffer.subarray(offset+index+2, offset+index+2+(size - 1)).get_string_from_utf8()
			index += 2 + size
			
			var tex_size = buffer[offset + index] << 8 | buffer[offset + index + 1]
			index += 2
			
			size = buffer[offset + index] << 8 | buffer[offset + index + 1]
			var text = buffer.subarray(offset+index+2, offset+index+2+(size - 1))
			text = text.uncompress(tex_size, File.COMPRESSION_GZIP).get_string_from_utf8()
			index += 2 + size
			
			var main = buffer[offset + index] == 1
			index += 1
			
			add_assembly_resource(res_name, text, main)
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

func add_assembly_resource_reference(resource_name : String, reference_source : String = "") -> void:
	if not RESOURCE_TYPE.ASSEMBLY in _data:
		_data[RESOURCE_TYPE.ASSEMBLY] = {}
	var asm = _data[RESOURCE_TYPE.ASSEMBLY]
	var res_name = resource_name
	if reference_source != "":
		res_name = "@" + res_name
		
	asm[res_name] = {
		"ref": null if reference_source == "" else reference_source,
		"text": "",
		"assembler": null,
		"main": false,
		"alive": true
	}


func add_assembly_resource(resource_name : String, src : String, is_main : bool = false) -> void:
	if not RESOURCE_TYPE.ASSEMBLY in _data:
		_data[RESOURCE_TYPE.ASSEMBLY] = {}
	var asm = _data[RESOURCE_TYPE.ASSEMBLY]
	if not (resource_name in asm):
		asm[resource_name] = {
			"ref": "",
			"text": "",
			"assembler": null,
			"main": false,
			"alive": true
		}
	asm[resource_name].text = src
	asm[resource_name].main = is_main


func get_assembly_resource(resource_name : String) -> Dictionary:
	if RESOURCE_TYPE.ASSEMBLY in _data:
		var asm = _data[RESOURCE_TYPE.ASSEMBLY]
		if resource_name in asm:
			if asm[resource_name].alive:
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
			asm[resource_name].text = src


func drop_assembly_resource(resource_name : String) -> void:
	if RESOURCE_TYPE.ASSEMBLY in _data:
		var asm = _data[RESOURCE_TYPE.ASSEMBLY]
		for resource in asm:
			if resource == resource_name:
				asm[resource_name].alive = false


# -------------------------------------------------------------------------
# Public Save/Load Methods
# -------------------------------------------------------------------------

func save(path : String) -> bool:
	var file = File.new()
	if file.open("user://" + path, File.WRITE) == OK:
		
		file.store_buffer("GPRJ".to_utf8())
		file.store_buffer(PoolByteArray(FILE_VERSION))
		
		var size = 0
		var buffer = _project_name.to_utf8()
		file.store_16(buffer.size())
		file.store_buffer(buffer)
		
		var index = PoolByteArray()
		var blocks = PoolByteArray()
		
		var offset = 0
		for resid in _data.keys():
			var resources = _GetOwnedResources(resid)
			if resources.size() <= 0:
				continue
			
			index.append(resid)
			index.append(resources.size())
			index.append((offset & 0xFF000000) >> 24)
			index.append((offset & 0x00FF0000) >> 16)
			index.append((offset & 0x0000FF00) >> 8)
			index.append(offset & 0x000000FF)
			var block = PoolByteArray()
			
			for res_name in resources:
				match resid:
					RESOURCE_TYPE.ASSEMBLY:
						buffer = res_name.to_utf8()
						size = buffer.size()
						# TODO: Do I really think the "Resource name" is going to need more than a BYTE
						# to store it's length?!
						block.append((size & 0xFF00) >> 8)
						block.append(size & 0xFF)
						block.append_array(buffer)
						
						buffer = _data[resid][res_name].text.to_utf8()
						size = buffer.size()
						block.append((size & 0xFF00) >> 8)
						block.append(size & 0xFF)
						
						buffer = buffer.compress(File.COMPRESSION_GZIP)
						size = buffer.size()
						block.append((size & 0xFF00) >> 8)
						block.append(size & 0xFF)
						block.append_array(buffer)
						
						# TODO: Do I want to save the Parser AST tree as well?
						# For now... I'll just rebuild the source.
						
						block.append(
							1 if _data[resid][res_name].main else 0
						)
			offset += block.size()
			blocks.append_array(block)
		
		file.store_32(index.size())
		file.store_32(blocks.size())
		file.store_buffer(index)
		file.store_buffer(blocks)
		
		file.close()
		return true
	return false


func load(path : String) -> bool:
	var file = File.new()
	if file.open("user://" + path, File.READ) == OK:
		_Reset()
	
		var magic = file.get_buffer(4).get_string_from_utf8()
		if magic != "GPROJ":
			_StoreError("load", "File missing magic string 'GPROJ'.")
			file.close()
			return false
		
		var version = file.get_buffer(2)
		if version[0] != 0:
			_StoreError("load", "Unknown major version number {v1}.".format({"v1": version[0]}))
			file.close()
			return false
		
		if version[1] != 1:
			_StoreError("load", "Minor version number {v2} is unknown.".format({"v2": version[1]}))
			file.close()
			return false
		
		var size = file.get_16()
		_project_name = file.get_buffer(size).get_string_from_utf8()
		
		var idx_block_size = file.get_32()
		var res_block_size = file.get_32()
		
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

# -------------------------------------------------------------------------
# Handler Methods
# -------------------------------------------------------------------------

