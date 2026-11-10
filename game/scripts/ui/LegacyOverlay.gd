class_name LegacyOverlay
extends ColorRect

# Omaha Kingpin Legacy & Perks modal and Tab 3 builder (GDD v1.1 §9.1).
# Note: Starting a new run is exclusively handled from the Start Screen.

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

	var vbox := UiPalette.build_modal_shell(self, "🎖️ KINGPIN LEGACY & PERKS", UiPalette.GOLD_ACCENT, true)

	build_legacy_section(
		vbox,
		_meta,
		func() -> void:
			meta_updated.emit()
			_rebuild()
	)


static func build_legacy_section(
	vbox: VBoxContainer,
	meta: Dictionary,
	on_meta_changed: Callable,
	_on_start_run: Callable = Callable()
) -> void:
	var cred := int(meta.get("street_cred", 0))
	UiPalette.add_label(vbox, "⭐ Street Cred: %d  (Toggle any unlocked perks ON)" % cred, UiPalette.FONT_SUBHEAD, UiPalette.CASH_EMERALD)

	# 6 Legacy Perks List
	var unlocked: Array = meta.get("unlocked_perks", [])
	var active: Array = meta.get("active_perks", [])

	for p_def in OmahaCatalog.LEGACY_PERKS:
		var pid := String(p_def["id"])
		var is_unlocked := unlocked.has(pid)
		var is_active := active.has(pid)
		var cost := int(p_def["cost"])

		var row_box := PanelContainer.new()
		row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_box.add_theme_stylebox_override("panel", UiPalette.make_box(
			UiPalette.CARD_BG if is_active else UiPalette.CARD_ALT_BG,
			UiPalette.CASH_EMERALD if is_active else UiPalette.BORDER_SLATE,
			14, 2, 16, 14
		))
		vbox.add_child(row_box)

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 12)
		row_box.add_child(row)

		var txt_col := VBoxContainer.new()
		txt_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(txt_col)
		UiPalette.add_label(txt_col, String(p_def["name"]), UiPalette.FONT_ROW_MAIN, UiPalette.GOLD_ACCENT if is_unlocked else UiPalette.TEXT_PRIMARY)
		UiPalette.add_label(txt_col, String(p_def["desc"]), UiPalette.FONT_SMALL, UiPalette.TEXT_SECONDARY)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(230, 78)
		if is_unlocked:
			btn.text = "✅ ON" if is_active else "⚪ OFF"
			UiPalette.style_button(btn, UiPalette.BTN_SUCCESS if is_active else UiPalette.CARD_BG, UiPalette.CASH_EMERALD if is_active else UiPalette.BORDER_SLATE)
			btn.pressed.connect(func() -> void:
				SaveManager.toggle_perk(meta, pid)
				Audio.play(&"tap")
				on_meta_changed.call()
			)
		else:
			btn.text = "%d ⭐" % cost
			btn.disabled = (cred < cost)
			UiPalette.style_button(btn, UiPalette.BTN_PRIMARY, UiPalette.GOLD_ACCENT)
			btn.pressed.connect(func() -> void:
				var res := SaveManager.unlock_perk(meta, pid)
				if bool(res.get("ok", false)):
					Audio.play(&"victory_fanfare")
					Haptics.pulse(30.0)
					on_meta_changed.call()
			)
		row.add_child(btn)
