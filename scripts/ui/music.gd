extends AudioStreamPlayer

# Add future tracks here in playback order; preload includes them in exports.
const TRACKS = [
	preload("res://assets/audio/beyond_evergreen_sea_final.ogg"),
	preload("res://assets/audio/rain_crow_whispers.mp3"),
	preload("res://assets/audio/crow_calls_over_rain_mix.mp3")
]
const TITLES = ["Beyond Evergreen Sea", "雨幕鸦语", "Crow Calls over Rain（混音）"]
const TRACK_GAP_SECONDS = 10.0
var track_index = -1
var gap_timer: Timer

func _ready() -> void:
	gap_timer = Timer.new()
	gap_timer.one_shot = true
	gap_timer.wait_time = TRACK_GAP_SECONDS
	gap_timer.ignore_time_scale = true
	add_child(gap_timer)
	gap_timer.timeout.connect(play_next)
	finished.connect(func(): gap_timer.start())

func play_next() -> void:
	if TRACKS.is_empty(): return
	gap_timer.stop()
	track_index = (track_index + 1) % TRACKS.size()
	var next_stream = TRACKS[track_index].duplicate()
	next_stream.loop = false
	next_stream.resource_name = TITLES[track_index]
	stream = next_stream
	play()
