extends Node


# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------
signal unsaved_project

# -------------------------------------------------------------------------
# Constants
# -------------------------------------------------------------------------
const PROJECT_FOLDER : String = "user://projects/"

# -------------------------------------------------------------------------
# Variables
# -------------------------------------------------------------------------
var _available_projects : Array = []

var _active_project : Project = null
var _active_project_dirty : bool = false
var _errors : Array = []

# -------------------------------------------------------------------------
# Onready Variables
# -------------------------------------------------------------------------


# -------------------------------------------------------------------------
# Override Methods
# -------------------------------------------------------------------------
func _ready() -> void:
	_LoadProjectList()

# -------------------------------------------------------------------------
# Private Methods
# -------------------------------------------------------------------------
func _StoreError(func_name : String, msg : String) -> void:
	_errors.append({
		"msg": msg,
		"func": func_name
	})


func _LoadProjectList() -> void:
	var dir = Directory.new()
	if dir.open(PROJECT_FOLDER) == OK:
		_available_projects.clear()
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var header = load_info(PROJECT_FOLDER + file_name, true)
				if header != null:
					_available_projects.append(header)
				else:
					print("WARNING: Failed to load possible project file '" + file_name + "'.");
			file_name = dir.get_next()


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


func _GetResourceChunkInfo(buffer : PoolByteArray, offset : int):
	if offset >= 0 and offset < buffer.size() - 4:
		var chunk_size = Utils.buffer_to_int(buffer, offset, 4)
		offset += 4
		if offset + chunk_size > buffer.size():
			_StoreError("_GetResourceBlockInfo", "Read Chunk size exceeds buffer bounds.")
			return null
		var size = Utils.buffer_to_int(buffer, offset, 2)
		offset += 2
		var res_name = Utils.buffer_to_int(buffer, offset, size)
		offset += size
		var isRef = buffer[offset] == 1
		return {"chunk_size":chunk_size, "resource_name": res_name, "isRef":isRef}
	else:
		_StoreError("_GetResourceBlockInfo", "Offset is out of bounds.")
	return null


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


func _ProcessAssemblyBuffer(proj : Project, buffer : PoolByteArray, offset : int, count : int) -> bool:
	if offset >= 0 and offset < buffer.size():
		var index = 0
		for _i in range(0, count):
			var block_size = Utils.buffer_to_int(buffer, offset + index, 4)
			if _errors.size() > 0:
				return false
			index += 4
			
			if offset + block_size > buffer.size():
				_StoreError("_ProcessAssemblyBuffer", "Given block size exceeds available block data.")
				return false
			
			var size = Utils.buffer_to_int(buffer, offset + index, 2)
			var res_name = Utils.buffer_to_string(buffer, offset + index + 2, size)
			index += 2 + size
			
			var isRef = buffer[offset + index]
			index += 1
			if isRef:
				size = Utils.buffer_to_int(buffer, offset + index, 2)
				index += 2
				var ref = Utils.buffer_to_string(buffer, offset + index, size)
				proj.add_assembly_resource(res_name, {"reference_project_id": ref})
			else:
				var src_size = Utils.buffer_to_int(buffer, offset + index, 2)
				index += 2
				
				size = Utils.buffer_to_int(buffer, offset + index, 2)
				var source = Utils.buffer_to_string(buffer, offset + index + 2, size, src_size)
				index += 2 + size
				
				var main = buffer[offset + index] == 1
				index += 1
				
				proj.add_assembly_resource(res_name, {"source":source, "is_main":main})
		return true
	else:
		_StoreError("_ProcessAssemblyBuffer", "Offset outside of buffer boundry.")
	return false


func _Save_Project(path : String, proj : Project) -> bool:
	var file = File.new()
	if file.open(path, File.WRITE) == OK:
		
		file.store_buffer("GPRJ".to_utf8())
		file.store_buffer(PoolByteArray(Project.FILE_VERSION))
		
		var size = 0
		var buffer = proj.get_project_id().to_utf8()
		file.store_16(buffer.size())
		file.store_buffer(buffer)
		
		buffer = proj.get_project_name().to_utf8()
		file.store_16(buffer.size())
		file.store_buffer(buffer)
		
		buffer = proj._GenerateBuffers()
		
		file.store_32(buffer.index.size())
		file.store_64(buffer.blocks.size())
		file.store_buffer(buffer.index)
		file.store_buffer(buffer.blocks)
		
		file.close()
		return true
	return false


func _Load_Project(path : String) -> Project:
	var file = File.new()
	if file.open(path, File.READ) == OK:
		var header = _LoadProjectHeader(file, "load")
		if header == null:
			file.close()
			return null
		
		var proj : Project = Project.new(header.project_id)
			
		var idx_block_size = file.get_32()
		var res_block_size = file.get_64()
		
		var index = _ProcessIndexBuffer(file.get_buffer(idx_block_size))
		if _errors.size() > 0:
			file.close()
			return null
		
		var resource_buffer = file.get_buffer(res_block_size)
		file.close()

		for entry in index:
			match entry.resid:
				Project.RESOURCE_TYPE.ASSEMBLY:
					if not _ProcessAssemblyBuffer(proj, resource_buffer, entry.offset, entry.count):
						return null
		return proj
	return null

# -------------------------------------------------------------------------
# Public Methods
# -------------------------------------------------------------------------
func get_project_list() -> Array:
	return _available_projects.duplicate(true)


func is_dirty() -> bool:
	if _active_project != null:
		return _active_project.is_dirty()
	return false


func new_project(name : String, force : bool = false) -> void:
	if _active_project != null and _active_project.is_dirty() and force == false:
		emit_signal("unsaved_project")
		return

	_active_project = Project.new()
	_active_project.set_project_name(name)


func get_project() -> Project:
	return _active_project

func get_assembler(resource_name):
	if _active_project != null:
		var resource = _active_project.get_assembly_resource(resource_name)
		if "assembler" in resource:
			return resource.assembler
	return null


func save_project() -> bool:
	if _active_project == null:
		return true
	var path = PROJECT_FOLDER + "GP_" + _active_project.get_project_id().to_upper() + ".gproj"
	var res = _Save_Project(path, _active_project)
	if res:
		_active_project._ClearDirty()
	return res


func load_project(id : String, force : bool = false) -> bool:
	if _active_project != null and _active_project.is_dirty() and force == false:
		emit_signal("unsaved_project")
		return false
	
	var nproj = _Load_Project(PROJECT_FOLDER + "GP_" + id.to_upper() + ".gproj")
	if nproj != null:
		_active_project = nproj
		_active_project._ClearDirty()
		return true
	return false


func import_project(os_path : String) -> bool:
	# TODO: This was quickly roughed out... may need some security checks.
	var imp_proj = _Load_Project(os_path)
	if imp_proj != null:
		var path = PROJECT_FOLDER + "GP_" + imp_proj.get_project_id().to_upper() + ".gproj"
		var res = _Save_Project(path, imp_proj)
		return res
	return false


func load_info(path : String, only_header : bool = false):
	var info = null
	var file = File.new()
	if file.open(PROJECT_FOLDER + path, File.READ) == OK:
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
				var resource = _GetResourceChunkInfo(blocks, entry.offset + idx)
				if resource != null:
					idx += resource.chunk_size
					resource.erase("chunk_size")
					info.resources[entry.resid].append(resource)
				else:
					return null
	return info


