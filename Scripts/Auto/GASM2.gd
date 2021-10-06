extends Node

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
const OPCODE_PREFIX = "opcodes_"
const OPCODE_EXT = ".json"
const OP_KEYS = ["name", "category", "description", "modes", "flags", "tags"]
const MODE_KEYS = ["opcode", "bytes", "cycles", "pagecross"]
const MODE_NAMES = [
	"implied",
	"immediate",
	"indirect",
	"relative",
	"accumulator",
	"zero_page", "zero_page_x", "zero_page_y",
	"absolute", "absolute_x", "absolute_y",
	"indirect_x", "indirect_y"
]

# -----------------------------------------------------------------------------
# ENUMs
# -----------------------------------------------------------------------------
enum MODE {IMP=0, IMM=1, IND=2, REL=3, ACC=4, ZP=5, ZPX=6, ZPY=7, ABS=8, ABSX=9, ABSY=10, INDX=11, INDY=12}


# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------
var _INST = {}
var _INST_CODES = {}
var _CATEGORIES = {}
var _ADDR_MODES = {}
var _TAGS = {}


# -----------------------------------------------------------------------------
# Override Methods
# -----------------------------------------------------------------------------
func _ready() -> void:
#	for _i in range(256):
#		CODE_LIST.append(null)
	_load_instruction_data("res://Data")

# -----------------------------------------------------------------------------
# Private Methods
# -----------------------------------------------------------------------------
func _load_instruction_data(path : String) -> void:
	var files = []
	var dir = Directory.new()
	dir.open(path)
	dir.list_dir_begin()

	var filename = dir.get_next()
	while filename != "":
		if filename.begins_with(OPCODE_PREFIX) and filename.ends_with(OPCODE_EXT):
			var file = File.new()
			file.open(path + "/" + filename, File.READ)
			var jsondat = parse_json(file.get_as_text())
			if jsondat:
				_store_instruction_data(jsondat)
			else:
				print("[ERROR] Failed to parse json data, '", path + "/" + filename, "'.")
		filename = dir.get_next()
	dir.list_dir_end()


func _obj_has_keys(ob : Dictionary, keys : Array) -> bool:
	for key in keys:
		if not (key in ob):
			return false
	return true


func _store_instruction_data(jdata : Dictionary) -> void:
	for key in jdata:
		var inst = key.to_lower()
		if not inst in _INST:
			if _obj_has_keys(jdata[key], OP_KEYS):
				var inst_data = {
					"name": jdata[key].name,
					"category": jdata[key].category,
					"description": jdata[key].description,
					"addr_modes":{},
					"flags": jdata[key].flags,
					"tags":[]
				}
				
				var process = true
				for addr_name in jdata[key].modes.keys():
					if addr_name in MODE_NAMES and _obj_has_keys(jdata[key].modes[addr_name], MODE_KEYS):
						var addr_id = get_addr_mode_id(addr_name) 
						inst_data.addr_modes[addr_id] = {
							"addr_name": addr_name,
							"code": Utils.hex_to_int(jdata[key].modes[addr_name].opcode),
							"bytes": jdata[key].modes[addr_name].bytes,
							"cycles": jdata[key].modes[addr_name].cycles,
							"pagecross": jdata[key].modes[addr_name].pagecross,
							"success": 0
						}
						if "success" in jdata[key].modes[addr_name]:
							inst_data.addr_modes[addr_id].success = jdata[key].modes[addr_name].success
					else:
						print("[WARNING] Key'{key}', Addressing Mode '{mode}' either unknown or missing required property.".format({"key":key, "mode":addr_name}))
						process = false
						break
				
				if process:
					_INST[inst] = inst_data
					if not (inst_data.category in _CATEGORIES):
						_CATEGORIES[inst_data.category] = []
					_CATEGORIES[inst_data.category].append(inst)
					for mode in inst_data.addr_modes:
						_INST_CODES[inst_data.addr_modes[mode].code] = {
							"inst": inst,
							"addr": mode
						}
						if not (mode in _ADDR_MODES):
							_ADDR_MODES[mode] = []
						_ADDR_MODES[mode].append(inst)
					for tag in jdata[key].tags:
						inst_data.tags.append(tag)
						if not (tag in _TAGS):
							_TAGS[tag] = []
						_TAGS[tag].append(inst)
			else:
				print("[WARNING] Key '{key}' missing required property.".format({"key":key}))
		else:
			print("[WARNING] Key '{key}' already stored in data.".format({"key":key}))

# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------


func get_instructions() -> Array:
	return _INST.keys()

func is_instruction(inst : String) -> bool:
	return inst.to_lower() in _INST

func instruction_has_address_mode(inst : String, addr_id : int) -> bool:
	return get_instruction_code(inst, addr_id) >= 0

func get_instruction_info(inst : String, addr_id : int = -1):
	inst = inst.to_lower()
	if inst in _INST:
		if addr_id in _INST[inst].addr_modes:
			var addr = _INST[inst].addr_modes[addr_id]
			return {
				"addr_name": addr.addr_name,
				"code": addr.code,
				"bytes": addr.bytes,
				"cycles": addr.cycles,
				"pagecross": addr.pagecross,
				"success": addr.success
			}
		else:
			var info = _INST[inst]
			var res = {
				"name": info.name,
				"category": info.category,
				"description": info.description,
				"addr_modes":[],
				"flags": [],
				"tags":[]
			}
			res.addr_modes = info.addr_modes.keys()
			for f in info.flags:
				res.flags.append(f)
			for t in info.tags:
				res.tags.append(t)
			return res
	return null

func get_instruction_code(inst : String, addr_id : int) -> int:
	inst = inst.to_lower()
	if inst in _INST and addr_id in _INST[inst].addr_modes:
		return _INST[inst].addr_modes[addr_id].code
	return -1

func get_instruction_bytes(inst : String, addr_id : int) -> int:
	inst = inst.to_lower()
	if inst in _INST and addr_id in _INST[inst].addr_modes:
		return _INST[inst].addr_modes[addr_id].bytes
	return -1

func get_instruction_cycles(inst : String, addr_id : int) -> Array:
	inst = inst.to_lower()
	if inst in _INST and addr_id in _INST[inst].addr_modes:
		return [
			_INST[inst].addr_modes[addr_id].cycles,
			_INST[inst].addr_modes[addr_id].pagecross,
			_INST[inst].addr_modes[addr_id].success
		]
	return [-1,0,0]

func is_inst_code_valid(code : int) -> bool:
	return code in _INST_CODES

func get_inst_code_name(code : int) -> String:
	if code in _INST_CODES:
		return _INST_CODES[code].inst
	return ""

func get_inst_code_mode(code : int) -> int:
	if code in _INST_CODES:
		return _INST_CODES[code].addr
	return -1

func get_inst_info_from_code(code : int):
	if code in _INST_CODES:
		return get_instruction_info(_INST_CODES[code].inst, _INST_CODES[code].addr)
	return null

func get_addr_mode_name(addr_id : int) -> String:
	if addr_id >= 0 and addr_id < MODE_NAMES.size():
		return MODE_NAMES[addr_id]
	return ""

func get_addr_mode_id(addr_name : String) -> int:
	for i in range(MODE_NAMES.size()):
		if MODE_NAMES[i] == addr_name:
			return i
	return -1

func get_instructions_by_address_mode(addr_id : int) -> Array:
	return _ADDR_MODES.keys()

func get_instruction_categories() -> Array:
	return _CATEGORIES.keys()

func get_category_instructions(category : String) -> Array:
	var instlist = []
	if category in _CATEGORIES:
		for inst in _CATEGORIES[category]:
			instlist.append(inst)
	return instlist

func get_instruction_tags() -> Array:
	return _TAGS.keys()

func get_instructions_by_tag(tag : String) -> Array:
	var instlist = []
	if tag in _TAGS:
		for inst in _TAGS[tag]:
			instlist.append(inst)
	return instlist

func get_instructions_by_tags(taglist : Array) -> Array:
	var instlist = []
	for tag in taglist:
		var nlist = get_instructions_by_tag(tag)
		for ins in nlist:
			if instlist.find(ins) < 0:
				instlist.append(ins)
	return instlist

