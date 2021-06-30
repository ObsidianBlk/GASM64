tool
extends Node

const OPCODE_PREFIX = "opcodes_"
const OPCODE_EXT = ".json"
const OP_KEYS = ["name", "description", "modes", "flags", "tags"]
const MODE_KEYS = ["opcode", "bytes", "cycles", "pagecross"]
const MODES = [
	"implied",
	"immediate",
	"indirect",
	"relative",
	"accumulator",
	"zero_page", "zero_page_x", "zero_page_y",
	"absolute", "absolute_x", "absolute_y",
	"indirect_x", "indirect_y"]

var DATA = {
	"OP": {},
	"MODES": {},
	"TAGS": {}
}

func _ready():
	_load_opcode_data("res://Data")


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
					"description": data[key].description,
					"modes":{},
					"flags": data[key].flags,
					"tags":[]
				}
				
				var process = true
				for mode in data[key].modes.keys():
					if mode in MODES and _obj_has_keys(data[key].modes[mode], MODE_KEYS):
						op.modes[mode] = {
							"opcode": data[key].modes[mode].opcode,
							"opval": hex_to_int(data[key].modes[mode].opcode),
							"bytes": data[key].modes[mode].bytes,
							"cycles": data[key].modes[mode].cycles,
							"pagecross": data[key].modes[mode].pagecross
						}
						if "success" in data[key].modes[mode]:
							op.modes[mode].success = data[key].modes[mode].success
					else:
						print("[WARNING] Key'", key, "' mode '", mode, "' either unknown or missing required property.")
						process = false
						break
				
				if process:
					DATA.OP[key] = op
					for mode in op.modes:
						if not (mode in DATA.MODES):
							DATA.MODES[mode] = []
						DATA.MODES[mode].append(key)
					for tag in data[key].tags:
						op.tags.append(tag)
						if not (tag in DATA.TAGS):
							DATA.TAGS[tag] = []
						DATA.TAGS[tag].append(key)
			else:
				print("[WARNING] Key '", key, "' missing required property.")
		else:
			print("[WARNING] Key '", key, "' already stored in data.")


func hex_to_int(hex : String) -> int:
	if hex.is_valid_hex_number() and not hex.is_valid_hex_number(true):
		hex = "0x" + hex
		return hex.hex_to_int()
	return -1

func is_valid_opcode(code : int) -> bool:
	return (get_modeinfo_from_code(code)).op != ""

func get_modeinfo_from_code(code : int) -> Dictionary:
	var modeinfo = {
		"op": "",
		"mode": "",
		"bytes": 0,
		"cycles": 0,
		"pagecross":0,
		"success":0
	}
	
	for key in DATA.OP:
		for mode in DATA.OP[key].modes:
			if DATA.OP[key].modes[mode].codeval == code:
				modeinfo.op = key
				modeinfo.mode = mode
				modeinfo.bytes = DATA.OP[key].modes[mode].bytes
				modeinfo.cycles = DATA.OP[key].modes[mode].cycles
				modeinfo.pagecross = DATA.OP[key].modes[mode].pagecross
				if "success" in DATA.OP[key].modes[mode]:
					modeinfo.success = DATA.OP[key].modes[mode].success
				return modeinfo
	return modeinfo

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

