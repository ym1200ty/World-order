class_name Market
extends RefCounted

static var G
static var W
static var L
## Global market: stocks, commodities, crypto. Prices move from real in-game causes:
## supply & demand (producers at war / sanctioned / occupied), sentiment, and BUY/SELL order flow
## (the player's trades and simulated funds both push prices).

const GENERIC := [["%s National Bank", "Banks"], ["%s Telecom", "Telecom"], ["%s Power & Utilities", "Utilities"],
	["%s Mining & Resources", "Mining"], ["%s Agro Holdings", "Agri"]]
const VOL := {"Tech": 0.018, "Semis": 0.022, "Media": 0.017, "Autos": 0.016, "Banks": 0.011, "Insurance": 0.009, "Utilities": 0.007, "Food": 0.008,
	"Pharma": 0.012, "Energy": 0.015, "Mining": 0.017, "Defense": 0.012, "Aviation": 0.019, "Luxury": 0.014}


static func init() -> void:
	var a: Dictionary = {}
	for k in Tables.COMM:
		var d: Array = Tables.COMM[k]
		a[k] = {"id": k, "k": "comm", "n": d[0], "base": d[1], "price": d[1], "hist": [d[1]], "chg": 0.0, "flow": 0.0, "depth": 6e8, "vol": d[2], "shock": 0.0}
	for r in Tables.CRYPTO:
		a[r[0]] = {"id": r[0], "k": "crypto", "n": r[1], "base": r[2], "price": r[2], "hist": [r[2]], "chg": 0.0, "flow": 0.0,
			"depth": 4e8 if r[0] in ["BTC", "ETH", "USDT"] else 6e7, "vol": r[3], "beta": r[4]}
	var n := 0
	var counts := {}
	for line in Tables.COMPANIES.strip_edges().split("\n"):
		var iso: String = line.get_slice(":", 0).strip_edges()
		if not W.cidx.has(iso):
			continue
		var g: float = W.countries[W.cidx[iso]].gdp
		for e in line.get_slice(":", 1).split(";"):
			var p := e.split(",")
			if p.size() < 3:
				continue
			var price: float = maxf(0.05, float(p[2]))
			var id := "S%d" % n
			n += 1
			a[id] = _stock(id, p[0].strip_edges(), p[1].strip_edges(), iso, price, g, "")
			counts[iso] = int(counts.get(iso, 0)) + 1
	for c in W.countries:
		var iso: String = c.id
		var k: int = 2 if int(counts.get(iso, 0)) >= 10 else (4 if c.gdp > 20 else 3)
		var g2: float = c.gdp
		var cont: String = str(c.cont)
		for i in k:
			var spec: Array = GENERIC[i]
			if i == 3 and not (cont in ["Africa", "South America", "Asia", "Oceania"]):
				spec = GENERIC[4]
			elif i == 2 and k == 2:
				spec = GENERIC[2]
			elif k == 2 and i == 1:
				spec = GENERIC[2]
			var id := "S%d" % n
			n += 1
			var price: float = 8.0 + 14.0 * log(g2 + 2.0) / log(10.0)
			a[id] = _stock(id, spec[0] % c.n, spec[1], iso, price, g2, spec[0])
	G.assets = a
	G.mk_sent = 0.1


static func _stock(id: String, nm: String, sec: String, iso: String, price: float, gdp: float, tpl: String) -> Dictionary:
	var depth: float = 2.0e6 * (1.0 + log(gdp + 1.0) / log(10.0))
	var h: Array = []
	for i in 3:
		h.append(price)
	return {"id": id, "k": "stock", "n": nm, "tpl": tpl, "sec": sec, "c": iso, "base": price, "price": price, "hist": h, "chg": 0.0,
		"flow": 0.0, "depth": depth, "vol": float(VOL.get(sec, 0.012)), "sent": 0.0}


static func disp_name(a: Dictionary) -> String:
	if a.k == "stock" and a.tpl != "":
		return L.t(a.tpl) % G.cname(a.c)
	return L.t(a.n) if a.k == "comm" else a.n


static func health(iso: String) -> float:
	if not G.countries.has(iso):
		return 0.8
	var c: Dictionary = G.countries[iso]
	if not c.alive:
		return 0.7
	var h := 1.0
	if G.wars_of(iso).size() > 0:
		h *= 0.8
	if c.occupier != "":
		h *= 0.4
	h *= 1.0 - 0.05 * mini(c.sanctioned_by.size(), 6)
	if float(c.stability) < 30.0:
		h *= 0.85
	return h


static func supply_ratio(k: String) -> float:
	var sup := 0.0
	var tot := 0.0
	for iso in Tables.PRODUCERS[k]:
		var sh: float = float(Tables.PRODUCERS[k][iso])
		tot += sh
		sup += sh * health(iso)
	return sup / maxf(tot, 0.001)


static func sector_factor(sec: String) -> float:
	var f := 1.0
	var sens: Dictionary = Tables.SECTOR_SENS.get(sec, {})
	for k in sens:
		var cm: Dictionary = G.assets[k]
		f += float(sens[k]) * (float(cm.price) / float(cm.base) - 1.0)
	var s: float = G.mk_sent
	match sec:
		"Defense":
			f *= 1.0 + minf(0.4, 0.03 * G.wars.size())
		"Banks", "Insurance":
			f *= 1.0 + 0.25 * s
		"Tech", "Semis", "Media":
			f *= 1.0 + 0.35 * s
		"Luxury", "Retail", "RealEstate":
			f *= 1.0 + 0.25 * s
		"Pharma":
			f *= 1.0 + 0.05 * s
	return clampf(f, 0.3, 2.5)


static func country_factor(iso: String) -> float:
	if not G.countries.has(iso):
		return 0.8
	var c: Dictionary = G.countries[iso]
	if not c.alive:
		return 0.7
	var f: float = 0.75 + 0.25 * clampf(float(c.stability) / 70.0, 0.0, 1.3)
	if G.wars_of(iso).size() > 0:
		f *= 0.9
	f *= 1.0 - 0.03 * mini(c.sanctioned_by.size(), 8)
	if c.occupier != "":
		f *= 0.6
	f *= 1.0 + (G.growth(iso) - 0.02) * 2.0
	return clampf(f, 0.3, 1.6)


static func _push(a: Dictionary, ch: float) -> void:
	var old: float = a.price
	a.price = maxf(float(a.base) * 0.01, old * (1.0 + ch))
	a.chg = float(a.price) / old - 1.0
	a.hist.append(a.price)
	if a.hist.size() > 60:
		a.hist.pop_front()
	a.flow = float(a.flow) * 0.35


static func daily() -> void:
	var rng: RandomNumberGenerator = G.rng
	# global sentiment
	var wc: int = G.wars.size()
	var target: float = 0.25 - 0.07 * wc
	var s0: float = G.mk_sent
	G.mk_sent = clampf(s0 + (target - s0) * 0.03 + rng.randfn(0.0, 0.035), -1.0, 1.0)
	var ds: float = G.mk_sent - s0
	# commodities
	for k in Tables.COMM:
		var a: Dictionary = G.assets[k]
		var ratio := supply_ratio(k)
		var demand: float = 1.0 + 0.1 * G.mk_sent
		if k in ["oil", "gas", "coal", "iron", "copper"]:
			demand += minf(0.12, 0.012 * wc)
		var tgt: float = float(a.base) * (1.0 + clampf((demand / ratio - 1.0) * 2.0, -0.6, 1.2))
		var p: float = a.price
		var imp: float = clampf(float(a.flow) / float(a.depth), -0.1, 0.1)
		a.shock = float(a.shock) * 0.9
		_push(a, (tgt - p) / p * 0.04 + imp + float(a.shock) + rng.randfn(0.0, float(a.vol)))
	# crypto
	for r in Tables.CRYPTO:
		var a: Dictionary = G.assets[r[0]]
		var imp2: float = clampf(float(a.flow) / float(a.depth), -0.15, 0.15)
		if r[0] == "USDT":
			var dep: float = 0.01 * maxf(0.0, -G.mk_sent - 0.5)
			_push(a, (1.0 - float(a.price)) * 0.2 + rng.randfn(0.0, float(a.vol)) - dep + imp2 * 0.1)
		else:
			var whale: float = rng.randfn(0.0, 0.004) if rng.randf() < 0.1 else 0.0
			_push(a, float(a.beta) * ds * 0.5 + 0.0003 * float(a.beta) + rng.randfn(0.0, float(a.vol)) + imp2 + whale)
	# stocks
	var sf := {}
	var cf := {}
	var tot_w := 0.0
	var idx := 0.0
	for id in G.assets:
		var a: Dictionary = G.assets[id]
		if a.k != "stock":
			continue
		var sec: String = a.sec
		if not sf.has(sec):
			sf[sec] = sector_factor(sec)
		var iso: String = a.c
		if not cf.has(iso):
			cf[iso] = country_factor(iso)
		a.sent = float(a.sent) * 0.97 + rng.randfn(0.0, 0.004)
		var tgt2: float = float(a.base) * float(sf[sec]) * float(cf[iso]) * (1.0 + float(a.sent))
		var p2: float = a.price
		var h: Array = a.hist
		var mom: float = 0.0
		if h.size() > 5:
			mom = float(h[-1]) / float(h[-5]) - 1.0
		var ai: float = float(a.depth) * (0.01 * mom + rng.randfn(0.0, 0.002))
		var imp3: float = clampf((float(a.flow) + ai) / float(a.depth), -0.1, 0.1)
		_push(a, (tgt2 - p2) / p2 * 0.05 + imp3 + rng.randfn(0.0, float(a.vol)))
		idx += float(a.price) / float(a.base) * float(a.depth)
		tot_w += float(a.depth)
	G.index_hist.append(idx / maxf(tot_w, 1.0) * 4000.0)
	if G.index_hist.size() > 60:
		G.index_hist.pop_front()


static func exec_price(a: Dictionary, qty: float, buy: bool) -> float:
	var cost: float = float(a.price) * qty
	var slip: float = minf(0.25, cost / float(a.depth) * 0.5)
	return float(a.price) * (1.0 + slip if buy else 1.0 - slip)


static func buy(id: String, qty: float) -> String:
	var a: Dictionary = G.assets[id]
	if qty <= 0.0:
		return L.t("Invalid quantity.")
	var fee: float = 1.004 if a.k == "crypto" else (1.001 if a.k == "comm" else 1.002)
	var cost: float = exec_price(a, qty, true) * qty * fee
	if cost > G.player_cash:
		return L.t("Not enough credits (%s Cr needed).") % G.commas(int(cost))
	G.player_cash -= cost
	G.holdings[id] = float(G.holdings.get(id, 0.0)) + qty
	G.basis[id] = float(G.basis.get(id, 0.0)) + cost
	a.flow = float(a.flow) + float(a.price) * qty
	G.changed.emit()
	return ""


static func sell(id: String, qty: float) -> String:
	var a: Dictionary = G.assets[id]
	var have: float = float(G.holdings.get(id, 0.0))
	if qty <= 0.0 or have < qty - 0.000001:
		return L.t("You only own %s.") % str(snappedf(have, 0.0001))
	var fee: float = 0.996 if a.k == "crypto" else (0.999 if a.k == "comm" else 0.998)
	var avg: float = float(G.basis.get(id, 0.0)) / maxf(have, 0.000001)
	G.player_cash += exec_price(a, qty, false) * qty * fee
	G.holdings[id] = have - qty
	G.basis[id] = maxf(0.0, float(G.basis.get(id, 0.0)) - avg * qty)
	if float(G.holdings[id]) < 0.000001:
		G.holdings.erase(id)
		G.basis.erase(id)
	a.flow = float(a.flow) - float(a.price) * qty
	G.changed.emit()
	return ""


static func portfolio_value() -> float:
	var v := 0.0
	for id in G.holdings:
		v += float(G.assets[id].price) * float(G.holdings[id])
	return v


static func query(kind: String, country: String, sector: String, text: String, sort: String, limit: int) -> Array:
	var out: Array = []
	var t := text.to_lower().strip_edges()
	for id in G.assets:
		var a: Dictionary = G.assets[id]
		if a.k != kind:
			continue
		if country != "" and a.get("c", "") != country:
			continue
		if sector != "" and a.get("sec", "") != sector:
			continue
		if t != "" and disp_name(a).to_lower().find(t) < 0:
			continue
		out.append(id)
	match sort:
		"chg":
			out.sort_custom(func(x, y): return float(G.assets[x].chg) > float(G.assets[y].chg))
		"low":
			out.sort_custom(func(x, y): return float(G.assets[x].chg) < float(G.assets[y].chg))
		"price":
			out.sort_custom(func(x, y): return float(G.assets[x].price) > float(G.assets[y].price))
		_:
			out.sort_custom(func(x, y): return float(G.assets[x].depth) > float(G.assets[y].depth))
	return out.slice(0, limit)
