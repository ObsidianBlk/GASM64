extends Node


# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------
signal unsaved_project

# -------------------------------------------------------------------------
# Constants
# -------------------------------------------------------------------------


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
	if dir.open(Project.FOLDER) == OK:
		_available_projects.clear()
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var header = load_info(Project.FOLDER + file_name, true)
				if header != null:
					_available_projects.append(header)
				else:
					print("WARNING: Failed to load possible project file '" + file_name + "'.");
			file_name = dir.get_next()


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


func get_project():
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
	return _active_project.save()


func load_project(id : String, force : bool = false) -> bool:
	if _active_project != null and _active_project.is_dirty() and force == false:
		emit_signal("unsaved_project")
		return false

	var nproj = Project.new(id)
	if nproj.load():
		_active_project = nproj
		return true
	return false


func import_project(os_path : String) -> bool:
	# TODO: This was quickly roughed out... may need some security checks.
	var imp_proj : Project = Project.new()
	if imp_proj.load({"path":os_path}):
		var path = imp_proj.get_project_filepath(true)
		return imp_proj.save({"path":path})
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


