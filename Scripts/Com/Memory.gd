extends MemDevice
class_name Memory


# ---------------------------------------------------------------------------
# Export Variables
# ---------------------------------------------------------------------------
export var ROM : bool = false


# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
var _mempool : PoolByteArray = PoolByteArray([0])


# ---------------------------------------------------------------------------
# Setter / Getter
# ---------------------------------------------------------------------------
func set_page_count(count : int) -> void:
	.set_page_count(count)
	if _mempool.size() != (256 * page_count):
		_mempool.resize(256 * page_count)

# ---------------------------------------------------------------------------
# Override Methods
# ---------------------------------------------------------------------------
func _ready() -> void:
	set_page_count(page_count)

# ---------------------------------------------------------------------------
# Public Methods
# ---------------------------------------------------------------------------
func read(idx : int) -> int:
	if idx >= 0 and idx < _mempool.size():
		return _mempool[idx]
	return 0

func write(idx : int, val : int) -> void:
	if not ROM and idx >= 0 and idx < _mempool.size():
		_mempool[idx] = val

func set_mem_addr(idx : int, val : int) -> void:
	if idx >= 0 and idx < _mempool.size():
		_mempool[idx] = val

func fill_mem(val : int) -> void:
	for i in range(_mempool.size()):
		_mempool[i] = val

func page_dump(offset : int) -> PoolByteArray:
	if offset >= 0 and offset < page_count:
		var idx = offset * 256
		return _mempool.subarray(idx, idx + 255)
	return PoolByteArray([])

func mem_dump(offset : int = -1, pages : int = -1) -> PoolByteArray:
	offset = max(0, offset)
	if offset >= page_count:
		return PoolByteArray([])
	pages = max(1, min(pages, page_count - offset))
	var first = offset * 256
	return _mempool.subarray(first, first + (pages * 256))
	
	
	
