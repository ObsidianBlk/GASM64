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
	for child in get_children():
		if child is MemDevice:
			if _MemDevice(child.page << 8) < 0:
				_mem_devices[child.page] = child
			else:
				print("WARNING: Unable to connect memory device. Starting page, ", child.page, ", collides with previously connected device.")


# ---------------------------------------------------------------------------
# Private Methods
# ---------------------------------------------------------------------------
func _MemDevice(addr : int) -> int:
	if addr >= 0 and addr <= 0xFFFF:
		var page = (addr & 0xFFFF) >> 8
		for key in _mem_devices.keys():
			var mdev = _mem_devices[key]
			if page >= key and page < key + mdev.page_count:
				return key
	return -1
	

# ---------------------------------------------------------------------------
# Public Methods
# ---------------------------------------------------------------------------
func write(addr : int, value : int) -> void:
	var page = _MemDevice(addr)
	if page in _mem_devices:
		_mem_devices[page].write(addr - (page << 8), value)

func read(addr : int) -> int:
	var page = _MemDevice(addr)
	if page in _mem_devices:
		return _mem_devices[page].read(addr - (page << 8))
	return 0

func set_mem_addr(addr : int, val : int) -> void:
	var page = _MemDevice(addr)
	if page in _mem_devices:
		_mem_devices[page].set_mem_addr(addr - (page << 8), val)

func fill(from_page : int, to_page : int, value : int) -> void:
	from_page = max(0, min(255, from_page))
	to_page = max(from_page, min(255, to_page))
	var page = from_page
	while page <= to_page:
		var dpage = _MemDevice(page << 8)
		if dpage in _mem_devices:
			for i in range(256):
				_mem_devices[dpage].set_mem_addr((page << 8) | i, value)
		page += 1


func page_dump(page : int) -> PoolByteArray:
	if page >= 0 and page <= 0xFF:
		for key in _mem_devices.keys():
			if page >= key and page < key + _mem_devices[key].page_count:
				return _mem_devices[key].page_dump(page - key)
	return PoolByteArray([])

func mem_dumb(offset : int, pages : int) -> PoolByteArray:
	return PoolByteArray([])

