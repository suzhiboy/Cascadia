extends Node

const CLIPS := {
	"tile_place": preload("res://assets/audio/sfx/tile_place.wav"),
	"token_place": preload("res://assets/audio/sfx/token_place.wav"),
	"rotate": preload("res://assets/audio/sfx/rotate.wav"),
	"refresh": preload("res://assets/audio/sfx/refresh.wav"),
	"turn_end": preload("res://assets/audio/sfx/turn_end.wav"),
	"game_end": preload("res://assets/audio/sfx/game_end.wav"),
	"ui_click": preload("res://assets/audio/sfx/ui_click.wav"),
	"error": preload("res://assets/audio/sfx/error.wav")
}

var player := AudioStreamPlayer.new()
var volume_db := 0.0:
	set(value):
		volume_db = value
		player.volume_db = value

func _ready() -> void:
	player.name = "Player"
	add_child(player)

func play(kind: String) -> void:
	player.stream = CLIPS[kind]
	player.play()
