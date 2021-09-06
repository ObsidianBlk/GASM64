extends Node
class_name Bus



# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
var _mem_devices : Dictionary = {}


# ---------------------------------------------------------------------------
# Override Methods
# ---------------------------------------------------------------------------
func _ready() -> void:
	var page = 0
	for child in get_children():
		if child is MemDevice:
			_mem_devices[[page, page + child.page_count]] = child

# ---------------------------------------------------------------------------
# Private Methods
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Public Methods
# ---------------------------------------------------------------------------
func write(addr : int, value : int) -> void:
	if addr >= 0 and addr <= 0xFFFF:
		var page = addr >> 8
		for key in _mem_devices.keys():
			if page >= key[0] and page <= key[1]:
				_mem_devices[key].write(addr - (key[0] << 8), value)

func read(addr : int) -> int:
	if addr >= 0 and addr <= 0xFFFF:
		var page = addr >> 8
		for key in _mem_devices.keys():
			if page >= key[0] and page <= key[1]:
				return _mem_devices[key].read(addr - (key[0] << 8))
	return 0

func set_mem_addr(addr : int, val : int) -> void:
	if addr >= 0 and addr <= 0xFFFF:
		var page = addr >> 8
		for key in _mem_devices.keys():
			if page >= key[0] and page <= key[1]:
				_mem_devices[key].set_mem_addr(addr - (key[0] << 8), val)

func mem_dumb(offset : int, page : int) -> PoolByteArray:
	return PoolByteArray([])

