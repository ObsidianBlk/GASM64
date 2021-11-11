extends Node


# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------
signal unsaved_project
signal verify_project_removal

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
		var proj : Project = Project.new()
		while file_name != "":
			if not dir.current_is_dir():
				if proj.load({"path": Project.FOLDER + file_name, "stubbed":true}):
					_available_projects.append({
						"project_name": proj.get_project_name(),
						"project_id": proj.get_project_id(),
						"resources": {
							Project.RESOURCE_TYPE.ASSEMBLY: proj.get_resource_names(Project.RESOURCE_TYPE.ASSEMBLY)
						}
					})
				else:
					print("WARNING: Failed to load possible project file '" + file_name + "'.");
			file_name = dir.get_next()


# -------------------------------------------------------------------------
# Public Methods
# -------------------------------------------------------------------------
func get_available_projects() -> Array:
	var arr : Array = []
	for item in _available_projects:
		arr.append({"project_name": item.project_name, "project_id":item.project_id})
	return arr


func get_project_resource_list(project_id : String, resource_type : int) -> Array:
	for item in _available_projects:
		if item.project_id == project_id:
			if resource_type in item.resources:
				return item.resources[resource_type].duplicate()
			break;
	return []


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

func delete_project(id : String, force : bool = false) -> bool:
	var proj : Project = Project.new(id)
	var dir : Directory = Directory.new()
	var filepath : String = proj.get_project_filepath()
	if dir.file_exists(filepath):
		if force:
			dir.remove(filepath)
			return true
		emit_signal("verify_project_removal")
	return false


