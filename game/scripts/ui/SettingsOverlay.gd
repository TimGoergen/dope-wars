class_name SettingsOverlay
extends ColorRect

# Settings Modal Overlay for Dope Wars: Omaha.
# Houses Master Audio controls (Mute toggle, SFX Volume slider, Haptics),
# and a Balance Tuning portal that links to DevTuningOverlay and returns here.
# Features a top-right 'x' close button and always returns the player to
# whichever screen opened it (Start Screen or Kingpin Screen).

signal settings_closed()
signal tuning_requested()

var _meta: Dictionary = {}
var _tuning: TuningConfig
var _source_screen: String = ""
var _on_close_cb: Callable = Callable()

var _mute_btn: Button
var _vol_slider: HSlider
var _vol_val_lbl: Label
var _haptic_btn: Button


func _init() -> void:
	color = UiPalette.MODAL_BACKDROP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open_settings(meta: Dictionary, tuning: TuningConfig, source: String = "", on_close: Callable = Callable()) -> void:
	_meta = meta
	_tuning = tuning
	_source_screen = source
	_on_close_cb = on_close

	for c in get_children():
		c.queue_free()

	move_to_front()

	var vbox := UiPalette.build_modal_shell(
		self,
		"⚙️ SETTINGS",
		UiPalette.BANK_CYAN,
		true,
		_on_close_pressed
	)
	vbox.add_theme_constant_override("separation", 24)

	# 1. AUDIO & SOUND EFFECTS CARD
	var audio_card := PanelContainer.new()
	audio_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_card.add_theme_stylebox_override(
		"panel",
		UiPalette.make_box(UiPalette.CARD_BG, UiPalette.BANK_CYAN, 18, 3, 22, 20)
	)
	vbox.add_child(audio_card)

	var audio_vbox := VBoxContainer.new()
	audio_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_vbox.add_theme_constant_override("separation", 16)
	audio_card.add_child(audio_vbox)

	UiPalette.add_label(audio_vbox, "🔊 AUDIO & SOUND EFFECTS", 40, UiPalette.BANK_CYAN, false, true)
	UiPalette.add_label(audio_vbox, "Configure game sound effects, master mute, and vibration feedback.", 30, UiPalette.TEXT_SECONDARY)

	# Master Mute Button
	_mute_btn = Button.new()
	_mute_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mute_btn.custom_minimum_size = Vector2(0, 96)
	_update_mute_btn_visual()
	_mute_btn.pressed.connect(func() -> void:
		Audio.muted = not Audio.muted
		_meta["muted"] = Audio.muted
		SaveManager.save_data(_meta)
		if not Audio.muted:
			Audio.play(&"cash_register")
		_update_mute_btn_visual()
	)
	audio_vbox.add_child(_mute_btn)

	# SFX Volume Slider Row
	var vol_hdr := HBoxContainer.new()
	vol_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_hdr.add_theme_constant_override("separation", 10)
	audio_vbox.add_child(vol_hdr)

	var vol_title := UiPalette.add_label(vol_hdr, "Sound Effects Volume", 34, UiPalette.TEXT_PRIMARY, false, true)
	vol_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var cur_pct := int(round(clampf(Audio.sfx_volume, 0.0, 1.0) * 100.0))
	_vol_val_lbl = UiPalette.add_label(vol_hdr, "%d%%" % cur_pct, 34, UiPalette.GOLD_ACCENT, false, true)

	_vol_slider = HSlider.new()
	_vol_slider.min_value = 0.0
	_vol_slider.max_value = 100.0
	_vol_slider.step = 5.0
	_vol_slider.value = float(cur_pct)
	_vol_slider.custom_minimum_size = Vector2(0, 60)
	_vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiPalette.style_slider(_vol_slider)
	_vol_slider.value_changed.connect(func(val: float) -> void:
		var vol := clampf(val / 100.0, 0.0, 1.0)
		Audio.sfx_volume = vol
		_meta["sfx_volume"] = vol
		SaveManager.save_data(_meta)
		if _vol_val_lbl != null:
			_vol_val_lbl.text = "%d%%" % int(val)
		Audio.play(&"tap")
	)
	audio_vbox.add_child(_vol_slider)

	# Haptics Row
	var haptic_row := HBoxContainer.new()
	haptic_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haptic_row.add_theme_constant_override("separation", 14)
	audio_vbox.add_child(haptic_row)

	var haptic_title := UiPalette.add_label(haptic_row, "Haptic Vibration", 34, UiPalette.TEXT_PRIMARY, false, true)
	haptic_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_haptic_btn = Button.new()
	_haptic_btn.custom_minimum_size = Vector2(240, 80)
	_update_haptic_btn_visual()
	_haptic_btn.pressed.connect(func() -> void:
		var was_on := (Haptics.scale > 0.01)
		Haptics.scale = 0.0 if was_on else 1.0
		_meta["haptics_enabled"] = (Haptics.scale > 0.01)
		SaveManager.save_data(_meta)
		if Haptics.scale > 0.01:
			Haptics.pulse(30.0)
		_update_haptic_btn_visual()
	)
	haptic_row.add_child(_haptic_btn)

	# 2. GAME BALANCE & DEV TUNING CARD
	var tuning_card := PanelContainer.new()
	tuning_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tuning_card.add_theme_stylebox_override(
		"panel",
		UiPalette.make_box(UiPalette.CARD_BG, UiPalette.GOLD_ACCENT, 18, 3, 22, 20)
	)
	vbox.add_child(tuning_card)

	var tuning_vbox := VBoxContainer.new()
	tuning_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tuning_vbox.add_theme_constant_override("separation", 16)
	tuning_card.add_child(tuning_vbox)

	UiPalette.add_label(tuning_vbox, "⚙️ GAME ENGINE & BALANCE", 40, UiPalette.GOLD_ACCENT, false, true)
	UiPalette.add_label(
		tuning_vbox,
		"American Tycoon balance console: starting cash, debt, coat capacity, cop encounters, Big Sal interest, and event odds.",
		30,
		UiPalette.TEXT_SECONDARY
	)

	var open_tuning_btn := Button.new()
	open_tuning_btn.text = "⚙️ OPEN BALANCE TUNING"
	open_tuning_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_tuning_btn.custom_minimum_size = Vector2(0, 108)
	UiPalette.style_button(
		open_tuning_btn,
		UiPalette.BTN_PRIMARY,
		UiPalette.GOLD_ACCENT,
		UiPalette.GOLD_ACCENT,
		38,
		14
	)
	open_tuning_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		# Hide settings temporarily while tuning is open
		visible = false
		tuning_requested.emit()
	)
	tuning_vbox.add_child(open_tuning_btn)

	visible = true


func _update_mute_btn_visual() -> void:
	if _mute_btn == null:
		return
	if Audio.muted:
		_mute_btn.text = "🔇 AUDIO MUTED (TAP TO UNMUTE)"
		UiPalette.style_button(
			_mute_btn,
			UiPalette.BTN_DANGER,
			UiPalette.DEBT_CRIMSON,
			UiPalette.TEXT_PRIMARY,
			32,
			14
		)
	else:
		_mute_btn.text = "🔊 AUDIO ACTIVE (TAP TO MUTE)"
		UiPalette.style_button(
			_mute_btn,
			UiPalette.BTN_SUCCESS,
			UiPalette.CASH_EMERALD,
			UiPalette.TEXT_PRIMARY,
			32,
			14
		)


func _update_haptic_btn_visual() -> void:
	if _haptic_btn == null:
		return
	var on := (Haptics.scale > 0.01)
	_haptic_btn.text = "📳 Vibration ON" if on else "📴 Vibration OFF"
	UiPalette.style_button(
		_haptic_btn,
		UiPalette.CARD_ALT_BG,
		UiPalette.CASH_EMERALD if on else UiPalette.BORDER_SLATE,
		UiPalette.TEXT_PRIMARY if on else UiPalette.TEXT_MUTED,
		30,
		12
	)


func _on_close_pressed() -> void:
	visible = false
	if _on_close_cb.is_valid():
		var cb := _on_close_cb
		_on_close_cb = Callable()
		cb.call()
	settings_closed.emit()
