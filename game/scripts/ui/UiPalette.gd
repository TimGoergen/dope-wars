class_name UiPalette

# High-Contrast Dark OLED "Omaha Street Noir" color palette, typography scale, and StyleBoxFlat builders
# optimized for the Pixel 10 Pro XL (1080 x 2400 portrait viewport).

const SLATE_BG := Color("#070A0F")
const PANEL_BG := Color("#151F2E")
const CARD_BG := Color("#202F45")
const CARD_ALT_BG := Color("#192638")
const ROW_HOVER_BG := Color("#293C58")
const MODAL_BACKDROP := Color(0.01, 0.03, 0.06, 0.90)

const BORDER_SLATE := Color("#3E5677")
const BORDER_BRIGHT := Color("#6488B8")

const TEXT_PRIMARY := Color("#F8FAFC")
const TEXT_SECONDARY := Color("#CBD5E1")
const TEXT_MUTED := Color("#64748B")

const CASH_EMERALD := Color("#4ADE80")
const CASH_DARK := Color("#14532D")
const BANK_CYAN := Color("#38BDF8")
const DEBT_CRIMSON := Color("#FB7185")
const GOLD_ACCENT := Color("#FACC15")
const PURPLE_VIP := Color("#C084FC")

const SPIKE_AMBER := Color("#FBBF24")
const SPIKE_BG := Color("#5C2406")
const FLOOD_CYAN := Color("#22D3EE")
const FLOOD_BG := Color("#0A4358")

const POLICE_RED := Color("#EF4444")
const POLICE_BLUE := Color("#3B82F6")
const BTN_PRIMARY := Color("#1D4ED8")
const BTN_SUCCESS := Color("#16A34A")
const BTN_DANGER := Color("#DC2626")
const BTN_AMBER := Color("#D97706")
const BTN_DISABLED := Color("#17202E")

# Chunky, high-visibility font scale for 1080x2400 portrait viewport (Pixel 10 Pro XL)
const FONT_HERO := 42
const FONT_TITLE := 46
const FONT_HEADER := 38
const FONT_SUBHEAD := 34
const FONT_ROW_MAIN := 34
const FONT_BUTTON := 30
const FONT_ROW_SUB := 26
const FONT_SMALL := 25
const FONT_TINY := 23


static var _bold_font: FontVariation


static func make_bold_font() -> FontVariation:
	if _bold_font == null:
		_bold_font = FontVariation.new()
		_bold_font.base_font = ThemeDB.fallback_font
		_bold_font.variation_embolden = 0.45
	return _bold_font


static func make_box(
	bg: Color,
	border: Color = Color.TRANSPARENT,
	radius: int = 12,
	border_width: int = 3,
	pad_h: int = 16,
	pad_v: int = 12
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	if border.a > 0.01 and border_width > 0:
		sb.border_color = border
		sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


static func style_button(
	btn: Button,
	bg: Color,
	border: Color = Color.TRANSPARENT,
	text_col: Color = TEXT_PRIMARY,
	font_sz: int = FONT_BUTTON,
	radius: int = 12
) -> void:
	var bw := 3 if border.a > 0.01 else 0
	var normal := make_box(bg, border, radius, bw, 14, 10)
	var hover := make_box(bg.lightened(0.12), border.lightened(0.18), radius, bw, 14, 10)
	var pressed := make_box(bg.darkened(0.18), border, radius, bw, 14, 10)
	var disabled := make_box(BTN_DISABLED, Color("#2A394F"), radius, 2, 14, 10)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.add_theme_color_override("font_focus_color", text_col)
	btn.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_font_override("font", make_bold_font())
	btn.clip_text = true


static func add_label(
	parent: Node,
	text: String,
	font_sz: int = FONT_ROW_MAIN,
	col: Color = TEXT_PRIMARY,
	wrap: bool = true,
	bold: bool = false
) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", col)
	if bold or font_sz >= FONT_ROW_MAIN:
		lbl.add_theme_font_override("font", make_bold_font())
	if wrap:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(lbl)
	return lbl


## Builds a strictly screen-bounded modal card inside `overlay` (never uses CenterContainer,
## so children can NEVER exceed the 1080px screen width).
static func build_modal_shell(
	overlay: ColorRect,
	title_text: String,
	border_col: Color,
	allow_close: bool = true,
	on_close: Callable = Callable()
) -> VBoxContainer:
	if allow_close:
		var bg_btn := Button.new()
		bg_btn.flat = true
		bg_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg_btn.pressed.connect(func() -> void:
			Audio.play(&"tap")
			if on_close.is_valid():
				on_close.call()
			else:
				overlay.visible = false
		)
		overlay.add_child(bg_btn)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 56)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	overlay.add_child(margin)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(outer_vbox)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", make_box(PANEL_BG, border_col, 22, 4, 24, 22))
	outer_vbox.add_child(card)

	var card_vbox := VBoxContainer.new()
	card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_vbox.add_theme_constant_override("separation", 16)
	card.add_child(card_vbox)

	# Header Row with wrapped title and unmissable Close button
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	card_vbox.add_child(header)

	var title_lbl := add_label(header, title_text, FONT_HEADER, GOLD_ACCENT, true, true)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if allow_close:
		var close_btn := Button.new()
		close_btn.text = "✕ CLOSE"
		close_btn.custom_minimum_size = Vector2(170, 72)
		style_button(close_btn, BTN_DANGER, DEBT_CRIMSON, TEXT_PRIMARY, FONT_SMALL)
		close_btn.pressed.connect(func() -> void:
			Audio.play(&"tap")
			if on_close.is_valid():
				on_close.call()
			else:
				overlay.visible = false
		)
		header.add_child(close_btn)

	# Scrollable body so tall content never pushes buttons off the bottom of the screen
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	card_vbox.add_child(scroll)

	var body_vbox := VBoxContainer.new()
	body_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(body_vbox)

	if allow_close:
		var bottom_close := Button.new()
		bottom_close.text = "⬅ BACK TO STREETS"
		bottom_close.custom_minimum_size = Vector2(0, 84)
		bottom_close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		style_button(bottom_close, CARD_BG, BORDER_BRIGHT, TEXT_PRIMARY, FONT_BUTTON)
		bottom_close.pressed.connect(func() -> void:
			Audio.play(&"tap")
			if on_close.is_valid():
				on_close.call()
			else:
				overlay.visible = false
		)
		card_vbox.add_child(bottom_close)

	return body_vbox
