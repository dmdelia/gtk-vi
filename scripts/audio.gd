extends AudioStreamPlayer
## Royalty-free procedural factory drone and simple four-beat score.
var game
var synth: AudioStreamGeneratorPlayback
var sample_counter = 0.0
var hum_phase = 0.0
var chirp = 0.0
var enabled = true
const RATE = 22050.0

func _ready() -> void:
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = RATE
	generator.buffer_length = 0.17
	stream = generator
	volume_db = -25.0
	play()
	synth = get_stream_playback() as AudioStreamGeneratorPlayback

func _process(_delta: float) -> void:
	if synth == null or not enabled:
		return
	var frames = mini(synth.get_frames_available(),3000)
	for i in frames:
		var seconds = sample_counter / RATE
		var time_beat = fmod(seconds*1.75,1.0)
		var tune = sin(TAU*55.0*seconds)*0.12 + sin(TAU*82.4*seconds)*0.045
		var kick = sin(TAU*(52+120*(1-time_beat))*seconds)*pow(1-time_beat,12)*0.26
		var snare = sin(TAU*2007*seconds)*pow(1.0-fmod(seconds*3.5,1.0),25)*0.02
		var engine_hum = sin(TAU*41*seconds)*0.11 + sin(TAU*123*seconds)*0.035
		var ambient = tune+kick+snare+engine_hum
		if game != null and game.mode != "menu":
			ambient = ambient*0.35 + engine_hum*0.7
		if game != null and game.current_vehicle != null:
			ambient += sin(TAU*(85+absf(game.current_vehicle.speed)*5)*seconds)*0.1
		synth.push_frame(Vector2(ambient,ambient*0.93))
		sample_counter += 1
