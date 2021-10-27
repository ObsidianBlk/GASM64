extends Reference
class_name Project


# -------------------------------------------------------------------------
# Constants and ENUMs
# -------------------------------------------------------------------------
enum RESOURCE_TYPE {ASSEMBLY}

# -------------------------------------------------------------------------
# Variables
# -------------------------------------------------------------------------
var _data = {}

# -------------------------------------------------------------------------
# Override Methods
# -------------------------------------------------------------------------
func _init(src : String) -> void:
	pass


# -------------------------------------------------------------------------
# Private Methods
# -------------------------------------------------------------------------
func _ClearCurrentAssemblyMain() -> void:
	if RESOURCE_TYPE.ASSEMBLY in _data:
		var asm = _data[RESOURCE_TYPE.ASSEMBLY]
		for resource in asm:
			if asm[resource].main == true:
				asm[resource].main = false
				break

# -------------------------------------------------------------------------
# Public Methods
# -------------------------------------------------------------------------
func add_assembly_resource(resource_name : String, reference_source : String = "") -> void:
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


func drop_assembly_resource(resource_name : String) -> void:
	if RESOURCE_TYPE.ASSEMBLY in _data:
		var asm = _data[RESOURCE_TYPE.ASSEMBLY]
		for resource in asm:
			if resource == resource_name:
				asm[resource_name].alive = false


# -------------------------------------------------------------------------
# Public Save Methods
# -------------------------------------------------------------------------


# -------------------------------------------------------------------------
# Handler Methods
# -------------------------------------------------------------------------

