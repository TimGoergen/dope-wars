class_name CombatOverlay
extends ColorRect

# Police Ambush shootout modal (Fight / Run / Surrender) with Shared 50/50 Crew Target Pool telemetry.

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

	var vbox := UiPalette.build_modal_shell(
		self,
		"🚨 POLICE AMBUSH — %s" % String(enc.get("short_badge", "OPD")),
		UiPalette.POLICE_RED,
		false
	)

	var sub := UiPalette.add_label(vbox, "%s\nOfficers Remaining: %d (Backup: %d)" % [
		String(enc.get("leader_name", "Officer Hardass")),
		cops.size(),
		backup_count
	], UiPalette.FONT_SUBHEAD, UiPalette.TEXT_PRIMARY)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Pursuing Unit vs Player/Crew Status Box
	var status_box := PanelContainer.new()
	status_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_box.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_BG, UiPalette.BORDER_SLATE, 14, 2, 18, 16))
	vbox.add_child(status_box)

	var status_vbox := VBoxContainer.new()
	status_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_vbox.add_theme_constant_override("separation", 10)
	status_box.add_child(status_vbox)

	UiPalette.add_label(status_vbox, "🚓 Lead Officer HP: %d / %d  (%d–%d dmg)" % [
		front_cop_hp, unit_max_hp, int(enc.get("min_dmg", 4)), int(enc.get("max_dmg", 9))
	], UiPalette.FONT_ROW_MAIN, UiPalette.POLICE_BLUE)

	var gun_summary := "Unarmed"
	if not _state.weapons.is_empty():
		var top_w := OmahaCatalog.get_weapon(_state.weapons[0])
		gun_summary = "%s (%d dmg) • %d/%d Armed" % [
			top_w["short_name"],
			int(top_w["damage"]),
			mini(_state.weapons.size(), 1 + _state.crew_count),
			1 + _state.crew_count
		]

	var crew_shield_str := "No Crew"
	if _state.crew_count > 0:
		crew_shield_str = "%d Crew (Front: %d/%d HP)" % [
			_state.crew_count,
			int(enc.get("front_crew_hp", _state.tuning.crew_encounter_hp)),
			_state.tuning.crew_encounter_hp
		]

	UiPalette.add_label(status_vbox, "❤️ HP: %d/%d  •  🛡️ Armor: %d\n👥 %s" % [
		_state.health, _state.max_health, _state.armor, crew_shield_str
	], UiPalette.FONT_ROW_MAIN, UiPalette.CASH_EMERALD)

	UiPalette.add_label(status_vbox, "🔫 %s  •  🚗 Escape: %d%%" % [
		gun_summary, escape_pct
	], UiPalette.FONT_ROW_SUB, UiPalette.GOLD_ACCENT)

	# Combat Log Line
	var log_lbl := UiPalette.add_label(vbox, String(enc.get("last_log", "")), UiPalette.FONT_ROW_MAIN, UiPalette.SPIKE_AMBER)
	log_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Action Buttons: FIGHT / RUN / SURRENDER
	var fight_btn := Button.new()
	fight_btn.text = "🔫 FIGHT BACK (%d Gun%s)" % [
		mini(_state.weapons.size(), 1 + _state.crew_count),
		"s" if mini(_state.weapons.size(), 1 + _state.crew_count) != 1 else ""
	]
	fight_btn.custom_minimum_size = Vector2(0, 92)
	fight_btn.disabled = _state.weapons.is_empty()
	UiPalette.style_button(fight_btn, UiPalette.BTN_DANGER, UiPalette.POLICE_RED, UiPalette.TEXT_PRIMARY, UiPalette.FONT_HEADER)
	fight_btn.pressed.connect(func() -> void:
		Audio.play(&"gunshot")
		Haptics.pulse(45.0)
		_state.combat_fight()
		combat_updated.emit()
	)
	vbox.add_child(fight_btn)

	var run_btn := Button.new()
	var v_name: String = OmahaCatalog.get_vehicle(_state.vehicle_tier)["short_name"]
	run_btn.text = "💨 RUN (%d%% — %s)" % [escape_pct, v_name]
	run_btn.custom_minimum_size = Vector2(0, 88)
	UiPalette.style_button(run_btn, UiPalette.BTN_PRIMARY, UiPalette.BANK_CYAN, UiPalette.TEXT_PRIMARY, UiPalette.FONT_SUBHEAD)
	run_btn.pressed.connect(func() -> void:
		Audio.play(&"drive_engine")
		Haptics.pulse(30.0)
		_state.combat_run()
		combat_updated.emit()
	)
	vbox.add_child(run_btn)

	var surr_btn := Button.new()
	surr_btn.text = "🏳️ SURRENDER (Drop Stash & 25% Cash)"
	surr_btn.custom_minimum_size = Vector2(0, 80)
	UiPalette.style_button(surr_btn, UiPalette.CARD_BG, UiPalette.BORDER_SLATE, UiPalette.TEXT_SECONDARY, UiPalette.FONT_ROW_SUB)
	surr_btn.pressed.connect(func() -> void:
		Audio.play(&"sell_loss")
		Haptics.pulse(35.0)
		_state.combat_surrender()
		combat_updated.emit()
	)
	vbox.add_child(surr_btn)
