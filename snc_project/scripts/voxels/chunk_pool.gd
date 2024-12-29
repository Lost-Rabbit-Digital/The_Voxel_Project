class_name ChunkPool
extends Resource

const POOL_SIZE := 64  # Maximum number of pooled chunks
const COMPRESSION_THRESHOLD := 30  # Seconds before compressing inactive chunks
const POOL_CLEANUP_INTERVAL := 60  # Seconds between pool cleanup

var _available_chunks: Array[ChunkData] = []
var _active_chunks: Dictionary = {}
var _last_access_times: Dictionary = {}
var _cleanup_timer: Timer

func _init() -> void:
	_cleanup_timer = Timer.new()
	_cleanup_timer.wait_time = POOL_CLEANUP_INTERVAL
	_cleanup_timer.timeout.connect(_cleanup_old_chunks)
	_cleanup_timer.start()

func get_chunk(chunk_pos: Vector3) -> ChunkData:
	if chunk_pos in _active_chunks:
		_update_chunk_access(chunk_pos)
		return _active_chunks[chunk_pos]
		
	var chunk: ChunkData
	if not _available_chunks.is_empty():
		chunk = _available_chunks.pop_back()
		chunk.clear()  # Reset chunk data
	else:
		chunk = ChunkData.new()
	
	_active_chunks[chunk_pos] = chunk
	_update_chunk_access(chunk_pos)
	return chunk

func return_chunk(chunk_pos: Vector3) -> void:
	if not chunk_pos in _active_chunks:
		return
		
	var chunk = _active_chunks[chunk_pos]
	_active_chunks.erase(chunk_pos)
	_last_access_times.erase(chunk_pos)
	
	if _available_chunks.size() < POOL_SIZE:
		chunk.clear()
		_available_chunks.push_back(chunk)

func _update_chunk_access(chunk_pos: Vector3) -> void:
	_last_access_times[chunk_pos] = Time.get_unix_time_from_system()

func _cleanup_old_chunks() -> void:
	var current_time = Time.get_unix_time_from_system()
	
	for chunk_pos in _active_chunks.keys():
		var last_access = _last_access_times.get(chunk_pos, 0)
		var chunk = _active_chunks[chunk_pos]
		
		if current_time - last_access > COMPRESSION_THRESHOLD and not chunk.is_compressed():
			chunk.compress_data()
		elif current_time - last_access < COMPRESSION_THRESHOLD and chunk.is_compressed():
			chunk.decompress_data()
