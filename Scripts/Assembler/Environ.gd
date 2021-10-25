extends Reference
class_name Environ


var _env : Dictionary = {}
var _parent : Environ = null


func _init(e : Environ = null):
	._init()
	if e != null:
		_parent = e

func is_root() -> bool:
	return _parent == null

func get_root() -> Environ:
	if _parent == null:
		return self
	return _parent.get_root()

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

func set_label(label : String, value, global : bool = false) -> void:
	if value != null:
		if global:
			get_root().set_label(label, value)
		else:
			if not (label in _env):
				_env[label] = value


