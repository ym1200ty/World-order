extends Node
## Static world geometry (autoload "World"): real country / province borders from Natural Earth.

var countries: Array = []
var provs: Array = []
var cities: Array = []
var verts := PackedVector2Array()      # x = lon, y = -lat
var tris := PackedInt32Array()
var crings := PackedVector2Array()
var cidx := {}                          # iso id -> index
var astar := AStar2D.new()
var city_pop := {}                      # pid -> total city population
var sea_edges := {}


func _ready() -> void:
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	countries = meta.countries
	provs = meta.provs
	cities = meta.cities
	var iv := FileAccess.get_file_as_bytes("res://data/verts.bin").to_int32_array()
	verts.resize(iv.size() / 2)
	for i in verts.size():
		verts[i] = Vector2(iv[2 * i] * 0.01, -iv[2 * i + 1] * 0.01)
	tris = FileAccess.get_file_as_bytes("res://data/tris.bin").to_int32_array()
	var cv := FileAccess.get_file_as_bytes("res://data/crings.bin").to_int32_array()
	crings.resize(cv.size() / 2)
	for i in crings.size():
		crings[i] = Vector2(cv[2 * i] * 0.01, -cv[2 * i + 1] * 0.01)
	for c in countries:
		c.provs = _ints(c.provs)
		c.cap = int(c.cap)
	for p in provs:
		p.nb = _ints(p.nb)
		p.sea = _ints(p.sea)
		p.c = int(p.c)
		p.coast = int(p.coast)
		for r in p.rings:
			r[0] = int(r[0])
			r[1] = int(r[1])
			r[2] = int(r[2])
	for i in countries.size():
		cidx[countries[i].id] = i
	for i in provs.size():
		var p: Dictionary = provs[i]
		astar.add_point(i, Vector2(p.cx, -p.cy))
	for i in provs.size():
		for j in provs[i].nb:
			if j > i:
				astar.connect_points(i, j, true)
		for j in provs[i].sea:
			if not astar.are_points_connected(i, j):
				astar.connect_points(i, j, true)
			sea_edges[i * 10000 + j] = true
			sea_edges[j * 10000 + i] = true
	for c in cities:
		if int(c[6]) >= 0:
			city_pop[int(c[6])] = int(city_pop.get(int(c[6]), 0)) + int(c[2])


func _ints(a: Array) -> Array:
	var out: Array = []
	for x in a:
		out.append(int(x))
	return out


func is_sea(a: int, b: int) -> bool:
	return sea_edges.has(a * 10000 + b)


func pos(pid: int) -> Vector2:
	var p: Dictionary = provs[pid]
	return Vector2(p.cx, -p.cy)


func ring(pid: int, k: int) -> PackedVector2Array:
	var r: Array = provs[pid].rings[k]
	return verts.slice(int(r[0]), int(r[0]) + int(r[1]))


func pick(w: Vector2) -> int:
	## w in world coords (lon, -lat). Returns province id or -1
	var lat := -w.y
	for i in provs.size():
		var bb: Array = provs[i].bb
		if w.x < bb[0] or w.x > bb[2] or lat < bb[1] or lat > bb[3]:
			continue
		var rings: Array = provs[i].rings
		for k in rings.size():
			if int(rings[k][2]) == 0 and Geometry2D.is_point_in_polygon(w, ring(i, k)):
				return i
	return -1


func terrain(pid: int) -> Array:
	## [name_key, defense multiplier]
	var p: Dictionary = provs[pid]
	var h: int = absi(hash(str(pid) + "t")) % 100
	var lat: float = absf(float(p.cy))
	if lat < 30.0 and h < 35:
		return ["Desert", 1.0]
	if h < 40:
		return ["Plains", 1.0]
	if h < 65:
		return ["Forest", 1.15]
	if h < 85:
		return ["Hills", 1.25]
	return ["Mountains", 1.45]


func fort(pid: int) -> int:
	var cp: int = int(city_pop.get(pid, 0))
	var f := 0
	if cp > 1500000:
		f = 2
	elif cp > 400000:
		f = 1
	return f
