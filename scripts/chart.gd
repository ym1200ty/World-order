extends Control
## Tiny line chart used for commodities, stocks and the global index.

var data: Array = []
var color := Color("7dff5c")
var grid := false


func _draw() -> void:
	if data.size() < 2:
		return
	var mn := INF
	var mx := -INF
	for v in data:
		mn = minf(mn, float(v))
		mx = maxf(mx, float(v))
	if mx - mn < 0.0001:
		mx = mn + 1.0
	if grid:
		for k in 5:
			var y := size.y * k / 4.0
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.08), 1.0)
	var pts := PackedVector2Array()
	for i in data.size():
		var x := size.x * i / float(data.size() - 1)
		var y := size.y - (float(data[i]) - mn) / (mx - mn) * (size.y - 6.0) - 3.0
		pts.append(Vector2(x, y))
	var fill := PackedVector2Array(pts)
	fill.append(Vector2(size.x, size.y))
	fill.append(Vector2(0, size.y))
	var fc := color
	fc.a = 0.12
	draw_colored_polygon(fill, fc)
	draw_polyline(pts, color, 2.0, true)
