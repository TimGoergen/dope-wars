class_name CombatOverlay
extends ColorRect

# Police Ambush shootout modal (Fight / Run / Surrender) with Shared 50/50 Crew Target Pool telemetry.
# Features officer profile picture, detailed damage attribution, intuitive round feedback, and generous spacing.

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

	if not _state.is_in_combat():
		visible = false
		return

	visible = true
	var enc := _state.active_combat
	var cops: Array = enc.get("cop_hp_list", [])
	var front_cop_hp := int(cops[0]) if not cops.is_empty() else 0
	var unit_max_hp := int(enc.get("unit_hp", 25))
	var backup_count := maxi(0, cops.size() - 1)
	var escape_pct := int(round(CombatEngine.get_escape_chance(enc, _state.vehicle_tier, _state.tuning) * 100.0))
	var tier := int(enc.get("tier", 1))

	var vbox := UiPalette.build_modal_shell(
		self,
		"🚨 POLICE AMBUSH — %s" % String(enc.get("short_badge", "OPD")),
		UiPalette.POLICE_RED,
		false
	)
	vbox.add_theme_constant_override("separation", 18)

	# 1. POLICE OFFICER DOSSIER / PROFILE PANEL
	var cop_card := PanelContainer.new()
	cop_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cop_card.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_BG, UiPalette.POLICE_RED, 20, 3, 24, 20))
	vbox.add_child(cop_card)

	var cop_hbox := HBoxContainer.new()
	cop_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cop_hbox.add_theme_constant_override("separation", 20)
	cop_card.add_child(cop_hbox)

	# Left: Policeman Profile Picture
	var portrait := UiIcons.create_icon_rect(UiIcons.cop_portrait_for_tier(tier), 136)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cop_hbox.add_child(portrait)

	# Right: Officer details & Cruisers status
	var cop_info := VBoxContainer.new()
	cop_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cop_info.add_theme_constant_override("separation", 6)
	cop_hbox.add_child(cop_info)

	var cop_name := String(enc.get("leader_name", "Officer Hardass"))
	UiPalette.add_label(cop_info, cop_name, 38, UiPalette.GOLD_ACCENT, true, true)

	var badge_str: String = String(enc.get("short_badge", "OPD")) + " Patrol Division"
	UiPalette.add_label(cop_info, badge_str, 28, UiPalette.TEXT_SECONDARY)

	var cruisers_str := "🚓 Cruisers: 1 Active" if backup_count == 0 else "🚓 Cruisers: %d Active (%d in reserve)" % [cops.size(), backup_count]
	UiPalette.add_label(cop_info, cruisers_str, 32, UiPalette.TEXT_PRIMARY)

	var lead_hp_str := "Lead Officer: %d / %d HP  •  %d–%d Dmg" % [
		front_cop_hp, unit_max_hp, int(enc.get("min_dmg", 4)), int(enc.get("max_dmg", 9))
	]
	UiPalette.add_label(cop_info, lead_hp_str, 32, UiPalette.POLICE_BLUE, true, true)

	# 2. INTUITIVE ACTION OUTCOME & ROUND FEEDBACK PANEL
	var last_act: String = String(enc.get("last_action", ""))
	var feedback_card := PanelContainer.new()
	feedback_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if last_act == "":
		# Opening ambush message
		feedback_card.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.SPIKE_BG, UiPalette.SPIKE_AMBER, 18, 2, 22, 16))
		vbox.add_child(feedback_card)
		var fb_vbox := VBoxContainer.new()
		fb_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fb_vbox.add_theme_constant_override("separation", 6)
		feedback_card.add_child(fb_vbox)

		var title := UiPalette.add_label(fb_vbox, "🚨 PULLED OVER!", 34, UiPalette.SPIKE_AMBER, false, true)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var desc := UiPalette.add_label(fb_vbox, "Squad car sirens are blazing behind you! Stand and fight, punch the gas to flee, or surrender.", 30, UiPalette.TEXT_PRIMARY)
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		# Detailed action outcome telemetry
		var fb_border := UiPalette.CASH_EMERALD if int(enc.get("last_player_dmg", 0)) > 0 else UiPalette.POLICE_RED
		feedback_card.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_ALT_BG, fb_border, 18, 3, 22, 18))
		vbox.add_child(feedback_card)

		var fb_vbox := VBoxContainer.new()
		fb_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fb_vbox.add_theme_constant_override("separation", 8)
		feedback_card.add_child(fb_vbox)

		var r_num := int(enc.get("round", 1))
		var round_hdr := UiPalette.add_label(fb_vbox, "ROUND %d ENGAGEMENT REPORT" % (r_num - 1), 32, UiPalette.GOLD_ACCENT, false, true)
		round_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		# Feedback: Your Attack / Move
		if last_act == "fight":
			var p_dmg := int(enc.get("last_player_dmg", 0))
			var downed := int(enc.get("last_cops_downed", 0))
			if p_dmg > 0:
				var hit_text := "💥 YOU HIT: Dealt %d DMG to Lead Officer!" % p_dmg
				if downed > 0:
					hit_text += " (☠️ %d Officer Down!)" % downed
				UiPalette.add_label(fb_vbox, hit_text, 34, UiPalette.CASH_EMERALD, true, true)
			else:
				UiPalette.add_label(fb_vbox, "❌ YOU MISSED: Your shots ricocheted harmlessly!", 32, UiPalette.TEXT_MUTED)
		elif last_act == "run":
			UiPalette.add_label(fb_vbox, "🚫 ESCAPE FAILED: Blocked by rail traffic and pinned down!", 34, UiPalette.SPIKE_AMBER, true, true)

		# Feedback: Cop Return Fire
		var cop_fire: Dictionary = enc.get("last_cop_fire", {})
		var dmg_player := int(cop_fire.get("dmg_to_player", 0))
		var dmg_armor := int(cop_fire.get("dmg_to_armor", 0))
		var dmg_hp := int(cop_fire.get("dmg_to_health", 0))
		var dmg_crew := int(cop_fire.get("dmg_to_crew", 0))
		var crew_lost := int(cop_fire.get("crew_killed", 0))

		if dmg_player > 0 or dmg_crew > 0 or crew_lost > 0:
			var details: Array[String] = []
			if dmg_armor > 0:
				details.append("-%d Armor" % dmg_armor)
			if dmg_hp > 0:
				details.append("-%d Health" % dmg_hp)
			if dmg_crew > 0:
				details.append("-%d Crew HP" % dmg_crew)
			if crew_lost > 0:
				details.append("☠️ %d Runner Lost" % crew_lost)
			var ret_text := "🚓 POLICE HIT: %s" % ", ".join(details)
			UiPalette.add_label(fb_vbox, ret_text, 34, UiPalette.POLICE_RED, true, true)
		else:
			UiPalette.add_label(fb_vbox, "🛡️ POLICE MISSED: All incoming rounds missed you!", 32, UiPalette.CASH_EMERALD)

	# 3. PLAYER & CREW READINESS PANEL
	var player_box := PanelContainer.new()
	player_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_box.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_BG, UiPalette.BORDER_SLATE, 18, 2, 22, 18))
	vbox.add_child(player_box)

	var player_vbox := VBoxContainer.new()
	player_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_vbox.add_theme_constant_override("separation", 10)
	player_box.add_child(player_vbox)

	var stat_row1 := HBoxContainer.new()
	stat_row1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_vbox.add_child(stat_row1)

	var hp_lbl := UiPalette.add_label(stat_row1, "❤️ Health: %d / %d" % [_state.health, _state.max_health], 34, UiPalette.CASH_EMERALD, false, true)
	hp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var arm_lbl := UiPalette.add_label(stat_row1, "🛡️ Armor: %d" % _state.armor, 34, UiPalette.BANK_CYAN, false, true)
	arm_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var stat_row2 := HBoxContainer.new()
	stat_row2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_vbox.add_child(stat_row2)

	var gun_str := "Unarmed"
	if not _state.weapons.is_empty():
		var top_w := OmahaCatalog.get_weapon(_state.weapons[0])
		gun_str = "%s (%d dmg • %d/%d armed)" % [
			top_w["short_name"],
			int(top_w["damage"]),
			mini(_state.weapons.size(), 1 + _state.crew_count),
			1 + _state.crew_count
		]
	var wep_lbl := UiPalette.add_label(stat_row2, "🔫 %s" % gun_str, 32, UiPalette.TEXT_PRIMARY)
	wep_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var crew_str := "No Crew"
	if _state.crew_count > 0:
		crew_str = "%d Runners (Front HP: %d/%d)" % [
			_state.crew_count,
			int(enc.get("front_crew_hp", _state.tuning.crew_encounter_hp)),
			_state.tuning.crew_encounter_hp
		]
	var crew_lbl := UiPalette.add_label(stat_row2, "👥 %s" % crew_str, 32, UiPalette.TEXT_SECONDARY)
	crew_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 4. ACTION BUTTONS (Generously sized with clear tactical labels)
	var fight_btn := Button.new()
	var shooters := mini(_state.weapons.size(), 1 + _state.crew_count)
	fight_btn.text = "🔫 FIGHT BACK (%d Shooter%s)" % [shooters, "s" if shooters != 1 else ""]
	fight_btn.custom_minimum_size = Vector2(0, 104)
	fight_btn.disabled = _state.weapons.is_empty()
	UiPalette.style_button(fight_btn, UiPalette.BTN_DANGER, UiPalette.POLICE_RED, UiPalette.TEXT_PRIMARY, 40)
	fight_btn.pressed.connect(func() -> void:
		Audio.play(&"gunshot")
		Haptics.pulse(45.0)
		_state.combat_fight()
		combat_updated.emit()
	)
	vbox.add_child(fight_btn)

	var run_btn := Button.new()
	var v_name: String = OmahaCatalog.get_vehicle(_state.vehicle_tier)["short_name"]
	run_btn.text = "💨 ATTEMPT ESCAPE (%d%% • %s)" % [escape_pct, v_name]
	run_btn.custom_minimum_size = Vector2(0, 96)
	UiPalette.style_button(run_btn, UiPalette.BTN_PRIMARY, UiPalette.BANK_CYAN, UiPalette.TEXT_PRIMARY, 36)
	run_btn.pressed.connect(func() -> void:
		Audio.play(&"drive_engine")
		Haptics.pulse(30.0)
		_state.combat_run()
		combat_updated.emit()
	)
	vbox.add_child(run_btn)

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
	vbox.add_child(surr_btn)
