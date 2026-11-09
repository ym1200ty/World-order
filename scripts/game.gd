extends Node
## WORLD ORDER - core simulation (autoload "Game").
## Logic lives here (+ Market / Military helper classes). UI only reads state and calls actions.

signal changed
signal map_changed
signal day_passed
signal news(text: String)
signal proposal(data: Dictionary)
signal battle_alert(pid: int)

const SAVE_PATH := "user://world_order_save.json"
const START_DATE := {"year": 2034, "month": 3, "day": 12, "hour": 0, "minute": 0, "second": 0}
const LAYER_NAMES := ["Geopolitical", "Economy", "Military", "Influence"]
const SECTORS := {
	"Mining": {"rate": 280.0, "comm": "iron", "prod": true}, "Energy": {"rate": 300.0, "comm": "oil", "prod": true},
	"Agriculture": {"rate": 230.0, "comm": "wheat", "prod": true}, "Manufacturing": {"rate": 250.0, "comm": "iron", "prod": false},
	"Electronics": {"rate": 290.0, "comm": "", "prod": false}, "Autos": {"rate": 260.0, "comm": "iron", "prod": false},
	"Shipping": {"rate": 240.0, "comm": "oil", "prod": false}, "Defense": {"rate": 330.0, "comm": "", "prod": false},
}
const LAWS := {
	"security_act": {"name": "Security Act", "desc": "Order +15, Civil Liberties -5", "bias": 8},
	"economic_reform": {"name": "Economic Reform", "desc": "Growth +1.5%, Approval -2", "bias": 0},
	"conscription": {"name": "Conscription Law", "desc": "Troops +20%, Approval -5", "bias": -10},
	"free_trade": {"name": "Free Trade Act", "desc": "Trade margin +3%, Growth +0.8%", "bias": 2},
	"press_law": {"name": "Press Freedom Act", "desc": "Liberties +10, Stability -2", "bias": 4},
	"war_powers": {"name": "War Powers Act", "desc": "War support +10, Liberties -6", "bias": -4},
}
const BASE_TYPES := {
	"land": "Land Base", "air": "Air Base", "naval": "Naval Base", "hq": "Command & Intelligence Center",
	"depot": "Supply Depot", "academy": "Training & Research Center",
}
const FIRST := ["Alistair", "Yara", "Lukas", "Sofia", "Marek", "Amira", "Viktor", "Elena", "Omar", "Hana", "Daniel", "Leila", "Tomas", "Nadia",
	"Ivan", "Mariam", "Carlos", "Aiko", "Kofi", "Rania"]
const LAST := ["Rhen", "Voss", "Chen", "Hale", "Morozov", "Haddad", "Okafor", "Silva", "Tanaka", "Novak", "Mansour", "Petrov", "Duarte",
	"Ibrahim", "Kowalski", "Reyes", "Sato", "Bauer", "Aziz", "Lindqvist"]
const SAVE_KEYS := ["day", "player", "countries", "relations", "wars", "war_uid", "assets", "mk_sent", "index_hist", "holdings", "basis",
	"player_cash", "player_companies", "loans_taken", "loans_given", "bonds", "has_bank", "contracts", "influence", "intel", "in_office",
	"exile", "exile_resistance", "party", "party_support", "next_election", "opposition_until", "pending_votes", "bases", "combat_log",
	"news_feed", "layer", "casualties", "enemy_casualties", "last_war_day", "army_uid", "recruit_q", "p_own", "p_ctl", "prov_op"]

var rng := RandomNumberGenerator.new()
var started := false
var day := 0
var paused := true
var speed := 1.0
var auto_pause := true
var player := ""
var countries := {}
var nbrs := {}
var relations := {}
var wars: Array = []
var war_uid := 1
var assets := {}
var mk_sent := 0.0
var index_hist: Array = []
var holdings := {}
var basis := {}
var player_cash := 250000.0
var player_companies: Array = []
var loans_taken: Array = []
var loans_given: Array = []
var bonds := 0.0
var has_bank := false
var contracts: Array = []
var influence := 100.0
var intel := 40.0
var in_office := true
var exile := false
var exile_resistance := 0.0
var party := ""
var party_support := 0.0
var next_election := 1460
var opposition_until := 0
var pending_votes: Array = []
var bases: Array = []
var combat_log: Array = []
var news_feed: Array = []
var layer := 0
var casualties := 0.0
var enemy_casualties := 0.0
var last_war_day := 0
var armies := {}
var army_uid := 0
var recruit_q: Array = []
var battles := {}
var p_own := {}
var p_ctl := {}
var prov_op := {}
var owned := {}
var sel_armies: Array = []
var _acc := 0.0
var _quiet := false
var _prop_pending := false
var _map_dirty := false


func _ready() -> void:
	rng.randomize()
	for cls in [Market, Military]:
		cls.G = self
		cls.W = World
		cls.L = Lang


func _process(delta: float) -> void:
	if not started or paused:
		return
	_acc += delta * speed
	var guard := 0
	while _acc >= 1.0 and guard < 10:
		_acc -= 1.0
		guard += 1
		advance_day()


# ---------------------------------------------------------------- names / helpers
func name_for(seed_str: String) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash(seed_str)
	return "%s %s" % [FIRST[r.randi() % FIRST.size()], LAST[r.randi() % LAST.size()]]


func cname(id: String) -> String:
	if not countries.has(id):
		return id
	return str(countries[id].ar) if Lang.ar else str(countries[id].name)


func pname(pid: int) -> String:
	var p: Dictionary = World.provs[pid]
	return str(p.ar) if Lang.ar else str(p.n)


func prov_owner(pid: int) -> String:
	return str(p_own.get(pid, World.countries[World.provs[pid].c].id))


func prov_ctl(pid: int) -> String:
	return str(p_ctl.get(pid, prov_owner(pid)))


func _key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


func rel(a: String, b: String) -> float:
	if a == b:
		return 100.0
	return float(relations.get(_key(a, b), 0.0))


func set_rel(a: String, b: String, v: float) -> void:
	relations[_key(a, b)] = clampf(v, -100.0, 100.0)


func add_rel(a: String, b: String, d: float) -> void:
	set_rel(a, b, rel(a, b) + d)


func _dist(a: String, b: String) -> float:
	var ca: Dictionary = countries[a]
	var cb: Dictionary = countries[b]
	return Vector2(ca.x, ca.y).distance_to(Vector2(cb.x, cb.y))


func alive_ids() -> Array:
	var out: Array = []
	for id in countries:
		if countries[id].alive:
			out.append(id)
	return out


func is_ally(a: String, b: String) -> bool:
	return countries.has(a) and b in countries[a].allies


func _make_alliance(a: String, b: String) -> void:
	if not (b in countries[a].allies):
		countries[a].allies.append(b)
	if not (a in countries[b].allies):
		countries[b].allies.append(a)
	set_rel(a, b, maxf(rel(a, b), 65.0))


func _break_alliance(a: String, b: String) -> void:
	countries[a].allies.erase(b)
	countries[b].allies.erase(a)


func wars_of(id: String) -> Array:
	var out: Array = []
	for w in wars:
		if id in w.sa or id in w.sb:
			out.append(w)
	return out


func at_war(a: String, b: String) -> bool:
	for w in wars:
		if (a in w.sa and b in w.sb) or (a in w.sb and b in w.sa):
			return true
	return false


func war_by_uid(uid: int) -> Dictionary:
	for w in wars:
		if int(w.uid) == uid:
			return w
	return {}


func player_in(w: Dictionary) -> bool:
	return player in w.sa or player in w.sb


func base_count(id: String) -> int:
	var n := 0
	for b in bases:
		if b.owner == id:
			n += 1
	return n


func power(id: String) -> float:
	return float(countries[id].pw) if countries.has(id) and countries[id].alive else 0.0


func army_power(id: String) -> int:
	return int(power(id) * 10.0)


func prestige(id: String) -> float:
	var c: Dictionary = countries[id]
	return sqrt(float(c.gdp)) * 3.0 + power(id) * 0.15 + c.allies.size() * 25.0


func growth(id: String) -> float:
	var c: Dictionary = countries[id]
	var g: float = 0.025 + (float(c.stability) - 60.0) / 1000.0 + float(c.growth_mod)
	g -= (float(c.tax) - 0.22) * 0.15
	g -= 0.012 * c.sanctioned_by.size()
	g -= 0.04 * float(c.occf)
	if wars_of(id).size() > 0:
		g -= 0.02
	if c.occupier != "":
		g -= 0.03
	return g


func can_govern() -> bool:
	if not countries.has(player):
		return false
	var c: Dictionary = countries[player]
	return in_office and not exile and c.alive and c.occupier == ""


func gov_error() -> String:
	if exile:
		return Lang.t("You are in exile and cannot govern.")
	if not in_office:
		return Lang.t("You are out of office. Win an election first.")
	return Lang.t("Your country is occupied.")


func say(text: String) -> void:
	news_feed.append(text)
	if news_feed.size() > 40:
		news_feed.pop_front()
	if not _quiet:
		news.emit(text)


func clog(text: String) -> void:
	combat_log.append("%s %d: %s" % [Lang.t("Day"), day, text])
	if combat_log.size() > 40:
		combat_log.pop_front()


func date_string() -> String:
	var u: int = Time.get_unix_time_from_datetime_dict(START_DATE) + day * 86400
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(u)
	return "%04d.%02d.%02d" % [d.year, d.month, d.day]


func commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var cnt := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


func fmt(v: float) -> String:
	var a := absf(v)
	if a >= 1e12:
		return "%.2fT" % (v / 1e12)
	if a >= 1e9:
		return "%.2fB" % (v / 1e9)
	if a >= 1e6:
		return "%.2fM" % (v / 1e6)
	if a >= 1e3:
		return "%.1fK" % (v / 1e3)
	return "%.0f" % v


func fmt_m(m: float) -> String:
	return fmt(m * 1e6)


# ---------------------------------------------------------------- province ownership
func _rebuild_owned() -> void:
	owned = {}
	for id in countries:
		owned[id] = []
	for pid in World.provs.size():
		owned[prov_owner(pid)].append(pid)


func _wsum(id: String) -> float:
	var s := 0.0
	for pid in owned.get(id, []):
		s += float(World.provs[pid].w)
	return s


func _refresh_occf(id: String) -> void:
	if not countries.has(id):
		return
	var tot := 0.0
	var cap := 0.0
	for pid in owned.get(id, []):
		var w: float = World.provs[pid].w
		tot += w
		if prov_ctl(pid) != id:
			cap += w
	countries[id].occf = cap / maxf(tot, 0.0001)


func set_ctl(pid: int, who: String) -> void:
	var owner := prov_owner(pid)
	var old := prov_ctl(pid)
	if who == old:
		return
	if who == owner:
		p_ctl.erase(pid)
	else:
		p_ctl[pid] = who
	_refresh_occf(owner)
	_map_dirty = true
	if owner == player or who == player or old == player:
		say(Lang.t("%s now controls %s.") % [cname(who), pname(pid)])
		clog(Lang.t("%s now controls %s.") % [cname(who), pname(pid)])


func set_prov_owner(pid: int, to: String) -> void:
	var old := prov_owner(pid)
	if old == to:
		return
	var orig: String = World.countries[World.provs[pid].c].id
	if to == orig:
		p_own.erase(pid)
	else:
		p_own[pid] = to
	p_ctl.erase(pid)
	var oc: Dictionary = countries[old]
	var tc: Dictionary = countries[to]
	var w: float = World.provs[pid].w
	var share: float = w / maxf(_wsum(old), 0.0001)
	var g: float = float(oc.gdp) * share
	var p: float = float(oc.pop) * share
	oc.gdp = float(oc.gdp) - g
	oc.pop = float(oc.pop) - p
	tc.gdp = float(tc.gdp) + g
	tc.pop = float(tc.pop) + p
	owned[old].erase(pid)
	owned[to].append(pid)
	oc.regions = owned[old].size()
	tc.regions = owned[to].size()
	_refresh_occf(old)
	_refresh_occf(to)
	_map_dirty = true
	if owned[old].is_empty():
		_kill(old, to)


func _kill(old: String, to: String) -> void:
	var oc: Dictionary = countries[old]
	oc.alive = false
	oc.merged_into = to
	oc.occupier = ""
	oc.annexing = false
	for al in oc.allies.duplicate():
		_break_alliance(old, al)
	for w in wars_of(old):
		w.sa.erase(old)
		w.sb.erase(old)
	for a in armies.values().duplicate():
		if a.o == old:
			if rng.randf() < 0.4:
				a.o = to
				a.sz = float(a.sz) * 0.85
				a.mo = 50.0
				a.path = []
				a.st = "idle"
			else:
				armies.erase(a.id)
	if not countries[to].nukes and oc.nukes:
		countries[to].nukes = true
		countries[to].nuke_ctrl = float(oc.occ_nuke)
	say(Lang.t("%s annexed %s.") % [cname(to), cname(old)])
	if old == player:
		exile = true
		exile_resistance = 0.0
		proposal.emit({"kind": "info", "text": Lang.t("Your country was annexed by %s. You continue as a government in exile - build resistance and keep your wealth working.") % cname(to)})


# ---------------------------------------------------------------- setup
func new_game(pid: String) -> void:
	rng.randomize()
	_quiet = true
	day = 0
	paused = true
	speed = 1.0
	player = pid
	countries = {}
	relations = {}
	nbrs = {}
	wars = []
	war_uid = 1
	holdings = {}
	basis = {}
	player_cash = 250000.0
	player_companies = []
	loans_taken = []
	loans_given = []
	bonds = 0.0
	has_bank = false
	contracts = []
	influence = 60.0
	intel = 20.0
	in_office = true
	exile = false
	exile_resistance = 0.0
	party = ""
	party_support = 0.0
	next_election = 1460
	opposition_until = 0
	pending_votes = []
	bases = []
	combat_log = []
	news_feed = []
	casualties = 0.0
	enemy_casualties = 0.0
	last_war_day = 0
	p_own = {}
	p_ctl = {}
	prov_op = {}
	battles = {}
	sel_armies = []
	recruit_q = []
	for i in World.countries.size():
		var m: Dictionary = World.countries[i]
		countries[m.id] = _make_country(i, m)
	_rebuild_owned()
	_make_fragile(countries[pid])
	_init_relations()
	Market.init()
	Military.spawn_all()
	Military.recompute_power()
	for i in 60:
		Market.daily()
	started = true
	_quiet = false
	say(Lang.t("Your nation is in crisis. Stabilise it, rebuild the army and grow. Press Play to start the world clock."))
	changed.emit()
	map_changed.emit()


func _make_country(idx: int, m: Dictionary) -> Dictionary:
	var id: String = m.id
	var gdp: float = maxf(float(m.gdp), 0.4)
	var pop: float = maxf(float(m.pop), 0.01)
	var troops: float = float(Tables.TROOPS.get(id, clampf(sqrt(pop) * 7.0 + gdp * 0.04, 3.0, 300.0)))
	var gdppc: float = gdp / pop
	var gov := "Republic"
	if id in Tables.ONE_PARTY:
		gov = "One-party State"
	elif id in Tables.MONARCHIES:
		gov = "Monarchy"
	elif id in Tables.CONST_MON:
		gov = "Constitutional Monarchy"
	elif id == "IRN":
		gov = "Islamic Republic"
	elif id in ["USA", "BRA", "MEX", "IND", "DEU", "NGA", "ETH", "RUS"]:
		gov = "Federal Republic"
	var tl: int = clampi(int(gdppc / 14.0), 0, 3)
	var tech := {}
	for k in Tables.TECHS:
		tech[k] = clampi(tl + rng.randi_range(-1, 0), 0, 3)
	return {
		"id": id, "idx": idx, "name": m.n, "ar": m.ar, "x": float(m.cx), "y": float(m.cy), "cont": m.cont,
		"pop": pop, "gdp": gdp, "troops": troops, "base_troops": troops, "pw": 0.0,
		"aircraft": troops * 0.6 + gdp / 60.0, "naval": troops * 0.12 + gdp / 600.0,
		"nukes": id in Tables.NUKES, "nuke_ctrl": 100.0, "occ_nuke": 0.0,
		"regions": m.provs.size(), "gov": gov, "occf": 0.0,
		"stability": 58.0 + rng.randf() * 20.0, "approval": 52.0 + rng.randf() * 16.0,
		"treasury": gdp * 100.0, "tax": 0.22, "mil_share": 0.03, "mobilized": false,
		"morale": 74.0, "supply": 70.0, "war_support": 55.0,
		"liberties": 60.0, "order": 50.0, "mod_app": 0.0, "growth_mod": 0.0, "trade_mod": 0.0,
		"laws": {}, "alive": true, "occupier": "", "overlord": "", "merged_into": "",
		"annex_progress": 0.0, "annexing": false, "occ_stability": 45.0, "occ_decide": 0,
		"allies": [], "sanctioned_by": [], "tariffs": {}, "tech": tech, "research": {},
		"cabinet": {"president": name_for(id + "pres"), "foreign": name_for(id + "for"), "finance": name_for(id + "fin"),
			"defense": name_for(id + "def"), "interior": name_for(id + "int")},
	}


func _make_fragile(c: Dictionary) -> void:
	c.stability = 34.0
	c.approval = 38.0
	c.treasury = float(c.gdp) * 100.0 * 0.012
	c.growth_mod = -0.012
	c.supply = 55.0
	c.morale = 55.0
	c.war_support = 40.0
	c.liberties = 50.0
	c.order = 35.0
	c.mod_app = -6.0
	c.base_troops = float(c.base_troops) * 0.8
	c.troops = float(c.base_troops)
	for k in c.tech:
		c.tech[k] = maxi(0, int(c.tech[k]) - 1)
	loans_taken.append({"principal": 120000.0, "remaining": 127800.0, "days_left": 300, "daily": 426.0, "rate": 6.5})
	player_cash += 100000.0


func _build_nbrs() -> void:
	nbrs = {}
	for pid in World.provs.size():
		var ca: String = World.countries[World.provs[pid].c].id
		for n in World.provs[pid].nb:
			var cb: String = World.countries[World.provs[n].c].id
			if ca != cb:
				if not nbrs.has(ca):
					nbrs[ca] = []
				if not (cb in nbrs[ca]):
					nbrs[ca].append(cb)


func _init_relations() -> void:
	var ids: Array = countries.keys()
	_build_nbrs()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: String = ids[i]
			var b: String = ids[j]
			var r: float = rng.randf_range(-30.0, 34.0) - _dist(a, b) / 40.0
			if countries[a].cont == countries[b].cont:
				r += 5.0
			if b in nbrs.get(a, []):
				r += rng.randf_range(-18.0, 8.0)
			set_rel(a, b, r)
	for i in Tables.NATO.size():
		for j in range(i + 1, Tables.NATO.size()):
			if countries.has(Tables.NATO[i]) and countries.has(Tables.NATO[j]):
				_make_alliance(Tables.NATO[i], Tables.NATO[j])
	for p in Tables.ALLIANCES:
		if countries.has(p[0]) and countries.has(p[1]):
			_make_alliance(p[0], p[1])
	for p in Tables.RIVALS:
		if countries.has(p[0]) and countries.has(p[1]):
			set_rel(p[0], p[1], float(p[2]))


# ---------------------------------------------------------------- daily loop
func advance_day() -> void:
	day += 1
	Market.daily()
	_update_countries()
	_update_wars()
	Military.daily()
	_update_occupations()
	_update_player_finance()
	_update_votes()
	if day % 5 == 0:
		_ai_peace()
	if day % 10 == 0:
		_ai_diplomacy()
	if day % 15 == 0:
		_random_event()
	if day >= next_election and (in_office and not exile):
		hold_election(false)
	if _map_dirty:
		_map_dirty = false
		map_changed.emit()
	day_passed.emit()
	if day % 7 == 0:
		changed.emit()


func _approval_target(c: Dictionary) -> float:
	var wc := wars_of(c.id).size()
	var t: float = 62.0 + (0.22 - float(c.tax)) * 160.0 + float(c.mod_app)
	t -= wc * 4.0 * (1.3 - float(c.war_support) / 100.0)
	t -= 30.0 * float(c.occf)
	if float(c.treasury) < 0.0:
		t -= 8.0
	if c.mobilized:
		t -= 4.0
	if c.occupier != "":
		t -= 15.0
	t += (float(c.liberties) - 60.0) * 0.1
	return clampf(t, 5.0, 95.0)


func _update_countries() -> void:
	for id in countries:
		var c: Dictionary = countries[id]
		if not c.alive:
			continue
		var wc := wars_of(id).size()
		c.gdp = float(c.gdp) * (1.0 + growth(id) / 365.0)
		c.pop = float(c.pop) * (1.0 + 0.008 / 365.0)
		var gdpday: float = float(c.gdp) * 1000.0 / 365.0
		var income: float = gdpday * float(c.tax) * 0.8 * (1.0 - float(c.occf))
		var spend: float = gdpday * (0.12 + float(c.mil_share) + (0.04 if c.mobilized else 0.0) + 0.02 * wc)
		if id == player:
			spend += 1.5 * base_count(id)
		if c.occupier != "":
			income *= 0.5
		if c.overlord != "" and countries.has(c.overlord) and countries[c.overlord].alive:
			var tribute := income * 0.1
			income -= tribute
			countries[c.overlord].treasury = float(countries[c.overlord].treasury) + tribute
		c.treasury = float(c.treasury) + income - spend
		c.approval = float(c.approval) + (_approval_target(c) - float(c.approval)) * 0.05
		var st_target: float = 22.0 + float(c.approval) * 0.55 + float(c.order) * 0.15 - wc * 3.0
		if c.occupier != "":
			st_target -= 20.0
		c.stability = clampf(float(c.stability) + (st_target - float(c.stability)) * 0.03 + rng.randfn(0.0, 0.15), 0.0, 100.0)
		if wc > 0:
			c.war_support = clampf(float(c.war_support) - 0.05 + (0.05 if float(c.occf) < 0.05 else -0.15), 5.0, 95.0)
		else:
			c.war_support = float(c.war_support) + (55.0 - float(c.war_support)) * 0.02
		if c.nukes and float(c.nuke_ctrl) < 100.0 and c.occupier == "":
			c.nuke_ctrl = minf(100.0, float(c.nuke_ctrl) + 0.6)
		if id != player and rng.randf() < 0.002 and c.sanctioned_by.size() > 0:
			c.sanctioned_by.pop_back()


func _update_votes() -> void:
	for v in pending_votes.duplicate():
		v.days = int(v.days) - 1
		if int(v.days) <= 0:
			pending_votes.erase(v)
			var yes := float(v.yes_final)
			if yes > 100.0:
				_enact(v.id, countries[player])
				say(Lang.t("Parliament passed the %s (%d/200).") % [Lang.t(LAWS[v.id].name), int(yes)])
			else:
				say(Lang.t("Parliament rejected the %s (%d/200).") % [Lang.t(LAWS[v.id].name), int(yes)])
			changed.emit()


func _enact(id: String, c: Dictionary) -> void:
	c.laws[id] = true
	match id:
		"security_act":
			c.order = float(c.order) + 15.0
			c.liberties = float(c.liberties) - 5.0
		"economic_reform":
			c.growth_mod = float(c.growth_mod) + 0.015
			c.mod_app = float(c.mod_app) - 2.0
		"conscription":
			c.base_troops = float(c.base_troops) * 1.2
			for a in armies.values():
				if a.o == player and Tables.UTYPES[a.t].land:
					a.mx = float(a.mx) * 1.2
					a.sz = float(a.sz) * 1.2
			c.mod_app = float(c.mod_app) - 5.0
		"free_trade":
			c.trade_mod = float(c.trade_mod) + 0.03
			c.growth_mod = float(c.growth_mod) + 0.008
		"press_law":
			c.liberties = float(c.liberties) + 10.0
			c.stability = float(c.stability) - 2.0
		"war_powers":
			c.war_support = float(c.war_support) + 10.0
			c.liberties = float(c.liberties) - 6.0


func _random_event() -> void:
	match rng.randi_range(0, 9):
		0:
			assets.oil.shock = float(assets.oil.shock) + 0.03
			say(Lang.t("Oil prices surge after supply cut in Sector-7"))
		1:
			assets.wheat.shock = float(assets.wheat.shock) + 0.04
			say(Lang.t("Wheat futures rising due to drought in Eastern Province"))
		2:
			assets.gold.shock = float(assets.gold.shock) - 0.02
			say(Lang.t("Gold slides as investors rotate into equities"))
		3:
			mk_sent = clampf(mk_sent + 0.2, -1.0, 1.0)
			say(Lang.t("Global markets rally on strong growth data"))
		4:
			mk_sent = clampf(mk_sent - 0.25, -1.0, 1.0)
			say(Lang.t("Global markets slump on recession fears"))
		5:
			var ids := alive_ids()
			var id: String = ids[rng.randi() % ids.size()]
			if id != player:
				countries[id].stability = maxf(0.0, float(countries[id].stability) - 4.0)
				say(Lang.t("Mass protests shake %s") % cname(id))
		6:
			assets.BTC.flow = float(assets.BTC.flow) + 6e7
			say(Lang.t("Institutional money floods into Bitcoin"))
		7:
			assets.BTC.flow = float(assets.BTC.flow) - 6e7
			assets.ETH.flow = float(assets.ETH.flow) - 3e7
			say(Lang.t("A major exchange hack shakes the crypto market"))
		8:
			assets.iron.shock = float(assets.iron.shock) + 0.02
			say(Lang.t("Iron ore demand jumps as construction booms"))
		9:
			assets.lithium.shock = float(assets.lithium.shock) + 0.03
			say(Lang.t("Lithium prices jump on electric-vehicle demand"))


# ---------------------------------------------------------------- wars
func declare_war(a: String, b: String) -> String:
	if a == b or not countries[a].alive or not countries[b].alive:
		return Lang.t("Invalid target.")
	if at_war(a, b):
		return Lang.t("Already at war.")
	if is_ally(a, b):
		return Lang.t("Break the alliance first.")
	var w := {"uid": war_uid, "a": a, "b": b, "sa": [a], "sb": [b], "progress": 0.0, "start": day, "last_fight": day}
	war_uid += 1
	for al in countries[a].allies:
		if al != b and al != player and countries[al].alive and not (al in w.sb):
			w.sa.append(al)
	for al in countries[b].allies:
		if al != a and al != player and countries[al].alive and not (al in w.sa) and rel(al, b) > 20.0 and rng.randf() < 0.7:
			w.sb.append(al)
	wars.append(w)
	last_war_day = day
	add_rel(a, b, -60.0)
	for al in countries[b].allies:
		add_rel(a, al, -25.0)
	for id in countries:
		if id != a and id != b and not (id in countries[b].allies):
			add_rel(a, id, -3.0)
	say(Lang.t("WAR: %s declared war on %s!") % [cname(a), cname(b)])
	if a != player and b != player and not _quiet:
		if player in countries[b].allies and not _prop_pending:
			_prop_pending = true
			proposal.emit({"kind": "join_war", "uid": w.uid, "side": "b", "text": Lang.t("Your ally %s was attacked by %s. Join the war?") % [cname(b), cname(a)]})
		elif player in countries[a].allies and not _prop_pending:
			_prop_pending = true
			proposal.emit({"kind": "join_war", "uid": w.uid, "side": "a", "text": Lang.t("Your ally %s attacked %s. Join the war?") % [cname(a), cname(b)]})
	elif b == player:
		proposal.emit({"kind": "info", "text": Lang.t("%s has declared war on you! Mobilize and defend.") % cname(a)})
	changed.emit()
	return ""


func join_war(uid: int, side: String) -> String:
	_prop_pending = false
	var w := war_by_uid(uid)
	if w.is_empty():
		return Lang.t("That war has already ended.")
	if side == "a":
		w.sa.append(player)
	else:
		w.sb.append(player)
	say(Lang.t("You joined the war on the side of %s.") % cname(w.a if side == "a" else w.b))
	changed.emit()
	return ""


func decline_join() -> void:
	_prop_pending = false


func player_declare_war(target: String) -> String:
	if not can_govern():
		return gov_error()
	var c: Dictionary = countries[player]
	if float(c.war_support) < 25.0:
		return Lang.t("War support is too low (%d%%). The public refuses.") % int(c.war_support)
	var r := declare_war(player, target)
	if r == "":
		c.stability = float(c.stability) - 2.0
		c.war_support = float(c.war_support) - 5.0
	return r


func _capture_score(target: String, captors: Array) -> float:
	var tot := 0.0
	var cap := 0.0
	for pid in owned.get(target, []):
		var w: float = World.provs[pid].w
		tot += w
		if prov_ctl(pid) in captors:
			cap += w
	var s: float = cap / maxf(tot, 0.0001) * 100.0
	var cp: int = int(World.countries[countries[target].idx].cap)
	if prov_owner(cp) == target and prov_ctl(cp) in captors:
		s += 25.0
	return s


func _update_wars() -> void:
	var done: Array = []
	for w in wars.duplicate():
		if w.sa.is_empty() or w.sb.is_empty() or not countries[w.a].alive or not countries[w.b].alive:
			wars.erase(w)
			continue
		var pa := _capture_score(w.b, w.sa)
		var pb := _capture_score(w.a, w.sb)
		w.progress = clampf(pa - pb, -100.0, 100.0)
		for pid in battles:
			var ctl := prov_ctl(pid)
			if ctl in w.sa or ctl in w.sb:
				w.last_fight = day
		if float(w.progress) >= 100.0:
			done.append([w, "a"])
		elif float(w.progress) <= -100.0:
			done.append([w, "b"])
	for e in done:
		_end_war(e[0], e[1])


func _revert_ctl(w: Dictionary) -> void:
	var members: Array = w.sa + w.sb
	for pid in p_ctl.keys():
		if prov_owner(pid) in members and p_ctl[pid] in members:
			p_ctl.erase(pid)
	for id in members:
		_refresh_occf(id)
	_map_dirty = true


func _cede(w: Dictionary, winner_side: String) -> void:
	var win_main: String = w.a if winner_side == "a" else w.b
	var lose_main: String = w.b if winner_side == "a" else w.a
	var captors: Array = w.sa if winner_side == "a" else w.sb
	for pid in owned[lose_main].duplicate():
		if prov_ctl(pid) in captors and countries[lose_main].alive:
			if owned[lose_main].size() <= 1:
				break
			set_prov_owner(pid, win_main)
	_revert_ctl(w)


func _end_war(w: Dictionary, result: String) -> void:
	wars.erase(w)
	match result:
		"a":
			_occupy(w.a, w.b)
		"b":
			_occupy(w.b, w.a)
		_:
			_revert_ctl(w)
			add_rel(w.a, w.b, 15.0)
			say(Lang.t("Ceasefire: %s and %s stop fighting.") % [cname(w.a), cname(w.b)])
	if player_in(w) and result != "draw":
		var won: bool = (result == "a" and player in w.sa) or (result == "b" and player in w.sb)
		proposal.emit({"kind": "info", "text": Lang.t("The war between %s and %s has ended - %s.") % [cname(w.a), cname(w.b), Lang.t("VICTORY") if won else Lang.t("DEFEAT")]})
	changed.emit()


func _occupy(a: String, b: String) -> void:
	var tc: Dictionary = countries[b]
	tc.occupier = a
	tc.occ_stability = 45.0
	tc.occ_nuke = 0.0
	tc.annexing = false
	tc.annex_progress = 0.0
	tc.overlord = ""
	tc.occ_decide = day + rng.randi_range(8, 25)
	for pid in owned[b]:
		p_ctl[pid] = a
	_refresh_occf(b)
	_map_dirty = true
	set_rel(a, b, -80.0)
	say(Lang.t("%s now occupies %s.") % [cname(a), cname(b)])
	_break_alliance(b, a)
	if a == player:
		proposal.emit({"kind": "occupation", "id": b})
	elif b == player:
		proposal.emit({"kind": "info", "text": Lang.t("Your country has been occupied by %s! You can create a Government in Exile from the Politics screen.") % cname(a)})


func _ai_peace() -> void:
	for w in wars.duplicate():
		if player_in(w):
			continue
		var p: float = w.progress
		var days: int = day - int(w.start)
		if absf(p) >= 35.0 and rng.randf() < 0.25 and days > 20:
			_cede(w, "a" if p > 0.0 else "b")
			wars.erase(w)
			say(Lang.t("Peace treaty: %s and %s. Territory changed hands.") % [cname(w.a), cname(w.b)])
		elif day - int(w.last_fight) > 40 and days > 60 and rng.randf() < 0.3:
			_end_war(w, "draw")
		elif days > 400 and rng.randf() < 0.1:
			_end_war(w, "draw")


func negotiate(uid: int, kind: String) -> String:
	if not can_govern():
		return gov_error()
	var w := war_by_uid(uid)
	if w.is_empty():
		return Lang.t("That war has already ended.")
	var mine: String = "a" if player in w.sa else "b"
	var enemy: String = w.b if mine == "a" else w.a
	var prog: float = float(w.progress) if mine == "a" else -float(w.progress)
	var days: float = float(day - int(w.start))
	var chance := 0.0
	match kind:
		"white":
			chance = 0.35 + clampf(days / 200.0, 0.0, 0.3) - prog / 150.0
		"terms":
			if prog < 15.0:
				return Lang.t("You are not winning decisively enough to dictate terms.")
			chance = 0.2 + prog / 110.0
		"surrender":
			chance = 0.95
	if rng.randf() > chance:
		return Lang.t("%s rejected the proposal.") % cname(enemy)
	var ec: Dictionary = countries[enemy]
	var pc: Dictionary = countries[player]
	match kind:
		"white":
			_revert_ctl(w)
		"terms":
			_cede(w, mine)
			var reps: float = maxf(0.0, float(ec.treasury)) * 0.15
			ec.treasury = float(ec.treasury) - reps
			pc.treasury = float(pc.treasury) + reps
		"surrender":
			_cede(w, "b" if mine == "a" else "a")
			var reps2: float = maxf(0.0, float(pc.treasury)) * 0.2
			pc.treasury = float(pc.treasury) - reps2
			ec.treasury = float(ec.treasury) + reps2
			pc.stability = float(pc.stability) - 5.0
	wars.erase(w)
	add_rel(w.a, w.b, 10.0)
	say(Lang.t("Peace agreement signed between %s and %s.") % [cname(w.a), cname(w.b)])
	changed.emit()
	return Lang.t("Peace agreed.")


func toggle_mobilize() -> String:
	if not can_govern():
		return gov_error()
	var c: Dictionary = countries[player]
	if not c.mobilized:
		if float(c.treasury) < 300.0:
			return Lang.t("Mobilization costs 300M.")
		c.treasury = float(c.treasury) - 300.0
		c.mobilized = true
		c.war_support = float(c.war_support) + 5.0
		for a in armies.values():
			if a.o == player and Tables.UTYPES[a.t].land:
				a.mx = float(a.mx) * 1.3
				a.sz = float(a.sz) * 1.3
		say(Lang.t("Mobilization ordered."))
	else:
		c.mobilized = false
		for a in armies.values():
			if a.o == player and Tables.UTYPES[a.t].land:
				a.mx = float(a.mx) / 1.3
				a.sz = minf(float(a.sz), float(a.mx))
		say(Lang.t("Demobilization ordered."))
	changed.emit()
	return ""


func resupply() -> String:
	if not can_govern():
		return gov_error()
	var c: Dictionary = countries[player]
	if float(c.treasury) < 150.0:
		return Lang.t("Resupply costs 150M.")
	c.treasury = float(c.treasury) - 150.0
	for a in armies.values():
		if a.o == player:
			a.sp = minf(100.0, float(a.sp) + 25.0)
	changed.emit()
	return ""


func build_base(host: String, type: String) -> String:
	if not can_govern():
		return gov_error()
	var c: Dictionary = countries[player]
	var cost := 400.0
	if host != player:
		if not (is_ally(player, host) or rel(player, host) >= 40.0):
			return Lang.t("%s requires an alliance or relations of 40+ for a base agreement.") % cname(host)
		if countries[host].occupier != "":
			return Lang.t("Host country is under occupation.")
		cost = 650.0
	if float(c.treasury) < cost:
		return Lang.t("Not enough treasury (%s needed).") % fmt_m(cost)
	c.treasury = float(c.treasury) - cost
	bases.append({"owner": player, "host": host, "type": type, "day": day})
	if type == "hq":
		intel += 10.0
	elif type == "depot":
		for a in armies.values():
			if a.o == player:
				a.sp = minf(100.0, float(a.sp) + 10.0)
	if host != player:
		add_rel(player, host, 3.0)
	say(Lang.t("%s built in %s.") % [Lang.t(BASE_TYPES[type]), cname(host)])
	changed.emit()
	return ""


func usable_arsenals() -> Array:
	var out: Array = []
	var c: Dictionary = countries[player]
	if c.alive and c.nukes:
		out.append({"owner": player, "ctrl": float(c.nuke_ctrl), "name": cname(player)})
	for id in countries:
		var t: Dictionary = countries[id]
		if t.alive and t.nukes and t.occupier == player:
			out.append({"owner": id, "ctrl": float(t.occ_nuke), "name": cname(id) + " (" + Lang.t("captured") + ")"})
	return out


func nuclear_strike(target: String) -> String:
	if not can_govern():
		return gov_error()
	if not at_war(player, target):
		return Lang.t("You can only strike a country you are at war with.")
	var ok := false
	for a in usable_arsenals():
		if float(a.ctrl) >= 80.0:
			ok = true
	if not ok:
		return Lang.t("No arsenal under reliable operational control (80%+ needed).")
	var t: Dictionary = countries[target]
	t.gdp = float(t.gdp) * 0.65
	t.pop = float(t.pop) * 0.85
	t.stability = maxf(0.0, float(t.stability) - 30.0)
	for a in armies.values():
		if a.o == target:
			a.sz = float(a.sz) * 0.6
	var c: Dictionary = countries[player]
	c.stability = float(c.stability) - 15.0
	c.approval = float(c.approval) - 20.0
	mk_sent = clampf(mk_sent - 0.6, -1.0, 1.0)
	for id in countries:
		if id != player and countries[id].alive:
			add_rel(player, id, -50.0)
			if not (id in c.sanctioned_by):
				c.sanctioned_by.append(id)
	say(Lang.t("NUCLEAR STRIKE: %s used nuclear weapons against %s! The world condemns the attack.") % [cname(player), cname(target)])
	changed.emit()
	return ""


# ---------------------------------------------------------------- occupation
func _clear_ctl_country(id: String) -> void:
	for pid in owned.get(id, []):
		p_ctl.erase(pid)
	_refresh_occf(id)
	_map_dirty = true


func _update_occupations() -> void:
	for id in countries:
		var c: Dictionary = countries[id]
		if not c.alive or c.occupier == "":
			continue
		var occ: String = c.occupier
		if not countries[occ].alive:
			c.occupier = ""
			_clear_ctl_country(id)
			continue
		var oc: Dictionary = countries[occ]
		oc.treasury = float(oc.treasury) - float(c.gdp) * 1000.0 / 365.0 * 0.03
		c.occ_stability = clampf(float(c.occ_stability) + rng.randfn(0.0, 0.6) + (0.08 if c.annexing else -0.02) + (0.05 if float(oc.stability) > 60.0 else -0.1), 0.0, 100.0)
		if c.nukes and float(c.occ_stability) >= 35.0:
			c.occ_nuke = minf(100.0, float(c.occ_nuke) + 0.6)
		if float(c.occ_stability) < 8.0:
			c.occupier = ""
			c.annexing = false
			c.annex_progress = 0.0
			_clear_ctl_country(id)
			set_rel(id, occ, -50.0)
			say(Lang.t("Resistance fighters liberated %s from %s.") % [cname(id), cname(occ)])
			if id == player:
				exile = false
			continue
		if c.annexing:
			c.annex_progress = float(c.annex_progress) + 100.0 / (18.0 + float(c.regions) * 0.5) * (0.5 + float(c.occ_stability) / 100.0)
			if float(c.annex_progress) >= 100.0:
				_annex(occ, id)
				continue
		if occ != player and not c.annexing and c.overlord == "" and day >= int(c.occ_decide):
			var r := rng.randf()
			if r < 0.5:
				c.annexing = true
				say(Lang.t("%s begins annexing %s.") % [cname(occ), cname(id)])
			elif r < 0.75:
				_make_puppet(occ, id)
			else:
				_release(occ, id)
	if exile and countries.has(player):
		var pc: Dictionary = countries[player]
		if pc.alive and pc.occupier == "":
			exile = false
		else:
			exile_resistance += 0.12 + 0.01 * pc.allies.size()
			influence += 0.1
			if exile_resistance >= 100.0:
				_liberate_player()


func _liberate_player() -> void:
	var c: Dictionary = countries[player]
	if not c.alive:
		var owner: String = c.merged_into
		for pid in World.countries[c.idx].provs:
			if prov_owner(pid) == owner:
				set_prov_owner(pid, player)
		c.alive = true
	c.occupier = ""
	c.merged_into = ""
	c.annexing = false
	c.stability = 40.0
	_clear_ctl_country(player)
	exile = false
	exile_resistance = 0.0
	say(Lang.t("Your people rose up - %s is free again!") % cname(player))
	proposal.emit({"kind": "info", "text": Lang.t("LIBERATION! %s has been restored. Your government returns.") % cname(player)})


func _annex(a: String, b: String) -> void:
	var bc: Dictionary = countries[b]
	var ac: Dictionary = countries[a]
	ac.stability = float(ac.stability) - 5.0
	if bc.nukes and not ac.nukes:
		ac.nukes = true
		ac.nuke_ctrl = float(bc.occ_nuke)
	bc.occupier = ""
	for pid in owned[b].duplicate():
		set_prov_owner(pid, a)
	changed.emit()


func _make_puppet(a: String, b: String) -> void:
	var c: Dictionary = countries[b]
	c.occupier = ""
	c.overlord = a
	c.gov = "Puppet Government"
	c.annexing = false
	_clear_ctl_country(b)
	set_rel(a, b, 10.0)
	say(Lang.t("%s installed a puppet government in %s.") % [cname(a), cname(b)])


func _release(a: String, b: String) -> void:
	var c: Dictionary = countries[b]
	c.occupier = ""
	c.annexing = false
	c.annex_progress = 0.0
	_clear_ctl_country(b)
	set_rel(a, b, 20.0)
	say(Lang.t("%s withdrew from %s and recognised its independence.") % [cname(a), cname(b)])


func occupation_choice(id: String, choice: String) -> String:
	var c: Dictionary = countries[id]
	if c.occupier != player:
		return Lang.t("You do not occupy that country.")
	match choice:
		"annex":
			c.annexing = true
			say(Lang.t("Annexation of %s started.") % cname(id))
		"puppet":
			_make_puppet(player, id)
		"release":
			_release(player, id)
		"partition":
			var n: int = int(owned[id].size() * 0.4)
			var list: Array = owned[id].duplicate()
			var capv: Vector2 = World.pos(int(World.countries[countries[player].idx].cap))
			list.sort_custom(func(x, y): return World.pos(x).distance_to(capv) < World.pos(y).distance_to(capv))
			for i in mini(n, list.size() - 1):
				set_prov_owner(list[i], player)
			c.occupier = ""
			_clear_ctl_country(id)
			set_rel(player, id, -40.0)
			say(Lang.t("%s was partitioned. You took 40%% of its land.") % cname(id))
	changed.emit()
	return ""


# ---------------------------------------------------------------- politics
func set_tax(t: float) -> String:
	if not can_govern():
		return gov_error()
	countries[player].tax = clampf(t, 0.0, 0.4)
	changed.emit()
	return ""


func tax_preview(t: float) -> Dictionary:
	var c: Dictionary = countries[player]
	var gdpday: float = float(c.gdp) * 1000.0 / 365.0
	return {"revenue": gdpday * t * 0.8, "approval": -(t - 0.22) * 160.0}


func propose_law(id: String) -> String:
	if not can_govern():
		return gov_error()
	var c: Dictionary = countries[player]
	if c.laws.has(id):
		return Lang.t("Already enacted.")
	for v in pending_votes:
		if v.id == id:
			return Lang.t("Already being debated.")
	if influence < 10.0:
		return Lang.t("Proposing a law costs 10 influence.")
	influence -= 10.0
	var yes: float = 100.0 + (float(c.approval) - 50.0) * 0.8 + party_support * 0.6 + float(LAWS[id].bias) + rng.randf_range(-18.0, 18.0)
	pending_votes.append({"id": id, "yes_final": clampf(yes, 40.0, 170.0), "days": 3, "total": 3})
	say(Lang.t("Parliament begins debating the %s.") % Lang.t(LAWS[id].name))
	changed.emit()
	return ""


func hold_election(snap: bool) -> String:
	if snap:
		if not can_govern():
			return gov_error()
		if influence < 30.0:
			return Lang.t("A snap election costs 30 influence.")
		influence -= 30.0
	elif exile:
		return Lang.t("Exile governments cannot hold elections.")
	var c: Dictionary = countries[player]
	var score: float = float(c.approval) + party_support * 0.5 + rng.randf_range(-8.0, 8.0)
	if score >= 50.0:
		in_office = true
		c.approval = float(c.approval) + 4.0
		next_election = day + 1460
		say(Lang.t("You WON the election with %d%%.") % int(clampf(score, 40.0, 70.0)))
		proposal.emit({"kind": "info", "text": Lang.t("Election victory! Your mandate is renewed for four years.")})
	else:
		in_office = false
		opposition_until = day + 120
		next_election = day + 120
		say(Lang.t("You LOST the election. The state is run by the new government; you stay as opposition."))
		proposal.emit({"kind": "info", "text": Lang.t("Election defeat. You are now in opposition. Your wealth and companies are untouched - you can run again in 120 days.")})
	changed.emit()
	return ""


func run_again() -> String:
	if in_office:
		return Lang.t("You are already in office.")
	if day < opposition_until:
		return Lang.t("You can run again in %d days.") % (opposition_until - day)
	return hold_election(false)


func form_party(pname_: String) -> String:
	if not can_govern():
		return gov_error()
	if party != "":
		return Lang.t("You already lead the %s.") % party
	if influence < 25.0:
		return Lang.t("Forming a party costs 25 influence.")
	if pname_.strip_edges() == "":
		return Lang.t("Choose a name.")
	influence -= 25.0
	party = pname_.strip_edges()
	party_support = 10.0
	countries[player].approval = float(countries[player].approval) + 1.0
	say(Lang.t("You founded the %s.") % party)
	changed.emit()
	return ""


func create_exile() -> String:
	var c: Dictionary = countries[player]
	if c.alive and c.occupier == "":
		return Lang.t("Your country is free. A government in exile is only possible after occupation.")
	if exile:
		return Lang.t("Your government in exile already exists.")
	exile = true
	exile_resistance = 0.0
	say(Lang.t("You established a Government in Exile."))
	changed.emit()
	return ""


func merge_with(other: String, new_name: String) -> String:
	if not can_govern():
		return gov_error()
	if not is_ally(player, other) or rel(player, other) < 60.0:
		return Lang.t("Merging requires an alliance and relations of 60+.")
	if at_war(player, other) or not countries[other].alive or countries[other].occupier != "":
		return Lang.t("Merge not possible right now.")
	if influence < 50.0:
		return Lang.t("A national merger costs 50 influence.")
	influence -= 50.0
	var a: Dictionary = countries[player]
	var b: Dictionary = countries[other]
	var bname: String = cname(other)
	a.treasury = float(a.treasury) + float(b.treasury)
	a.base_troops = float(a.base_troops) + float(b.base_troops) * 0.85
	a.stability = float(a.stability) - 10.0
	if b.nukes and not a.nukes:
		a.nukes = true
		a.nuke_ctrl = 40.0
	for al in b.allies.duplicate():
		_break_alliance(other, al)
		if al != player and rel(player, al) > 30.0:
			_make_alliance(player, al)
	for ar in armies.values():
		if ar.o == other:
			ar.o = player
			ar.sz = float(ar.sz) * 0.85
			ar.path = []
			ar.st = "idle"
	if new_name.strip_edges() != "":
		a.name = new_name.strip_edges()
		a.ar = new_name.strip_edges()
	for pid in owned[other].duplicate():
		set_prov_owner(pid, player)
	say(Lang.t("%s and %s merged into %s.") % [cname(player), bname, cname(player)])
	changed.emit()
	return ""


# ---------------------------------------------------------------- diplomacy
func improve_relations(b: String) -> String:
	if not can_govern():
		return gov_error()
	if influence < 10.0:
		return Lang.t("Needs 10 influence.")
	influence -= 10.0
	add_rel(player, b, 8.0)
	changed.emit()
	return ""


func propose_alliance(b: String) -> String:
	if not can_govern():
		return gov_error()
	if is_ally(player, b):
		return Lang.t("Already allied.")
	if at_war(player, b):
		return Lang.t("You are at war with them.")
	if influence < 15.0:
		return Lang.t("Needs 15 influence.")
	influence -= 15.0
	var r := rel(player, b)
	if r >= 40.0 and rng.randf() < 0.5 + (r - 40.0) / 100.0:
		_make_alliance(player, b)
		say(Lang.t("%s joined your alliance.") % cname(b))
		changed.emit()
		return ""
	add_rel(player, b, -2.0)
	changed.emit()
	return Lang.t("%s declined the alliance (relations %d, 40+ recommended).") % [cname(b), int(r)]


func accept_alliance(from: String) -> void:
	_prop_pending = false
	_make_alliance(player, from)
	say(Lang.t("Alliance formed with %s.") % cname(from))
	changed.emit()


func decline_alliance() -> void:
	_prop_pending = false


func break_alliance(b: String) -> String:
	if not can_govern():
		return gov_error()
	_break_alliance(player, b)
	add_rel(player, b, -20.0)
	say(Lang.t("Alliance with %s ended.") % cname(b))
	changed.emit()
	return ""


func sanction(b: String) -> String:
	if not can_govern():
		return gov_error()
	var c: Dictionary = countries[b]
	if player in c.sanctioned_by:
		return Lang.t("Already sanctioned.")
	c.sanctioned_by.append(player)
	add_rel(player, b, -20.0)
	for ct in contracts.duplicate():
		if ct.partner == b:
			contracts.erase(ct)
	say(Lang.t("You imposed sanctions on %s.") % cname(b))
	changed.emit()
	return ""


func lift_sanction(b: String) -> String:
	if not can_govern():
		return gov_error()
	countries[b].sanctioned_by.erase(player)
	add_rel(player, b, 8.0)
	changed.emit()
	return ""


func sabotage(b: String) -> String:
	if not can_govern():
		return gov_error()
	if intel < 30.0:
		return Lang.t("Needs 30 intel.")
	intel -= 30.0
	var c: Dictionary = countries[b]
	if rng.randf() < 0.6:
		c.stability = maxf(0.0, float(c.stability) - 6.0)
		say(Lang.t("Covert operation weakened %s.") % cname(b))
		add_rel(player, b, -5.0)
	else:
		add_rel(player, b, -25.0)
		say(Lang.t("Your agents were caught in %s! Relations plunge.") % cname(b))
	changed.emit()
	return ""


func _ai_diplomacy() -> void:
	var ids := alive_ids()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: String = ids[i]
			var b: String = ids[j]
			var r := rel(a, b)
			r += (0.0 - r) * 0.01 + rng.randfn(0.0, 1.2)
			if is_ally(a, b):
				r = maxf(r, 45.0)
			if at_war(a, b):
				r = minf(r, -40.0)
			set_rel(a, b, r)
	if not _prop_pending and can_govern():
		for id in ids:
			if id != player and not is_ally(player, id) and not at_war(player, id) and rel(player, id) >= 35.0 and rng.randf() < 0.01:
				_prop_pending = true
				proposal.emit({"kind": "alliance", "from": id})
				break
	for i in 6:
		var a2: String = ids[rng.randi() % ids.size()]
		var b2: String = ids[rng.randi() % ids.size()]
		if a2 != b2 and a2 != player and b2 != player and rel(a2, b2) > 55.0 and not is_ally(a2, b2) and rng.randf() < 0.2:
			_make_alliance(a2, b2)
			say(Lang.t("%s and %s signed an alliance.") % [cname(a2), cname(b2)])
	if day > 45 and wars.size() < 4 and day - last_war_day > 25 and rng.randf() < 0.6:
		var a3: String = ids[rng.randi() % ids.size()]
		if a3 == player or countries[a3].occupier != "" or wars_of(a3).size() > 0 or float(countries[a3].pop) < 2.0:
			return
		var cands: Array = nbrs.get(a3, []).duplicate()
		for t in ids:
			if _dist(a3, t) < 25.0 and not (t in cands):
				cands.append(t)
		var best := ""
		var best_rel := -22.0
		for t in cands:
			if not countries[t].alive or t == a3 or is_ally(a3, t) or at_war(a3, t) or countries[t].occupier != "":
				continue
			var rr := rel(a3, t)
			var ok: bool = power(a3) > power(t) * 1.2 or (t == player and rr < -50.0 and power(a3) > power(t) * 0.8)
			if rr < best_rel and ok:
				best_rel = rr
				best = t
		if best != "":
			declare_war(a3, best)


# ---------------------------------------------------------------- personal economy
func company_value() -> float:
	var v := 0.0
	for pc in player_companies:
		v += int(pc.factories) * 36000.0
	return v


func total_debt() -> float:
	var d := 0.0
	for l in loans_taken:
		d += float(l.remaining)
	return d


func lent_value() -> float:
	var v := 0.0
	for l in loans_given:
		v += float(l.remaining)
	return v


func portfolio_value() -> float:
	return Market.portfolio_value()


func portfolio_basis() -> float:
	var v := 0.0
	for id in basis:
		v += float(basis[id])
	return v


func networth() -> float:
	return player_cash + portfolio_value() + bonds + lent_value() + company_value() - total_debt()


func max_borrow() -> float:
	return 100000.0 + maxf(0.0, networth() + total_debt()) * 0.5


func take_loan(amount: float) -> String:
	if total_debt() + amount * 1.065 > max_borrow():
		return Lang.t("Credit limit reached (%s Cr).") % commas(int(max_borrow()))
	var total := amount * 1.065
	loans_taken.append({"principal": amount, "remaining": total, "days_left": 360, "daily": total / 360.0, "rate": 6.5})
	player_cash += amount
	say(Lang.t("Loan of %s Cr taken at 6.5%%.") % commas(int(amount)))
	changed.emit()
	return ""


func repay_loan(idx: int) -> String:
	if idx < 0 or idx >= loans_taken.size():
		return Lang.t("Loan not found.")
	var l: Dictionary = loans_taken[idx]
	if player_cash < float(l.remaining):
		return Lang.t("You need %s Cr to repay in full.") % commas(int(l.remaining))
	player_cash -= float(l.remaining)
	loans_taken.remove_at(idx)
	changed.emit()
	return ""


func buy_bonds(amount: float) -> String:
	if amount > player_cash:
		return Lang.t("Not enough credits.")
	player_cash -= amount
	bonds += amount
	changed.emit()
	return ""


func sell_bonds(amount: float) -> String:
	if amount > bonds:
		return Lang.t("You hold only %s Cr of bonds.") % commas(int(bonds))
	bonds -= amount
	player_cash += amount
	changed.emit()
	return ""


func open_bank() -> String:
	if has_bank:
		return Lang.t("You already own a bank.")
	if player_cash < 200000.0:
		return Lang.t("Opening a bank costs 200,000 Cr.")
	player_cash -= 200000.0
	has_bank = true
	say(Lang.t("Your bank opened for business."))
	changed.emit()
	return ""


func lend_to_country(id: String, amount: float) -> String:
	if not has_bank:
		return Lang.t("Open a bank first.")
	if amount > player_cash:
		return Lang.t("Not enough credits.")
	var c: Dictionary = countries[id]
	if not c.alive:
		return Lang.t("That country no longer exists.")
	var r: float = 4.0 + (100.0 - float(c.stability)) / 10.0
	var total: float = amount * (1.0 + r / 100.0)
	player_cash -= amount
	loans_given.append({"to": id, "remaining": total, "daily": total / 360.0, "days_left": 360, "rate": r})
	add_rel(player, id, 2.0 + amount / 50000.0)
	say(Lang.t("Your bank lent %s Cr to %s at %.1f%%.") % [commas(int(amount)), cname(id), r])
	changed.emit()
	return ""


func found_company(cname_: String, sector: String, host: String) -> String:
	if player_cash < 50000.0:
		return Lang.t("Founding a company costs 50,000 Cr.")
	if cname_.strip_edges() == "":
		return Lang.t("Choose a company name.")
	if not countries[host].alive:
		return Lang.t("Host country does not exist.")
	player_cash -= 50000.0
	player_companies.append({"name": cname_.strip_edges(), "sector": sector, "country": host, "factories": 1})
	say(Lang.t("You founded %s (%s) in %s.") % [cname_.strip_edges(), Lang.t(sector), cname(host)])
	changed.emit()
	return ""


func build_factory(idx: int) -> String:
	if idx < 0 or idx >= player_companies.size():
		return Lang.t("Found a company first.")
	if player_cash < 40000.0:
		return Lang.t("A factory costs 40,000 Cr.")
	player_cash -= 40000.0
	player_companies[idx].factories = int(player_companies[idx].factories) + 1
	changed.emit()
	return ""


func company_income(pc: Dictionary) -> float:
	var s: Dictionary = SECTORS[pc.sector]
	var f := int(pc.factories)
	var inc: float = float(s.rate) * f
	var cm: String = s.comm
	if cm != "":
		var dev: float = float(assets[cm].price) / float(assets[cm].base) - 1.0
		inc *= 1.0 + (1.0 if s.prod else -1.0) * 0.6 * dev
	var host: Dictionary = countries[pc.country]
	if not host.alive:
		inc *= 0.2
	elif host.occupier != "" or float(host.occf) > 0.3:
		inc *= 0.4
	elif wars_of(pc.country).size() > 0:
		inc *= 0.8
	inc *= 0.7 + 0.3 * clampf(float(host.stability) / 70.0, 0.0, 1.3)
	return inc - 40.0 * f


func contract_profit(ct: Dictionary) -> float:
	var p: float = float(assets[ct.comm].price)
	var pc: Dictionary = countries[player]
	var margin: float = 0.06 + _dist(player, ct.partner) / 200.0 * 0.06 + float(pc.trade_mod)
	margin -= float(pc.tariffs.get(ct.partner, 0.0))
	margin -= float(countries[ct.partner].tariffs.get(player, 0.0))
	return float(ct.qty) * p * margin


func add_contract(comm: String, partner: String, qty: int, export_dir: bool) -> String:
	if player_cash < 5000.0:
		return Lang.t("Setting up a contract costs 5,000 Cr.")
	if not countries[partner].alive or at_war(player, partner) or player in countries[partner].sanctioned_by:
		return Lang.t("Cannot trade with that country (war, sanctions or collapse).")
	player_cash -= 5000.0
	contracts.append({"comm": comm, "partner": partner, "qty": qty, "export": export_dir})
	say(Lang.t("New %s contract with %s.") % [Lang.t(assets[comm].n), cname(partner)])
	changed.emit()
	return ""


func cancel_contract(idx: int) -> void:
	if idx >= 0 and idx < contracts.size():
		contracts.remove_at(idx)
		changed.emit()


func set_tariff(partner: String, t: float) -> String:
	if not can_govern():
		return gov_error()
	countries[player].tariffs[partner] = clampf(t, 0.0, 0.5)
	if t > 0.0:
		add_rel(player, partner, -t * 8.0)
	changed.emit()
	return ""


func _update_player_finance() -> void:
	for l in loans_taken.duplicate():
		var pay: float = minf(float(l.daily), float(l.remaining))
		if player_cash >= pay:
			player_cash -= pay
			l.remaining = float(l.remaining) - pay
		else:
			l.remaining = float(l.remaining) * 1.002
			influence = maxf(0.0, influence - 0.3)
		l.days_left = int(l.days_left) - 1
		if float(l.remaining) <= 0.5:
			loans_taken.erase(l)
			say(Lang.t("A loan was fully repaid."))
	player_cash += bonds * 0.042 / 365.0
	if has_bank:
		player_cash += 120.0
	for l in loans_given.duplicate():
		var c: Dictionary = countries[l.to]
		if not c.alive or (float(c.stability) < 30.0 and rng.randf() < 0.005):
			say(Lang.t("%s defaulted on your bank's loan!") % cname(l.to))
			loans_given.erase(l)
			continue
		var pay2: float = minf(float(l.daily), float(l.remaining))
		player_cash += pay2
		l.remaining = float(l.remaining) - pay2
		if float(l.remaining) <= 0.5:
			loans_given.erase(l)
	for pc in player_companies:
		player_cash += company_income(pc)
		if wars_of(pc.country).size() > 0 and int(pc.factories) > 1 and rng.randf() < 0.004:
			pc.factories = int(pc.factories) - 1
			say(Lang.t("A factory of %s was destroyed in the fighting in %s!") % [pc.name, cname(pc.country)])
	for ct in contracts.duplicate():
		var partner: Dictionary = countries[ct.partner]
		if not partner.alive or at_war(player, ct.partner) or player in partner.sanctioned_by or ct.partner in countries[player].sanctioned_by:
			contracts.erase(ct)
			say(Lang.t("Contract with %s was cancelled.") % cname(ct.partner))
			continue
		player_cash += contract_profit(ct)
	if day % 30 == 0:
		for id in holdings:
			if assets[id].k == "stock":
				player_cash += float(assets[id].price) * float(holdings[id]) * 0.003
	if influence < 300.0:
		influence += 0.25 + prestige(player) / 4000.0
	var hq := 0
	for b in bases:
		if b.owner == player and b.type == "hq":
			hq += 1
	intel = minf(300.0, intel + 0.1 + 0.05 * hq)


# ---------------------------------------------------------------- save / load
func save_game() -> bool:
	var d := {}
	for k in SAVE_KEYS:
		d[k] = get(k)
	d["armies"] = armies.values()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func _int_dict(src: Variant) -> Dictionary:
	var out := {}
	for k in src:
		out[int(k)] = src[k]
	return out


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return false
	day = int(d.day)
	player = str(d.player)
	countries = d.countries
	relations = d.relations
	wars = d.wars
	war_uid = int(d.war_uid)
	assets = d.assets
	mk_sent = float(d.mk_sent)
	index_hist = d.index_hist
	holdings = d.holdings
	basis = d.basis
	player_cash = float(d.player_cash)
	player_companies = d.player_companies
	loans_taken = d.loans_taken
	loans_given = d.loans_given
	bonds = float(d.bonds)
	has_bank = bool(d.has_bank)
	contracts = d.contracts
	influence = float(d.influence)
	intel = float(d.intel)
	in_office = bool(d.in_office)
	exile = bool(d.exile)
	exile_resistance = float(d.exile_resistance)
	party = str(d.party)
	party_support = float(d.party_support)
	next_election = int(d.next_election)
	opposition_until = int(d.opposition_until)
	pending_votes = d.pending_votes
	bases = d.bases
	combat_log = d.combat_log
	news_feed = d.news_feed
	layer = int(d.layer)
	casualties = float(d.casualties)
	enemy_casualties = float(d.enemy_casualties)
	last_war_day = int(d.last_war_day)
	army_uid = int(d.army_uid)
	recruit_q = d.recruit_q
	for r in recruit_q:
		r.ready = int(r.ready)
	p_own = _int_dict(d.p_own)
	p_ctl = _int_dict(d.p_ctl)
	prov_op = _int_dict(d.prov_op)
	armies = {}
	for a in d.armies:
		a.id = int(a.id)
		a.p = int(a.p)
		a.n = int(a.n)
		a.train = int(a.train)
		a.cd = int(a.cd)
		a.cd2 = int(a.cd2)
		a.tac_d = int(a.tac_d)
		var path: Array = []
		for x in a.path:
			path.append(int(x))
		a.path = path
		armies[a.id] = a
	for w in wars:
		w.uid = int(w.uid)
		w.start = int(w.start)
		w.last_fight = int(w.last_fight)
	_build_nbrs()
	_rebuild_owned()
	battles = {}
	sel_armies = []
	started = true
	paused = true
	_prop_pending = false
	changed.emit()
	map_changed.emit()
	return true
