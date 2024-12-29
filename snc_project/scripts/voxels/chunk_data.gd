class_name ChunkData
extends Resource

# Constants for chunk dimensions
const CHUNK_SIZE := 16  # Single dimension size
const CHUNK_VOLUME := CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE
const chunk_size := Vector3(CHUNK_SIZE, CHUNK_SIZE, CHUNK_SIZE)
const EMPTY_BLOCK := 0

# Member variables
var _voxels: PackedInt32Array
var _compressed_data: PackedByteArray
var _is_compressed := false
var _dirty := false
var chunk_position: Vector3

func _init() -> void:
	clear()

func clear() -> void:
	_voxels = PackedInt32Array()
	_voxels.resize(CHUNK_VOLUME)  # Use the volume constant
	_voxels.fill(EMPTY_BLOCK)
	_compressed_data = PackedByteArray()
	_is_compressed = false
	_dirty = false

func get_voxel_positions() -> Array:
	var positions = []
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			for z in range(CHUNK_SIZE):
				var pos = Vector3(x, y, z)
				var index = get_index(pos)
				if _voxels[index] != EMPTY_BLOCK:
					positions.append(pos)
	return positions

func local_to_world(local_pos: Vector3) -> Vector3:
	# Convert local chunk coordinates to world coordinates
	# by adding the chunk's position * chunk size
	return local_pos + chunk_position * Vector3(CHUNK_SIZE, CHUNK_SIZE, CHUNK_SIZE)

func world_to_local(world_pos: Vector3) -> Vector3:
	# Convert world coordinates to local chunk coordinates
	# by subtracting the chunk's position * chunk size
	return world_pos - chunk_position * Vector3(CHUNK_SIZE, CHUNK_SIZE, CHUNK_SIZE)

func compress_data() -> void:
	if _is_compressed or _voxels.is_empty():
		return
		
	# First, optimize the data format for compression
	var optimized_data := PackedByteArray()
	var current_value := _voxels[0]
	var count := 1
	
	# Run-length encoding for consecutive same values
	for i in range(1, _voxels.size()):
		if _voxels[i] == current_value and count < 255:
			count += 1
		else:
			optimized_data.append(count)
			optimized_data.append(current_value)
			current_value = _voxels[i]
			count = 1
	
	# Add the last run
	if count > 0:
		optimized_data.append(count)
		optimized_data.append(current_value)
	
	# Compress the optimized data
	_compressed_data = optimized_data.compress(FileAccess.COMPRESSION_GZIP)
	_voxels = PackedInt32Array()  # Clear uncompressed data
	_is_compressed = true

func setup(pos: Vector3) -> void:
	chunk_position = pos
	clear()

func decompress_data() -> void:
	if not _is_compressed:
		return
		
	var decompressed = _compressed_data.decompress(
		CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE * 4,  # Maximum possible size
		FileAccess.COMPRESSION_GZIP
	)
	
	_voxels = PackedInt32Array()
	_voxels.resize(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE)
	var index := 0
	
	# Decode run-length encoding
	var i := 0
	while i < decompressed.size() - 1:
		var count = decompressed[i]
		var value = decompressed[i + 1]
		
		for j in range(count):
			if index < _voxels.size():
				_voxels[index] = value
				index += 1
		
		i += 2
	
	_compressed_data = PackedByteArray()
	_is_compressed = false

func get_voxel(pos: Vector3) -> int:
	if _is_compressed:
		decompress_data()
	
	var index = get_index(pos)
	if index == -1:
		return EMPTY_BLOCK
	return _voxels[index]

func set_voxel(pos: Vector3, value: int) -> void:
	if _is_compressed:
		decompress_data()
	
	var index = get_index(pos)
	if index != -1:
		_voxels[index] = value
		_dirty = true

func get_index(pos: Vector3) -> int:
	if not is_position_valid(pos):
		return -1
		
	return int(pos.x + (pos.y * CHUNK_SIZE) + (pos.z * CHUNK_SIZE * CHUNK_SIZE))

func is_position_valid(pos: Vector3) -> bool:
	return pos.x >= 0 and pos.x < CHUNK_SIZE and \
		   pos.y >= 0 and pos.y < CHUNK_SIZE and \
		   pos.z >= 0 and pos.z < CHUNK_SIZE

func is_compressed() -> bool:
	return _is_compressed

func is_dirty() -> bool:
	return _dirty
