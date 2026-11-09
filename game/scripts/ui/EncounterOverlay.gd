class_name EncounterOverlay
extends ColorRect

# Choice prompt modal for street encounters (Carhartt Jacket Vendor / Camaro Trunk Gun Dealer).
# Features a large mobile-friendly character dossier panel with stylistic person portraits,
# dialogue speech bubble, visual item offer breakdown, and action buttons with icon representation.

signal encounter_resolved()

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

	if _state.pending_choice_event.is_empty() or _state.is_in_combat() or _state.game_over:
		visible = false
		return

	visible = true
	var ev := _state.pending_choice_event
	var ev_type: String = String(ev.get("type", "generic"))
	var cost := int(ev.get("cost", 0))
	var can_afford := _state.cash >= cost

	var border_col := UiPalette.GOLD_ACCENT if ev_type == "carhartt" else UiPalette.PURPLE_VIP
	var title_text := "🧥 STREET OPPORTUNITY" if ev_type == "carhartt" else "🚗 TRUNK DEAL"

	var vbox := UiPalette.build_modal_shell(
		self,
		title_text,
		border_col,
		false
	)
	vbox.add_theme_constant_override("separation", 18)

	# =========================================================================
	# 1. CHARACTER DOSSIER PANEL (Stylistic Portrait + Dialogue Speech Bubble)
	# =========================================================================
	var char_card := PanelContainer.new()
	char_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_card.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_BG, border_col, 20, 3, 24, 20))
	vbox.add_child(char_card)

	var char_vbox := VBoxContainer.new()
	char_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_vbox.add_theme_constant_override("separation", 14)
	char_card.add_child(char_vbox)

	# Character Epithet / Name
	var char_name := "MEGA SAVER LOT HUSTLER" if ev_type == "carhartt" else "IROC-Z TRUNK SPECIALIST"
	var name_lbl := UiPalette.add_label(char_vbox, char_name, 34, border_col, false, true)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Stylistic Character Portrait
	var portrait_center := CenterContainer.new()
	portrait_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_vbox.add_child(portrait_center)

	var portrait_icon := UiIcons.encounter_portrait_for_type(ev_type)
	var portrait := UiIcons.create_icon_rect(portrait_icon, 180)
	portrait_center.add_child(portrait)

	# Dialogue Speech Bubble
	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.add_theme_stylebox_override(
		"panel",
		UiPalette.make_box(Color("#141D2B"), UiPalette.BORDER_SLATE, 14, 2, 20, 16)
	)
	char_vbox.add_child(bubble)

	var prompt_str := String(ev.get("prompt", "A street stranger approaches you with an offer."))
	var prompt_lbl := UiPalette.add_label(bubble, "“%s”" % prompt_str, 32, UiPalette.TEXT_PRIMARY)
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# =========================================================================
	# 2. OFFER ITEM BREAKDOWN CARD
	# =========================================================================
	var offer_card := PanelContainer.new()
	offer_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offer_card.add_theme_stylebox_override(
		"panel",
		UiPalette.make_box(Color("#0B1320"), UiPalette.BORDER_SLATE, 16, 2, 20, 16)
	)
	vbox.add_child(offer_card)

	var offer_hbox := HBoxContainer.new()
	offer_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offer_hbox.add_theme_constant_override("separation", 18)
	offer_card.add_child(offer_hbox)

	if ev_type == "carhartt":
		var coat_icon := UiIcons.create_icon_rect("coat", 84)
		coat_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		offer_hbox.add_child(coat_icon)

		var coat_vbox := VBoxContainer.new()
		coat_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		coat_vbox.add_theme_constant_override("separation", 6)
		offer_hbox.add_child(coat_vbox)

		UiPalette.add_label(coat_vbox, "Carhartt Duck Canvas Jacket", 32, UiPalette.GOLD_ACCENT, false, true)
		var bonus := int(ev.get("bonus", 10))
		var cur_cap := _state.get_max_capacity()
		var stat_str := "🎒 Capacity: %d ➔ %d (+%d Pockets)" % [cur_cap, cur_cap + bonus, bonus]
		UiPalette.add_label(coat_vbox, stat_str, 28, UiPalette.CASH_EMERALD, false, true)
	elif ev_type == "trunk_gun":
		var gun_icon := UiIcons.create_icon_rect("gun", 84)
		gun_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		offer_hbox.add_child(gun_icon)

		var gun_vbox := VBoxContainer.new()
		gun_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gun_vbox.add_theme_constant_override("separation", 6)
		offer_hbox.add_child(gun_vbox)

		var wid := String(ev.get("weapon_id", ""))
		var w_def := OmahaCatalog.get_weapon(wid)
		UiPalette.add_label(gun_vbox, "%s (30%% Street Discount)" % String(w_def.get("name", "Firearm")), 32, UiPalette.PURPLE_VIP, false, true)
		var dmg_str := "💥 %d Damage  •  %d%% Accuracy  •  Slot %d/%d" % [
			int(w_def.get("damage", 15)),
			int(round(float(w_def.get("hit_chance", 0.75)) * 100.0)),
			_state.weapons.size() + 1,
			_state.get_max_weapon_slots()
		]
		UiPalette.add_label(gun_vbox, dmg_str, 28, UiPalette.CASH_EMERALD, false, true)
	else:
		var misc_vbox := VBoxContainer.new()
		misc_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		offer_hbox.add_child(misc_vbox)
		UiPalette.add_label(misc_vbox, String(ev.get("title", "Street Offer")), 32, UiPalette.TEXT_PRIMARY, false, true)

	# =========================================================================
	# 3. ACTION BUTTONS (Generous mobile touch targets with visual icons)
	# =========================================================================
	var btn_vbox := VBoxContainer.new()
	btn_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_vbox.add_theme_constant_override("separation", 14)
	vbox.add_child(btn_vbox)

	# Accept / Buy Button
	var buy_btn := Button.new()
	var buy_text := "BUY DEAL (%s)" % Money.format(cost) if can_afford else "NEED CASH (%s)" % Money.format(cost)
	buy_btn.text = buy_text
	buy_btn.icon = UiIcons.get_icon("cash", 48)
	buy_btn.custom_minimum_size = Vector2(0, 110)
	buy_btn.disabled = not can_afford
	UiPalette.style_button(
		buy_btn,
		UiPalette.BTN_SUCCESS if can_afford else UiPalette.BTN_DISABLED,
		UiPalette.CASH_EMERALD if can_afford else UiPalette.BORDER_SLATE,
		UiPalette.TEXT_PRIMARY if can_afford else UiPalette.TEXT_MUTED,
		38
	)
	buy_btn.pressed.connect(func() -> void:
		Audio.play(&"cash_register")
		Haptics.pulse(25.0)
		_state.accept_choice_event()
		encounter_resolved.emit()
	)
	btn_vbox.add_child(buy_btn)

	# Pass / Decline Button
	var pass_btn := Button.new()
	pass_btn.text = "PASS & WALK AWAY"
	pass_btn.icon = UiIcons.get_icon("close_x", 40)
	pass_btn.custom_minimum_size = Vector2(0, 96)
	UiPalette.style_button(pass_btn, UiPalette.CARD_BG, UiPalette.BORDER_SLATE, UiPalette.TEXT_SECONDARY, 34)
	pass_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		_state.decline_choice_event()
		encounter_resolved.emit()
	)
	btn_vbox.add_child(pass_btn)
