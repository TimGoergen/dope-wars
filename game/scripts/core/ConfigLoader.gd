class_name ConfigLoader

# Loads res://config/tuning.tres and applies any developer overrides from user://tuning_overrides.json.

const TUNING_PATH := "res://config/tuning.tres"


static func load_tuning(apply_overrides: bool = true) -> TuningConfig:
	var base: TuningConfig = load(TUNING_PATH) as TuningConfig
	var tuning: TuningConfig
	if base != null:
		tuning = base.duplicate() as TuningConfig
	else:
		tuning = TuningConfig.new()
	if apply_overrides:
		var overrides := TuningOverrides.load_overrides()
		if not overrides.is_empty():
			TuningOverrides.apply(tuning, overrides)
	return tuning
