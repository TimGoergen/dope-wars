class_name DevTuningOverlay
extends ColorRect

# American Tycoon-style On-Device Balance Tuning Panel (GDD v1.1 §9.2).
# Edits live TuningConfig values and saves changes to user://tuning_overrides.json.

signal tuning_applied()

var _tuning: TuningConfig
var _inputs: Dictionary = {}

const TUNABLE_KEYS := [
	["starting_cash", "Starting Cash ($)", true],
	["starting_debt", "Starting Debt ($)", true],
	["starting_capacity", "Starting Coat Pockets", true],
	["loan_interest_rate", "Big Sal Daily Interest (0.10 = 10%)", false],
	["bank_interest_rate", "Bank Daily Interest (0.05 = 5%)", false],
	["street_atm_fee_rate", "Street ATM Fee (0.05 = 5%)", false],
	["market_availability_chance", "Market Drug Availability (0.75)", false],
	["spike_multiplier", "Spike Event Multiplier (4.0)", false],
	["flood_divisor", "Flood Event Divisor (4.0)", false],
	["event_slot_chance", "Daily Event Slot Chance (0.35)", false],
	["heat_per_cop_kill", "Heat Gained per Cop Kill", false],
	["heat_bellevue_decay", "Bellevue Daily Heat Decay", false],
	["crew_encounter_hp", "Crew Member Shootout HP", true],
	["base_escape_chance", "Base Police Run Chance (0.55)", false]
]


func _init() -> void:
	color = UiPalette.MODAL_BACKDROP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open_panel(tuning: TuningConfig) -> void:
	_tuning = tuning
	_inputs.clear()
	for c in get_children():
		c.queue_free()

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(960, 0)
	card.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.PANEL_BG, UiPalette.BANK_CYAN, 18, 3, 30, 24))
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := UiPalette.add_label(header, "⚙️ BALANCE TUNING DEV PANEL (tuning.tres)", UiPalette.FONT_HEADER, UiPalette.BANK_CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(64, 54)
	UiPalette.style_button(close_btn, UiPalette.CARD_BG, UiPalette.BORDER_SLATE)
	close_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		visible = false
	)
	header.add_child(close_btn)

	for item in TUNABLE_KEYS:
		var key := String(item[0])
		var label_txt := String(item[1])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		vbox.add_child(row)

		var lbl := UiPalette.add_label(row, label_txt, UiPalette.FONT_SMALL, UiPalette.TEXT_PRIMARY)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var edit := LineEdit.new()
		edit.custom_minimum_size = Vector2(220, 48)
		edit.text = str(_tuning.get(key))
		edit.add_theme_font_size_override("font_size", UiPalette.FONT_SMALL)
		row.add_child(edit)
		_inputs[key] = {"edit": edit, "is_int": bool(item[2])}

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 14)
	vbox.add_child(btn_row)

	var save_btn := Button.new()
	save_btn.text = "💾 SAVE & APPLY OVERRIDES"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.custom_minimum_size = Vector2(0, 72)
	UiPalette.style_button(save_btn, UiPalette.BTN_SUCCESS, UiPalette.CASH_EMERALD)
	save_btn.pressed.connect(func() -> void:
		var overrides := TuningOverrides.load_overrides()
		for key in _inputs.keys():
			var info: Dictionary = _inputs[key]
			var edit: LineEdit = info["edit"]
			var raw := edit.text.strip_edges()
			if raw.is_valid_float() or raw.is_valid_int():
				var val: Variant = int(raw) if bool(info["is_int"]) else float(raw)
				overrides[key] = val
				_tuning.set(key, val)
		TuningOverrides.save(overrides)
		Audio.play(&"cash_register")
		visible = false
		tuning_applied.emit()
	)
	btn_row.add_child(save_btn)

	var reset_btn := Button.new()
	reset_btn.text = "🔄 RESET TO DEFAULTS"
	reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_btn.custom_minimum_size = Vector2(0, 72)
	UiPalette.style_button(reset_btn, UiPalette.BTN_DANGER, UiPalette.DEBT_CRIMSON)
	reset_btn.pressed.connect(func() -> void:
		TuningOverrides.clear()
		var fresh := ConfigLoader.load_tuning(false)
		for item in TUNABLE_KEYS:
			var k := String(item[0])
			_tuning.set(k, fresh.get(k))
		Audio.play(&"sell_loss")
		visible = false
		tuning_applied.emit()
	)
	btn_row.add_child(reset_btn)

	visible = true
