class_name RunSummaryOverlay
extends ColorRect

# End-of-Run Settlement & Persistent Hall of Fame Leaderboard modal with separate tabs for each game mode.

signal play_again_requested()

var _state: GameState
var _meta: Dictionary
var _selected_mode: String = "31"
var _tab_buttons: Dictionary = {}
var _mode_subhead_lbl: Label
var _hof_entries_container: VBoxContainer


func _init() -> void:
	color = UiPalette.MODAL_BACKDROP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open_summary(state: GameState, meta: Dictionary, show_run_banner: bool = true, default_mode: String = "") -> void:
	_state = state
	_meta = meta
	move_to_front()
	for c in get_children():
		c.queue_free()

	var is_end_of_run: bool = show_run_banner and (_state != null) and (_state.run_completed or _state.game_over)
	var header_text := "🏆 OMAHA HALL OF FAME"
	if is_end_of_run:
		header_text = "🏆 RUN COMPLETE!" if _state.run_completed else "💀 WASTED IN OMAHA"

	if default_mode != "":
		_selected_mode = default_mode
	elif is_end_of_run and _state != null:
		_selected_mode = SaveManager.get_mode_key(_state.max_days)
	else:
		_selected_mode = SaveManager.get_mode_key(int(_meta.get("preferred_mode_days", 31)))

	var border_color := UiPalette.GOLD_ACCENT
	if is_end_of_run and _state.game_over:
		border_color = UiPalette.DEBT_CRIMSON

	var vbox := UiPalette.build_modal_shell(
		self,
		header_text,
		border_color,
		true,
		func() -> void:
			visible = false
			if is_end_of_run:
				play_again_requested.emit()
	)

	if is_end_of_run:
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

	# Hall of Fame Section Header
	UiPalette.add_label(vbox, "Top Omaha Metro Runs:", UiPalette.FONT_SUBHEAD, UiPalette.GOLD_ACCENT)

	# Mode Tabs Row: [ 31 Days ] [ 60 Days ] [ 90 Days ] [ Endless ]
	var tabs_row := HBoxContainer.new()
	tabs_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_row.add_theme_constant_override("separation", 8)
	vbox.add_child(tabs_row)

	_tab_buttons.clear()
	for m_key in SaveManager.MODE_KEYS:
		var btn := Button.new()
		btn.text = SaveManager.get_mode_title(m_key)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 76)
		_style_tab_button(btn, m_key, m_key == _selected_mode)
		var this_mode: String = String(m_key)
		btn.pressed.connect(func() -> void:
			if _selected_mode != this_mode:
				Audio.play(&"tap")
				Haptics.pulse(20.0)
				_select_mode(this_mode)
		)
		tabs_row.add_child(btn)
		_tab_buttons[m_key] = btn

	# Mode Subhead Label
	_mode_subhead_lbl = UiPalette.add_label(
		vbox,
		"Top %s Runs • %s" % [SaveManager.get_mode_title(_selected_mode), SaveManager.get_mode_subtitle(_selected_mode)],
		UiPalette.FONT_BUTTON,
		_get_mode_accent_color(_selected_mode)
	)
	_mode_subhead_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Container for dynamic leaderboard entries
	_hof_entries_container = VBoxContainer.new()
	_hof_entries_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hof_entries_container.add_theme_constant_override("separation", 10)
	vbox.add_child(_hof_entries_container)

	_rebuild_hof_list()

	var new_btn := Button.new()
	if is_end_of_run:
		new_btn.text = "🏠 RETURN TO START SCREEN"
		new_btn.custom_minimum_size = Vector2(0, 96)
		UiPalette.style_button(new_btn, UiPalette.BTN_SUCCESS, UiPalette.CASH_EMERALD, UiPalette.TEXT_PRIMARY, UiPalette.FONT_HEADER)
		new_btn.pressed.connect(func() -> void:
			Audio.play(&"tap")
			visible = false
			play_again_requested.emit()
		)
	else:
		new_btn.text = "Close Leaderboard"
		new_btn.custom_minimum_size = Vector2(0, 84)
		UiPalette.style_button(new_btn, UiPalette.CARD_BG, UiPalette.BORDER_SLATE, UiPalette.TEXT_PRIMARY, UiPalette.FONT_BUTTON)
		new_btn.pressed.connect(func() -> void:
			Audio.play(&"tap")
			visible = false
		)
	vbox.add_child(new_btn)
	visible = true


func _select_mode(mode_key: String) -> void:
	_selected_mode = mode_key
	for k in _tab_buttons.keys():
		var b := _tab_buttons[k] as Button
		if b != null:
			_style_tab_button(b, k, k == _selected_mode)
	if _mode_subhead_lbl != null:
		var accent := _get_mode_accent_color(_selected_mode)
		_mode_subhead_lbl.text = "Top %s Runs • %s" % [
			SaveManager.get_mode_title(_selected_mode),
			SaveManager.get_mode_subtitle(_selected_mode)
		]
		_mode_subhead_lbl.add_theme_color_override("font_color", accent)
	_rebuild_hof_list()


func _rebuild_hof_list() -> void:
	if _hof_entries_container == null:
		return
	for c in _hof_entries_container.get_children():
		c.queue_free()

	var hof: Array = SaveManager.get_hall_of_fame(_meta, _selected_mode)
	if hof.is_empty():
		var empty_panel := PanelContainer.new()
		empty_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_panel.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_BG, UiPalette.BORDER_SLATE, 12, 1, 20, 20))
		_hof_entries_container.add_child(empty_panel)

		var ev := VBoxContainer.new()
		ev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ev.add_theme_constant_override("separation", 8)
		empty_panel.add_child(ev)

		var no_runs_lbl := UiPalette.add_label(
			ev,
			"No completed runs recorded yet for %s." % SaveManager.get_mode_title(_selected_mode),
			UiPalette.FONT_ROW_MAIN,
			UiPalette.TEXT_MUTED
		)
		no_runs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_runs_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		var tip_lbl := UiPalette.add_label(
			ev,
			"Survive the Omaha metro hustle to claim your spot on the leaderboard!",
			UiPalette.FONT_SMALL,
			UiPalette.TEXT_SECONDARY
		)
		tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return

	var max_rows := mini(15, hof.size())
	for i in range(max_rows):
		var entry: Dictionary = hof[i]
		var is_first: bool = (i == 0)
		var is_survived: bool = bool(entry.get("survived", true))
		var r_box := PanelContainer.new()
		r_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var border_col: Color = UiPalette.GOLD_ACCENT if is_first else UiPalette.BORDER_SLATE
		var border_w: int = 3 if is_first else 1
		r_box.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_ALT_BG, border_col, 12, border_w, 16, 12))
		_hof_entries_container.add_child(r_box)

		var r_hb := HBoxContainer.new()
		r_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r_hb.add_theme_constant_override("separation", 14)
		r_box.add_child(r_hb)

		# Rank Label
		var rank_str := "#1 👑" if is_first else ("#%d" % (i + 1))
		var rank_col: Color
		if is_first:
			rank_col = UiPalette.GOLD_ACCENT
		elif i == 1:
			rank_col = Color(0.85, 0.88, 0.95)
		elif i == 2:
			rank_col = Color(0.85, 0.60, 0.40)
		else:
			rank_col = UiPalette.TEXT_SECONDARY

		var rank_lbl := UiPalette.add_label(r_hb, rank_str, UiPalette.FONT_ROW_MAIN, rank_col, true)
		rank_lbl.custom_minimum_size = Vector2(90, 0)
		rank_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF

		# Net Worth Label
		var nw_val := int(entry.get("net_worth", 0))
		var nw_lbl := UiPalette.add_label(r_hb, Money.format_short(nw_val), UiPalette.FONT_ROW_MAIN, UiPalette.CASH_EMERALD if is_survived else UiPalette.DEBT_CRIMSON, true)
		nw_lbl.custom_minimum_size = Vector2(190, 0)
		nw_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF

		# Details Column
		var detail_vb := VBoxContainer.new()
		detail_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_vb.add_theme_constant_override("separation", 4)
		r_hb.add_child(detail_vb)

		var fate_str := String(entry.get("fate", "Retired"))
		var fate_lbl := UiPalette.add_label(detail_vb, fate_str, UiPalette.FONT_BUTTON, UiPalette.TEXT_PRIMARY)
		fate_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		var d_name := String(entry.get("district", "Omaha Metro"))
		var days_val := int(entry.get("days", 31))
		var max_d := int(entry.get("max_days", 31))
		var cred := int(entry.get("cred_earned", 0))

		var sub_info := ""
		if max_d <= 0 or bool(entry.get("is_endless", false)):
			sub_info = "%s • Day %d" % [d_name, days_val]
		else:
			sub_info = "%s • Day %d / %d" % [d_name, days_val, max_d]
		if cred > 0:
			sub_info += " • +%d ⭐" % cred

		var sub_lbl := UiPalette.add_label(detail_vb, sub_info, UiPalette.FONT_SMALL, UiPalette.TEXT_SECONDARY)
		sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _get_mode_accent_color(mode_key: String) -> Color:
	match mode_key:
		"60":
			return UiPalette.CASH_EMERALD
		"90":
			return UiPalette.GOLD_ACCENT
		"endless":
			return UiPalette.PURPLE_VIP
		_:
			return UiPalette.BANK_CYAN


func _style_tab_button(btn: Button, mode_key: String, is_active: bool) -> void:
	var accent := _get_mode_accent_color(mode_key)
	var bg := UiPalette.BTN_PRIMARY if is_active else UiPalette.CARD_BG
	var border := accent if is_active else UiPalette.BORDER_SLATE
	var text_col := accent if is_active else UiPalette.TEXT_MUTED
	var border_width := 3 if is_active else 1

	var normal := UiPalette.make_box(bg, border, 12, border_width, 8, 8)
	var hover := UiPalette.make_box(bg.lightened(0.08), border.lightened(0.15), 12, border_width, 8, 8)
	var pressed := UiPalette.make_box(bg.darkened(0.12), border, 12, border_width, 8, 8)

	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col.lightened(0.15))
	btn.add_theme_color_override("font_pressed_color", text_col.darkened(0.15))
	btn.add_theme_font_size_override("font_size", UiPalette.FONT_BUTTON)
