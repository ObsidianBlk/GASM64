extends Reference
class_name Environ


var _env : Dictionary = {}
var _parent : Environ = null

var _PC : int = 0

var _allow_redefinition : bool = false
var _redefinition_global : bool = false

func _init(e : Environ = null):
	._init()
	if e != null:
		_parent = e
		_allow_redefinition = _parent.allow_redefinition()
		_redefinition_global = _parent.redefinition_global()

func allow_redefinition(allow = null) -> bool:
	if typeof(allow) == TYPE_BOOL:
		_allow_redefinition = allow
		if _redefinition_global and _parent != null:
			_parent.allow_redefinition(allow)
	return _allow_redefinition

func redefinition_global(global = null) -> bool:
	if typeof(global) == TYPE_BOOL:
		_redefinition_global = global
		if _parent != null:
			_parent.redefinition_global(global)
	return _redefinition_global

func has_label(label : String) -> bool:
	if label in _env:
		return true
	if _parent != null:
		return _parent.has_label(label)
	return false

func get_label(label : String):
	if label in _env:
		return _env[label]
	if _parent != null:
		return _parent.get_label(label)
	return null

func set_label(label : String, value) -> void:
	if value != null:
		if not (label in _env) or (label in _env and _allow_redefinition):
			_env[label] = value

func PC(pcv = null) -> int:
	if _parent != null:
		return _parent.PC(pcv)
	elif typeof(pcv) == TYPE_INT:
		if pcv >= 0 and pcv <= 0xFFFF:
			_PC = pcv
	return _PC

func PC_next(amount : int  = 1) -> int:
	if _parent != null:
		return _parent.PC_next()
	var cpc : int = _PC
	_PC = (_PC + amount) % 0xFFFF
	return cpc



