extends Control
## WORLD ORDER - UI shell, built entirely in code (supports Arabic RTL).

const GOLD := Color("d4af37")
const BG := Color("04080f")
const TXT := Color("e8e2d0")
const GREEN := Color("4cd964")
const RED := Color("ff5a4d")
const BLUE := Color("4a90ff")
const GRAY := Color("8a93a3")
const ORANGE := Color("ff9a3c")

var MapScript: GDScript = preload("res://scripts/map_view.gd")
var ChartScript: GDScript = preload("res://scripts/chart.gd")

var map_view: Control
var top_labels := {}
var left_panel: PanelContainer
var stat_labels := {}
var right_panel: PanelContainer
var right_content: VBoxContainer
var right_scroll: ScrollContainer
var right_mode := "country"
var screen: PanelContainer
var screen_title: Label
var screen_scroll: ScrollContainer
var screen_flow: HFlowContainer
var ticker: Label
var menu_layer: Control
var menu_country: OptionButton
var menu_info: Label
var menu_resume: Button
var menu_continue: Button
var current_screen := ""
var order_kind := ""
var eco_tab := "stocks"
var qty_stock := 10
var qty_comm := 10
var qty_crypto := 1.0
var f_country := ""
var f_sector := ""
var f_text := ""
var f_sort := "cap"
var stock_box: VBoxContainer
var alli_text := ""


func T(s: String) -> String:
	return Lang.t(s)


func _ready() -> void:
	Game.changed.connect(_on_changed)
	Game.day_passed.connect(_on_day)
	Game.news.connect(_on_news)
	Game.proposal.connect(_on_proposal)
	Game.battle_alert.connect(_on_battle_alert)
	_build_all()


func _build_all() -> void:
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	theme = _make_theme()
	layout_direction = Control.LAYOUT_DIRECTION_RTL if Lang.ar else Control.LAYOUT_DIRECTION_LTR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_build_top())
	var mid := Control.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.clip_contents = true
	mid.layout_direction = Control.LAYOUT_DIRECTION_LTR
	root.add_child(mid)
	map_view = MapScript.new()
	mid.add_child(map_view)
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_view.province_clicked.connect(_on_province_clicked)
	map_view.province_right_clicked.connect(_on_province_right)
	map_view.army_clicked.connect(_on_army_clicked)
	_build_left(mid)
	_build_right(mid)
	_build_screen(mid)
	ticker = Label.new()
	ticker.text = "WORLD ORDER"
	ticker.clip_text = true
	ticker.add_theme_font_size_override("font_size", 15)
	ticker.add_theme_color_override("font_color", Color("ffcc66"))
	root.add_child(ticker)
	root.add_child(_build_nav())
	_build_menu()
	if Game.started:
		menu_layer.visible = false
		map_view.refresh_colors()
		_refresh_all()
	else:
		_show_menu()


# ---------------------------------------------------------------- theme & helpers
func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = Lang.font
	t.default_font_size = 18
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.07, 0.11, 0.94)
	sb.border_color = Color(0.55, 0.45, 0.18, 0.85)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	t.set_stylebox("panel", "PanelContainer", sb)
	var names := {"normal": Color(0.08, 0.11, 0.17), "hover": Color(0.14, 0.18, 0.26), "pressed": Color(0.35, 0.28, 0.1),
		"disabled": Color(0.06, 0.07, 0.09), "focus": Color(0.08, 0.11, 0.17)}
	for st in names:
		var b := StyleBoxFlat.new()
		b.bg_color = names[st]
		b.border_color = Color(0.7, 0.58, 0.2, 0.9 if st != "disabled" else 0.3)
		b.set_border_width_all(1)
		b.set_corner_radius_all(5)
		b.content_margin_left = 12
		b.content_margin_right = 12
		b.content_margin_top = 8
		b.content_margin_bottom = 8
		t.set_stylebox(st, "Button", b)
		t.set_stylebox(st, "OptionButton", b)
	t.set_color("font_color", "Button", TXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.4, 0.4))
	t.set_color("font_color", "OptionButton", TXT)
	t.set_color("font_color", "Label", TXT)
	t.set_constant("separation", "VBoxContainer", 5)
	t.set_constant("h_separation", "HFlowContainer", 10)
	t.set_constant("v_separation", "HFlowContainer", 10)
	return t


func _label(text: String, color := TXT, size := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	return l


func _wrap(text: String, color := TXT, size := 0) -> Label:
	var l := _label(text, color, size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(200, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _btn(parent: Node, text: String, cb: Callable, color := Color.WHITE) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	if color != Color.WHITE:
		b.add_theme_color_override("font_color", color)
	parent.add_child(b)
	return b


func _kv(parent: Node, k: String, v: String, color := TXT) -> Label:
	var h := HBoxContainer.new()
	var a := _label(k, GRAY)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	var b := _label(v, color)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(b)
	parent.add_child(h)
	return b


func _bar(parent: Node, value: float, maxv: float, color: Color, minv := 0.0) -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = minv
	p.max_value = maxv
	p.value = value
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, 10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.08)
	back.set_corner_radius_all(3)
	p.add_theme_stylebox_override("fill", fill)
	p.add_theme_stylebox_override("background", back)
	parent.add_child(p)
	return p


func _chart(parent: Node, data: Array, color: Color, h := 50.0, grid := false) -> Control:
	var c: Control = ChartScript.new()
	c.data = data
	c.color = color
	c.grid = grid
	c.custom_minimum_size = Vector2(0, h)
	c.layout_direction = Control.LAYOUT_DIRECTION_LTR
	parent.add_child(c)
	return c


func _card(title: String, width := 360.0) -> VBoxContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 0)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(_label(title, GOLD, 22))
	v.add_child(HSeparator.new())
	screen_flow.add_child(p)
	return v


func _opt(items: Array) -> OptionButton:
	var o := OptionButton.new()
	for i in items.size():
		o.add_item(str(items[i][0]), i)
		o.set_item_metadata(i, items[i][1])
	return o


func _opt_val(o: OptionButton) -> Variant:
	if o.item_count == 0 or o.selected < 0:
		return null
	return o.get_item_metadata(o.selected)


func _opt_select(o: OptionButton, v: Variant) -> void:
	for i in o.item_count:
		if o.get_item_metadata(i) == v:
			o.select(i)


func _clear(node: Node) -> void:
	for ch in node.get_children():
		node.remove_child(ch)
		ch.queue_free()


func _msg(text: String) -> void:
	var d := AcceptDialog.new()
	d.exclusive = false
	d.title = T("Notice")
	d.ok_button_text = T("OK")
	d.dialog_text = text
	d.dialog_autowrap = true
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(d.queue_free)
	add_child(d)
	d.popup_centered(Vector2i(480, 170))


func _act(res: String) -> void:
	if res != "":
		_msg(res)


func _confirm(text: String, on_ok: Callable, on_cancel := Callable(), ok_text := "") -> void:
	var d := ConfirmationDialog.new()
	d.exclusive = false
	d.title = T("Notice")
	d.dialog_text = text
	d.dialog_autowrap = true
	d.ok_button_text = ok_text if ok_text != "" else T("OK")
	d.cancel_button_text = T("Cancel")
	d.confirmed.connect(func(): on_ok.call())
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(func():
		if on_cancel.is_valid():
			on_cancel.call())
	d.canceled.connect(d.queue_free)
	add_child(d)
	d.popup_centered(Vector2i(500, 200))


func _dialog(title: String, build: Callable, on_ok: Callable, ok_text := "") -> void:
	var d := ConfirmationDialog.new()
	d.exclusive = false
	d.title = title
	d.ok_button_text = ok_text if ok_text != "" else T("OK")
	d.cancel_button_text = T("Cancel")
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(420, 0)
	d.add_child(v)
	var ctl: Dictionary = build.call(v)
	d.confirmed.connect(func(): on_ok.call(ctl))
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(d.queue_free)
	add_child(d)
	d.popup_centered(Vector2i(480, 280))


func _pf(p: float) -> String:
	if p >= 1000.0:
		return Game.commas(int(p))
	if p >= 10.0:
		return "%.2f" % p
	return "%.4f" % p


func _pct(v: float) -> String:
	return "\u200e%+.2f%%" % (v * 100.0)


# ---------------------------------------------------------------- top / left / right / nav
func _build_top() -> Control:
	var p := PanelContainer.new()
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 14)
	p.add_child(fl)
	fl.add_child(_label("WORLD ORDER", GOLD, 24))
	for k in ["date", "cash", "treasury", "oil", "gold", "btc", "power", "influence"]:
		var l := _label("")
		fl.add_child(l)
		top_labels[k] = l
	top_labels["pause"] = _btn(fl, T("Play"), _toggle_pause)
	var sp := OptionButton.new()
	for s in ["1x", "2x", "5x", "10x"]:
		sp.add_item(s)
	sp.item_selected.connect(func(i): Game.speed = [1.0, 2.0, 5.0, 10.0][i])
	fl.add_child(sp)
	_btn(fl, T("Stats"), func(): left_panel.visible = not left_panel.visible)
	_btn(fl, T("Menu"), _show_menu)
	return p


func _build_left(mid: Control) -> void:
	left_panel = PanelContainer.new()
	mid.add_child(left_panel)
	left_panel.position = Vector2(8, 8)
	left_panel.custom_minimum_size = Vector2(235, 0)
	left_panel.visible = get_viewport_rect().size.x >= 1100.0
	var box := VBoxContainer.new()
	left_panel.add_child(box)
	stat_labels["title"] = _label("", GOLD, 19)
	box.add_child(stat_labels["title"])
	stat_labels["gov"] = _label("", GRAY, 14)
	box.add_child(stat_labels["gov"])
	box.add_child(HSeparator.new())
	for k in ["Stability", "Prestige", "Diplomatic Power", "Espionage", "Territories", "Population", "Growth", "War Support"]:
		stat_labels[k] = _kv(box, T(k), "-")
	stat_labels["bar_stab"] = _bar(box, 0, 100, GREEN)
	stat_labels["bar_war"] = _bar(box, 0, 100, ORANGE)
	_btn(box, T("Policies & Laws"), func(): _open_screen("politics"))


func _build_right(mid: Control) -> void:
	right_panel = PanelContainer.new()
	mid.add_child(right_panel)
	right_panel.anchor_left = 1.0
	right_panel.anchor_right = 1.0
	right_panel.anchor_top = 0.0
	right_panel.anchor_bottom = 1.0
	var w: float = minf(430.0, get_viewport_rect().size.x * 0.92)
	right_panel.offset_left = -w
	right_panel.offset_right = -6
	right_panel.offset_top = 6
	right_panel.offset_bottom = -6
	right_panel.visible = false
	var v := VBoxContainer.new()
	right_panel.add_child(v)
	var tabs := HBoxContainer.new()
	v.add_child(tabs)
	var t1 := _btn(tabs, T("Country"), func():
		right_mode = "country"
		_fill_right())
	t1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t2 := _btn(tabs, T("Military"), func():
		right_mode = "military"
		_fill_right())
	t2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn(tabs, "X", func(): right_panel.visible = false)
	right_scroll = ScrollContainer.new()
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(right_scroll)
	right_content = VBoxContainer.new()
	right_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right_content)


func _build_screen(mid: Control) -> void:
	screen = PanelContainer.new()
	mid.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.offset_left = 6
	screen.offset_top = 6
	screen.offset_right = -6
	screen.offset_bottom = -6
	screen.visible = false
	var v := VBoxContainer.new()
	screen.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	screen_title = _label("", GOLD, 26)
	screen_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(screen_title)
	_btn(h, T("Close"), _close_screen)
	screen_scroll = ScrollContainer.new()
	screen_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(screen_scroll)
	screen_flow = HFlowContainer.new()
	screen_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen_scroll.add_child(screen_flow)


func _build_nav() -> Control:
	var h := HBoxContainer.new()
	for item in [["Politics", "politics"], ["Economy", "economy"], ["Military", "military"], ["Map", "map"], ["Trade", "trade"], ["Alliance", "alliance"]]:
		var b := Button.new()
		b.text = T(item[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 50)
		var key: String = item[1]
		b.pressed.connect(func(): _nav(key))
		h.add_child(b)
	return h


func _nav(key: String) -> void:
	if not Game.started:
		return
	match key:
		"map":
			_close_screen()
			Game.layer = (Game.layer + 1) % Game.LAYER_NAMES.size()
			_on_news(T("Map layer: %s") % T(Game.LAYER_NAMES[Game.layer]))
			map_view.refresh_colors()
		"military":
			_close_screen()
			if right_panel.visible and right_mode == "military":
				right_panel.visible = false
			else:
				right_mode = "military"
				_fill_right()
		_:
			_open_screen(key)


func _toggle_pause() -> void:
	if not Game.started:
		return
	Game.paused = not Game.paused
	_refresh_top()


func _unhandled_key_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo or not Game.started or menu_layer.visible:
		return
	match k.keycode:
		KEY_SPACE:
			_toggle_pause()
		KEY_TAB:
			_nav("map")
		KEY_1:
			_nav("politics")
		KEY_2:
			_nav("economy")
		KEY_3:
			_nav("military")
		KEY_4:
			_nav("map")
		KEY_5:
			_nav("trade")
		KEY_6:
			_nav("alliance")
		KEY_R:
			_dlg_build_base()
		KEY_M:
			_start_order("move")
		KEY_S:
			Military.stop(Game.sel_armies)
		KEY_ESCAPE:
			_cancel_order()
			_close_screen()


# ---------------------------------------------------------------- menu
func _build_menu() -> void:
	menu_layer = ColorRect.new()
	(menu_layer as ColorRect).color = Color(0.02, 0.03, 0.06, 0.97)
	add_child(menu_layer)
	menu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cc := CenterContainer.new()
	menu_layer.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(460, 0)
	cc.add_child(v)
	var t := _label("WORLD ORDER", GOLD, 52)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := _label(T("Global Geopolitical, Economic & Military Simulator"), GRAY, 16)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	_btn(v, "العربية / English", func():
		Lang.set_arabic(not Lang.ar)
		_build_all())
	v.add_child(_label(T("Choose your nation:")))
	var items: Array = []
	for m in World.countries:
		items.append([m.ar if Lang.ar else m.n, m.id])
	items.sort_custom(func(a, b): return a[0] < b[0])
	menu_country = _opt(items)
	_opt_select(menu_country, "EGY")
	v.add_child(menu_country)
	menu_info = _wrap("", GRAY, 14)
	v.add_child(menu_info)
	menu_country.item_selected.connect(func(_i): _menu_update_info())
	_menu_update_info()
	_btn(v, T("New Game"), func():
		Game.new_game(str(_opt_val(menu_country)))
		menu_layer.visible = false
		_close_screen()
		right_panel.visible = false
		map_view.refresh_colors()
		map_view.focus_on(Game.player)
		_refresh_all())
	menu_continue = _btn(v, T("Continue saved game"), func():
		if Game.load_game():
			menu_layer.visible = false
			map_view.refresh_colors()
			map_view.focus_on(Game.player)
			_refresh_all()
		else:
			_msg(T("No saved game found.")))
	menu_resume = _btn(v, T("Resume"), func(): menu_layer.visible = false)
	_btn(v, T("Save game"), func():
		if Game.started:
			_msg(T("Game saved.") if Game.save_game() else T("Could not save.")))
	var ap := CheckButton.new()
	ap.text = T("Auto-pause when a battle starts")
	ap.button_pressed = Game.auto_pause
	ap.toggled.connect(func(on): Game.auto_pause = on)
	v.add_child(ap)
	if OS.has_feature("pc"):
		_btn(v, T("Quit"), func(): get_tree().quit())
	var hint := _wrap(T("Space = pause | Tab = map layer | 1-6 = screens | M = move | S = stop | R = build base | wheel / pinch = zoom | right-click = order"), GRAY, 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)


func _menu_update_info() -> void:
	var id: String = str(_opt_val(menu_country))
	if id == "":
		return
	var m: Dictionary = World.countries[World.cidx[id]]
	var troops: float = float(Tables.TROOPS.get(id, clampf(sqrt(float(m.pop)) * 7.0 + float(m.gdp) * 0.04, 3.0, 300.0)))
	menu_info.text = T("Population %.1fM | GDP %s B | Troops %sK | Provinces %d") % [float(m.pop), Game.commas(int(m.gdp)), Game.commas(int(troops)), m.provs.size()]


func _show_menu() -> void:
	if Game.started:
		Game.paused = true
		_refresh_top()
	menu_resume.visible = Game.started
	menu_continue.visible = Game.has_save()
	menu_layer.visible = true


# ---------------------------------------------------------------- refresh
func _on_changed() -> void:
	_refresh_all()


func _focus_is_text() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit


func _on_day() -> void:
	_refresh_top()
	_refresh_left()
	if screen.visible and not _focus_is_text():
		var every := 2 if current_screen == "economy" else 7
		if Game.day % every == 0:
			_rebuild_screen()
	if right_panel.visible and Game.day % 2 == 0:
		_fill_right()


func _on_news(text: String) -> void:
	var lines: Array = Game.news_feed.slice(-3)
	if lines.is_empty() or lines[-1] != text:
		ticker.text = text
	else:
		ticker.text = "  |  ".join(lines)


func _refresh_all() -> void:
	_refresh_top()
	_refresh_left()
	if screen.visible:
		_rebuild_screen()
	if right_panel.visible:
		_fill_right()


func _refresh_top() -> void:
	if not Game.started:
		return
	var c: Dictionary = Game.countries[Game.player]
	top_labels.date.text = "%s | %s %d" % [Game.date_string(), T("Day"), Game.day]
	top_labels.cash.text = "%s %s Cr" % [T("Cash"), Game.commas(int(Game.player_cash))]
	top_labels.treasury.text = "%s %s" % [T("Treasury"), (Game.fmt_m(float(c.treasury)) if c.alive else "-")]
	top_labels.oil.text = "%s %.1f" % [T("Oil"), float(Game.assets.oil.price)]
	top_labels.gold.text = "%s %s" % [T("Gold"), Game.commas(int(Game.assets.gold.price))]
	top_labels.btc.text = "BTC %s" % Game.commas(int(Game.assets.BTC.price))
	top_labels.power.text = "%s %s" % [T("Army"), Game.commas(Game.army_power(Game.player))]
	top_labels.influence.text = "%s %d" % [T("Influence"), int(Game.influence)]
	top_labels.pause.text = T("Play") if Game.paused else T("Pause")


func _refresh_left() -> void:
	if not Game.started:
		return
	var c: Dictionary = Game.countries[Game.player]
	stat_labels.title.text = "%s - %s" % [T("PLAYER"), Game.cname(Game.player)]
	var status: String = T(str(c.gov))
	if Game.exile:
		status = T("GOVERNMENT IN EXILE")
	elif not Game.in_office:
		status = T("OPPOSITION (out of office)")
	stat_labels.gov.text = status
	stat_labels["Stability"].text = "%d%%" % int(c.stability)
	stat_labels["Prestige"].text = Game.commas(int(Game.prestige(Game.player)))
	stat_labels["Diplomatic Power"].text = str(int(Game.influence))
	stat_labels["Espionage"].text = str(int(Game.intel))
	stat_labels["Territories"].text = str(Game.owned.get(Game.player, []).size())
	stat_labels["Population"].text = "%.1fM" % float(c.pop)
	var g := Game.growth(Game.player) * 100.0
	stat_labels["Growth"].text = "\u200e%+.1f%%" % g
	stat_labels["Growth"].add_theme_color_override("font_color", GREEN if g >= 0.0 else RED)
	stat_labels["War Support"].text = "%d%%" % int(c.war_support)
	stat_labels.bar_stab.value = float(c.stability)
	stat_labels.bar_war.value = float(c.war_support)


# ---------------------------------------------------------------- map interaction
func _start_order(kind: String) -> void:
	if Game.sel_armies.is_empty():
		_msg(T("Select an army first (click its marker on the map)."))
		return
	order_kind = kind
	map_view.order_mode = true
	map_view.queue_redraw()


func _cancel_order() -> void:
	order_kind = ""
	map_view.order_mode = false
	map_view.queue_redraw()


func _my_selected() -> Array:
	var out: Array = []
	for id in Game.sel_armies:
		if Game.armies.has(id) and Game.armies[id].o == Game.player:
			out.append(id)
	return out


func _on_army_clicked(id: int, additive: bool) -> void:
	if not Game.armies.has(id):
		return
	if additive and Game.armies[id].o == Game.player:
		if id in Game.sel_armies:
			Game.sel_armies.erase(id)
		else:
			Game.sel_armies.append(id)
	else:
		Game.sel_armies = [id]
	_cancel_order()
	right_mode = "military"
	_fill_right()
	map_view.queue_redraw()


func _on_province_clicked(pid: int) -> void:
	if pid < 0:
		return
	if order_kind != "":
		_do_order(pid)
		return
	_close_screen()
	right_mode = "country"
	_fill_right()


func _on_province_right(pid: int) -> void:
	if _my_selected().is_empty():
		return
	_do_order(pid)


func _do_order(pid: int) -> void:
	var ids := _my_selected()
	if ids.is_empty():
		_cancel_order()
		return
	var errs: Array = []
	for id in ids:
		var a: Dictionary = Game.armies[id]
		if Tables.UTYPES[a.t].land:
			var r := Military.order_move([id], pid)
			if r != "":
				errs.append(r)
		elif order_kind == "strike" or Game.at_war(Game.player, Game.prov_ctl(pid)):
			var r2 := Military.strike(id, pid)
			if r2 != "":
				errs.append(r2)
		else:
			var r3 := Military.order_move([id], pid)
			if r3 != "":
				errs.append(r3)
	_cancel_order()
	if not errs.is_empty():
		_on_news(str(errs[0]))
	_fill_right()


func _on_battle_alert(pid: int) -> void:
	if Game.auto_pause:
		Game.paused = true
		_refresh_top()
	_confirm(T("Battle began in %s!") % Game.pname(pid), func():
		map_view.focus_pid(pid, 5.0)
		var ids: Array = []
		for a in Game.armies.values():
			if a.p == pid and a.o == Game.player:
				ids.append(a.id)
		Game.sel_armies = ids
		right_mode = "military"
		_fill_right(), Callable(), T("Go to battle"))


# ---------------------------------------------------------------- right panel
func _fill_right() -> void:
	if not Game.started:
		return
	var sv := right_scroll.scroll_vertical
	_clear(right_content)
	right_panel.visible = true
	if right_mode == "military":
		_fill_military()
	else:
		_fill_country()
	right_scroll.set_deferred("scroll_vertical", sv)


func _rel_text(r: float) -> String:
	if r >= 60.0:
		return T("Close ally")
	if r >= 30.0:
		return T("Friendly")
	if r > -30.0:
		return T("Neutral")
	if r > -60.0:
		return T("Hostile")
	return T("Enemy")


func _fill_country() -> void:
	var v := right_content
	var pid: int = map_view.selected_pid
	var id: String = Game.player
	if pid >= 0:
		id = Game.prov_owner(pid)
	if not Game.countries.has(id):
		return
	var c: Dictionary = Game.countries[id]
	v.add_child(_label(Game.cname(id).to_upper(), GOLD, 24))
	v.add_child(_label(T(str(c.gov)), GRAY, 14))
	if pid >= 0:
		v.add_child(HSeparator.new())
		v.add_child(_label("%s: %s" % [T("Province"), Game.pname(pid)], TXT, 19))
		var ctl := Game.prov_ctl(pid)
		if ctl != id:
			v.add_child(_label(T("Occupied by %s") % Game.cname(ctl), RED))
		_kv(v, T("Terrain"), T(str(World.terrain(pid)[0])))
		_kv(v, T("Fortification"), str(World.fort(pid)))
		_kv(v, T("City population"), Game.commas(int(World.city_pop.get(pid, 0))))
		var here: Array = []
		for a in Game.armies.values():
			if a.p == pid and (a.o == Game.player or Game.at_war(Game.player, a.o) or Game.is_ally(Game.player, a.o)):
				here.append(a)
		if not here.is_empty():
			v.add_child(_label(T("Armies here:"), GOLD))
			for a in here:
				var aid: int = a.id
				var h := HBoxContainer.new()
				var lb := _label("%s %s (%s)" % [Game.cname(a.o), Military.uname(a), Game.commas(int(float(a.sz) * 1000.0))], GREEN if a.o == Game.player else RED, 14)
				lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(lb)
				_btn(h, T("Select"), func(): _on_army_clicked(aid, false))
				v.add_child(h)
		if not _my_selected().is_empty():
			_btn(v, T("Send selected armies here"), func():
				order_kind = "move"
				_do_order(pid), GOLD)
	v.add_child(HSeparator.new())
	if not c.alive:
		v.add_child(_label(T("Annexed by %s") % Game.cname(c.merged_into), RED))
		return
	if c.occupier != "":
		v.add_child(_label(T("OCCUPIED by %s") % Game.cname(c.occupier), RED))
	if c.overlord != "":
		v.add_child(_label(T("Puppet of %s") % Game.cname(c.overlord), ORANGE))
	var isme: bool = id == Game.player
	if not isme:
		var r := Game.rel(Game.player, id)
		_kv(v, T("Relations"), "%d - %s" % [int(r), _rel_text(r)], GREEN if r >= 30.0 else (RED if r <= -30.0 else GOLD))
		_bar(v, r, 100.0, GREEN if r >= 0.0 else RED, -100.0)
		if Game.is_ally(Game.player, id):
			v.add_child(_label(T("ALLIED (treaty active)"), BLUE))
		if Game.at_war(Game.player, id):
			v.add_child(_label(T("AT WAR"), RED))
		if Game.player in c.sanctioned_by:
			v.add_child(_label(T("Sanctioned by you"), ORANGE))
	else:
		v.add_child(_label(T("This is your country"), GREEN))
	_kv(v, T("Population"), "%.1fM" % float(c.pop))
	_kv(v, T("GDP"), "%s B" % Game.commas(int(c.gdp)))
	_kv(v, T("Army power"), Game.commas(Game.army_power(id)))
	_kv(v, T("Troops"), "%sK" % Game.commas(int(c.troops)))
	_kv(v, T("Stability"), "%d%%" % int(c.stability))
	_kv(v, T("Provinces"), str(Game.owned.get(id, []).size()))
	_kv(v, T("Nuclear arsenal"), T("Yes") if c.nukes else T("No"), RED if c.nukes else TXT)
	var allies_txt: Array = []
	for a in c.allies:
		allies_txt.append(Game.cname(a))
	_kv(v, T("Allies"), ", ".join(allies_txt.slice(0, 6)) + (" ..." if allies_txt.size() > 6 else "") if not allies_txt.is_empty() else T("none"))
	v.add_child(HSeparator.new())
	if isme:
		return
	_btn(v, T("Improve relations (10 influence)"), func(): _act(Game.improve_relations(id)))
	if Game.is_ally(Game.player, id):
		_btn(v, T("Break alliance"), func(): _act(Game.break_alliance(id)))
	else:
		_btn(v, T("Propose alliance (15 influence)"), func(): _act(Game.propose_alliance(id)))
	if Game.player in c.sanctioned_by:
		_btn(v, T("Lift sanctions"), func(): _act(Game.lift_sanction(id)))
	else:
		_btn(v, T("Impose sanctions / embargo"), func(): _act(Game.sanction(id)))
	_btn(v, T("Covert sabotage (30 intel)"), func(): _act(Game.sabotage(id)))
	_btn(v, T("Lend money (needs bank)"), func(): _dlg_lend(id))
	if c.occupier == Game.player:
		_btn(v, T("Decide its future..."), func(): _dlg_occupation(id))
	if Game.at_war(Game.player, id):
		_btn(v, T("Peace negotiation"), _dlg_peace, GOLD)
	elif not Game.is_ally(Game.player, id):
		var nm: String = Game.cname(id)
		_btn(v, T("DECLARE WAR"), func(): _confirm(T("Declare war on %s? World opinion will turn against you.") % nm, func(): _act(Game.player_declare_war(id)), Callable(), T("Declare War")), RED)


func _player_wars() -> Array:
	var out: Array = []
	for w in Game.wars:
		if Game.player_in(w):
			out.append(w)
	return out


func _status_text(a: Dictionary) -> String:
	if int(a.train) > 0:
		return T("Training (%d d)") % int(a.train)
	if a.eng:
		return T("ENGAGED")
	if not a.path.is_empty():
		return T("Moving (ETA %d d)") % int(ceil(Military.eta(a)))
	return T("Idle")


func _fill_military() -> void:
	var v := right_content
	var c: Dictionary = Game.countries[Game.player]
	v.add_child(_label(T("OPERATIONS COMMAND"), ORANGE, 22))
	var mine: Array = Military.armies_of(Game.player)
	var land := 0
	var air := 0
	var navy := 0
	var msl := 0
	for a in mine:
		match a.t:
			"air":
				air += 1
			"navy":
				navy += 1
			"msl":
				msl += 1
			_:
				land += 1
	_kv(v, T("Total troops"), "%sK" % Game.commas(int(c.troops)), Color("ffcc66"))
	_kv(v, T("Armies"), "%d  (%s %d | %s %d | %s %d)" % [land, T("Air"), air, T("Navy"), navy, T("Missiles"), msl])
	_kv(v, T("Army power"), Game.commas(Game.army_power(Game.player)))
	_kv(v, T("Treasury"), Game.fmt_m(float(c.treasury)))
	var tl: Array = []
	for k in Tables.TECHS:
		tl.append("%s %d" % [T(Tables.TECHS[k]).get_slice(" ", 0), int(c.tech.get(k, 0))])
	v.add_child(_wrap(T("Tech levels:") + " " + " | ".join(tl), GRAY, 13))
	if not Game.recruit_q.is_empty():
		v.add_child(_label(T("In production: %d") % Game.recruit_q.size(), GRAY, 13))
	v.add_child(HSeparator.new())
	var g := HFlowContainer.new()
	v.add_child(g)
	_btn(g, T("Declare War"), _dlg_declare_war, RED)
	_btn(g, T("Demobilize") if c.mobilized else T("Mobilize"), func(): _act(Game.toggle_mobilize()))
	_btn(g, T("Recruit"), _dlg_recruit, GREEN)
	_btn(g, T("Research"), _dlg_research)
	_btn(g, T("Build Base (R)"), _dlg_build_base)
	_btn(g, T("Resupply (150M)"), func(): _act(Game.resupply()))
	_btn(g, T("Nuclear Arsenal"), _dlg_nuclear, RED)
	_btn(g, T("Peace Negotiation"), _dlg_peace, GOLD)
	_btn(g, T("Select all land armies"), func():
		Game.sel_armies = []
		for a in mine:
			if Tables.UTYPES[a.t].land:
				Game.sel_armies.append(a.id)
		_fill_right()
		map_view.queue_redraw())
	# selected army card
	var sel := Game.sel_armies.filter(func(i): return Game.armies.has(i))
	if not sel.is_empty():
		v.add_child(HSeparator.new())
		_army_card(v, sel)
	# wars
	v.add_child(HSeparator.new())
	var pw := _player_wars()
	if pw.is_empty():
		v.add_child(_label(T("Not at war. Threat level: LOW"), GREEN))
	for w in pw:
		var mine_side: bool = Game.player in w.sa
		var enemy: String = w.b if mine_side else w.a
		var prog: float = float(w.progress) if mine_side else -float(w.progress)
		v.add_child(_label("%s %s" % [T("WAR vs"), Game.cname(enemy)], RED, 18))
		_kv(v, T("War score"), "%d%%" % int(prog), GREEN if prog >= 0.0 else RED)
		_bar(v, prog, 100.0, ORANGE, -100.0)
		var held := 0
		for pid in Game.owned.get(enemy, []):
			if Game.prov_ctl(pid) in (w.sa if mine_side else w.sb):
				held += 1
		v.add_child(_label(T("Provinces captured: %d / %d") % [held, Game.owned.get(enemy, []).size()], GRAY, 14))
	_kv(v, T("Casualties"), Game.commas(int(Game.casualties)), RED)
	_kv(v, T("Enemy casualties"), Game.commas(int(Game.enemy_casualties)))
	# battles
	if not Game.battles.is_empty():
		v.add_child(HSeparator.new())
		v.add_child(_label(T("ACTIVE BATTLES"), RED, 18))
		for pid in Game.battles:
			var bp: int = int(pid)
			var h := HBoxContainer.new()
			var lb := _label("%s" % Game.pname(bp), TXT, 15)
			lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(lb)
			_btn(h, T("Go"), func(): map_view.focus_pid(bp, 5.0))
			v.add_child(h)
	# army list
	v.add_child(HSeparator.new())
	v.add_child(_label(T("YOUR ARMIES"), GOLD, 18))
	mine.sort_custom(func(a, b): return str(a.t) + "%05d" % int(a.n) < str(b.t) + "%05d" % int(b.n))
	var shown := 0
	for a in mine:
		if shown >= 60:
			break
		shown += 1
		var aid: int = a.id
		var h2 := HBoxContainer.new()
		var lb2 := _label("%s | %dK | %s" % [Military.uname(a), int(a.sz), _status_text(a)], TXT if not a.eng else RED, 13)
		lb2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h2.add_child(lb2)
		_btn(h2, T("Select"), func():
			Game.sel_armies = [aid]
			map_view.focus_pid(Game.armies[aid].p, maxf(map_view.zoom, 3.0))
			_fill_right())
		v.add_child(h2)
	v.add_child(HSeparator.new())
	v.add_child(_label(T("COMBAT LOG"), GOLD, 18))
	var lines: Array = Game.combat_log.slice(-8)
	lines.reverse()
	for ln in lines:
		v.add_child(_wrap(str(ln), TXT, 13))


func _stars(sk: float) -> String:
	return "%.1f / 5" % sk


func _army_card(v: VBoxContainer, sel: Array) -> void:
	var a: Dictionary = Game.armies[sel[0]]
	var own: bool = a.o == Game.player
	v.add_child(_label("%s - %s" % [Game.cname(a.o), Military.uname(a)], GREEN if own else RED, 20))
	if sel.size() > 1:
		v.add_child(_label(T("%d armies selected") % sel.size(), GOLD, 14))
	_kv(v, T("Commander"), str(a.gen))
	_kv(v, T("Strength"), "%.1fK / %.1fK" % [float(a.sz), float(a.mx)])
	_bar(v, float(a.sz), maxf(float(a.mx), 0.1), GREEN)
	_kv(v, T("Skill"), _stars(float(a.sk)), GOLD)
	_bar(v, float(a.sk), 5.0, GOLD)
	_kv(v, T("Morale"), "%d%%" % int(a.mo))
	_bar(v, float(a.mo), 100.0, BLUE)
	_kv(v, T("Supply"), "%d%%" % int(a.sp), RED if float(a.sp) < 25.0 else TXT)
	_bar(v, float(a.sp), 100.0, ORANGE)
	_kv(v, T("Location"), Game.pname(a.p))
	_kv(v, T("Status"), _status_text(a), RED if a.eng else TXT)
	if Tables.UTYPES[a.t].land:
		var ctl := Game.prov_ctl(a.p)
		_kv(v, T("Power (atk / def)"), "%d / %d" % [int(Military.power_of(a, true)), int(Military.power_of(a, false) * Military._def_mult(a, a.p))])
	if not own:
		return
	var g := HFlowContainer.new()
	v.add_child(g)
	var land: bool = Tables.UTYPES[a.t].land
	if land:
		_btn(g, T("Move (M)"), func(): _start_order("move"), GOLD)
	else:
		_btn(g, T("Strike target"), func(): _start_order("strike"), RED)
		_btn(g, T("Relocate"), func(): _start_order("move"))
	_btn(g, T("Stop (S)"), func(): Military.stop(sel))
	if land:
		var st := HBoxContainer.new()
		v.add_child(st)
		st.add_child(_label(T("Stance:"), GRAY, 14))
		for s in [["aggr", "Aggressive"], ["bal", "Balanced"], ["def", "Defensive"]]:
			var key: String = s[0]
			var b := _btn(st, T(s[1]), func(): Military.set_stance(sel, key), GOLD if a.stance == key else Color.WHITE)
	var g2 := HFlowContainer.new()
	v.add_child(g2)
	_btn(g2, T("Train (+0.5 skill)"), func(): _act(Military.train(a.id)))
	if land:
		_btn(g2, T("Split"), func(): _act(Military.split(a.id)))
		if sel.size() > 1:
			_btn(g2, T("Merge"), func(): _act(Military.merge(sel)))
		_btn(g2, T("Retreat"), func(): _act(Military.retreat(a.id)))
	_btn(g2, T("Disband"), func(): _confirm(T("Disband this army?"), func(): Military.disband(a.id), Callable(), T("Disband")), RED)
	if land:
		v.add_child(_label(T("TACTICS"), GOLD, 16))
		for k in Tables.TACTICS:
			var td: Dictionary = Tables.TACTICS[k]
			var key2: String = k
			var h := HBoxContainer.new()
			var b2 := Button.new()
			b2.text = "%s%s" % [T(td.name), (" (%d)" % int(a.cd)) if int(a.cd) > 0 else ""]
			b2.disabled = int(a.cd) > 0
			b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b2.tooltip_text = T(td.desc)
			b2.pressed.connect(func(): _act(Military.use_tactic(a.id, key2)))
			h.add_child(b2)
			v.add_child(h)
			v.add_child(_wrap(T(td.desc), GRAY, 12))


# ---------------------------------------------------------------- dialogs
func _target_items(include_allies := false) -> Array:
	var items: Array = []
	var nb: Array = Game.nbrs.get(Game.player, [])
	for id in Game.alive_ids():
		if id == Game.player or Game.at_war(Game.player, id):
			continue
		if not include_allies and Game.is_ally(Game.player, id):
			continue
		var tag := "★ " if id in nb else ""
		items.append([tag + Game.cname(id), id])
	items.sort_custom(func(a, b): return Game.rel(Game.player, a[1]) < Game.rel(Game.player, b[1]))
	return items


func _dlg_declare_war() -> void:
	var items := _target_items()
	_dialog(T("Declare War"), func(v):
		v.add_child(_label(T("Target nation (sorted by hostility, ★ = neighbor):")))
		var o := _opt(items)
		v.add_child(o)
		return {"o": o},
		func(ctl):
			var t: Variant = _opt_val(ctl.o)
			if t != null:
				_act(Game.player_declare_war(str(t))),
		T("Declare War"))


func _dlg_build_base() -> void:
	if not Game.started:
		return
	var hosts: Array = [[Game.cname(Game.player) + " (" + T("own land") + ")", Game.player]]
	for id in Game.alive_ids():
		if id != Game.player and (Game.is_ally(Game.player, id) or Game.rel(Game.player, id) >= 40.0):
			hosts.append([Game.cname(id) + " (" + T("agreement") + ")", id])
	var types: Array = []
	for k in Game.BASE_TYPES:
		types.append([T(Game.BASE_TYPES[k]), k])
	_dialog(T("Build Base"), func(v):
		v.add_child(_label(T("Host country (own 400M / foreign 650M):")))
		var h := _opt(hosts)
		v.add_child(h)
		v.add_child(_label(T("Type:")))
		var t := _opt(types)
		v.add_child(t)
		return {"h": h, "t": t},
		func(ctl): _act(Game.build_base(str(_opt_val(ctl.h)), str(_opt_val(ctl.t)))),
		T("Build"))


func _dlg_recruit() -> void:
	var items: Array = []
	for k in Tables.UTYPES:
		var u: Dictionary = Tables.UTYPES[k]
		items.append(["%s - %s (%s)" % [T(u.name), "%dK" % int(u.sz), Game.fmt_m(float(u.sz) * float(u.cost) * 12.0)], k])
	_dialog(T("Recruit a new army"), func(v):
		v.add_child(_wrap(T("New units appear at your capital after 10 days. Limited by manpower.")))
		var o := _opt(items)
		v.add_child(o)
		return {"o": o},
		func(ctl): _act(Military.recruit(str(_opt_val(ctl.o)))),
		T("Recruit"))


func _dlg_research() -> void:
	var c: Dictionary = Game.countries[Game.player]
	var items: Array = []
	for k in Tables.TECHS:
		var lvl: int = int(c.tech.get(k, 0))
		items.append(["%s - %s %d (%s)" % [T(Tables.TECHS[k]), T("level"), lvl, Game.fmt_m((lvl + 1) * (300.0 + float(c.gdp) * 0.05))], k])
	_dialog(T("Research"), func(v):
		if c.research.has("t"):
			v.add_child(_label(T("In progress: %s (%d days)") % [T(Tables.TECHS[c.research.t]), int(c.research.d)], GOLD))
		v.add_child(_wrap(T("Each level adds +7% power to that branch.")))
		var o := _opt(items)
		v.add_child(o)
		return {"o": o},
		func(ctl): _act(Military.research(str(_opt_val(ctl.o)))),
		T("Start research"))


func _dlg_peace() -> void:
	var pw := _player_wars()
	if pw.is_empty():
		_msg(T("You are not at war."))
		return
	var items: Array = []
	for w in pw:
		var mine: bool = Game.player in w.sa
		items.append([T("vs") + " " + Game.cname(w.b if mine else w.a), int(w.uid)])
	_dialog(T("Peace Negotiation"), func(v):
		var o := _opt(items)
		v.add_child(o)
		var k := _opt([[T("White peace (status quo)"), "white"], [T("Dictate terms (take occupied land + reparations)"), "terms"], [T("Surrender (cede land + pay)"), "surrender"]])
		v.add_child(k)
		return {"o": o, "k": k},
		func(ctl): _act(Game.negotiate(int(_opt_val(ctl.o)), str(_opt_val(ctl.k)))),
		T("Propose"))


func _dlg_nuclear() -> void:
	var arsenals := Game.usable_arsenals()
	var targets: Array = []
	for w in _player_wars():
		var mine: bool = Game.player in w.sa
		var e: String = w.b if mine else w.a
		targets.append([Game.cname(e), e])
	_dialog(T("Nuclear Arsenal"), func(v):
		if arsenals.is_empty():
			v.add_child(_wrap(T("You control no nuclear arsenal. Occupying a nuclear state does not hand you its weapons automatically: you need 80%+ institutional control first."), GRAY))
		for a in arsenals:
			v.add_child(_label("%s - %s %d%%" % [a.name, T("operational control"), int(a.ctrl)], GREEN if float(a.ctrl) >= 80.0 else ORANGE))
		var o := _opt(targets)
		v.add_child(_label(T("Strike target (must be at war):")))
		v.add_child(o)
		v.add_child(_wrap(T("WARNING: worldwide condemnation, sanctions, instability."), RED, 14))
		return {"o": o},
		func(ctl):
			var t: Variant = _opt_val(ctl.o)
			if t == null:
				_msg(T("No valid target."))
			else:
				_act(Game.nuclear_strike(str(t))),
		T("LAUNCH"))


func _dlg_lend(id: String) -> void:
	_dialog("%s %s" % [T("Lend to"), Game.cname(id)], func(v):
		v.add_child(_wrap(T("Bank loan, 1 year. Interest depends on their stability.")))
		var o := _opt([["50,000 Cr", 50000.0], ["100,000 Cr", 100000.0], ["250,000 Cr", 250000.0]])
		v.add_child(o)
		return {"o": o},
		func(ctl): _act(Game.lend_to_country(id, float(_opt_val(ctl.o)))),
		T("Lend"))


func _dlg_occupation(id: String) -> void:
	_dialog("%s: %s" % [T("Occupied"), Game.cname(id)], func(v):
		v.add_child(_wrap(T("Occupation is not annexation. Choose the future of this country:")))
		var o := _opt([[T("Annex (takes time, reduces your stability)"), "annex"], [T("Install puppet government"), "puppet"],
			[T("Partition (take 40% of its land)"), "partition"], [T("Release as independent state"), "release"]])
		v.add_child(o)
		return {"o": o},
		func(ctl): _act(Game.occupation_choice(id, str(_opt_val(ctl.o)))),
		T("Decide"))


func _on_proposal(d: Dictionary) -> void:
	match str(d.kind):
		"alliance":
			var f: String = d.from
			_confirm(T("%s proposes a defensive alliance with you.") % Game.cname(f), func(): Game.accept_alliance(f), func(): Game.decline_alliance(), T("Accept"))
		"join_war":
			var uid := int(d.uid)
			var side: String = d.side
			_confirm(str(d.text), func(): _act(Game.join_war(uid, side)), func(): Game.decline_join(), T("Join war"))
		"occupation":
			_dlg_occupation(str(d.id))
		"info":
			_msg(str(d.text))


# ---------------------------------------------------------------- screens
func _open_screen(name: String) -> void:
	if screen.visible and current_screen == name:
		_close_screen()
		return
	current_screen = name
	right_panel.visible = false
	screen.visible = true
	_rebuild_screen()


func _close_screen() -> void:
	screen.visible = false
	current_screen = ""


func _rebuild_screen() -> void:
	if not Game.started:
		return
	var sv := screen_scroll.scroll_vertical
	_clear(screen_flow)
	match current_screen:
		"politics":
			screen_title.text = T("Politics & Country Management")
			_screen_politics()
		"economy":
			screen_title.text = T("Economy, Markets & Banking")
			_screen_economy()
		"trade":
			screen_title.text = T("World Trade")
			_screen_trade()
		"alliance":
			screen_title.text = T("Diplomacy & Alliances")
			_screen_alliance()
	screen_scroll.set_deferred("scroll_vertical", sv)


func _screen_politics() -> void:
	var c: Dictionary = Game.countries[Game.player]
	var v := _card(T("Country Overview"))
	v.add_child(_label(Game.cname(Game.player).to_upper(), GOLD, 28))
	_kv(v, T("Government"), T(str(c.gov)))
	_kv(v, T("Population"), "%.1fM" % float(c.pop))
	_kv(v, T("GDP"), "%s B" % Game.commas(int(c.gdp)))
	_kv(v, T("Stability"), "%d%%" % int(c.stability))
	_bar(v, float(c.stability), 100.0, GREEN)
	v.add_child(HSeparator.new())
	v.add_child(_label(T("PRESIDENT"), GOLD))
	v.add_child(_label(str(c.cabinet.president), TXT, 22))
	_kv(v, T("Approval"), "%d%%" % int(c.approval))
	_bar(v, float(c.approval), 100.0, GOLD)
	if Game.party != "":
		_kv(v, T("Your party"), Game.party)
	if Game.exile:
		v.add_child(_wrap(T("You lead a GOVERNMENT IN EXILE. Resistance: %d%%") % int(Game.exile_resistance), RED))
		_bar(v, Game.exile_resistance, 100.0, RED)
	elif not Game.in_office:
		v.add_child(_wrap(T("You are in opposition. Next election run in %d days.") % maxi(0, Game.opposition_until - Game.day), RED))
	else:
		_kv(v, T("Next election"), T("in %d days") % maxi(0, Game.next_election - Game.day))
	v.add_child(_wrap(T("Resources: Influence %d | Intel %d | Power %s") % [int(Game.influence), int(Game.intel), Game.commas(Game.army_power(Game.player))], GRAY, 14))
	v = _card(T("Ministers Cabinet & Parliament"))
	for role in [["Foreign", "foreign"], ["Finance", "finance"], ["Defense", "defense"], ["Interior", "interior"]]:
		_kv(v, "%s %s" % [T(role[0]), T("Minister")], str(c.cabinet[role[1]]))
	v.add_child(_wrap(T("Vacant or absent posts are run by the AI - the state never stops."), GRAY, 13))
	v.add_child(HSeparator.new())
	v.add_child(_label(T("PARLIAMENT VOTING"), GOLD))
	if Game.pending_votes.is_empty():
		v.add_child(_label(T("No bills in debate."), GRAY))
	for pv in Game.pending_votes:
		var prog: float = 1.0 - float(pv.days) / float(pv.total)
		var yes: float = lerpf(100.0, float(pv.yes_final), prog)
		v.add_child(_label(T(str(Game.LAWS[pv.id].name)), TXT, 18))
		_kv(v, T("Current vote"), "%d %s / %d %s" % [int(yes), T("YES"), 200 - int(yes), T("NO")], GREEN if yes > 100.0 else RED)
		_bar(v, yes, 200.0, GOLD)
		v.add_child(_label("%d/200 | %dd | %s" % [int(yes), int(pv.days), T("PASSING") if yes > 100.0 else T("FAILING")], GRAY, 13))
	v.add_child(HSeparator.new())
	v.add_child(_label(T("LAWS"), GOLD))
	for id in Game.LAWS:
		var law: Dictionary = Game.LAWS[id]
		var h := HBoxContainer.new()
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(_label(T(str(law.name)), TXT, 17))
		col.add_child(_wrap(T(str(law.desc)), GRAY, 13))
		h.add_child(col)
		if c.laws.has(id):
			h.add_child(_label(T("Enacted"), GREEN))
		else:
			var lid: String = id
			_btn(h, T("Propose"), func(): _act(Game.propose_law(lid)))
		v.add_child(h)
	v = _card(T("Economy & Policy"))
	v.add_child(_label(T("TAXATION"), GOLD))
	var tl := _kv(v, T("Tax rate"), "%d%%" % int(float(c.tax) * 100.0))
	var sl := HSlider.new()
	sl.min_value = 0
	sl.max_value = 40
	sl.step = 1
	sl.value = float(c.tax) * 100.0
	sl.custom_minimum_size = Vector2(0, 28)
	sl.layout_direction = Control.LAYOUT_DIRECTION_LTR
	v.add_child(sl)
	var rev := _kv(v, T("Revenue"), "")
	var app := _kv(v, T("Public approval (vs 22%)"), "")
	var upd := func(val: float):
		var pr: Dictionary = Game.tax_preview(val / 100.0)
		tl.text = "%d%%" % int(val)
		rev.text = "%s /%s" % [Game.fmt_m(float(pr.revenue)), T("day")]
		rev.add_theme_color_override("font_color", GREEN)
		app.text = "%+d%%" % int(pr.approval)
		app.add_theme_color_override("font_color", GREEN if float(pr.approval) >= 0.0 else RED)
	upd.call(sl.value)
	sl.value_changed.connect(func(val): upd.call(val))
	sl.drag_ended.connect(func(ch):
		if ch:
			_act(Game.set_tax(sl.value / 100.0)))
	v.add_child(HSeparator.new())
	v.add_child(_label(T("DIPLOMACY"), GOLD))
	var an: Array = []
	for a in c.allies:
		an.append(Game.cname(a))
	_kv(v, T("Alliances"), (", ".join(an.slice(0, 5)) + (" ..." if an.size() > 5 else "")) if not an.is_empty() else T("none"), BLUE)
	_kv(v, T("Sanctions on you"), str(c.sanctioned_by.size()), RED if c.sanctioned_by.size() > 0 else GREEN)
	v.add_child(HSeparator.new())
	v.add_child(_label(T("TERRITORIAL CONTROL"), GOLD))
	var any := false
	for id in Game.countries:
		var t: Dictionary = Game.countries[id]
		if t.alive and t.occupier == Game.player:
			any = true
			v.add_child(_label("%s: %s" % [T("Occupation"), Game.cname(id)], TXT, 18))
			_kv(v, T("Stability"), "%d%%" % int(t.occ_stability))
			_kv(v, T("Resistance"), T("Low") if float(t.occ_stability) > 60.0 else (T("Moderate") if float(t.occ_stability) > 30.0 else T("HIGH")))
			if t.annexing:
				_kv(v, T("Annexation progress"), "%d%%" % int(t.annex_progress), GOLD)
				_bar(v, float(t.annex_progress), 100.0, GOLD)
			else:
				var tid: String = id
				_btn(v, T("Decide its future..."), func(): _dlg_occupation(tid))
		elif t.alive and t.overlord == Game.player:
			any = true
			v.add_child(_wrap(T("Puppet state: %s (pays 10%% of revenue)") % Game.cname(id), TXT, 16))
	if c.occf > 0.0:
		v.add_child(_label(T("Your land under occupation: %d%%") % int(float(c.occf) * 100.0), RED))
	if not any:
		v.add_child(_label(T("No occupied territories."), GRAY))
	v.add_child(HSeparator.new())
	var br := HFlowContainer.new()
	v.add_child(br)
	_btn(br, T("Elections"), _dlg_elections)
	_btn(br, T("Form Party"), _dlg_party)
	_btn(br, T("Merge Nations"), _dlg_merge)
	_btn(br, T("Create Government in Exile"), func(): _act(Game.create_exile()))


func _dlg_elections() -> void:
	if not Game.in_office and not Game.exile:
		_act(Game.run_again())
		return
	_confirm(T("Call a snap election? Costs 30 influence. If approval is low you may lose office (your wealth and companies stay yours)."), func(): _act(Game.hold_election(true)), Callable(), T("Call election"))


func _dlg_party() -> void:
	_dialog(T("Form a Party (25 influence)"), func(v):
		v.add_child(_label(T("Party name:")))
		var e := LineEdit.new()
		e.text = T("National Front")
		v.add_child(e)
		return {"e": e},
		func(ctl): _act(Game.form_party(ctl.e.text)),
		T("Found"))


func _dlg_merge() -> void:
	var items: Array = []
	for a in Game.countries[Game.player].allies:
		if Game.countries[a].alive:
			items.append([Game.cname(a), a])
	if items.is_empty():
		_msg(T("You need an allied nation (relations 60+) to merge with."))
		return
	_dialog(T("Merge Nations (50 influence)"), func(v):
		v.add_child(_label(T("Partner:")))
		var o := _opt(items)
		v.add_child(o)
		v.add_child(_label(T("Name of the unified state (optional):")))
		var e := LineEdit.new()
		v.add_child(e)
		v.add_child(_wrap(T("Economies, treasuries and armies combine - but integration costs stability and army efficiency (85%)."), GRAY, 13))
		return {"o": o, "e": e},
		func(ctl): _act(Game.merge_with(str(_opt_val(ctl.o)), ctl.e.text)),
		T("Merge"))


# ---------------------------------------------------------------- economy
func _qty_opt(items: Array, current: Variant, cb: Callable) -> OptionButton:
	var o := _opt(items)
	_opt_select(o, current)
	o.item_selected.connect(func(i): cb.call(o.get_item_metadata(i)))
	return o


func _asset_row(parent: Node, a: Dictionary, kind: String) -> void:
	var id: String = a.id
	var chg: float = float(a.chg)
	var h := HBoxContainer.new()
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(_label(Market.disp_name(a), TXT, 17))
	var own: float = float(Game.holdings.get(id, 0.0))
	var sub := "%s %s  %s" % [_pf(float(a.price)), "Cr", _pct(chg)]
	if kind == "stock":
		sub = "%s | %s | %s" % [Game.cname(a.c), T(str(a.sec)), sub]
	if own > 0.0:
		sub += " | %s %s" % [T("owned"), str(snappedf(own, 0.0001))]
	var sl := _label(sub, GREEN if chg >= 0.0 else RED, 13)
	info.add_child(sl)
	h.add_child(info)
	var ch := _chart(h, a.hist.slice(-40), GREEN if chg >= 0.0 else RED, 34.0)
	ch.custom_minimum_size = Vector2(70, 34)
	_btn(h, T("Buy"), func(): _trade(id, kind, true), GREEN)
	_btn(h, T("Sell"), func(): _trade(id, kind, false), ORANGE)
	parent.add_child(h)


func _trade(id: String, kind: String, buy: bool) -> void:
	var q: float = float(qty_stock) if kind == "stock" else (float(qty_comm) if kind == "comm" else qty_crypto)
	_act(Market.buy(id, q) if buy else Market.sell(id, q))


func _screen_economy() -> void:
	var tabs := _card(T("Markets"), 600.0)
	var tr := HFlowContainer.new()
	tabs.add_child(tr)
	for t in [["stocks", "Stocks"], ["comm", "Commodities"], ["crypto", "Crypto"], ["portfolio", "Portfolio"], ["bank", "Banking & Companies"]]:
		var key: String = t[0]
		_btn(tr, T(t[1]), func():
			eco_tab = key
			_rebuild_screen(), GOLD if eco_tab == key else Color.WHITE)
	var s_txt := "%s: %s" % [T("Market sentiment"), ("%+.0f" % (Game.mk_sent * 100.0))]
	tabs.add_child(_label(s_txt, GREEN if Game.mk_sent >= 0.0 else RED, 14))
	match eco_tab:
		"stocks":
			_eco_stocks()
		"comm":
			_eco_comm()
		"crypto":
			_eco_crypto()
		"portfolio":
			_eco_portfolio()
		_:
			_eco_bank()


func _eco_stocks() -> void:
	var v := _card(T("Global Stock Index"), 480.0)
	var idx: Array = Game.index_hist
	var ch30 := 0.0
	if idx.size() > 30:
		ch30 = float(idx[-1]) / float(idx[-31]) - 1.0
	_kv(v, T("GLOBAL INDEX"), "%.2f  %s" % [Game.index_value() if false else float(idx[-1]), _pct(ch30)], GREEN if ch30 >= 0.0 else RED)
	_chart(v, idx, Color("7dff5c"), 120.0, true)
	v.add_child(_wrap(T("Prices move with supply & demand, wars, sanctions, sentiment and everyone's buy/sell orders - including yours."), GRAY, 13))
	var f := _card(T("Find stocks (1600+ companies)"), 520.0)
	var countries: Array = [[T("All countries"), ""]]
	var cs := {}
	var secs := {}
	for id in Game.assets:
		var a: Dictionary = Game.assets[id]
		if a.k == "stock":
			cs[a.c] = true
			secs[a.sec] = true
	var clist: Array = []
	for c in cs:
		clist.append([Game.cname(c), c])
	clist.sort_custom(func(x, y): return x[0] < y[0])
	countries.append_array(clist)
	var slist: Array = [[T("All sectors"), ""]]
	var sl2: Array = []
	for s in secs:
		sl2.append([T(str(s)), s])
	sl2.sort_custom(func(x, y): return x[0] < y[0])
	slist.append_array(sl2)
	var row := HFlowContainer.new()
	f.add_child(row)
	row.add_child(_qty_opt(countries, f_country, func(x):
		f_country = str(x)
		_fill_stock_list()))
	row.add_child(_qty_opt(slist, f_sector, func(x):
		f_sector = str(x)
		_fill_stock_list()))
	row.add_child(_qty_opt([[T("Largest"), "cap"], [T("Top gainers"), "chg"], [T("Top losers"), "low"], [T("Highest price"), "price"]], f_sort, func(x):
		f_sort = str(x)
		_fill_stock_list()))
	var e := LineEdit.new()
	e.placeholder_text = T("Search company...")
	e.text = f_text
	e.custom_minimum_size = Vector2(200, 0)
	e.text_changed.connect(func(t):
		f_text = t
		_fill_stock_list())
	f.add_child(e)
	var qh := HBoxContainer.new()
	qh.add_child(_label(T("Quantity:")))
	qh.add_child(_qty_opt([["1", 1], ["10", 10], ["100", 100], ["1000", 1000], ["10000", 10000]], qty_stock, func(x): qty_stock = int(x)))
	f.add_child(qh)
	stock_box = VBoxContainer.new()
	f.add_child(stock_box)
	_fill_stock_list()


func _fill_stock_list() -> void:
	if stock_box == null or not is_instance_valid(stock_box):
		return
	_clear(stock_box)
	var ids := Market.query("stock", f_country, f_sector, f_text, f_sort, 30)
	if ids.is_empty():
		stock_box.add_child(_label(T("No matches."), GRAY))
	for id in ids:
		_asset_row(stock_box, Game.assets[id], "stock")


func _eco_comm() -> void:
	var v := _card(T("Commodities"), 560.0)
	v.add_child(_wrap(T("Prices follow world supply: producers at war, occupied or sanctioned cut supply and push prices up."), GRAY, 13))
	var qh := HBoxContainer.new()
	qh.add_child(_label(T("Quantity:")))
	qh.add_child(_qty_opt([["1", 1], ["10", 10], ["100", 100], ["1000", 1000]], qty_comm, func(x): qty_comm = int(x)))
	v.add_child(qh)
	for k in Tables.COMM:
		var a: Dictionary = Game.assets[k]
		_asset_row(v, a, "comm")
		var ratio := Market.supply_ratio(k)
		var tops: Array = []
		var prod: Dictionary = Tables.PRODUCERS[k]
		var keys: Array = prod.keys()
		keys.sort_custom(func(x, y): return prod[x] > prod[y])
		for p in keys.slice(0, 4):
			tops.append("%s %d" % [Game.cname(p), int(prod[p])])
		v.add_child(_label("%s %d%% | %s" % [T("Supply"), int(ratio * 100.0), ", ".join(tops)], RED if ratio < 0.92 else GRAY, 12))


func _eco_crypto() -> void:
	var v := _card(T("Crypto Exchange"), 560.0)
	v.add_child(_wrap(T("Crypto reacts to global risk appetite, wars and big buyers/sellers. Highly volatile."), GRAY, 13))
	var qh := HBoxContainer.new()
	qh.add_child(_label(T("Quantity:")))
	qh.add_child(_qty_opt([["0.01", 0.01], ["0.1", 0.1], ["1", 1.0], ["10", 10.0], ["100", 100.0], ["1000", 1000.0]], qty_crypto, func(x): qty_crypto = float(x)))
	v.add_child(qh)
	for r in Tables.CRYPTO:
		_asset_row(v, Game.assets[r[0]], "crypto")


func _eco_portfolio() -> void:
	var v := _card(T("Investment Portfolio"), 560.0)
	var pv := Game.portfolio_value()
	var pl := pv - Game.portfolio_basis()
	_kv(v, T("Portfolio value"), "%s Cr" % Game.commas(int(pv)), GOLD)
	_kv(v, T("Profit / loss"), "%s Cr" % Game.commas(int(pl)), GREEN if pl >= 0.0 else RED)
	var ids: Array = Game.holdings.keys()
	ids.sort_custom(func(x, y): return float(Game.assets[x].price) * float(Game.holdings[x]) > float(Game.assets[y].price) * float(Game.holdings[y]))
	if ids.is_empty():
		v.add_child(_label(T("You own no assets yet."), GRAY))
	for id in ids:
		var a: Dictionary = Game.assets[id]
		var h := HBoxContainer.new()
		var qty: float = float(Game.holdings[id])
		var val: float = float(a.price) * qty
		var gain: float = val - float(Game.basis.get(id, 0.0))
		var lb := _label("%s x%s = %s Cr (%s)" % [Market.disp_name(a), str(snappedf(qty, 0.0001)), Game.commas(int(val)), Game.commas(int(gain))], GREEN if gain >= 0.0 else RED, 14)
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(lb)
		var aid: String = id
		_btn(h, T("Sell all"), func(): _act(Market.sell(aid, float(Game.holdings.get(aid, 0.0)))), ORANGE)
		v.add_child(h)
	v.add_child(HSeparator.new())
	_kv(v, T("Cash"), "%s Cr" % Game.commas(int(Game.player_cash)))
	_kv(v, T("Government bonds"), "%s Cr" % Game.commas(int(Game.bonds)))
	_kv(v, T("Debt"), "%s Cr" % Game.commas(int(Game.total_debt())), RED if Game.total_debt() > 0.0 else TXT)
	_kv(v, T("NET WORTH"), "%s Cr" % Game.commas(int(Game.networth())), GOLD)
	v.add_child(_wrap(T("Personal wealth is separate from the state treasury."), GRAY, 13))


func _eco_bank() -> void:
	var v := _card(T("Banking & Bonds"))
	v.add_child(_label(T("BANK LOANS"), GOLD))
	if Game.loans_taken.is_empty():
		v.add_child(_label(T("No active loans."), GRAY))
	for i in Game.loans_taken.size():
		var l: Dictionary = Game.loans_taken[i]
		var h2 := HBoxContainer.new()
		var lb := _label("%s %s Cr | %.1f%% | %d %s" % [T("Owe"), Game.commas(int(l.remaining)), float(l.rate), int(l.days_left), T("days left")], TXT, 15)
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h2.add_child(lb)
		var li := i
		_btn(h2, T("Repay"), func(): _act(Game.repay_loan(li)))
		v.add_child(h2)
	var lr := HFlowContainer.new()
	v.add_child(lr)
	for amt in [50000.0, 100000.0, 250000.0]:
		var a: float = amt
		_btn(lr, "%s %s" % [T("Borrow"), Game.commas(int(a))], func(): _act(Game.take_loan(a)))
	_kv(v, T("Credit limit"), "%s Cr" % Game.commas(int(Game.max_borrow())))
	v.add_child(HSeparator.new())
	v.add_child(_label(T("BONDS (4.2% APY)"), GOLD))
	_kv(v, T("Global bond fund held"), "%s Cr" % Game.commas(int(Game.bonds)))
	var br := HFlowContainer.new()
	v.add_child(br)
	_btn(br, T("Buy 10K"), func(): _act(Game.buy_bonds(10000.0)))
	_btn(br, T("Sell 10K"), func(): _act(Game.sell_bonds(10000.0)))
	v.add_child(HSeparator.new())
	if Game.has_bank:
		v.add_child(_label(T("YOUR BANK"), GOLD))
		for l2 in Game.loans_given:
			_kv(v, "%s %s" % [T("Loan to"), Game.cname(l2.to)], "%s Cr @ %.1f%%" % [Game.commas(int(l2.remaining)), float(l2.rate)])
		v.add_child(_wrap(T("Select a country on the map and press 'Lend money'."), GRAY, 13))
	else:
		_btn(v, T("Open Bank (200,000 Cr)"), func(): _act(Game.open_bank()))
	v = _card(T("Player Companies"))
	if Game.player_companies.is_empty():
		v.add_child(_label(T("You own no companies yet."), GRAY))
	for i in Game.player_companies.size():
		var pc: Dictionary = Game.player_companies[i]
		var inc := Game.company_income(pc)
		var h3 := HBoxContainer.new()
		var info2 := VBoxContainer.new()
		info2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info2.add_child(_label(str(pc.name), TXT, 18))
		info2.add_child(_label("%s | %s | %d %s | %+d Cr/%s" % [T(str(pc.sector)), Game.cname(pc.country), int(pc.factories), T("factories"), int(inc), T("day")], GREEN if inc >= 0.0 else RED, 13))
		h3.add_child(info2)
		var pi := i
		_btn(h3, T("Build Factory"), func(): _act(Game.build_factory(pi)))
		v.add_child(h3)
	_btn(v, T("Create Company (50K)"), _dlg_company)
	v = _card(T("News Feed"))
	var nl: Array = Game.news_feed.slice(-10)
	nl.reverse()
	for n in nl:
		v.add_child(_wrap("- " + str(n), TXT, 14))


func _dlg_company() -> void:
	var secs: Array = []
	for k in Game.SECTORS:
		secs.append([T(k), k])
	var hosts: Array = []
	for id in Game.alive_ids():
		hosts.append([Game.cname(id), id])
	hosts.sort_custom(func(a, b): return a[0] < b[0])
	_dialog(T("Create Company (50,000 Cr)"), func(v):
		v.add_child(_label(T("Company name:")))
		var e := LineEdit.new()
		e.text = T("Nile Industries")
		v.add_child(e)
		v.add_child(_label(T("Sector:")))
		var s := _opt(secs)
		v.add_child(s)
		v.add_child(_label(T("Home factory in:")))
		var h := _opt(hosts)
		_opt_select(h, Game.player)
		v.add_child(h)
		return {"e": e, "s": s, "h": h},
		func(ctl): _act(Game.found_company(ctl.e.text, str(_opt_val(ctl.s)), str(_opt_val(ctl.h)))),
		T("Create"))


# ---------------------------------------------------------------- trade & alliance
func _comm_items() -> Array:
	var out: Array = []
	for k in Tables.COMM:
		out.append([T(Tables.COMM[k][0]), k])
	return out


func _country_items(exclude_player := true) -> Array:
	var out: Array = []
	for id in Game.alive_ids():
		if exclude_player and id == Game.player:
			continue
		out.append([Game.cname(id), id])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out


func _screen_trade() -> void:
	var v := _card(T("Trade Contracts"), 460.0)
	v.add_child(_wrap(T("Recurring commodity trade with a partner. Margin grows with distance and Free Trade laws, shrinks with tariffs. War or sanctions cancel contracts."), GRAY, 13))
	if Game.contracts.is_empty():
		v.add_child(_label(T("No active contracts."), GRAY))
	for i in Game.contracts.size():
		var ct: Dictionary = Game.contracts[i]
		var p := Game.contract_profit(ct)
		var h := HBoxContainer.new()
		var lb := _wrap("%s %d/%s %s %s | %+d Cr/%s" % [T(Tables.COMM[ct.comm][0]), int(ct.qty), T("day"), T("to") if ct.export else T("from"), Game.cname(ct.partner), int(p), T("day")], GREEN if p >= 0.0 else RED, 15)
		h.add_child(lb)
		var ci := i
		_btn(h, T("Cancel"), func(): Game.cancel_contract(ci))
		v.add_child(h)
	v = _card(T("New Contract (5,000 Cr)"), 380.0)
	var co := _opt(_comm_items())
	v.add_child(_label(T("Commodity:")))
	v.add_child(co)
	var pids := _country_items()
	v.add_child(_label(T("Partner:")))
	var po := _opt(pids)
	v.add_child(po)
	v.add_child(_label(T("Units per day:")))
	var qo := _opt([["100", 100], ["500", 500], ["1000", 1000], ["5000", 5000]])
	v.add_child(qo)
	var dr := _opt([[T("Export (sell to partner)"), true], [T("Import (buy from partner)"), false]])
	v.add_child(dr)
	_btn(v, T("Sign contract"), func(): _act(Game.add_contract(str(_opt_val(co)), str(_opt_val(po)), int(_opt_val(qo)), bool(_opt_val(dr)))))
	v = _card(T("Tariffs (your country)"), 380.0)
	v.add_child(_wrap(T("Tariffs cut contract margins but cost relations."), GRAY, 13))
	var tr: Dictionary = Game.countries[Game.player].tariffs
	var to := _opt(pids)
	v.add_child(to)
	var tv := _opt([["0%", 0.0], ["10%", 0.1], ["25%", 0.25], ["50%", 0.5]])
	v.add_child(tv)
	_btn(v, T("Apply tariff"), func(): _act(Game.set_tariff(str(_opt_val(to)), float(_opt_val(tv)))))
	for k in tr:
		if float(tr[k]) > 0.0:
			_kv(v, Game.cname(k), "%d%%" % int(float(tr[k]) * 100.0))


func _screen_alliance() -> void:
	var v := _card(T("Allies & Standing"), 400.0)
	var c: Dictionary = Game.countries[Game.player]
	if c.allies.is_empty():
		v.add_child(_label(T("You have no allies."), GRAY))
	for a in c.allies.slice(0, 20):
		_kv(v, Game.cname(a), "%s (%d)" % [T("ALLIED"), int(Game.rel(Game.player, a))], BLUE)
	v.add_child(HSeparator.new())
	_kv(v, T("Influence"), str(int(Game.influence)))
	_kv(v, T("Intel"), str(int(Game.intel)))
	var ids := Game.alive_ids()
	ids.erase(Game.player)
	var q := alli_text.to_lower()
	ids = ids.filter(func(id): return q == "" or Game.cname(id).to_lower().find(q) >= 0)
	ids.sort_custom(func(a, b): return Game.rel(Game.player, a) > Game.rel(Game.player, b))
	v = _card(T("All Nations"), 620.0)
	var e := LineEdit.new()
	e.placeholder_text = T("Search country...")
	e.text = alli_text
	e.text_submitted.connect(func(t):
		alli_text = t
		_rebuild_screen())
	v.add_child(e)
	_btn(v, T("Search"), func():
		alli_text = e.text
		_rebuild_screen())
	for id in ids.slice(0, 40):
		var r := Game.rel(Game.player, id)
		var h := HBoxContainer.new()
		var lb := _label("%s  %d" % [Game.cname(id), int(r)], GREEN if r >= 30.0 else (RED if r <= -30.0 else GOLD), 16)
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(lb)
		var tid: String = id
		_btn(h, "+", func(): _act(Game.improve_relations(tid)))
		if Game.is_ally(Game.player, id):
			_btn(h, T("Break"), func(): _act(Game.break_alliance(tid)))
		else:
			_btn(h, T("Ally"), func(): _act(Game.propose_alliance(tid)))
		_btn(h, T("View"), func():
			_close_screen()
			var cp: int = int(World.countries[Game.countries[tid].idx].cap)
			map_view.selected_pid = cp
			map_view.focus_on(tid)
			right_mode = "country"
			_fill_right())
		v.add_child(h)
