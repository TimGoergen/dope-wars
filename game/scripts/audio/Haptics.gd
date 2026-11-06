class_name Haptics
extends RefCounted

# Safe single-site Android vibration wrapper (modeled after American Tycoon's Haptics.gd).
# Enforces a 15ms–500ms pulse clamp and 40ms rate limit so mobile JNI VibratorService never floods.

static var scale: float = 1.0

const MIN_SAFE_VIBRATION_MS := 15.0
const MAX_SAFE_VIBRATION_MS := 500.0

static var _last_vibrate_ms: int = 0


static func pulse(duration_ms: float) -> void:
	if scale <= 0.01 or duration_ms <= 0.0:
		return
	var now := Time.get_ticks_msec()
	if now - _last_vibrate_ms < 40:
		return
	var scaled := duration_ms * scale
	if scaled >= MIN_SAFE_VIBRATION_MS and OS.has_feature("mobile"):
		var ms := clampi(int(scaled), int(MIN_SAFE_VIBRATION_MS), int(MAX_SAFE_VIBRATION_MS))
		_last_vibrate_ms = now
		Input.vibrate_handheld(ms)
