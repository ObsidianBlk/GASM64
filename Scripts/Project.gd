extends Reference
class_name Project


# -------------------------------------------------------------------------
# Constants and ENUMs
# -------------------------------------------------------------------------
const FOLDER : String = "projects/"
const DEFAULT_PATH : String = "user://" + FOLDER
const FILE_VERSION : Array = [0, 1]
enum RESOURCE_TYPE {ASSEMBLY}

# -------------------------------------------------------------------------
# Variables
# -------------------------------------------------------------------------
var _filepath : String = ""
var _project_id : String = ""
var _project_name : String = "Project"
var _data_stubbed : bool = false
var _data : Dictionary = {}

var _is_dirty : bool = false

var _errors : Array = []

# -------------------------------------------------------------------------
# Override Methods
# -------------------------------------------------------------------------
func _init(id : String = "") -> void:
	if id != "":
		if id.length() == 32 and id.is_valid_hex_number():
			_project_id = id
	if _project_id == "":
		_project_id = Utils.uuidv4(true)


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
func _Reset(id : String = "") -> void:
	if id != "" and id.length() == 24 and id.is_valid_hex_number():
		_project_id = id
	_errors = []
	_data = {}
	_is_dirty = true


func _GenerateAssemblyBuffer(block : PoolByteArray, res_name : String) -> void:
	var buffer = res_name.to_utf8()
	var size = buffer.size()
	# TODO: Do I really think the "Resource name" is going to need more than a BYTE
	# to store it's length?!
	block.append_array(Utils.int_to_buffer(size, 2))
	block.append_array(buffer)
	
	var resbuf = PoolByteArray([])
	
	if _data[RESOURCE_TYPE.ASSEMBLY][res_name].ref != "":
		resbuf.append(0x80) # This identifies this block as a "reference" resource.
		buffer = _data[RESOURCE_TYPE.ASSEMBLY][res_name].ref.to_utf8()
		size = buffer.size()
		resbuf.append_array(Utils.int_to_buffer(size, 2))
		resbuf.append_array(buffer)
	else:
		var key = 0
		var asm = _data[RESOURCE_TYPE.ASSEMBLY][res_name].assembler
		if asm and asm.is_valid():
			key = key | 0x01
			
		resbuf.append(key) # This identifies this block as a "local" resource.
		
		# Getting the byte array of the source text file.
		buffer = _data[RESOURCE_TYPE.ASSEMBLY][res_name].source.to_utf8()
		size = buffer.size()
		# And storing the uncompressed size.
		resbuf.append_array(Utils.int_to_buffer(size, 2))
		
		# Compressing the source text file
		buffer = buffer.compress(File.COMPRESSION_GZIP)
		size = buffer.size()
		# Storing compressed size and buffer.
		resbuf.append_array(Utils.int_to_buffer(size, 2))
		resbuf.append_array(buffer)
		
		if key & 0x01 != 0:
			var astbuf : PoolByteArray = asm.get_ast_buffer()
			size = astbuf.size()
			astbuf = astbuf.compress(File.COMPRESSION_GZIP)
			resbuf.append_array(Utils.int_to_buffer(size, 4))
			resbuf.append_array(Utils.int_to_buffer(astbuf.size(), 4))
			resbuf.append_array(astbuf)
		
		resbuf.append(
			1 if _data[RESOURCE_TYPE.ASSEMBLY][res_name].main else 0
		)
	
	block.append_array(Utils.int_to_buffer(resbuf.size(), 4))
	block.append_array(resbuf)


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
					_GenerateAssemblyBuffer(block, res_name)
		offset += block.size() + 4
		blocks.append_array(Utils.int_to_buffer(block.size(), 4))
		blocks.append_array(block)
	return {"index":index, "blocks":blocks}


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


func _ProcessAssemblyBuffer(buffer : PoolByteArray, offset : int, count : int) -> bool:
	if offset >= 0 and offset < buffer.size():
		var block_size = Utils.buffer_to_int(buffer, offset, 8)
		if _errors.size() > 0:
			return false
		
		if offset + block_size > buffer.size():
			_StoreError("_ProcessAssemblyBuffer", "Given block size exceeds available block data.")
			return false
		offset += 4
		
		for _i in range(0, count):
			var size = Utils.buffer_to_int(buffer, offset, 2)
			var res_name = Utils.buffer_to_string(buffer, offset + 2, size)
			offset += 2 + size
			
			var resource_size = Utils.buffer_to_int(buffer, offset, 4)
			offset += 4
			
			var key = buffer[offset]
			offset += 1
			if key & 0x80 != 0:
				size = Utils.buffer_to_int(buffer, offset, 2)
				offset += 2
				var ref = Utils.buffer_to_string(buffer, offset, size)
				offset += size
				add_assembly_resource(res_name, {"reference_project_id": ref})
			else:
				if _data_stubbed:
					offset += resource_size
					add_assembly_resource(res_name)
				else:
					var options = {"source":"", "is_main":false}
					var src_size = Utils.buffer_to_int(buffer, offset, 2)
					offset += 2
					
					size = Utils.buffer_to_int(buffer, offset, 2)
					options.source = Utils.buffer_to_string(buffer, offset + 2, size, src_size)
					offset += 2 + size
					
					var asm : Assembler = null
					if key & 0x01 != 0:
						var ast_size = Utils.buffer_to_int(buffer, offset, 4)
						size = Utils.buffer_to_int(buffer, offset+4, 4)
						offset += 8
						
						var astbuf = buffer.subarray(offset, size-1).decompress(File.COMPRESSION_GZIP)
						asm = Assembler.new()
						if not asm.prime_ast_buffer(astbuf):
							_StoreError("_ProcessAssemblyBuffer", "Failed to import AST tree data.")
							return false
						options["assembler"] = asm
					
					options.is_main = buffer[offset] == 1
					offset += 1
					
					add_assembly_resource(res_name, options)
		return true
	else:
		_StoreError("_ProcessAssemblyBuffer", "Offset outside of buffer boundry.")
	return false

func _ValidateProjectFolder() -> bool:
	var dir : Directory = Directory.new()
	if dir.open("user://") == OK:
		if dir.dir_exists(FOLDER):
			return true
		if dir.make_dir(FOLDER) == OK:
			return true
	return false

func _SaveProject(path : String) -> bool:
	if not _ValidateProjectFolder():
		return false
	
	var file = File.new()
	if file.open(path, File.WRITE) == OK:
		
		file.store_buffer("GPRJ".to_utf8())
		file.store_buffer(PoolByteArray(FILE_VERSION))
		
		var buffer = _project_id.to_utf8()
		file.store_16(buffer.size())
		file.store_buffer(buffer)
		
		buffer = _project_name.to_utf8()
		file.store_16(buffer.size())
		file.store_buffer(buffer)
		
		buffer = _GenerateBuffers()
		
		file.store_32(buffer.index.size())
		file.store_64(buffer.blocks.size())
		file.store_buffer(buffer.index)
		file.store_buffer(buffer.blocks)
		
		file.close()
		return true
	return false


func _LoadProjectHeader(file : File, func_name : String):
	var magic = file.get_buffer(4).get_string_from_utf8()
	if magic != "GPRJ":
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



func _LoadProject(path : String, options : Dictionary = {}) -> bool:
	var file = File.new()
	if file.open(path, File.READ) == OK:
		var header = _LoadProjectHeader(file, "load")
		if header != null:
			_project_id = header.project_id
			_project_name = header.project_name
			if "header_only" in options and options.header_only == true:
				_data_stubbed = true
				file.close()
				return true
		else:
			file.close()
			return false
		
		if "stubbed" in options and options.stubbed == true:
			_data_stubbed = true
			
		var idx_block_size = file.get_32()
		var res_block_size = file.get_64()
		
		var index = _ProcessIndexBuffer(file.get_buffer(idx_block_size))
		if _errors.size() > 0:
			file.close()
			return false
		
		var resource_buffer = file.get_buffer(res_block_size)
		file.close()

		for entry in index:
			match entry.resid:
				RESOURCE_TYPE.ASSEMBLY:
					if not _ProcessAssemblyBuffer(resource_buffer, entry.offset, entry.count):
						return false
		return true
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

func is_dirty() -> bool:
	return _is_dirty

func is_stubbed() -> bool:
	return _data_stubbed

func get_project_id() -> String:
	return _project_id

func set_project_name(proj_name : String) -> void:
	_project_name = proj_name
	_is_dirty = true

func get_project_name() -> String:
	return _project_name

func get_project_filepath(ignore_existing : bool = false) -> String:
	if _filepath != "" and not ignore_existing:
		return _filepath
	return DEFAULT_PATH + "GP_" + _project_id.to_upper() + ".gproj"

func get_resource_list() -> Array:
	var resource_list = []
	for res_type_name in RESOURCE_TYPE.keys():
		var rtype = RESOURCE_TYPE[res_type_name]
		if rtype in _data:
			var resources = _data[rtype]
			for res_name in resources.keys():
				if resources[res_name].alive == true:
					resource_list.append({
						type = rtype,
						name = res_name,
						ref = resources[res_name].ref != ""
					})
	return resource_list

func has_resource(type : int, resource_name : String) -> bool:
	if RESOURCE_TYPE.values().find(type) >= 0:
		return resource_name in _data[type]
	return false

func add_resource(type : int, resource_name : String, options : Dictionary = {}) -> void:
	match type:
		RESOURCE_TYPE.ASSEMBLY:
			add_assembly_resource(resource_name, options)

func drop_resource(type : int, resource_name : String) -> void:
	match type:
		RESOURCE_TYPE.ASSEMBLY:
			drop_assembly_resource(resource_name)

func get_resource(type : int, resource_name : String) -> Dictionary:
	match type:
		RESOURCE_TYPE.ASSEMBLY:
			return get_assembly_resource(resource_name)
	return {"type":-1}

func set_resource(type : int, resource_name : String, options : Dictionary) -> void:
	match type:
		RESOURCE_TYPE.ASSEMBLY:
			set_assembly_resource(resource_name, options)

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
		if res[0].size() != 32:
			_StoreError("add_assembly_resource", "Reference project ID invalid.")
			return
		# TODO: Verify res[0] is a large hex value.
		# TODO: Verify res[1] is a valid resource_name
		# TODO: Verify res[0] project exists.
	# TODO: Verify resource existance.
	
	var source = ""
	var assembler = null
	var is_main = false
	
	if ref == "" and not _data_stubbed:
		assembler = Assembler.new()
		source = "" if not ("source" in options) else options.source
		if ref == "" and "is_main" in options:
			is_main = options.is_main == true
	 
	if not (resource_name in asm):
		if _data_stubbed:
			asm[resource_name] = {
				"stub": true,
				"alive": true
			}
			if ref != "":
				asm[resource_name].ref = ref
		else:
			asm[resource_name] = {
				"ref": ref,
				"source": source,
				"assembler": assembler,
				"main": is_main,
				"alive": true
			}
			_is_dirty = true


func drop_assembly_resource(resource_name : String) -> void:
	if _data_stubbed:
		return
	
	if RESOURCE_TYPE.ASSEMBLY in _data:
		var asm = _data[RESOURCE_TYPE.ASSEMBLY]
		for resource in asm:
			if resource == resource_name:
				asm[resource_name].alive = false
				_is_dirty = true


func get_assembly_resource(resource_name : String) -> Dictionary:
	if RESOURCE_TYPE.ASSEMBLY in _data and not _data_stubbed:
		var asm = _data[RESOURCE_TYPE.ASSEMBLY]
		if resource_name in asm:
			if asm[resource_name].alive:
				# TODO: If Reg has a value, load that reference project to get the data.
				return {
					"type": RESOURCE_TYPE.ASSEMBLY,
					"source": asm[resource_name].source,
					"assembler": asm[resource_name].assembler,
					"main": asm[resource_name].main
				}
	return {"type":-1}


func set_assembly_resource(resource_name : String, options : Dictionary = {}) -> void:
	if RESOURCE_TYPE.ASSEMBLY in _data and not _data_stubbed:
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


func load(options : Dictionary = {}) -> bool:
	var path = get_project_filepath()
	if "path" in options:
		path = options.path
	
	if _LoadProject(path, options):
		_filepath = path
		_is_dirty = false
		return true
	return false


func save(options : Dictionary = {}) -> bool:
	if not _data_stubbed:
		var path = get_project_filepath()
		if "path" in options:
			path = options.path
		if path != "":
			if _SaveProject(path):
				_filepath = path
				if "clear_dirty" in options and options.clear_dirty:
					_is_dirty = false
				return true
	return false



