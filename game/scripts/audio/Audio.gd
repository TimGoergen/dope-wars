extends Node

# THE AUDIO SINGLETON (registered in project.godot as `Audio`).
# Supports drop-in .wav/.ogg files in res://audio/cues/ AND includes a built-in
# Procedural PCM AudioStreamWAV Synthesizer so all cues sound crisp out of the box
# with zero external asset dependencies, while staying 100% silent in --headless mode.

const CUES_DIR := "res://audio/cues/"
const BUS_MASTER := &"Master"
const BUS_SFX := &"SFX"
const BUS_UI := &"UI"
const SAMPLE_RATE := 22050
const POOL_SIZE := 8

var muted: bool = false
var sfx_volume: float = 1.0

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _last_play_ms: Dictionary = {}
var _is_headless: bool = false


func _ready() -> void:
	_is_headless = (DisplayServer.get_name() == "headless")
	if _is_headless:
		return
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_players.append(p)
	_build_synth_cues()


func play(cue: StringName, pitch_scale: float = 1.0) -> void:
	if _is_headless or muted or sfx_volume <= 0.01:
		return
	var now := Time.get_ticks_msec()
	var last: int = int(_last_play_ms.get(cue, -9999))
	if now - last < 35:
		return
	_last_play_ms[cue] = now

	var stream: AudioStream = _resolve_stream(cue)
	if stream == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = pitch_scale
			p.volume_db = linear_to_db(clampf(sfx_volume, 0.01, 1.0)) - 4.0
			p.play()
			return


func _resolve_stream(cue: StringName) -> AudioStream:
	if _streams.has(cue):
		return _streams[cue]
	var wav_path := CUES_DIR + String(cue) + ".wav"
	if ResourceLoader.exists(wav_path):
		var s := load(wav_path) as AudioStream
		_streams[cue] = s
		return s
	return null


func _build_synth_cues() -> void:
	_streams[&"tap"] = _synth_tone(620.0, 480.0, 0.035, 0.25, false)
	_streams[&"buy"] = _synth_dual_tone(523.25, 659.25, 0.09, 0.35)
	_streams[&"sell_profit"] = _synth_arpeggio([587.33, 783.99, 1046.50], 0.055, 0.42)
	_streams[&"sell_loss"] = _synth_tone(340.0, 210.0, 0.12, 0.35, false)
	_streams[&"drive_engine"] = _synth_tone(95.0, 145.0, 0.14, 0.32, true)
	_streams[&"event_spike"] = _synth_arpeggio([659.25, 880.0, 1174.66], 0.06, 0.40)
	_streams[&"event_flood"] = _synth_arpeggio([880.0, 659.25, 440.0], 0.06, 0.38)
	_streams[&"cop_siren"] = _synth_siren(0.28, 0.42)
	_streams[&"gunshot"] = _synth_tone(180.0, 45.0, 0.11, 0.50, true)
	_streams[&"cash_register"] = _synth_arpeggio([987.77, 1318.51], 0.065, 0.40)
	_streams[&"enforcer_hit"] = _synth_tone(140.0, 55.0, 0.16, 0.48, true)
	_streams[&"victory_fanfare"] = _synth_arpeggio([523.25, 659.25, 783.99, 1046.50], 0.075, 0.45)


func _synth_tone(f_start: float, f_end: float, duration: float, amp: float, add_noise: bool) -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f_start * 100.0)
	for i in range(count):
		var t := float(i) / float(max(count - 1, 1))
		var freq := lerpf(f_start, f_end, t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var env := (1.0 - t) * (1.0 - t)
		var sample := sin(phase) * amp * env
		if add_noise:
			sample += rng.randf_range(-0.5, 0.5) * amp * env * 0.75
		var pcm := clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF
	return _make_wav(data)


func _synth_dual_tone(f1: float, f2: float, duration: float, amp: float) -> AudioStreamWAV:
	return _synth_arpeggio([f1, f2], duration * 0.5, amp)


func _synth_arpeggio(freqs: Array, step_dur: float, amp: float) -> AudioStreamWAV:
	var step_samples := int(SAMPLE_RATE * step_dur)
	var total := step_samples * freqs.size()
	var data := PackedByteArray()
	data.resize(total * 2)
	var phase := 0.0
	for s in range(freqs.size()):
		var freq := float(freqs[s])
		for i in range(step_samples):
			var idx := s * step_samples + i
			var t := float(i) / float(max(step_samples - 1, 1))
			var env := 1.0 - (t * 0.65)
			phase += TAU * freq / float(SAMPLE_RATE)
			var sample := (sin(phase) + 0.25 * sin(phase * 2.0)) * amp * env * 0.8
			var pcm := clampi(int(sample * 32767.0), -32768, 32767)
			data[idx * 2] = pcm & 0xFF
			data[idx * 2 + 1] = (pcm >> 8) & 0xFF
	return _make_wav(data)


func _synth_siren(duration: float, amp: float) -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in range(count):
		var t := float(i) / float(max(count - 1, 1))
		var freq := lerpf(640.0, 960.0, absf(sin(t * PI * 2.0)))
		phase += TAU * freq / float(SAMPLE_RATE)
		var env := 1.0 - (t * 0.25)
		var sample := sin(phase) * amp * env
		var pcm := clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF
	return _make_wav(data)


func _make_wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav
