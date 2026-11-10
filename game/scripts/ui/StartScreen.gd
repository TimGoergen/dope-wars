class_name StartScreen
extends Control

# Start Screen for Dope Wars: Omaha Metro Edition.
# Displays the title artwork background, active run continuation, and run mode launcher.
# This screen is the canonical and only location to start a new run.

signal continue_requested()
signal start_new_run_requested(mode_days: int)
signal hall_of_fame_requested()
signal perks_requested()
signal tuning_requested()
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
var _abandon_btn: Button


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

	# 2. Subtle Dark Gradient Scrim across the lower 58% for button readability
	var scrim := TextureRect.new()
	scrim.texture = UiPalette.make_vertical_gradient(Color(0.02, 0.04, 0.08, 0.0), Color(0.02, 0.04, 0.08, 0.40), 32, 256)
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.anchor_top = 0.40
	scrim.anchor_bottom = 1.0
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	# 3. Main Action Container pinned to lower screen
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 980)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.alignment = BoxContainer.ALIGNMENT_END
	main_vbox.add_theme_constant_override("separation", 16)
	margin.add_child(main_vbox)

	# Card container wrapping buttons (50% transparency per user request)
	_buttons_card = PanelContainer.new()
	_buttons_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons_card.add_theme_stylebox_override("panel", UiPalette.make_box(
		Color(0.05, 0.08, 0.13, 0.50),
		Color(UiPalette.BORDER_SLATE.r, UiPalette.BORDER_SLATE.g, UiPalette.BORDER_SLATE.b, 0.70),
		20,
		2,
		20,
		18
	))
	main_vbox.add_child(_buttons_card)

	var card_vbox := VBoxContainer.new()
	card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.add_theme_constant_override("separation", 12)
	_buttons_card.add_child(card_vbox)

	# Continue Section (Panel + Button)
	_continue_box = PanelContainer.new()
	_continue_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_continue_box.add_theme_stylebox_override("panel", UiPalette.make_box(
		Color(0.08, 0.16, 0.12, 0.60),
		UiPalette.CASH_EMERALD,
		16,
		3,
		18,
		14
	))
	card_vbox.add_child(_continue_box)

	var cont_inner_vbox := VBoxContainer.new()
	cont_inner_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cont_inner_vbox.add_theme_constant_override("separation", 8)
	_continue_box.add_child(cont_inner_vbox)

	# 20% larger: 26px -> 31px
	_continue_info_lbl = UiPalette.add_label(cont_inner_vbox, "ACTIVE RUN IN PROGRESS", 31, UiPalette.GOLD_ACCENT, false)
	_continue_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 20% larger: 38px -> 46px
	_continue_btn = Button.new()
	_continue_btn.text = "▶ Continue Run"
	_continue_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_continue_btn.custom_minimum_size = Vector2(0, 114)
	UiPalette.style_button(_continue_btn, UiPalette.BTN_SUCCESS, UiPalette.CASH_EMERALD, UiPalette.TEXT_PRIMARY, 46)
	_continue_btn.pressed.connect(func() -> void:
		Audio.play(&"drive_engine")
		Haptics.pulse(30.0)
		continue_requested.emit()
	)
	cont_inner_vbox.add_child(_continue_btn)

	# Section Header (20% larger: 34px -> 41px)
	var section_lbl := UiPalette.add_label(card_vbox, "START A NEW RUN", 41, UiPalette.BANK_CYAN, false)
	section_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# New Game - 31 Days (Omaha flavor: tight & concise)
	_btn_31 = _create_new_game_button(
		"New Game - 31 Days",
		"30th & Ames Sprint • Beat Big Sal",
		31,
		Color(0.12, 0.25, 0.68, 0.65),
		UiPalette.BANK_CYAN
	)
	card_vbox.add_child(_btn_31)

	# New Game - 60 Days (Omaha flavor: tight & concise)
	_btn_60 = _create_new_game_button(
		"New Game - 60 Days",
		"South O to West O • Run 24th St",
		60,
		Color(0.13, 0.18, 0.27, 0.65),
		UiPalette.BORDER_BRIGHT
	)
	card_vbox.add_child(_btn_60)

	# New Game - 90 Days (Omaha flavor: tight & concise)
	_btn_90 = _create_new_game_button(
		"New Game - 90 Days",
		"North O to Bellevue • Own the Metro",
		90,
		Color(0.13, 0.18, 0.27, 0.65),
		UiPalette.BORDER_BRIGHT
	)
	card_vbox.add_child(_btn_90)

	# New Game - Endless (Omaha flavor: tight & concise)
	_btn_endless = _create_new_game_button(
		"New Game - Endless",
		"River City Turf • No Deadlines",
		0,
		Color(0.13, 0.18, 0.27, 0.65),
		UiPalette.PURPLE_VIP
	)
	card_vbox.add_child(_btn_endless)

	# Utility Row: Hall of Fame, Perks & Street Cred, Dev Tuning, Audio Toggle
	var util_row := HBoxContainer.new()
	util_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	util_row.add_theme_constant_override("separation", 10)
	main_vbox.add_child(util_row)

	var hof_btn := Button.new()
	hof_btn.text = "🏆 Hall of Fame"
	hof_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hof_btn.custom_minimum_size = Vector2(0, 92)
	UiPalette.style_button(hof_btn, Color(0.13, 0.18, 0.27, 0.65), UiPalette.GOLD_ACCENT, UiPalette.GOLD_ACCENT, 28)
	hof_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		hall_of_fame_requested.emit()
	)
	util_row.add_child(hof_btn)

	var perks_btn := Button.new()
	perks_btn.text = "🎖️ Perks"
	perks_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	perks_btn.custom_minimum_size = Vector2(0, 92)
	UiPalette.style_button(perks_btn, Color(0.13, 0.18, 0.27, 0.65), UiPalette.BANK_CYAN, UiPalette.BANK_CYAN, 28)
	perks_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		perks_requested.emit()
	)
	util_row.add_child(perks_btn)

	var tune_btn := Button.new()
	tune_btn.text = "⚙️ Tuning"
	tune_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tune_btn.custom_minimum_size = Vector2(0, 92)
	UiPalette.style_button(tune_btn, Color(0.13, 0.18, 0.27, 0.65), UiPalette.BORDER_SLATE, UiPalette.TEXT_SECONDARY, 28)
	tune_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		tuning_requested.emit()
	)
	util_row.add_child(tune_btn)

	_audio_btn = Button.new()
	_audio_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_audio_btn.custom_minimum_size = Vector2(0, 92)
	_update_audio_btn_visual()
	_audio_btn.pressed.connect(func() -> void:
		Audio.muted = not Audio.muted
		_meta["muted"] = Audio.muted
		SaveManager.save_data(_meta)
		if not Audio.muted:
			Audio.play(&"cash_register")
		meta_updated.emit()
		_update_audio_btn_visual()
	)
	util_row.add_child(_audio_btn)

	# 4. Confirmation Dialog Modal (for abandoning active run)
	_build_confirm_modal()


func _update_audio_btn_visual() -> void:
	if _audio_btn == null:
		return
	if Audio.muted:
		_audio_btn.text = "🔇 Muted"
		UiPalette.style_button(_audio_btn, Color(0.13, 0.18, 0.27, 0.65), UiPalette.BORDER_SLATE, UiPalette.TEXT_MUTED, 28)
	else:
		_audio_btn.text = "🔊 Sound"
		UiPalette.style_button(_audio_btn, Color(0.13, 0.18, 0.27, 0.65), UiPalette.CASH_EMERALD, UiPalette.CASH_EMERALD, 28)


func _create_new_game_button(title: String, subtitle: String, days: int, bg_col: Color, border_col: Color) -> Button:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 114)
	# 20% larger base button font: 38px -> 46px
	UiPalette.style_button(btn, bg_col, border_col, UiPalette.TEXT_PRIMARY, 46)
	btn.text = "" # Cleared so internal 2-line VBox handles both bold title & Omaha flavor line

	var inner_vbox := VBoxContainer.new()
	inner_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	inner_vbox.add_theme_constant_override("separation", 3)
	inner_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(inner_vbox)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", UiPalette.make_bold_font())
	title_lbl.add_theme_font_size_override("font_size", 46) # 20% larger: 38 * 1.2 = 46px
	title_lbl.add_theme_color_override("font_color", UiPalette.TEXT_PRIMARY)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	title_lbl.add_theme_constant_override("outline_size", 5)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_vbox.add_child(title_lbl)

	if subtitle != "":
		var sub_lbl := Label.new()
		sub_lbl.text = subtitle
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_lbl.add_theme_font_override("font", UiPalette.make_bold_font())
		sub_lbl.add_theme_font_size_override("font_size", 28) # Clean, legible Omaha flavor line
		sub_lbl.add_theme_color_override("font_color", border_col.lightened(0.2) if border_col.a > 0.0 else UiPalette.TEXT_SECONDARY)
		sub_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
		sub_lbl.add_theme_constant_override("outline_size", 4)
		sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner_vbox.add_child(sub_lbl)

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
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 680)
	margin.add_theme_constant_override("margin_bottom", 680)
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
	vbox.add_theme_constant_override("separation", 22)
	panel.add_child(vbox)

	# 20% larger: 38px -> 46px
	var title_lbl := UiPalette.add_label(vbox, "⚠️ ABANDON ACTIVE RUN?", 46, UiPalette.DEBT_CRIMSON, false)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 20% larger: 34px -> 41px
	_confirm_msg_lbl = UiPalette.add_label(
		vbox,
		"You have an Omaha run in progress.\nStarting a new run will permanently overwrite your progress.\n\nStart new run anyway?",
		41,
		UiPalette.TEXT_PRIMARY,
		false
	)
	_confirm_msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var btn_row := VBoxContainer.new()
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_theme_constant_override("separation", 14)
	vbox.add_child(btn_row)

	# 20% larger: 38px -> 46px
	_abandon_btn = Button.new()
	_abandon_btn.text = "⚠️ Abandon & Start New Run"
	_abandon_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_abandon_btn.custom_minimum_size = Vector2(0, 108)
	UiPalette.style_button(_abandon_btn, UiPalette.BTN_DANGER, UiPalette.DEBT_CRIMSON, UiPalette.TEXT_PRIMARY, 46)
	_abandon_btn.pressed.connect(func() -> void:
		_confirm_overlay.visible = false
		Audio.play(&"drive_engine")
		Haptics.pulse(40.0)
		start_new_run_requested.emit(_pending_mode_days)
	)
	btn_row.add_child(_abandon_btn)

	# 20% larger: 30px -> 36px
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel (Keep Current Run)"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.custom_minimum_size = Vector2(0, 92)
	UiPalette.style_button(cancel_btn, UiPalette.CARD_BG, UiPalette.BORDER_SLATE, UiPalette.TEXT_SECONDARY, 36)
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

		var mode_name := ("%d-Day" % days) if days > 0 else "Endless"
		_confirm_msg_lbl.text = "Active Omaha Run:\n%s • %s • Cash: %s\n\nStarting a new run will permanently overwrite your progress.\nStart new %s Omaha run anyway?" % [
			d_str,
			dist_name,
			Money.format(cash_val),
			mode_name
		]
		_abandon_btn.text = "⚠️ Abandon & Start %s Run" % mode_name
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

	_update_audio_btn_visual()
