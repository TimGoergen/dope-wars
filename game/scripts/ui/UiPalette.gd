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
const BTN_PRIMARY := Color("#1E40AF")
const BTN_SUCCESS := Color("#0D5C2E")
const BTN_DANGER := Color("#991B1B")
const BTN_AMBER := Color("#92400E")
const BTN_DISABLED := Color("#17202E")

# Chunky, high-visibility font scale for 1080x2400 portrait viewport (Pixel 10 Pro XL)
const FONT_HERO_CASH := 64
const FONT_HERO_DEBT := 56
const FONT_HERO_ROW2 := 46
const FONT_HERO_ROW3 := 44
const FONT_SELL_BTN := 60
const FONT_DRUG_BTN := 45
const FONT_DRUG_PRICE := 46
const FONT_DRUG_NAME := 44
const FONT_DRUG_SUB := 34
const FONT_HERO := 48
const FONT_TITLE := 46
const FONT_HEADER := 38
const FONT_SUBHEAD := 34
const FONT_ROW_MAIN := 34
const FONT_BUTTON := 30
const FONT_ROW_SUB := 26
const FONT_SMALL := 25
const FONT_TINY := 23


static var _bold_font: FontVariation
static var _empty_stylebox: StyleBoxEmpty


static func make_bold_font() -> FontVariation:
	if _bold_font == null:
		_bold_font = FontVariation.new()
		_bold_font.base_font = ThemeDB.fallback_font
		_bold_font.variation_embolden = 0.45
	return _bold_font


static func make_empty_box() -> StyleBoxEmpty:
	if _empty_stylebox == null:
		_empty_stylebox = StyleBoxEmpty.new()
	return _empty_stylebox


static func make_vertical_gradient(top_color: Color, bottom_color: Color, w: int = 32, h: int = 96) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([top_color, bottom_color])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = w
	tex.height = h
	return tex


static func make_pronounced_edge_fade(edge_color: Color, at_top: bool, h: int = 130) -> GradientTexture2D:
	var grad := Gradient.new()
	var transparent := Color(edge_color.r, edge_color.g, edge_color.b, 0.0)
	if at_top:
		grad.colors = PackedColorArray([
			Color(edge_color.r, edge_color.g, edge_color.b, 1.0),
			Color(edge_color.r, edge_color.g, edge_color.b, 0.85),
			Color(edge_color.r, edge_color.g, edge_color.b, 0.50),
			Color(edge_color.r, edge_color.g, edge_color.b, 0.20),
			transparent
		])
		grad.offsets = PackedFloat32Array([0.0, 0.25, 0.55, 0.80, 1.0])
	else:
		grad.colors = PackedColorArray([
			transparent,
			Color(edge_color.r, edge_color.g, edge_color.b, 0.20),
			Color(edge_color.r, edge_color.g, edge_color.b, 0.50),
			Color(edge_color.r, edge_color.g, edge_color.b, 0.85),
			Color(edge_color.r, edge_color.g, edge_color.b, 1.0)
		])
		grad.offsets = PackedFloat32Array([0.0, 0.20, 0.45, 0.75, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = 32
	tex.height = h
	return tex


static func style_flat_inert_button(btn: Button) -> void:
	var eb := make_empty_box()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", eb)
	btn.add_theme_stylebox_override("hover", eb)
	btn.add_theme_stylebox_override("pressed", eb)
	btn.add_theme_stylebox_override("focus", eb)
	btn.add_theme_stylebox_override("disabled", eb)
	btn.add_theme_color_override("icon_normal_color", Color.WHITE)
	btn.add_theme_color_override("icon_hover_color", Color.WHITE)
	btn.add_theme_color_override("icon_pressed_color", Color.WHITE)
	btn.add_theme_color_override("icon_focus_color", Color.WHITE)
	btn.add_theme_color_override("icon_disabled_color", Color(1.0, 1.0, 1.0, 0.35))


static func style_close_button(btn: Button) -> void:
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	var normal := make_box(Color("#131B29"), BORDER_BRIGHT, 0, 3, 0, 0)
	var hover := make_box(Color("#1E293B"), GOLD_ACCENT, 0, 3, 0, 0)
	var pressed := make_box(Color("#0B0F17"), BORDER_BRIGHT, 0, 3, 0, 0)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_color_override("icon_normal_color", TEXT_PRIMARY)
	btn.add_theme_color_override("icon_hover_color", GOLD_ACCENT)
	btn.add_theme_color_override("icon_pressed_color", TEXT_SECONDARY)


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
	var extracted := UiIcons.extract_leading_icon(btn.text)
	var icon_name := String(extracted["icon"])
	if icon_name != "":
		btn.icon = UiIcons.get_icon(icon_name, clampi(font_sz + 8, 30, 52))
		btn.text = String(extracted["text"])
	else:
		btn.text = UiIcons.strip_emojis(btn.text)

	var bw := 3 if border.a > 0.01 else 0
	var normal := make_box(bg, border, radius, bw, 12, 8)
	var hover := make_box(bg.lightened(0.08), border.lightened(0.12), radius, bw, 12, 8)
	var pressed := make_box(bg.darkened(0.16), border, radius, bw, 12, 8)
	var disabled := make_box(BTN_DISABLED, Color("#2A394F"), radius, 2, 12, 8)

	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.add_theme_color_override("font_focus_color", text_col)
	btn.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	btn.add_theme_color_override("icon_normal_color", Color.WHITE)
	btn.add_theme_color_override("icon_hover_color", Color.WHITE)
	btn.add_theme_color_override("icon_pressed_color", Color.WHITE)
	btn.add_theme_color_override("icon_focus_color", Color.WHITE)
	btn.add_theme_color_override("icon_disabled_color", Color(1.0, 1.0, 1.0, 0.45))
	btn.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	btn.add_theme_constant_override("outline_size", 0 if btn.disabled else 5)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_font_override("font", make_bold_font())
	btn.clip_text = true


static func style_slider(slider: HSlider) -> void:
	var grabber_tex := UiIcons.get_icon("slider_grabber", 56)
	var grabber_hl := UiIcons.get_icon("slider_grabber_highlight", 56)
	slider.add_theme_icon_override("grabber", grabber_tex)
	slider.add_theme_icon_override("grabber_highlight", grabber_hl)
	slider.add_theme_icon_override("grabber_disabled", grabber_tex)

	var track_bg := make_box(CARD_BG, BORDER_SLATE, 8, 2, 0, 0)
	track_bg.content_margin_top = 20
	track_bg.content_margin_bottom = 20

	var track_fill := make_box(GOLD_ACCENT, GOLD_ACCENT, 8, 0, 0, 0)
	track_fill.content_margin_top = 20
	track_fill.content_margin_bottom = 20

	slider.add_theme_stylebox_override("slider", track_bg)
	slider.add_theme_stylebox_override("grabber_area", track_fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", track_fill)


static func style_bottom_tab_button(btn: Button, is_active: bool, tab_idx: int) -> void:
	var bg := BTN_PRIMARY if is_active else CARD_BG
	var border := GOLD_ACCENT if is_active else BORDER_BRIGHT
	var text_col := GOLD_ACCENT if is_active else TEXT_PRIMARY
	var normal := make_box(bg, border, 20, 4, 14, 14)
	var hover := make_box(bg.lightened(0.08), border.lightened(0.12), 20, 4, 14, 14)
	var pressed := make_box(bg.darkened(0.16), border, 20, 4, 14, 14)

	for sb in [normal, hover, pressed]:
		sb.content_margin_top = 54
		sb.content_margin_bottom = 14
		if tab_idx == 0:
			sb.corner_radius_bottom_left = 64
		elif tab_idx == 2:
			sb.corner_radius_bottom_right = 64

	btn.focus_mode = Control.FOCUS_NONE
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	btn.add_theme_constant_override("icon_max_width", 128)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.add_theme_color_override("font_focus_color", text_col)
	btn.add_theme_color_override("icon_normal_color", Color.WHITE)
	btn.add_theme_color_override("icon_hover_color", Color.WHITE)
	btn.add_theme_color_override("icon_pressed_color", Color.WHITE)
	btn.add_theme_color_override("icon_focus_color", Color.WHITE)
	btn.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	btn.add_theme_constant_override("outline_size", 5)
	btn.add_theme_font_size_override("font_size", FONT_DRUG_BTN)
	btn.add_theme_font_override("font", make_bold_font())
	btn.clip_text = false


static func add_label(
	parent: Node,
	text: String,
	font_sz: int = FONT_ROW_MAIN,
	col: Color = TEXT_PRIMARY,
	wrap: bool = true,
	bold: bool = false
) -> Label:
	var extracted := UiIcons.extract_leading_icon(text)
	var icon_name := String(extracted["icon"])
	var clean_text := String(extracted["text"]) if icon_name != "" else UiIcons.strip_emojis(text)

	var target_parent: Node = parent
	if icon_name != "" and parent is VBoxContainer:
		var hb := HBoxContainer.new()
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_theme_constant_override("separation", 10)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(hb)
		var ic := UiIcons.create_icon_rect(icon_name, clampi(font_sz + 8, 28, 48))
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(ic)
		target_parent = hb

	var lbl := Label.new()
	lbl.text = clean_text
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", col)
	if bold or font_sz >= FONT_ROW_MAIN:
		lbl.add_theme_font_override("font", make_bold_font())
	if wrap:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if target_parent != parent:
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_parent.add_child(lbl)
	return lbl


static func add_rich_label(
	parent: Node,
	text: String,
	font_sz: int = FONT_ROW_MAIN,
	col: Color = TEXT_PRIMARY,
	wrap: bool = true
) -> RichTextLabel:
	var extracted := UiIcons.extract_leading_icon(text)
	var icon_name := String(extracted["icon"])
	var clean_text := String(extracted["text"]) if icon_name != "" else UiIcons.strip_emojis(text)

	var target_parent: Node = parent
	if icon_name != "" and parent is VBoxContainer:
		var hb := HBoxContainer.new()
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_theme_constant_override("separation", 10)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(hb)
		var ic := UiIcons.create_icon_rect(icon_name, clampi(font_sz + 8, 28, 48))
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(ic)
		target_parent = hb

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl.add_theme_font_size_override("normal_font_size", font_sz)
	rtl.add_theme_font_size_override("bold_font_size", font_sz)
	rtl.add_theme_font_override("bold_font", make_bold_font())
	rtl.add_theme_color_override("default_color", col)
	if wrap:
		rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.text = clean_text
	if target_parent != parent:
		rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_parent.add_child(rtl)
	return rtl


static func add_hero_label(
	parent: Node,
	text: String,
	font_sz: int,
	col: Color,
	align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var lbl := Label.new()
	lbl.text = UiIcons.strip_emojis(text)
	lbl.horizontal_alignment = align
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_override("font", make_bold_font())
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.90))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 3)
	lbl.add_theme_constant_override("shadow_outline_size", 4)
	parent.add_child(lbl)
	return lbl


static func add_hero_stat(
	parent: Node,
	icon_name: String,
	icon_px: int,
	text: String,
	font_sz: int,
	col: Color,
	align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
	expand_h: bool = false
) -> Label:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	if expand_h:
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		hb.alignment = BoxContainer.ALIGNMENT_END
	else:
		hb.alignment = BoxContainer.ALIGNMENT_BEGIN
	parent.add_child(hb)

	var icon_rect := UiIcons.create_icon_rect(icon_name, icon_px)
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(icon_rect)

	var lbl := add_hero_label(hb, text, font_sz, col, align)
	return lbl


static func make_hero_header_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#111B29")
	sb.border_color = GOLD_ACCENT
	sb.set_border_width_all(4)
	sb.corner_radius_top_left = 64
	sb.corner_radius_top_right = 64
	sb.corner_radius_bottom_left = 24
	sb.corner_radius_bottom_right = 24
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 24
	sb.content_margin_bottom = 16
	return sb


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
	margin.add_theme_constant_override("margin_top", 96)
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

	# Header Row with optional SVG icon, wrapped title, and unmissable Close button
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	card_vbox.add_child(header)

	var extracted := UiIcons.extract_leading_icon(title_text)
	var icon_name := String(extracted["icon"])
	var clean_title := String(extracted["text"]) if icon_name != "" else UiIcons.strip_emojis(title_text)
	if icon_name != "":
		var hdr_icon := UiIcons.create_icon_rect(icon_name, 48)
		hdr_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(hdr_icon)

	var title_lbl := add_label(header, clean_title, FONT_HEADER, GOLD_ACCENT, true, true)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if allow_close:
		var close_btn := Button.new()
		close_btn.text = ""
		close_btn.icon = UiIcons.get_icon("close_x", 62)
		close_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		close_btn.custom_minimum_size = Vector2(90, 90)
		close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		style_close_button(close_btn)
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

	return body_vbox
