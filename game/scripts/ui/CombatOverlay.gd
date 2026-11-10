class_name CombatOverlay
extends ColorRect

# Police Ambush shootout modal (Fight / Run / Surrender).
# Features side-by-side Player vs Foe character panels with stylistic portraits,
# visual health meters, and dynamic Red/Green action glow indicating visual impact
# without requiring the player to read paragraphs of text. Tactical buttons and controls
# are cleanly positioned in the bottom half of the screen.

signal combat_updated()

var _state: GameState


func _init() -> void:
	color = UiPalette.MODAL_BACKDROP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func refresh(state: GameState) -> void:
	_state = state
	for c in get_children():
		c.queue_free()

	if _state.has_combat_result():
		visible = true
		_build_result_view()
		return

	if not _state.is_in_combat():
		visible = false
		return

	visible = true
	_build_combat_view()


func _build_combat_view() -> void:
	var enc := _state.active_combat
	var cops: Array = enc.get("cop_hp_list", [])
	var front_cop_hp := int(cops[0]) if not cops.is_empty() else 0
	var unit_max_hp := int(enc.get("unit_hp", 25))
	var backup_count := maxi(0, cops.size() - 1)
	var escape_pct := int(round(CombatEngine.get_escape_chance(enc, _state.vehicle_tier, _state.tuning) * 100.0))
	var tier := int(enc.get("tier", 1))
	var round_num := int(enc.get("round", 1))
	var last_act: String = String(enc.get("last_action", ""))
	var last_p_dmg := int(enc.get("last_player_dmg", 0))
	var last_downed := int(enc.get("last_cops_downed", 0))

	var cop_fire: Dictionary = enc.get("last_cop_fire", {})
	var dmg_player := int(cop_fire.get("dmg_to_player", 0))
	var dmg_armor := int(cop_fire.get("dmg_to_armor", 0))
	var dmg_hp := int(cop_fire.get("dmg_to_health", 0))
	var dmg_crew := int(cop_fire.get("dmg_to_crew", 0))
	var crew_lost := int(cop_fire.get("crew_killed", 0))

	var vbox := UiPalette.build_modal_shell(
		self,
		"🚨 POLICE ENCOUNTER — %s" % String(enc.get("short_badge", "OPD")),
		UiPalette.POLICE_RED,
		false
	)
	vbox.add_theme_constant_override("separation", 16)

	# =========================================================================
	# TOP HALF: SIDE-BY-SIDE CHARACTER PANELS (PLAYER VS FOE)
	# =========================================================================
	var top_section := HBoxContainer.new()
	top_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_section.add_theme_constant_override("separation", 16)
	vbox.add_child(top_section)

	# -------------------------------------------------------------------------
	# 1. EVALUATE ACTION GLOW & IMPACT BADGES
	# -------------------------------------------------------------------------
	# Foe is target of Player attack:
	# Negative impact (Red glow) if damaged; Green glow if evaded/unhurt
	var foe_glow := "none"
	var foe_badge_text := "🚨 PURSUIT"
	var foe_badge_col := UiPalette.SPIKE_AMBER
	var foe_badge_bg := Color("#1E1B18")
	var foe_badge_border := UiPalette.BORDER_SLATE

	if last_act == "fight":
		if last_p_dmg > 0:
			foe_glow = "red"
			foe_badge_col = UiPalette.TEXT_PRIMARY
			foe_badge_bg = Color("#3B0D14")
			foe_badge_border = UiPalette.POLICE_RED
			if last_downed > 0:
				foe_badge_text = "☠️ DOWN! (-%d)" % last_p_dmg
			else:
				foe_badge_text = "💥 -%d HP" % last_p_dmg
		else:
			foe_glow = "green"
			foe_badge_col = UiPalette.CASH_EMERALD
			foe_badge_bg = Color("#0A2617")
			foe_badge_border = UiPalette.CASH_EMERALD
			foe_badge_text = "💨 MISSED (0 DMG)"
	elif last_act == "run":
		foe_badge_text = "🚓 PINNED YOU"
		foe_badge_col = UiPalette.BANK_CYAN
		foe_badge_bg = Color("#0D1D2D")
		foe_badge_border = UiPalette.BANK_CYAN

	# Player is target of Cop return fire / interception:
	# Negative impact (Red glow) if hurt; Green glow if dodged/defended
	var player_glow := "none"
	var player_badge_text := "🔫 READY"
	var player_badge_col := UiPalette.TEXT_SECONDARY
	var player_badge_bg := Color("#111827")
	var player_badge_border := UiPalette.BORDER_SLATE

	if last_act != "":
		if dmg_player > 0 or dmg_crew > 0 or crew_lost > 0:
			player_glow = "red"
			player_badge_col = UiPalette.TEXT_PRIMARY
			player_badge_bg = Color("#3B0D14")
			player_badge_border = UiPalette.POLICE_RED
			if dmg_hp > 0:
				player_badge_text = "💔 -%d HP" % dmg_hp
			elif dmg_armor > 0:
				player_badge_text = "🛡️ -%d ARM" % dmg_armor
			elif crew_lost > 0:
				player_badge_text = "☠️ RUNNER DOWN"
			else:
				player_badge_text = "👥 -%d CREW" % dmg_crew
		else:
			player_glow = "green"
			player_badge_col = UiPalette.CASH_EMERALD
			player_badge_bg = Color("#0A2617")
			player_badge_border = UiPalette.CASH_EMERALD
			player_badge_text = "✨ DODGED!"

	# -------------------------------------------------------------------------
	# 2. BUILD PLAYER CHARACTER PANEL (LEFT)
	# -------------------------------------------------------------------------
	_build_character_panel(
		top_section,
		"YOU",
		UiPalette.GOLD_ACCENT,
		"player_portrait",
		player_badge_text,
		player_badge_col,
		player_badge_border,
		player_badge_bg,
		_state.health,
		_state.max_health,
		UiPalette.CASH_EMERALD,
		"❤️ %d / %d HP" % [_state.health, _state.max_health],
		"🛡️ %d Armor" % _state.armor,
		_get_player_weapon_subtext(),
		player_glow
	)

	# -------------------------------------------------------------------------
	# 3. BUILD FOE CHARACTER PANEL (RIGHT)
	# -------------------------------------------------------------------------
	var cop_title: String = String(enc.get("short_badge", "OPD")) + " PATROL"
	var cop_sub := "🚓 1 Cruiser Active" if backup_count == 0 else "🚓 %d Cruisers (+%d)" % [cops.size(), backup_count]
	var cop_threat := "💥 %d–%d DMG" % [int(enc.get("min_dmg", 4)), int(enc.get("max_dmg", 9))]
	_build_character_panel(
		top_section,
		cop_title,
		UiPalette.POLICE_RED,
		UiIcons.cop_portrait_for_tier(tier),
		foe_badge_text,
		foe_badge_col,
		foe_badge_border,
		foe_badge_bg,
		front_cop_hp,
		unit_max_hp,
		UiPalette.POLICE_RED,
		"❤️ %d / %d HP" % [front_cop_hp, unit_max_hp],
		cop_sub,
		cop_threat,
		foe_glow
	)

	# =========================================================================
	# BOTTOM HALF: TACTICAL TELEMETRY & ACTION CONTROLS
	# =========================================================================
	var div := ColorRect.new()
	div.color = UiPalette.BORDER_SLATE
	div.custom_minimum_size = Vector2(0, 3)
	div.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(div)

	var bottom_section := VBoxContainer.new()
	bottom_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_section.add_theme_constant_override("separation", 14)
	vbox.add_child(bottom_section)

	# Tactical status summary pill bar
	var tac_bar := HBoxContainer.new()
	tac_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tac_bar.add_theme_constant_override("separation", 12)
	bottom_section.add_child(tac_bar)

	var v_name: String = OmahaCatalog.get_vehicle(_state.vehicle_tier)["short_name"]
	var v_badge := _create_mini_badge(
		tac_bar,
		"🚗 %s (%d%% Escape)" % [v_name, escape_pct],
		UiPalette.BANK_CYAN,
		Color("#0B192A")
	)
	v_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var crew_str := "No Crew" if _state.crew_count <= 0 else "%d Runners Armed" % _state.crew_count
	var shooters := mini(_state.weapons.size(), 1 + _state.crew_count)
	var squad_str := "🔫 %d Shooters • %s" % [shooters, crew_str]
	var squad_badge := _create_mini_badge(
		tac_bar,
		squad_str,
		UiPalette.TEXT_PRIMARY,
		Color("#131B29")
	)
	squad_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Optional 1-line recap banner if an action was taken
	if last_act != "":
		var recap_box := PanelContainer.new()
		recap_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recap_box.add_theme_stylebox_override(
			"panel",
			UiPalette.make_box(Color("#141D2B"), UiPalette.BORDER_SLATE, 12, 1, 16, 10)
		)
		bottom_section.add_child(recap_box)
		var recap_lbl := UiPalette.add_label(
			recap_box,
			"Round %d: %s" % [round_num - 1, String(enc.get("last_log", ""))],
			28,
			UiPalette.TEXT_SECONDARY,
			true
		)
		recap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# ACTION BUTTON 1: FIGHT BACK
	var fight_btn := Button.new()
	var total_wep_dmg := _calc_max_weapon_damage()
	fight_btn.text = "🔫 FIGHT BACK (%d Shooter%s • Max %d DMG)" % [
		shooters, "s" if shooters != 1 else "", total_wep_dmg
	]
	fight_btn.custom_minimum_size = Vector2(0, 104)
	fight_btn.disabled = _state.weapons.is_empty()
	UiPalette.style_button(fight_btn, UiPalette.BTN_DANGER, UiPalette.POLICE_RED, UiPalette.TEXT_PRIMARY, 38)
	fight_btn.pressed.connect(func() -> void:
		Audio.play(&"gunshot")
		Haptics.pulse(45.0)
		_state.combat_fight()
		combat_updated.emit()
	)
	bottom_section.add_child(fight_btn)

	# ACTION BUTTON 2: ATTEMPT ESCAPE
	var run_btn := Button.new()
	run_btn.text = "💨 ATTEMPT ESCAPE (%d%% Chance)" % escape_pct
	run_btn.custom_minimum_size = Vector2(0, 96)
	UiPalette.style_button(run_btn, UiPalette.BTN_PRIMARY, UiPalette.BANK_CYAN, UiPalette.TEXT_PRIMARY, 36)
	run_btn.pressed.connect(func() -> void:
		Audio.play(&"drive_engine")
		Haptics.pulse(30.0)
		_state.combat_run()
		combat_updated.emit()
	)
	bottom_section.add_child(run_btn)

	# ACTION BUTTON 3: SURRENDER
	var surr_btn := Button.new()
	surr_btn.text = "🏳️ SURRENDER (Forfeit Stash & 25% Cash)"
	surr_btn.custom_minimum_size = Vector2(0, 88)
	UiPalette.style_button(surr_btn, UiPalette.CARD_BG, UiPalette.BORDER_SLATE, UiPalette.TEXT_SECONDARY, 32)
	surr_btn.pressed.connect(func() -> void:
		Audio.play(&"sell_loss")
		Haptics.pulse(35.0)
		_state.combat_surrender()
		combat_updated.emit()
	)
	bottom_section.add_child(surr_btn)


func _build_result_view() -> void:
	var res: Dictionary = _state.combat_result
	var outcome: String = String(res.get("outcome", "victory"))
	var title: String = String(res.get("title", "ENCOUNTER RESOLVED"))
	var subtitle: String = String(res.get("subtitle", ""))
	var flavor_text: String = String(res.get("flavor_text", ""))
	var rounds: int = int(res.get("rounds", 1))
	var bounty: int = int(res.get("bounty", 0))
	var cops_downed: int = int(res.get("cops_downed", 0))
	var hp_lost: int = int(res.get("hp_lost", 0))
	var armor_lost: int = int(res.get("armor_lost", 0))
	var cash_lost: int = int(res.get("cash_lost", 0))
	var tier: int = int(res.get("tier", 1))
	var short_badge: String = String(res.get("short_badge", "OPD"))

	var is_win := (outcome == "victory" or outcome == "escaped")
	var outcome_headline := "You won!" if is_win else "You lose."

	var theme_col: Color = UiPalette.CASH_EMERALD if is_win else UiPalette.POLICE_RED
	var header_text: String = "🏆 YOU WON! — %s NEUTRALIZED" % short_badge
	var portrait_icon: String = "player_portrait"
	var badge_text: String = "🏆 YOU WON!"
	var badge_col: Color = UiPalette.CASH_EMERALD
	var badge_bg: Color = Color("#0A2617")

	match outcome:
		"escaped":
			theme_col = UiPalette.BANK_CYAN
			header_text = "💨 YOU WON! — %s EVADED" % short_badge
			portrait_icon = "car"
			badge_text = "💨 YOU WON! (ESCAPED)"
			badge_col = UiPalette.BANK_CYAN
			badge_bg = Color("#0D1D2D")
		"surrendered":
			theme_col = UiPalette.SPIKE_AMBER
			header_text = "🏳️ YOU LOSE. — SURRENDERED TO %s" % short_badge
			portrait_icon = UiIcons.cop_portrait_for_tier(tier)
			badge_text = "❌ YOU LOSE. (SURRENDERED)"
			badge_col = UiPalette.SPIKE_AMBER
			badge_bg = Color("#1E1B18")
		"killed":
			theme_col = UiPalette.POLICE_RED
			header_text = "☠️ YOU LOSE. — KILLED BY %s" % short_badge
			portrait_icon = UiIcons.cop_portrait_for_tier(tier)
			badge_text = "☠️ YOU LOSE. (KILLED)"
			badge_col = UiPalette.POLICE_RED
			badge_bg = Color("#3B0D14")
		_:
			theme_col = UiPalette.CASH_EMERALD
			header_text = "🏆 YOU WON! — %s NEUTRALIZED" % short_badge
			portrait_icon = "player_portrait"
			badge_text = "🏆 YOU WON! (UNIT DOWNED)"
			badge_col = UiPalette.CASH_EMERALD
			badge_bg = Color("#0A2617")

	var vbox := UiPalette.build_modal_shell(
		self,
		header_text,
		theme_col,
		false
	)
	vbox.add_theme_constant_override("separation", 18)

	# 1. Outcome Dossier Panel (Stylistic Portrait + Headline + Subtitle)
	var dossier_card := PanelContainer.new()
	dossier_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier_card.add_theme_stylebox_override(
		"panel",
		UiPalette.make_box(UiPalette.CARD_BG, theme_col, 20, 3, 24, 20)
	)
	vbox.add_child(dossier_card)

	var dossier_vbox := VBoxContainer.new()
	dossier_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier_vbox.add_theme_constant_override("separation", 12)
	dossier_card.add_child(dossier_vbox)

	# Main Outcome Clear Headline: "You won!" or "You lose."
	var outcome_lbl := UiPalette.add_label(dossier_vbox, outcome_headline, 56, theme_col, false, true)
	outcome_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Secondary Context Headline
	var title_lbl := UiPalette.add_label(dossier_vbox, title, 32, UiPalette.TEXT_PRIMARY, false, true)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Stylistic Character Portrait
	var portrait_center := CenterContainer.new()
	portrait_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier_vbox.add_child(portrait_center)
	var portrait := UiIcons.create_icon_rect(portrait_icon, 160)
	portrait_center.add_child(portrait)

	# Outcome Badge
	var b_box := PanelContainer.new()
	b_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b_box.add_theme_stylebox_override(
		"panel",
		UiPalette.make_box(badge_bg, theme_col, 10, 2, 18, 6)
	)
	dossier_vbox.add_child(b_box)
	var b_lbl := Label.new()
	b_lbl.text = badge_text
	b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b_lbl.add_theme_font_size_override("font_size", 28)
	b_lbl.add_theme_color_override("font_color", badge_col)
	b_lbl.add_theme_font_override("font", UiPalette.make_bold_font())
	b_box.add_child(b_lbl)

	# Subtitle
	if subtitle != "":
		var sub_lbl := UiPalette.add_label(dossier_vbox, subtitle, 26, UiPalette.TEXT_SECONDARY)
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 2. Atmospheric Flavor Text Story Bubble
	var story_card := PanelContainer.new()
	story_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_card.add_theme_stylebox_override(
		"panel",
		UiPalette.make_box(Color("#101726"), UiPalette.BORDER_SLATE, 16, 2, 24, 20)
	)
	vbox.add_child(story_card)

	var story_lbl := UiPalette.add_label(story_card, flavor_text, 30, UiPalette.TEXT_PRIMARY)
	story_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	# 3. Telemetry & Outcome Badges Row
	var tele_row := HBoxContainer.new()
	tele_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tele_row.add_theme_constant_override("separation", 12)
	vbox.add_child(tele_row)

	match outcome:
		"victory":
			_create_tele_pill(tele_row, "💰 +%s" % Money.format_short(bounty), UiPalette.CASH_EMERALD, Color("#0B2518"))
			_create_tele_pill(tele_row, "☠️ %d Down" % cops_downed, UiPalette.TEXT_PRIMARY, Color("#131B29"))
			_create_tele_pill(tele_row, "⏱️ %d Rnd%s" % [rounds, "s" if rounds != 1 else ""], UiPalette.TEXT_SECONDARY, Color("#131B29"))
			var total_dmg_taken := hp_lost + armor_lost
			if total_dmg_taken > 0:
				_create_tele_pill(tele_row, "💔 -%d HP" % total_dmg_taken, UiPalette.SPIKE_AMBER, Color("#26170B"))
			else:
				_create_tele_pill(tele_row, "✨ Unhit", UiPalette.CASH_EMERALD, Color("#0B2518"))
		"escaped":
			_create_tele_pill(tele_row, "🚗 %s" % String(res.get("vehicle_name", "Vehicle")), UiPalette.BANK_CYAN, Color("#0B1D2D"))
			_create_tele_pill(tele_row, "🎒 Stash Safe", UiPalette.CASH_EMERALD, Color("#0B2518"))
			_create_tele_pill(tele_row, "⏱️ %d Rnd%s" % [rounds, "s" if rounds != 1 else ""], UiPalette.TEXT_SECONDARY, Color("#131B29"))
			_create_tele_pill(tele_row, "🚨 +5% Heat", UiPalette.SPIKE_AMBER, Color("#26170B"))
		"surrendered":
			_create_tele_pill(tele_row, "💸 -%s" % Money.format_short(cash_lost), UiPalette.DEBT_CRIMSON, Color("#3B0D14"))
			_create_tele_pill(tele_row, "🎒 %d Lost" % int(res.get("drugs_units_lost", 0)), UiPalette.SPIKE_AMBER, Color("#26170B"))
			_create_tele_pill(tele_row, "🚨 Heat 10%", UiPalette.BANK_CYAN, Color("#0B1D2D"))
		"killed":
			_create_tele_pill(tele_row, "☠️ Fatal", UiPalette.POLICE_RED, Color("#3B0D14"))
			_create_tele_pill(tele_row, "⏱️ %d Rnds" % rounds, UiPalette.TEXT_SECONDARY, Color("#131B29"))
			_create_tele_pill(tele_row, "📅 Day %d" % int(res.get("day", 1)), UiPalette.GOLD_ACCENT, Color("#1E1B18"))

	# 4. Prominent Close & Move On Button
	var close_btn := Button.new()
	if is_win:
		close_btn.text = "CLOSE & MOVE ON (YOU WON)"
		close_btn.icon = UiIcons.get_icon("check", 48)
	elif outcome == "surrendered":
		close_btn.text = "CLOSE & MOVE ON (YOU LOSE)"
		close_btn.icon = UiIcons.get_icon("close_x", 48)
	else:
		close_btn.text = "VIEW RUN SUMMARY (YOU LOSE) ➔"
		close_btn.icon = UiIcons.get_icon("close_x", 48)
	close_btn.custom_minimum_size = Vector2(0, 104)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var btn_bg: Color = UiPalette.BTN_SUCCESS if is_win else (UiPalette.BTN_AMBER if outcome == "surrendered" else UiPalette.BTN_DANGER)
	var btn_border: Color = UiPalette.CASH_EMERALD if is_win else (UiPalette.SPIKE_AMBER if outcome == "surrendered" else UiPalette.POLICE_RED)
	UiPalette.style_button(close_btn, btn_bg, btn_border, UiPalette.TEXT_PRIMARY, 38)
	close_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		Haptics.pulse(20.0)
		_state.clear_combat_result()
		combat_updated.emit()
	)
	vbox.add_child(close_btn)


func _create_tele_pill(parent: HBoxContainer, text: String, text_col: Color, bg_col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override(
		"panel",
		UiPalette.make_box(bg_col, UiPalette.BORDER_SLATE, 12, 1, 8, 8)
	)
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", text_col)
	lbl.add_theme_font_override("font", UiPalette.make_bold_font())
	p.add_child(lbl)
	parent.add_child(p)
	return p


func _build_character_panel(
	parent: HBoxContainer,
	char_name: String,
	title_col: Color,
	portrait_icon: String,
	badge_text: String,
	badge_col: Color,
	badge_border: Color,
	badge_bg: Color,
	hp_val: int,
	hp_max: int,
	hp_bar_col: Color,
	hp_label_text: String,
	stat_sub1: String,
	stat_sub2: String,
	glow_type: String
) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 480)

	var sb: StyleBoxFlat
	if glow_type == "red":
		sb = UiPalette.make_box(Color("#260E14"), Color("#EF4444"), 20, 6, 16, 16)
	elif glow_type == "green":
		sb = UiPalette.make_box(Color("#0B2518"), Color("#10B981"), 20, 6, 16, 16)
	else:
		sb = UiPalette.make_box(UiPalette.CARD_BG, UiPalette.BORDER_SLATE, 20, 3, 16, 16)

	card.add_theme_stylebox_override("panel", sb)
	parent.add_child(card)

	# Flash animation on active glow
	if glow_type != "none":
		card.modulate = Color(1.4, 1.4, 1.4)
		var tw := card.create_tween()
		tw.tween_property(card, "modulate", Color.WHITE, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var cvbox := VBoxContainer.new()
	cvbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cvbox.add_theme_constant_override("separation", 10)
	card.add_child(cvbox)

	# 1. Header Label
	var lbl := UiPalette.add_label(cvbox, char_name, 32, title_col, false, true)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 2. Stylistic Portrait (Centered)
	var port_center := CenterContainer.new()
	port_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cvbox.add_child(port_center)

	var portrait := UiIcons.create_icon_rect(portrait_icon, 160)
	port_center.add_child(portrait)

	# 3. Action Impact Visual Badge (Centered right under portrait)
	var badge_box := PanelContainer.new()
	badge_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge_box.add_theme_stylebox_override(
		"panel",
		UiPalette.make_box(badge_bg, badge_border, 10, 2, 16, 6)
	)
	cvbox.add_child(badge_box)

	var badge_lbl := Label.new()
	badge_lbl.text = badge_text
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_lbl.add_theme_font_size_override("font_size", 28)
	badge_lbl.add_theme_color_override("font_color", badge_col)
	badge_lbl.add_theme_font_override("font", UiPalette.make_bold_font())
	badge_box.add_child(badge_lbl)

	# 4. Health Meter & Text
	var hp_lbl := UiPalette.add_label(cvbox, hp_label_text, 28, hp_bar_col, false, true)
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var hp_bar := ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = maxi(1, hp_max)
	hp_bar.value = clampi(hp_val, 0, hp_max)
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(0, 16)
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bar_bg := UiPalette.make_box(Color("#0B0F17"), UiPalette.BORDER_SLATE, 6, 1, 0, 0)
	var bar_fill := UiPalette.make_box(hp_bar_col, hp_bar_col, 6, 0, 0, 0)
	hp_bar.add_theme_stylebox_override("background", bar_bg)
	hp_bar.add_theme_stylebox_override("fill", bar_fill)
	cvbox.add_child(hp_bar)

	# 5. Sub-stats row 1 (Armor / Cruisers)
	if stat_sub1 != "":
		var sub1_lbl := UiPalette.add_label(cvbox, stat_sub1, 26, UiPalette.TEXT_PRIMARY)
		sub1_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 6. Sub-stats row 2 (Firepower / Threat)
	if stat_sub2 != "":
		var sub2_lbl := UiPalette.add_label(cvbox, stat_sub2, 24, UiPalette.TEXT_SECONDARY)
		sub2_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	return card


func _create_mini_badge(parent: Node, text: String, text_col: Color, bg_col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override(
		"panel",
		UiPalette.make_box(bg_col, UiPalette.BORDER_SLATE, 12, 1, 14, 8)
	)
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", text_col)
	lbl.add_theme_font_override("font", UiPalette.make_bold_font())
	p.add_child(lbl)
	parent.add_child(p)
	return p


func _get_player_weapon_subtext() -> String:
	if _state.weapons.is_empty():
		return "Unarmed"
	var top_w := OmahaCatalog.get_weapon(_state.weapons[0])
	return "%s" % String(top_w["short_name"])


func _calc_max_weapon_damage() -> int:
	var total := 0
	var shooters := mini(_state.weapons.size(), 1 + _state.crew_count)
	for i in range(shooters):
		var w := OmahaCatalog.get_weapon(_state.weapons[i])
		total += int(w["damage"])
	return total
