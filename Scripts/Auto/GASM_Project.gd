extends Node


# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------
signal project_added(id, name)
signal project_removed(id)

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


func _UpdateAvailableProject(proj : Project) -> void:
	for ap in _available_projects:
		if ap.id == proj.get_project_id():
			return
	_available_projects.append({
		"project_name": proj.get_project_name(),
		"project_id": proj.get_project_id(),
		"resources": proj.get_resource_list()
	})
	emit_signal(
		"project_added",
		proj.get_project_id(),
		proj.get_project_name()
	)
	

func _LoadProjectList() -> void:
	var dir = Directory.new()
	if dir.open(Project.DEFAULT_PATH) == OK:
		_available_projects.clear()
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var proj : Project = Project.new()
		while file_name != "":
			if not dir.current_is_dir():
				if proj.load({"path": Project.DEFAULT_PATH + file_name, "stubbed":true}):
					_UpdateAvailableProject(proj)
#					_available_projects.append({
#						"project_name": proj.get_project_name(),
#						"project_id": proj.get_project_id(),
#						"resources": {
#							Project.RESOURCE_TYPE.ASSEMBLY: proj.get_resource_names(Project.RESOURCE_TYPE.ASSEMBLY)
#						}
#					})
				else:
					print("WARNING: Failed to load possible project file '" + file_name + "'.");
			file_name = dir.get_next()


# -------------------------------------------------------------------------
# Public Methods
# -------------------------------------------------------------------------
func get_available_projects() -> Array:
	var arr : Array = []
	for item in _available_projects:
		arr.append({"name": item.project_name, "id":item.project_id})
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


func new_project(name : String, auto_save : bool = false) -> bool:
	var old_project = _active_project
	_active_project = Project.new()
	_active_project.set_project_name(name)
	var update_available = true
	if auto_save:
		update_available = _active_project.save()
		
	if update_available:
		_UpdateAvailableProject(_active_project)
	else:
		_active_project = old_project
	return update_available


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


func load_project(id : String) -> bool:
	if _active_project != null and _active_project.get_project_id() == id:
		return true
	
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

func delete_project(id : String) -> bool:
	var proj : Project = Project.new(id)
	var dir : Directory = Directory.new()
	var filepath : String = proj.get_project_filepath()
	if dir.file_exists(filepath):
		dir.remove(filepath)
		emit_signal("project_removed", id)
		return true
	return false


