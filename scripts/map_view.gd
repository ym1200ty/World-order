extends Control
## Real world map (Natural Earth): country + province borders, glowing neon style, city lights,
## army markers, battles and occupation progress. Pan / zoom / tap / right-click orders.

signal army_clicked(id: int, additive: bool)
signal province_clicked(pid: int)
signal province_right_clicked(pid: int)

const CODES := {"inf": "INF", "mech": "MCH", "arm": "ARM", "art": "ART", "sf": "SF", "air": "AIR", "navy": "NAV", "msl": "MSL"}

var zoom := 1.0
var pan := Vector2.ZERO
var hover_pid := -1
var selected_pid := -1
var order_mode := false
var _dragging := false
var _drag_dist := 0.0
var _t := 0.0
var _redraw_t := 0.0

var meshes: Array = []
var c_verts: Array = []
var c_idx: Array = []
var c_ranges: Array = []
var c_sig: Array = []
var prov_lines: Array = []
var country_lines: Array = []
var c_bbox: Array = []
var col_cache := {}
var _army_rects: Array = []


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_static()
	Game.map_changed.connect(refresh_colors)
	Game.changed.connect(refresh_colors)
	Game.day_passed.connect(queue_redraw)


func _process(delta: float) -> void:
	_t += delta
	_redraw_t += delta
	if Game.started and _redraw_t > 0.06 and (not Game.battles.is_empty() or not Game.sel_armies.is_empty() or order_mode):
		_redraw_t = 0.0
		queue_redraw()


# ---------------------------------------------------------------- static geometry
func _build_static() -> void:
	var n: int = World.countries.size()
	meshes.resize(n)
	c_verts.resize(n)
	c_idx.resize(n)
	c_ranges.resize(n)
	c_sig.resize(n)
	prov_lines.resize(n)
	country_lines.resize(n)
	c_bbox.resize(n)
	for ci in n:
		var c: Dictionary = World.countries[ci]
		var verts := PackedVector2Array()
		var idx := PackedInt32Array()
		var ranges: Array = []
		var lines := PackedVector2Array()
		var bb := Rect2()
		var first := true
		for pid in c.provs:
			var p: Dictionary = World.provs[pid]
			var vs: int = int(p.v0)
			var vn: int = int(p.vn)
			var base: int = verts.size()
			verts.append_array(World.verts.slice(vs, vs + vn))
			var t0: int = int(p.t0)
			for k in range(t0, t0 + int(p.tn)):
				idx.append(World.tris[k] - vs + base)
			ranges.append([pid, base, vn])
			for r in p.rings:
				var rs: int = int(r[0])
				var rn: int = int(r[1])
				for k in rn:
					lines.append(World.verts[rs + k])
					lines.append(World.verts[rs + (k + 1) % rn])
			var b: Array = p.bb
			var rect := Rect2(Vector2(float(b[0]), -float(b[3])), Vector2(float(b[2]) - float(b[0]), float(b[3]) - float(b[1])))
			bb = rect if first else bb.merge(rect)
			first = false
		c_verts[ci] = verts
		c_idx[ci] = idx
		c_ranges[ci] = ranges
		prov_lines[ci] = lines
		c_bbox[ci] = bb
		c_sig[ci] = -1
		meshes[ci] = ArrayMesh.new()
		var cl := PackedVector2Array()
		for r in c.rings:
			var rs2: int = int(r[0])
			var rn2: int = int(r[1])
			for k in rn2:
				cl.append(World.crings[rs2 + k])
				cl.append(World.crings[rs2 + (k + 1) % rn2])
		country_lines[ci] = cl


func color_for(id: String) -> Color:
	if col_cache.has(id):
		return col_cache[id]
	var col := _color_calc(id)
	col_cache[id] = col
	return col


func _color_calc(id: String) -> Color:
	var c: Dictionary = Game.countries[id]
	if not c.alive:
		var o: String = c.merged_into
		if o != "" and o != id and Game.countries.has(o) and Game.countries[o].alive:
			return color_for(o)
		return Color(0.3, 0.3, 0.3)
	if id == Game.player:
		return Color("2ee6a8")
	var r := Game.rel(Game.player, id)
	match Game.layer:
		1:
			var t := clampf((log(float(c.gdp) + 1.0) - log(5.0)) / (log(25000.0) - log(5.0)), 0.0, 1.0)
			return Color.from_hsv(0.36, 0.85, 0.35 + 0.65 * t)
		2:
			var t2 := clampf(Game.power(id) / 3000.0, 0.0, 1.0)
			return Color.from_hsv(0.02, 0.9, 0.35 + 0.65 * t2)
		3:
			if r >= 0.0:
				return Color(0.2, 0.45 + r / 180.0, 1.0)
			return Color(1.0, 0.4 + (100.0 + r) / 220.0, 0.2)
		_:
			if Game.is_ally(Game.player, id) or r >= 22.0:
				return Color("3d7bff")
			if Game.at_war(Game.player, id) or r <= -22.0:
				return Color("ff3b30")
			return Color("f2b705")


func refresh_colors() -> void:
	if not Game.started:
		return
	col_cache.clear()
	for ci in World.countries.size():
		var ranges: Array = c_ranges[ci]
		var sig_parts: Array = [Game.layer]
		var cols := PackedColorArray()
		cols.resize((c_verts[ci] as PackedVector2Array).size())
		for r in ranges:
			var pid: int = r[0]
			var owner: String = Game.prov_owner(pid)
			var ctl: String = Game.prov_ctl(pid)
			var base := color_for(owner)
			var h: float = float(absi(hash(pid)) % 7) * 0.012
			var fill := Color(base.r, base.g, base.b, 0.40 + h)
			if ctl != owner:
				var oc := color_for(ctl)
				fill = Color(oc.r, oc.g, oc.b, 0.62)
			sig_parts.append(fill.to_rgba32())
			for k in range(int(r[1]), int(r[1]) + int(r[2])):
				cols[k] = fill
		var sig: int = hash(sig_parts)
		if sig != int(c_sig[ci]):
			c_sig[ci] = sig
			var m: ArrayMesh = meshes[ci]
			m.clear_surfaces()
			if (c_idx[ci] as PackedInt32Array).size() > 0:
				var arrays := []
				arrays.resize(Mesh.ARRAY_MAX)
				arrays[Mesh.ARRAY_VERTEX] = c_verts[ci]
				arrays[Mesh.ARRAY_COLOR] = cols
				arrays[Mesh.ARRAY_INDEX] = c_idx[ci]
				m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	queue_redraw()


# ---------------------------------------------------------------- view helpers
func _scale() -> float:
	return minf(size.x / 370.0, size.y / 150.0) * zoom


func _origin() -> Vector2:
	return size * 0.5 + pan + Vector2(0, 12.0 * _scale())


func to_world(p: Vector2) -> Vector2:
	return (p - _origin()) / _scale()


func focus_pid(pid: int, z := 4.0) -> void:
	zoom = z
	pan = Vector2.ZERO
	pan = -(World.pos(pid) + Vector2(0, 12.0)) * _scale()
	_clamp_pan()
	queue_redraw()


func focus_on(id: String) -> void:
	if not Game.countries.has(id):
		return
	var ci: int = Game.countries[id].idx
	var bb: Rect2 = c_bbox[ci]
	zoom = clampf(minf(330.0 / maxf(bb.size.x, 1.0), 130.0 / maxf(bb.size.y, 1.0)), 1.2, 9.0)
	pan = Vector2.ZERO
	pan = -(bb.get_center() + Vector2(0, 12.0)) * _scale()
	_clamp_pan()
	queue_redraw()


func _clamp_pan() -> void:
	var lim := size * 0.55 * zoom
	pan = Vector2(clampf(pan.x, -lim.x, lim.x), clampf(pan.y, -lim.y, lim.y))


func _zoom_at(f: float, pos: Vector2) -> void:
	var old := zoom
	zoom = clampf(zoom * f, 0.9, 45.0)
	var k := zoom / old
	var c := size * 0.5
	pan = (pos - c) - (pos - c - pan) * k
	_clamp_pan()
	queue_redraw()


# ---------------------------------------------------------------- input
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(1.18, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(1.0 / 1.18, mb.position)
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_dragging = mb.button_index == MOUSE_BUTTON_LEFT
				_drag_dist = 0.0
			else:
				var was_drag: bool = _drag_dist >= 10.0
				if mb.button_index == MOUSE_BUTTON_LEFT:
					if not was_drag:
						_click(mb.position, mb.shift_pressed or mb.ctrl_pressed)
					_dragging = false
				elif not was_drag:
					var pid := World.pick(to_world(mb.position))
					if pid >= 0:
						province_right_clicked.emit(pid)
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if _dragging:
			pan += mm.relative
			_drag_dist += mm.relative.length()
			_clamp_pan()
			queue_redraw()
		else:
			var h := World.pick(to_world(mm.position))
			if h != hover_pid:
				hover_pid = h
				tooltip_text = _tip(h)
				queue_redraw()
	elif e is InputEventMagnifyGesture:
		var mg := e as InputEventMagnifyGesture
		_zoom_at(mg.factor, mg.position)


func _click(pos: Vector2, additive: bool) -> void:
	for i in range(_army_rects.size() - 1, -1, -1):
		var r: Array = _army_rects[i]
		if (r[0] as Rect2).has_point(pos):
			army_clicked.emit(int(r[1]), additive)
			return
	var pid := World.pick(to_world(pos))
	selected_pid = pid
	province_clicked.emit(pid)
	queue_redraw()


func _tip(pid: int) -> String:
	if pid < 0 or not Game.started:
		return ""
	var o := Game.prov_owner(pid)
	var ctl := Game.prov_ctl(pid)
	var s := "%s\n%s" % [Game.pname(pid), Game.cname(o)]
	if ctl != o:
		s += "\n" + Lang.t("Occupied by %s") % Game.cname(ctl)
	return s


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("04080f"))
	draw_circle(size * 0.5, size.y * 0.7, Color(0.05, 0.10, 0.18, 0.25))
	var s := _scale()
	var o := _origin()
	var vr := Rect2((Vector2.ZERO - o) / s, size / s)
	draw_set_transform(o, 0.0, Vector2(s, s))
	for lon in range(-180, 181, 30):
		draw_line(Vector2(lon, -85), Vector2(lon, 60), Color(1, 1, 1, 0.035), 1.0 / s)
	for lat in range(-60, 86, 30):
		draw_line(Vector2(-180, -lat), Vector2(180, -lat), Color(1, 1, 1, 0.035), 1.0 / s)
	if not Game.started:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var vis: Array = []
	for ci in World.countries.size():
		if (c_bbox[ci] as Rect2).intersects(vr):
			vis.append(ci)
	for ci in vis:
		var m: ArrayMesh = meshes[ci]
		if m.get_surface_count() > 0:
			draw_mesh(m, null)
	if zoom > 1.7:
		var pa: float = clampf((zoom - 1.7) * 0.07, 0.0, 0.16)
		for ci in vis:
			draw_multiline(prov_lines[ci], Color(1, 1, 1, pa), 0.9 / s)
	for ci in vis:
		var id: String = World.countries[ci].id
		var col: Color = color_for(id).lightened(0.25)
		var cl: PackedVector2Array = country_lines[ci]
		draw_multiline(cl, Color(col.r, col.g, col.b, 0.10), 9.0 / s)
		draw_multiline(cl, Color(col.r, col.g, col.b, 0.22), 4.5 / s)
		draw_multiline(cl, Color(col.r, col.g, col.b, 0.95), 1.4 / s)
	for pid in [selected_pid, hover_pid]:
		if pid >= 0:
			var gold := Color(1, 0.9, 0.4, 0.95) if pid == selected_pid else Color(1, 1, 1, 0.6)
			for k in World.provs[pid].rings.size():
				var rg: PackedVector2Array = World.ring(pid, k)
				rg.append(rg[0])
				draw_polyline(rg, gold, 2.2 / s)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var thr: float = 6.0e6 / pow(zoom, 1.6)
	for c in World.cities:
		var pop: float = float(c[2])
		if pop < thr and not (int(c[4]) == 1 and zoom > 1.2):
			continue
		var p := o + Vector2(float(c[0]), -float(c[1])) * s
		if p.x < -10 or p.y < -10 or p.x > size.x + 10 or p.y > size.y + 10:
			continue
		var col2 := Color(1, 0.92, 0.65)
		var pid2: int = int(c[6])
		if pid2 >= 0:
			col2 = color_for(Game.prov_ctl(pid2)).lightened(0.55)
		var r: float = clampf(1.2 + log(pop / 3e5) * 0.9, 1.2, 4.5) * clampf(0.7 + zoom * 0.12, 0.8, 1.8)
		draw_circle(p, r * 2.6, Color(col2.r, col2.g, col2.b, 0.10))
		draw_circle(p, r, Color(col2.r, col2.g, col2.b, 0.95))
	var font: Font = Lang.font
	for ci in vis:
		var id2: String = World.countries[ci].id
		var cc: Dictionary = Game.countries[id2]
		if not cc.alive:
			continue
		var bb: Rect2 = c_bbox[ci]
		var wpx: float = bb.size.x * s
		var nm: String = Game.cname(id2)
		var fs: int = int(clampf(wpx / maxf(nm.length() * 0.7, 4.0), 9.0, 22.0))
		if wpx > nm.length() * 6.0 and wpx > 36.0:
			var cp := o + Vector2(float(cc.x), -float(cc.y)) * s
			var tw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string_outline(font, cp - Vector2(tw * 0.5, -fs * 0.3), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8))
			draw_string(font, cp - Vector2(tw * 0.5, -fs * 0.3), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.92))
	if zoom > 5.0:
		for ci in vis:
			for pid in World.countries[ci].provs:
				var pb: Array = World.provs[pid].bb
				var ww: float = (float(pb[2]) - float(pb[0])) * s
				if ww < 60.0:
					continue
				var pp := o + World.pos(pid) * s
				if pp.x < 0 or pp.y < 0 or pp.x > size.x or pp.y > size.y:
					continue
				var pn: String = Game.pname(pid)
				var tw2 := font.get_string_size(pn, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
				draw_string(font, pp - Vector2(tw2 * 0.5, 0), pn, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.6))
	_draw_war_layer(o, s, font)


func _army_visible(a: Dictionary) -> bool:
	return a.o == Game.player or Game.at_war(Game.player, a.o) or Game.is_ally(Game.player, a.o)


func _acol(a: Dictionary) -> Color:
	if a.o == Game.player:
		return Color("2ee6a8")
	if Game.at_war(Game.player, a.o):
		return Color("ff4b3e")
	return Color("5aa0ff")


func _draw_war_layer(o: Vector2, s: float, font: Font) -> void:
	for pid in Game.prov_op:
		var p := o + World.pos(int(pid)) * s
		draw_arc(p, 14.0, -PI / 2.0, -PI / 2.0 + TAU * float(Game.prov_op[pid]) / 100.0, 24, Color(1, 0.7, 0.2, 0.9), 3.0)
	for pid in Game.battles:
		var p := o + World.pos(int(pid)) * s
		var pulse := 1.0 + 0.25 * sin(_t * 8.0)
		draw_circle(p, 18.0 * pulse, Color(1, 0.15, 0.1, 0.25))
		draw_arc(p, 18.0 * pulse, 0, TAU, 28, Color(1, 0.3, 0.2, 0.95), 2.5)
		draw_line(p + Vector2(-8, -8), p + Vector2(8, 8), Color.WHITE, 2.5)
		draw_line(p + Vector2(8, -8), p + Vector2(-8, 8), Color.WHITE, 2.5)
	_army_rects = []
	var groups := {}
	for a in Game.armies.values():
		if not _army_visible(a):
			continue
		if not groups.has(a.p):
			groups[a.p] = []
		groups[a.p].append(a)
	var big: bool = zoom >= 1.6
	for pid in groups:
		var base := o + World.pos(int(pid)) * s + Vector2(0, -16)
		if base.x < -60 or base.y < -40 or base.x > size.x + 60 or base.y > size.y + 40:
			continue
		var list: Array = groups[pid]
		if not big:
			var col := _acol(list[0])
			draw_rect(Rect2(base - Vector2(4, 4), Vector2(8, 8)), col)
			if list.size() > 1:
				draw_string(font, base + Vector2(6, 4), str(list.size()), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
			_army_rects.append([Rect2(base - Vector2(9, 9), Vector2(18, 18)), int(list[0].id)])
			continue
		var n: int = mini(list.size(), 6)
		for i in n:
			var a: Dictionary = list[i]
			var pos := base + Vector2((i - (n - 1) * 0.5) * 36.0, 0)
			var rect := Rect2(pos - Vector2(16, 9), Vector2(32, 18))
			var col2 := _acol(a)
			draw_rect(rect, Color(0.04, 0.06, 0.1, 0.9))
			draw_rect(rect, col2, false, 2.0)
			draw_string(font, pos + Vector2(-14, 4), str(CODES.get(a.t, "?")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col2)
			draw_string(font, pos + Vector2(-12, 22), str(int(a.sz)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.85))
			if a.id in Game.sel_armies:
				draw_rect(rect.grow(3), Color(1, 0.95, 0.3), false, 2.5)
			if a.eng:
				draw_rect(rect.grow(1), Color(1, 0.2, 0.1, 0.55), false, 2.0)
			_army_rects.append([rect, int(a.id)])
		if list.size() > 6:
			draw_string(font, base + Vector2(110, 4), "+%d" % (list.size() - 6), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	for id in Game.sel_armies:
		if not Game.armies.has(id):
			continue
		var a: Dictionary = Game.armies[id]
		if a.path.is_empty():
			continue
		var pts := PackedVector2Array([o + World.pos(int(a.p)) * s])
		for pid in a.path:
			pts.append(o + World.pos(int(pid)) * s)
		draw_polyline(pts, Color(1, 0.95, 0.3, 0.9), 2.5, true)
		draw_circle(pts[pts.size() - 1], 5.0, Color(1, 0.95, 0.3))
	if order_mode:
		draw_string(font, Vector2(14, size.y - 14), Lang.t("Click a destination province (right-click also works)"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.95, 0.3))
