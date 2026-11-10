class_name StartScreen
extends Control

# Start Screen for Dope Wars: Omaha Metro Edition.
# Displays the title artwork background, active run continuation, and run mode launcher.
# This screen is the canonical and only location to start a new run.

signal continue_requested()
signal start_new_run_requested(mode_days: int)
signal hall_of_fame_requested()
signal perks_requested()
signal meta_updated()

var _meta: Dictionary = {}
var _state: GameState = null
var _pending_mode_days: int = 31

# UI nodes
var _bg_rect: TextureRect
var _buttons_card: PanelContainer
var _continue_box: PanelContainer
var _continue_btn: Button
var _continue_info_lbl: Label
var _btn_31: Button
var _btn_60: Button
var _btn_90: Button
var _btn_endless: Button
var _audio_btn: Button
var _confirm_overlay: ColorRect
var _confirm_msg_lbl: Label


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func open_start_screen(meta: Dictionary, state: GameState) -> void:
	_meta = meta
	_state = state
	_confirm_overlay.visible = false
	_refresh_display()
	visible = true


func has_active_run() -> bool:
	var saved: Dictionary = _meta.get("current_run", {})
	if saved.is_empty():
		return false
	if bool(saved.get("game_over", false)) or bool(saved.get("run_completed", false)):
		return false
	return true


func _build_ui() -> void:
	# 1. Background Image (artwork with title "Dope Wars: Omaha")
	_bg_rect = TextureRect.new()
	var bg_tex := load("res://art/branding/start_screen_bg.jpg") as Texture2D
	if bg_tex != null:
		_bg_rect.texture = bg_tex
	_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_rect)

	# 2. Subtle Dark Gradient Scrim across the lower 55% for button readability
	var scrim := TextureRect.new()
	scrim.texture = UiPalette.make_vertical_gradient(Color(0.02, 0.04, 0.08, 0.0), Color(0.02, 0.04, 0.08, 0.96), 32, 256)
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.anchor_top = 0.42
	scrim.anchor_bottom = 1.0
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	# 3. Main Action Container pinned to lower screen
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 1120)
	margin.add_theme_constant_override("margin_bottom", 64)
	add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.alignment = BoxContainer.ALIGNMENT_END
	main_vbox.add_theme_constant_override("separation", 18)
	margin.add_child(main_vbox)

	# Card container wrapping buttons
	_buttons_card = PanelContainer.new()
	_buttons_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons_card.add_theme_stylebox_override("panel", UiPalette.make_box(
		Color(0.05, 0.08, 0.13, 0.88),
		UiPalette.BORDER_SLATE,
		20,
		2,
		24,
		20
	))
	main_vbox.add_child(_buttons_card)

	var card_vbox := VBoxContainer.new()
	card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.add_theme_constant_override("separation", 14)
	_buttons_card.add_child(card_vbox)

	# Continue Section (Panel + Button)
	_continue_box = PanelContainer.new()
	_continue_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_continue_box.add_theme_stylebox_override("panel", UiPalette.make_box(
		Color(0.08, 0.16, 0.12, 0.90),
		UiPalette.CASH_EMERALD,
		14,
		2,
		18,
		14
	))
	card_vbox.add_child(_continue_box)

	var cont_inner_vbox := VBoxContainer.new()
	cont_inner_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cont_inner_vbox.add_theme_constant_override("separation", 8)
	_continue_box.add_child(cont_inner_vbox)

	_continue_info_lbl = UiPalette.add_label(cont_inner_vbox, "ACTIVE RUN IN PROGRESS", UiPalette.FONT_ROW_SUB, UiPalette.GOLD_ACCENT, false)
	_continue_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_continue_btn = Button.new()
	_continue_btn.text = "▶ Continue"
	_continue_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_continue_btn.custom_minimum_size = Vector2(0, 108)
	UiPalette.style_button(_continue_btn, UiPalette.BTN_SUCCESS, UiPalette.CASH_EMERALD, UiPalette.TEXT_PRIMARY, UiPalette.FONT_HEADER)
	_continue_btn.pressed.connect(func() -> void:
		Audio.play(&"drive_engine")
		Haptics.pulse(30.0)
		continue_requested.emit()
	)
	cont_inner_vbox.add_child(_continue_btn)

	# Section Header
	var section_lbl := UiPalette.add_label(card_vbox, "START A NEW RUN", UiPalette.FONT_SUBHEAD, UiPalette.BANK_CYAN, false)
	section_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# New Game - 31 Days (Classic)
	_btn_31 = _create_new_game_button("New Game - 31 Days", "Classic Omaha Hustle", 31, UiPalette.BTN_PRIMARY, UiPalette.BANK_CYAN)
	card_vbox.add_child(_btn_31)

	# New Game - 60 Days
	_btn_60 = _create_new_game_button("New Game - 60 Days", "Extended Syndicate", 60, UiPalette.CARD_BG, UiPalette.BORDER_BRIGHT)
	card_vbox.add_child(_btn_60)

	# New Game - 90 Days
	_btn_90 = _create_new_game_button("New Game - 90 Days", "Marathon Kingpin", 90, UiPalette.CARD_BG, UiPalette.BORDER_BRIGHT)
	card_vbox.add_child(_btn_90)

	# New Game - Endless
	_btn_endless = _create_new_game_button("New Game - Endless", "Sandbox Free Trade", 0, UiPalette.CARD_BG, UiPalette.PURPLE_VIP)
	card_vbox.add_child(_btn_endless)

	# Utility Row: Hall of Fame, Perks & Street Cred, Audio Toggle
	var util_row := HBoxContainer.new()
	util_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	util_row.add_theme_constant_override("separation", 14)
	main_vbox.add_child(util_row)

	var hof_btn := Button.new()
	hof_btn.text = "🏆 Hall of Fame"
	hof_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hof_btn.custom_minimum_size = Vector2(0, 84)
	UiPalette.style_button(hof_btn, UiPalette.CARD_BG, UiPalette.GOLD_ACCENT, UiPalette.GOLD_ACCENT, UiPalette.FONT_SMALL)
	hof_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		hall_of_fame_requested.emit()
	)
	util_row.add_child(hof_btn)

	var perks_btn := Button.new()
	perks_btn.text = "🎖️ Perks"
	perks_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	perks_btn.custom_minimum_size = Vector2(0, 84)
	UiPalette.style_button(perks_btn, UiPalette.CARD_BG, UiPalette.BORDER_BRIGHT, UiPalette.BANK_CYAN, UiPalette.FONT_SMALL)
	perks_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		perks_requested.emit()
	)
	util_row.add_child(perks_btn)

	_audio_btn = Button.new()
	_audio_btn.text = "🔊 Sound"
	_audio_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_audio_btn.custom_minimum_size = Vector2(0, 84)
	UiPalette.style_button(_audio_btn, UiPalette.CARD_BG, UiPalette.BORDER_SLATE, UiPalette.TEXT_PRIMARY, UiPalette.FONT_SMALL)
	_audio_btn.pressed.connect(func() -> void:
		Audio.muted = not Audio.muted
		_meta["muted"] = Audio.muted
		SaveManager.save_data(_meta)
		meta_updated.emit()
		_refresh_display()
	)
	util_row.add_child(_audio_btn)

	# 4. Confirmation Dialog Modal (for abandoning active run)
	_build_confirm_modal()


func _create_new_game_button(title: String, subtitle: String, days: int, bg_col: Color, border_col: Color) -> Button:
	var btn := Button.new()
	btn.text = "%s  (%s)" % [title, subtitle] if subtitle != "" else title
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 96)
	UiPalette.style_button(btn, bg_col, border_col, UiPalette.TEXT_PRIMARY, UiPalette.FONT_HEADER)
	btn.pressed.connect(func() -> void:
		_on_new_game_pressed(days)
	)
	return btn


func _build_confirm_modal() -> void:
	_confirm_overlay = ColorRect.new()
	_confirm_overlay.color = UiPalette.MODAL_BACKDROP
	_confirm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_overlay.visible = false
	add_child(_confirm_overlay)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 700)
	margin.add_theme_constant_override("margin_bottom", 700)
	_confirm_overlay.add_child(margin)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiPalette.make_box(
		UiPalette.PANEL_BG,
		UiPalette.DEBT_CRIMSON,
		20,
		3,
		28,
		24
	))
	margin.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	var title_lbl := UiPalette.add_label(vbox, "⚠️ ABANDON ACTIVE RUN?", UiPalette.FONT_HEADER, UiPalette.DEBT_CRIMSON, false)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_confirm_msg_lbl = UiPalette.add_label(
		vbox,
		"You have a run currently in progress.\nStarting a new run will permanently abandon your progress.\n\nStart new run anyway?",
		UiPalette.FONT_ROW_MAIN,
		UiPalette.TEXT_PRIMARY,
		false
	)
	_confirm_msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var btn_row := VBoxContainer.new()
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_theme_constant_override("separation", 14)
	vbox.add_child(btn_row)

	var abandon_btn := Button.new()
	abandon_btn.text = "⚠️ Abandon & Start New Run"
	abandon_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	abandon_btn.custom_minimum_size = Vector2(0, 96)
	UiPalette.style_button(abandon_btn, UiPalette.BTN_DANGER, UiPalette.DEBT_CRIMSON, UiPalette.TEXT_PRIMARY, UiPalette.FONT_HEADER)
	abandon_btn.pressed.connect(func() -> void:
		_confirm_overlay.visible = false
		Audio.play(&"drive_engine")
		Haptics.pulse(40.0)
		start_new_run_requested.emit(_pending_mode_days)
	)
	btn_row.add_child(abandon_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel (Keep Current Run)"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.custom_minimum_size = Vector2(0, 84)
	UiPalette.style_button(cancel_btn, UiPalette.CARD_BG, UiPalette.BORDER_SLATE, UiPalette.TEXT_SECONDARY, UiPalette.FONT_BUTTON)
	cancel_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		_confirm_overlay.visible = false
	)
	btn_row.add_child(cancel_btn)


func _on_new_game_pressed(days: int) -> void:
	if has_active_run():
		_pending_mode_days = days
		var saved: Dictionary = _meta.get("current_run", {})
		var cur_day := int(saved.get("day", 1))
		var max_d := int(saved.get("max_days", 31))
		var d_str := "Day %d of %d" % [cur_day, max_d] if max_d > 0 else "Day %d (Endless)" % cur_day
		var dist_id := String(saved.get("current_district_id", "downtown"))
		var dist_name := String(OmahaCatalog.get_district(dist_id)["name"])
		var cash_val := int(saved.get("cash", 0))

		_confirm_msg_lbl.text = "You currently have an active run:\n%s • %s • Cash: %s\n\nStarting a new run will permanently overwrite your progress.\nStart new %s run anyway?" % [
			d_str,
			dist_name,
			Money.format(cash_val),
			("%d-day" % days) if days > 0 else "endless"
		]
		_confirm_overlay.visible = true
	else:
		Audio.play(&"drive_engine")
		Haptics.pulse(30.0)
		start_new_run_requested.emit(days)


func _refresh_display() -> void:
	var active := has_active_run()
	_continue_box.visible = active
	if active:
		var saved: Dictionary = _meta.get("current_run", {})
		var cur_day := int(saved.get("day", 1))
		var max_d := int(saved.get("max_days", 31))
		var d_str := "Day %d/%d" % [cur_day, max_d] if max_d > 0 else "Day %d (Endless)" % cur_day
		var dist_id := String(saved.get("current_district_id", "downtown"))
		var dist_name := String(OmahaCatalog.get_district(dist_id)["name"])
		var cash_val := int(saved.get("cash", 0))
		var bank_val := int(saved.get("bank", 0))
		var debt_val := int(saved.get("debt", 0))
		var nw := cash_val + bank_val - debt_val
		_continue_info_lbl.text = "ACTIVE RUN: %s • %s • Net Worth: %s" % [d_str, dist_name, Money.format_short(nw)]

	if _audio_btn != null:
		_audio_btn.text = "🔇 Muted" if Audio.muted else "🔊 Sound"
