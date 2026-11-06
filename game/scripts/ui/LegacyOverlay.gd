class_name LegacyOverlay
extends ColorRect

# Omaha Kingpin Legacy & New Game Launcher modal (GDD v1.1 §9.1).
# Lets the player unlock & toggle any number of Starting Perks (no slot limit)
# and launch a 31-Day, 60-Day, 90-Day, or Endless run.

signal start_new_run_requested(mode_days: int)
signal meta_updated()

var _meta: Dictionary = {}


func _init() -> void:
	color = UiPalette.MODAL_BACKDROP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open_modal(meta: Dictionary) -> void:
	_meta = meta
	_rebuild()
	visible = true


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(980, 0)
	card.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.PANEL_BG, UiPalette.GOLD_ACCENT, 18, 3, 30, 26))
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	card.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := UiPalette.add_label(header, "🎖️ OMAHA KINGPIN LEGACY & NEW RUN", UiPalette.FONT_HEADER, UiPalette.GOLD_ACCENT)
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

	var cred := int(_meta.get("street_cred", 0))
	UiPalette.add_label(vbox, "⭐ Available Street Cred: %d   (All unlocked perks can be toggled ON simultaneously)" % cred, UiPalette.FONT_SUBHEAD, UiPalette.CASH_EMERALD)

	# 6 Legacy Perks List
	var unlocked: Array = _meta.get("unlocked_perks", [])
	var active: Array = _meta.get("active_perks", [])

	for p_def in OmahaCatalog.LEGACY_PERKS:
		var pid := String(p_def["id"])
		var is_unlocked := unlocked.has(pid)
		var is_active := active.has(pid)
		var cost := int(p_def["cost"])

		var row_box := PanelContainer.new()
		row_box.add_theme_stylebox_override("panel", UiPalette.make_box(
			UiPalette.CARD_BG if is_active else UiPalette.CARD_ALT_BG,
			UiPalette.CASH_EMERALD if is_active else UiPalette.BORDER_SLATE,
			10, 2, 16, 10
		))
		vbox.add_child(row_box)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row_box.add_child(row)

		var txt_col := VBoxContainer.new()
		txt_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(txt_col)
		UiPalette.add_label(txt_col, String(p_def["name"]), UiPalette.FONT_ROW_MAIN, UiPalette.GOLD_ACCENT if is_unlocked else UiPalette.TEXT_PRIMARY)
		UiPalette.add_label(txt_col, String(p_def["desc"]), UiPalette.FONT_SMALL, UiPalette.TEXT_SECONDARY)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(210, 58)
		if is_unlocked:
			btn.text = "✅ ACTIVE" if is_active else "⚪ OFF"
			UiPalette.style_button(btn, UiPalette.BTN_SUCCESS if is_active else UiPalette.CARD_BG, UiPalette.CASH_EMERALD if is_active else UiPalette.BORDER_SLATE)
			btn.pressed.connect(func() -> void:
				SaveManager.toggle_perk(_meta, pid)
				Audio.play(&"tap")
				meta_updated.emit()
				_rebuild()
			)
		else:
			btn.text = "Unlock (%d ⭐)" % cost
			btn.disabled = (cred < cost)
			UiPalette.style_button(btn, UiPalette.BTN_PRIMARY, UiPalette.GOLD_ACCENT)
			btn.pressed.connect(func() -> void:
				var res := SaveManager.unlock_perk(_meta, pid)
				if bool(res.get("ok", false)):
					Audio.play(&"victory_fanfare")
					Haptics.pulse(30.0)
					meta_updated.emit()
					_rebuild()
			)
		row.add_child(btn)

	# Game Length Selector
	UiPalette.add_label(vbox, "🚗 Start New Run (Select Campaign Length):", UiPalette.FONT_SUBHEAD, UiPalette.BANK_CYAN)
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 12)
	vbox.add_child(mode_row)

	for pair in [["31 Days (Classic)", 31], ["60 Days", 60], ["90 Days", 90], ["Endless", 0]]:
		var b := Button.new()
		b.text = String(pair[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 74)
		var days_val := int(pair[1])
		UiPalette.style_button(b, UiPalette.BTN_SUCCESS if days_val == 31 else UiPalette.BTN_PRIMARY, UiPalette.CASH_EMERALD if days_val == 31 else UiPalette.BANK_CYAN)
		b.pressed.connect(func() -> void:
			Audio.play(&"drive_engine")
			Haptics.pulse(25.0)
			visible = false
			start_new_run_requested.emit(days_val)
		)
		mode_row.add_child(b)
