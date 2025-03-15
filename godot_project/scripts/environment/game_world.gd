extends Node3D

@onready var chunk_manager: ChunkManager = $ChunkManager
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	if chunk_manager:
		camera.position = Vector3(0, 32, 0)
		chunk_manager.update_chunks(camera.global_position)

func _physics_process(_delta):
	if chunk_manager:
		chunk_manager.update_chunks(camera.global_position)

func _exit_tree() -> void:
	if chunk_manager:
		chunk_manager.cleanup()
