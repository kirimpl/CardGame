extends Node

@export var playlist: Array[AudioStream] = []
var player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	player = AudioStreamPlayer.new()
	add_child(player)
	
	player.bus = "Music"
	player.finished.connect(_play_random_track)
	
	_play_random_track()

func _play_random_track() -> void:
	if playlist.is_empty() or player == null:
		return
	
	var new_track: AudioStream = playlist.pick_random()
	if playlist.size() > 1:
		var guard := 0
		while player.stream == new_track and guard < 8:
			new_track = playlist.pick_random()
			guard += 1
		
	player.stream = new_track
	player.play()


func _exit_tree() -> void:
	if player == null:
		return
	if player.finished.is_connected(_play_random_track):
		player.finished.disconnect(_play_random_track)
	player.stop()
	player.stream = null
	player.queue_free()
	player = null
