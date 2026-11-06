class_name EncounterOverlay
extends ColorRect

# Choice prompt modal for street encounters (Carhartt Jacket Vendor / Camaro Trunk Gun Dealer).

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

	var vbox := UiPalette.build_modal_shell(
		self,
		"🧥 " + String(ev.get("title", "Street Offer")),
		UiPalette.GOLD_ACCENT,
		false
	)

	var prompt := UiPalette.add_label(vbox, String(ev.get("prompt", "")), UiPalette.FONT_ROW_MAIN, UiPalette.TEXT_PRIMARY)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	vbox.add_child(row)

	var accept_btn := Button.new()
	accept_btn.text = "BUY (%s)" % Money.format(int(ev.get("cost", 0)))
	accept_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accept_btn.custom_minimum_size = Vector2(0, 88)
	UiPalette.style_button(accept_btn, UiPalette.BTN_SUCCESS, UiPalette.CASH_EMERALD, UiPalette.TEXT_PRIMARY, UiPalette.FONT_SUBHEAD)
	accept_btn.pressed.connect(func() -> void:
		Audio.play(&"cash_register")
		Haptics.pulse(25.0)
		_state.accept_choice_event()
		encounter_resolved.emit()
	)
	row.add_child(accept_btn)

	var pass_btn := Button.new()
	pass_btn.text = "PASS"
	pass_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pass_btn.custom_minimum_size = Vector2(0, 88)
	UiPalette.style_button(pass_btn, UiPalette.CARD_BG, UiPalette.BORDER_SLATE, UiPalette.TEXT_SECONDARY, UiPalette.FONT_SUBHEAD)
	pass_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		_state.decline_choice_event()
		encounter_resolved.emit()
	)
	row.add_child(pass_btn)
