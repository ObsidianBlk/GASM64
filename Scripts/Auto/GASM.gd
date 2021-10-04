tool
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
enum MODES {IMP=0, IMM=1, IND=2, REL=3, ACC=4, ZP=5, ZPX=6, ZPY=7, ABS=8, ABSX=9, ABSY=10, INDX=11, INDY=12}


# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------
var DATA = {
	"OP": {},
	"CATEGORIES": {},
	"MODES": {},
	"TAGS": {}
}
var CODE_LIST = []

# -----------------------------------------------------------------------------
# Override Methods
# -----------------------------------------------------------------------------
func _ready():
	for _i in range(256):
		CODE_LIST.append(null)
	_load_opcode_data("res://Data")

# -----------------------------------------------------------------------------
# Private Methods
# -----------------------------------------------------------------------------
func _load_opcode_data(oppath : String) -> void:
	var files = []
	var dir = Directory.new()
	dir.open(oppath)
	dir.list_dir_begin()

	var filename = dir.get_next()
	while filename != "":
		if filename.begins_with(OPCODE_PREFIX) and filename.ends_with(OPCODE_EXT):
			var file = File.new()
			file.open(oppath + "/" + filename, File.READ)
			var jsondat = parse_json(file.get_as_text())
			if jsondat:
				_store_opdata(jsondat)
			else:
				print("[ERROR] Failed to parse json data, '", oppath + "/" + filename, "'.")
		filename = dir.get_next()
	dir.list_dir_end()


func _obj_has_keys(ob : Dictionary, keys : Array) -> bool:
	for key in keys:
		if not (key in ob):
			return false
	return true


func _store_opdata(data : Dictionary) -> void:
	for key in data:
		if not (key in DATA.OP):
			if _obj_has_keys(data[key], OP_KEYS):
				var op = {
					"name": data[key].name,
					"category": data[key].category,
					"description": data[key].description,
					"modes":{},
					"flags": data[key].flags,
					"tags":[]
				}
				
				var process = true
				for mode in data[key].modes.keys():
					if mode in MODE_NAMES and _obj_has_keys(data[key].modes[mode], MODE_KEYS):
						op.modes[mode] = {
							"op": key,
							"mode_id": get_mode_id_from_name(mode),
							"opcode": data[key].modes[mode].opcode,
							"opval": Utils.hex_to_int(data[key].modes[mode].opcode),
							"bytes": data[key].modes[mode].bytes,
							"cycles": data[key].modes[mode].cycles,
							"pagecross": data[key].modes[mode].pagecross,
							"success": 0
						}
						if "success" in data[key].modes[mode]:
							op.modes[mode].success = data[key].modes[mode].success
					else:
						print("[WARNING] Key'", key, "' mode '", mode, "' either unknown or missing required property.")
						process = false
						break
				
				if process:
					DATA.OP[key] = op
					if not (op.category in DATA.CATEGORIES):
						DATA.CATEGORIES[op.category] = []
					DATA.CATEGORIES[op.category].append(key)
					for mode in op.modes:
						if not (mode in DATA.MODES):
							DATA.MODES[mode] = []
						DATA.MODES[mode].append(key)
						CODE_LIST[op.modes[mode].opval] = op.modes[mode]
					for tag in data[key].tags:
						op.tags.append(tag)
						if not (tag in DATA.TAGS):
							DATA.TAGS[tag] = []
						DATA.TAGS[tag].append(key)
			else:
				print("[WARNING] Key '", key, "' missing required property.")
		else:
			print("[WARNING] Key '", key, "' already stored in data.")


# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------

func is_valid_opcode(code : int) -> bool:
	if code >= 0 and code < CODE_LIST.size():
		return CODE_LIST[code] != null
	return false

func get_op_info(op_name : String) -> Dictionary:
	var opi = {
		"name": "",
		"category": "",
		"description": "",
		"modes":null,
		"flags": "",
		"tags":null
	}
	
	if op_name in DATA.OP:
		var op = DATA.OP[op_name]
		opi.name = op.name
		opi.category = op.category
		opi.description = op.description
		opi.flags = op.flags
		opi.tags = []
		opi.modes = {}
		for i in range(0, op.tags.size()):
			opi.tags.append(op.tags[i])
		for mode in op.modes:
			opi.modes[mode] = {
				"opcode": op.modes[mode].opcode,
				"opval": op.modes[mode].opval,
				"bytes": op.modes[mode].bytes,
				"cycles": op.modes[mode].cycles,
				"pagecross": op.modes[mode].pagecross,
				"success": op.modes[mode].success
			}
	
	return opi

func is_op(op_name : String) -> bool:
	return op_name.to_upper() in DATA.OP

func get_ops() -> Array:
	return DATA.OP.keys()

func op_has_mode(op_name : String, mode_id : int) -> bool:
	return get_opcode_from_name_and_mode(op_name, mode_id) >= 0

func get_categories() -> Array:
	return DATA.CATEGORIES.keys()

func get_ops_from_category(cat_name : String) -> Array:
	var oplist = []
	if cat_name in DATA.CATEGORIES:
		for i in range(0, DATA.CATEGORIES[cat_name].size()):
			oplist.append(DATA.CATEGORIES[cat_name][i])
	return oplist

func get_modeinfo_from_code(code : int) -> Dictionary:
	if code >= 0 and code < CODE_LIST.size():
		if CODE_LIST[code] != null:
			return CODE_LIST[code]
	return {"op":""}

func get_op_cycles(code : int) -> int:
	if code >= 0 and code < CODE_LIST.size():
		if CODE_LIST[code] != null:
			return CODE_LIST[code].cycles
	return 2

func get_op_bytes(code : int) -> int:
	if code >= 0 and code < CODE_LIST.size():
		if CODE_LIST[code] != null:
			return CODE_LIST[code].bytes
	return 1

func get_op_mode_id(code : int) -> int:
	if code >= 0 and code < CODE_LIST.size():
		if CODE_LIST[code] != null:
			return CODE_LIST[code].mode_id
	return -1

func get_op_asm_name(code : int) -> String:
	if code >= 0 and code < CODE_LIST.size():
		if CODE_LIST[code] != null:
			return CODE_LIST[code].op
	return ""

func get_opcodes_by_tag(tag : String) -> Array:
	var opcodes = []
	if tag in DATA.TAGS:
		for i in range(0, DATA.TAGS[tag].size()):
			opcodes.append(DATA.TAGS[tag][i])
	return opcodes

func get_opcodes_by_tags(tags : Array) -> Array:
	var opcodes = []
	if tags.size() > 0:
		opcodes = get_opcodes_by_tag(tags[0])
		if tags.size() > 1:
			for i in range(1, tags.size()):
				var ctags = opcodes
				var ntags = get_opcodes_by_tag(tags[i])
				opcodes = []
				if ntags.size() > 0:
					for c in range(0, ctags.size()):
						if ntags.find(ctags[c]) >= 0:
							opcodes.append(ctags[c])
				if opcodes.size() <= 0:
					break;
	
	return opcodes

func get_opcode_from_name_and_mode(op : String, mode : int) -> int:
	op = op.to_lower()
	if op in DATA.OP:
		var mode_name = get_mode_name_from_ID(mode)
		if mode_name in DATA.OP[op].modes:
			return DATA.OP[op].modes[mode_name].opval
	return -1

func get_mode_id_from_name(mode_name : String) -> int:
	for i in range(MODE_NAMES.size()):
		if MODE_NAMES[i] == mode_name:
			return i
	return -1

func get_mode_name_from_ID(mode_id : int) -> String:
	if mode_id >= 0 and mode_id < MODE_NAMES.size():
		return MODE_NAMES[mode_id]
	return ""
