extends Reference
class_name Project


# -------------------------------------------------------------------------
# Constants and ENUMs
# -------------------------------------------------------------------------
const FILE_VERSION : Array = [0, 1]
enum RESOURCE_TYPE {ASSEMBLY}

# -------------------------------------------------------------------------
# Variables
# -------------------------------------------------------------------------
var _project_id : String = ""
var _project_name : String = "Project"
var _data : Dictionary = {}

var _is_dirty : bool = false

var _errors : Array = []

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
# Private Helper Methods
# -------------------------------------------------------------------------
func _ClearDirty() -> void:
	_is_dirty = false

func _Reset(id : String = "") -> void:
	if id != "" and id.length() == 24 and id.is_valid_hex_number():
		_project_id = id
	_errors = []
	_data = {}
	_is_dirty = true

func _GenerateBuffers() -> Dictionary:
	var index = PoolByteArray()
	var blocks = PoolByteArray()
	
	var offset = 0
	for resid in _data.keys():
		var resources = _GetOwnedResources(resid)
		if resources.size() <= 0:
			continue
		
		index.append(resid)
		index.append(resources.size())
		index.append_array(Utils.int_to_buffer(offset, 4))
		var block = PoolByteArray()
		
		for res_name in resources:
			match resid:
				RESOURCE_TYPE.ASSEMBLY:
					var buffer = res_name.to_utf8()
					var size = buffer.size()
					# TODO: Do I really think the "Resource name" is going to need more than a BYTE
					# to store it's length?!
					block.append_array(Utils.int_to_buffer(size, 2))
					block.append_array(buffer)
					
					if _data[resid][res_name].ref != "":
						block.append(1) # This identifies this block as a "reference" resource.
						buffer = _data[resid][res_name].ref.to_utf8()
						size = buffer.size()
						block.append_array(Utils.int_to_buffer(size, 2))
						block.append_array(buffer)
					else:
						block.append(0) # This identifies this block as a "local" resource.
						buffer = _data[resid][res_name].source.to_utf8()
						size = buffer.size()
						block.append_array(Utils.int_to_buffer(size, 2))
						
						buffer = buffer.compress(File.COMPRESSION_GZIP)
						size = buffer.size()
						block.append_array(Utils.int_to_buffer(size, 2))
						block.append_array(buffer)
						
						# TODO: Do I want to save the Parser AST tree as well?
						# For now... I'll just rebuild the source.
						
						block.append(
							1 if _data[resid][res_name].main else 0
						)
		offset += block.size() + 4
		blocks.append_array(Utils.int_to_buffer(block.size(), 4))
		blocks.append_array(block)
	return {"index":index, "blocks":blocks}



# -------------------------------------------------------------------------
# Public Methods
# -------------------------------------------------------------------------
func error_count() -> int:
	return _errors.size()

func get_error(idx : int):
	if idx >= 0 and idx < _errors.size():
		return _errors[idx]
	return null

func is_dirty() -> bool:
	return _is_dirty

func get_project_id() -> String:
	return _project_id

func set_project_name(proj_name : String) -> void:
	_project_name = proj_name
	_is_dirty = true

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
		assembler = Assembler.new()
		source = "" if not ("source" in options) else options.source
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
		_is_dirty = true


func drop_assembly_resource(resource_name : String) -> void:
	if RESOURCE_TYPE.ASSEMBLY in _data:
		var asm = _data[RESOURCE_TYPE.ASSEMBLY]
		for resource in asm:
			if resource == resource_name:
				asm[resource_name].alive = false
				_is_dirty = true


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


func set_assembly_resource(resource_name : String, options : Dictionary = {}) -> void:
	if RESOURCE_TYPE.ASSEMBLY in _data:
		var asm = _data[RESOURCE_TYPE.ASSEMBLY]
		if resource_name in asm and asm[resource_name].ref == "":
			if "source" in options:
				asm[resource_name].source = options.source
				_is_dirty = true
			if "is_main" in options:
				if options.is_main:
					if asm[resource_name].main != true:
						_ClearCurrentAssemblyMain()
						asm[resource_name].main = true
				else:
					asm[resource_name].main = false
				_is_dirty = true




