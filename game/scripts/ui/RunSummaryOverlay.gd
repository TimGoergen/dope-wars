class_name RunSummaryOverlay
extends ColorRect

# End-of-Run Settlement & Persistent Hall of Fame Leaderboard modal.

signal play_again_requested()

var _state: GameState
var _meta: Dictionary


func _init() -> void:
	color = UiPalette.MODAL_BACKDROP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open_summary(state: GameState, meta: Dictionary, show_run_banner: bool = true) -> void:
	_state = state
	_meta = meta
	for c in get_children():
		c.queue_free()

	var header_text := "🏆 OMAHA HALL OF FAME"
	if show_run_banner and (_state.run_completed or _state.game_over):
		header_text = "🏆 RUN COMPLETE!" if _state.run_completed else "💀 WASTED IN OMAHA"

	var vbox := UiPalette.build_modal_shell(
		self,
		header_text,
		UiPalette.GOLD_ACCENT if not _state.game_over else UiPalette.DEBT_CRIMSON,
		true
	)

	if show_run_banner and (_state.run_completed or _state.game_over):
		var summary_box := PanelContainer.new()
		summary_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary_box.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_BG, UiPalette.BORDER_BRIGHT, 14, 2, 20, 16))
		vbox.add_child(summary_box)
		var sv := VBoxContainer.new()
		sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sv.add_theme_constant_override("separation", 10)
		summary_box.add_child(sv)

		UiPalette.add_label(sv, "Final Net Worth: %s" % Money.format(_state.final_net_worth), UiPalette.FONT_HEADER, UiPalette.CASH_EMERALD if _state.final_net_worth >= 0 else UiPalette.DEBT_CRIMSON)
		UiPalette.add_label(sv, "Fate: %s" % _state.end_fate, UiPalette.FONT_ROW_MAIN, UiPalette.TEXT_PRIMARY)
		UiPalette.add_label(sv, "Street Cred Earned: +%d ⭐ (Total: %d ⭐)" % [_state.street_cred_earned, int(_meta.get("street_cred", 0))], UiPalette.FONT_SUBHEAD, UiPalette.GOLD_ACCENT)

	# Hall of Fame Table
	UiPalette.add_label(vbox, "Top Omaha Metro Runs:", UiPalette.FONT_SUBHEAD, UiPalette.BANK_CYAN)
	var hof: Array = _meta.get("hall_of_fame", [])
	if hof.is_empty():
		UiPalette.add_label(vbox, "No completed runs recorded yet. Finish Day 31 to claim the crown!", UiPalette.FONT_ROW_MAIN, UiPalette.TEXT_MUTED)
	else:
		var max_rows := mini(10, hof.size())
		for i in range(max_rows):
			var entry: Dictionary = hof[i]
			var r_box := PanelContainer.new()
			r_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r_box.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_ALT_BG, UiPalette.BORDER_SLATE, 10, 1, 16, 10))
			vbox.add_child(r_box)
			var r_hb := HBoxContainer.new()
			r_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r_hb.add_theme_constant_override("separation", 12)
			r_box.add_child(r_hb)

			var rank_lbl := UiPalette.add_label(r_hb, "#%d  %s" % [i + 1, Money.format_short(int(entry.get("net_worth", 0)))], UiPalette.FONT_ROW_MAIN, UiPalette.CASH_EMERALD if bool(entry.get("survived", true)) else UiPalette.DEBT_CRIMSON, false)
			rank_lbl.custom_minimum_size = Vector2(240, 0)

			var fate_lbl := UiPalette.add_label(r_hb, "%s (Day %d)" % [String(entry.get("fate", "")), int(entry.get("days", 31))], UiPalette.FONT_SMALL, UiPalette.TEXT_SECONDARY)
			fate_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var new_btn := Button.new()
	new_btn.text = "🚗 NEW RUN / PERKS"
	new_btn.custom_minimum_size = Vector2(0, 88)
	UiPalette.style_button(new_btn, UiPalette.BTN_SUCCESS, UiPalette.CASH_EMERALD, UiPalette.TEXT_PRIMARY, UiPalette.FONT_HEADER)
	new_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		visible = false
		play_again_requested.emit()
	)
	vbox.add_child(new_btn)
	visible = true
