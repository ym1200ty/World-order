class_name Military
extends RefCounted

static var G
static var W
static var L
## Armies, movement, battles, occupation, tactics, recruiting, training and research.
## Everything runs on real provinces: armies move province-to-province, fight where they meet,
## and a province changes hands only after an army holds it uninterrupted.

const LAND_MIX := [["inf", 0.50, 1.2], ["mech", 0.15, 1.0], ["arm", 0.13, 0.8], ["art", 0.09, 0.6], ["sf", 0.03, 0.3]]
const AIR_RANGE := 12.0
const SEA_RANGE := 9.0
const MSL_RANGE := 20.0


static func uname(a: Dictionary) -> String:
	return "%s %d" % [L.t(Tables.UTYPES[a.t].name), int(a.n)]


static func tech_key(t: String) -> String:
	match t:
		"inf", "sf", "art":
			return "inf"
		"mech", "arm":
			return "arm"
	return t


static func tech_level(o: String, t: String) -> int:
	return int(G.countries[o].tech.get(tech_key(t), 0))


static func new_army(o: String, t: String, sz: float, sk: float, p: int) -> Dictionary:
	G.army_uid += 1
	var cnt := 1
	for a in G.armies.values():
		if a.o == o and a.t == t:
			cnt += 1
	var a := {"id": G.army_uid, "o": o, "n": cnt, "t": t, "sz": sz, "mx": sz, "sk": sk, "mo": 78.0, "sp": 85.0, "p": p, "path": [], "prog": 0.0,
		"st": "idle", "stance": "bal", "xp": 0.0, "gen": G.name_for(o + str(G.army_uid)), "train": 0, "tac": "", "tac_d": 0, "cd": 0, "cd2": 0, "eng": false}
	G.armies[a.id] = a
	return a


static func spawn_all() -> void:
	G.armies = {}
	G.army_uid = 0
	for id in G.countries:
		spawn_country(id)


static func spawn_country(id: String) -> void:
	var c: Dictionary = G.countries[id]
	var owned: Array = G.owned.get(id, [])
	if owned.is_empty():
		return
	var rng: RandomNumberGenerator = G.rng
	var troops: float = c.base_troops
	var gdppc: float = float(c.gdp) / maxf(float(c.pop), 0.1)
	var base_sk: float = 1.4 + clampf(gdppc / 22.0, 0.0, 2.6)
	var n_land: int = clampi(roundi(troops / 20.0), 2, 40)
	var capp: int = int(W.countries[c.idx].cap)
	for i in n_land:
		var r := rng.randf()
		var acc := 0.0
		var pick: Array = LAND_MIX[0]
		for m in LAND_MIX:
			acc += float(m[1])
			if r <= acc:
				pick = m
				break
		var sz: float = troops / n_land * float(pick[2])
		var p: int = capp if i % 6 == 0 else int(owned[rng.randi() % owned.size()])
		new_army(id, pick[0], maxf(2.0, sz), clampf(base_sk + rng.randf_range(-0.4, 0.4), 1.0, 4.6), p)
	var n_air: int = clampi(roundi(float(c.aircraft) / 110.0), 0, 12)
	for i in n_air:
		new_army(id, "air", 8.0, clampf(base_sk + rng.randf_range(-0.3, 0.3), 1.0, 4.8), int(owned[rng.randi() % owned.size()]))
	var coastal: Array = []
	for p in owned:
		if int(W.provs[p].coast) == 1:
			coastal.append(p)
	if not coastal.is_empty():
		for i in clampi(roundi(float(c.naval) / 30.0), 0, 8):
			new_army(id, "navy", 6.0, clampf(base_sk, 1.0, 4.6), int(coastal[rng.randi() % coastal.size()]))
	var nm: int = clampi(roundi(float(c.gdp) / 2500.0), 0, 3) + (2 if c.nukes else 0)
	for i in nm:
		new_army(id, "msl", 3.0, clampf(base_sk, 1.0, 4.6), capp)


# ------------------------------------------------------------------ power
static func tactic_mult(a: Dictionary, atk: bool) -> float:
	var m := 1.0
	if int(a.tac_d) > 0:
		match a.tac:
			"flank":
				m = 1.35 if atk else 1.0
			"entrench":
				m = 0.7 if atk else 1.35
			"barrage":
				m = 1.4 if atk else 1.0
			"airsup":
				m = 1.3
			"blitz":
				m = 1.5 if atk else 1.0
	if a.stance == "aggr":
		m *= 1.15 if atk else 0.9
	elif a.stance == "def":
		m *= 0.85 if atk else 1.15
	return m


static func power_of(a: Dictionary, atk: bool) -> float:
	var t: Dictionary = Tables.UTYPES[a.t]
	if not t.land:
		return 0.0
	var base: float = float(a.sz) * (float(t.atk) if atk else float(t.def))
	var sk: float = 0.6 + 0.2 * float(a.sk)
	var mo: float = 0.6 + 0.4 * float(a.mo) / 100.0
	var sp: float = 0.5 + 0.5 * float(a.sp) / 100.0
	var tech: float = 1.0 + 0.07 * tech_level(a.o, a.t)
	return base * sk * mo * sp * tech * tactic_mult(a, atk)


static func recompute_power() -> void:
	var pw := {}
	for a in G.armies.values():
		var t: Dictionary = Tables.UTYPES[a.t]
		var v: float
		if t.land:
			v = power_of(a, true)
		else:
			var mult: float = 3.0 if a.t == "air" else (3.0 if a.t == "navy" else 4.0)
			v = float(a.sz) * mult * (0.6 + 0.2 * float(a.sk)) * (1.0 + 0.07 * tech_level(a.o, a.t))
		pw[a.o] = float(pw.get(a.o, 0.0)) + v
	for id in G.countries:
		var c: Dictionary = G.countries[id]
		c.pw = float(pw.get(id, 0.0))
		c.troops = 0.0
	for a in G.armies.values():
		if Tables.UTYPES[a.t].land:
			G.countries[a.o].troops = float(G.countries[a.o].troops) + float(a.sz)


static func armies_of(o: String) -> Array:
	var out: Array = []
	for a in G.armies.values():
		if a.o == o:
			out.append(a)
	return out


# ------------------------------------------------------------------ pathing
static func can_enter(o: String, pid: int) -> bool:
	## Armies may cross any territory; crossing neutral land costs relations and supply.
	return G.countries[G.prov_ctl(pid)].alive


static func friendly_or_enemy(o: String, ctl: String) -> bool:
	return ctl == o or G.is_ally(o, ctl) or G.at_war(o, ctl) or G.countries[ctl].overlord == o or G.countries[o].overlord == ctl or G.rel(o, ctl) >= 60.0


static func find_path(o: String, from: int, to: int) -> Array:
	var astar: AStar2D = W.astar
	var off: Array = []
	for i in W.provs.size():
		if i != from and i != to and not can_enter(o, i):
			astar.set_point_disabled(i, true)
			off.append(i)
	var path: Array = []
	if can_enter(o, to):
		path = Array(astar.get_id_path(from, to))
	for i in off:
		astar.set_point_disabled(i, false)
	if path.size() > 0:
		path.pop_front()
	return path


static func step_days(a: Dictionary, from: int, to: int) -> float:
	var d: float = W.pos(from).distance_to(W.pos(to))
	var spd: float = float(Tables.UTYPES[a.t].spd)
	if W.is_sea(from, to):
		d *= 3.0
	return maxf(0.6, d / spd)


static func eta(a: Dictionary) -> float:
	var t := 0.0
	var cur: int = a.p
	for pid in a.path:
		t += step_days(a, cur, pid)
		cur = pid
	return t - float(a.prog) * 1.0


static func order_move(ids: Array, dest: int) -> String:
	var ok := 0
	for id in ids:
		if not G.armies.has(id):
			continue
		var a: Dictionary = G.armies[id]
		if a.o != G.player or int(a.train) > 0:
			continue
		if not Tables.UTYPES[a.t].land:
			# air/navy/missile: relocate to a friendly province (base)
			if G.prov_ctl(dest) == a.o or G.is_ally(a.o, G.prov_ctl(dest)):
				if W.pos(a.p).distance_to(W.pos(dest)) <= (AIR_RANGE * 2.0 if a.t == "air" else 30.0):
					a.p = dest
					ok += 1
			continue
		var path := find_path(a.o, a.p, dest)
		if path.is_empty() and a.p != dest:
			continue
		a.path = path
		a.prog = 0.0
		a.st = "move" if not path.is_empty() else "idle"
		a.eng = false
		ok += 1
	if ok == 0:
		return L.t("No route: the destination is blocked (foreign territory) or unreachable.")
	G.changed.emit()
	return ""


# ------------------------------------------------------------------ player commands
static func set_stance(ids: Array, s: String) -> void:
	for id in ids:
		if G.armies.has(id) and G.armies[id].o == G.player:
			G.armies[id].stance = s
	G.changed.emit()


static func stop(ids: Array) -> void:
	for id in ids:
		if G.armies.has(id):
			G.armies[id].path = []
			G.armies[id].st = "idle"
	G.changed.emit()


static func retreat(id: int) -> String:
	var a: Dictionary = G.armies[id]
	var best := -1
	for n in W.provs[a.p].nb:
		var ctl: String = G.prov_ctl(n)
		if (ctl == a.o or G.is_ally(a.o, ctl)) and not _enemy_in(n, a.o):
			best = n
			break
	if best < 0:
		return L.t("No safe province to retreat to.")
	a.p = best
	a.path = []
	a.st = "idle"
	a.sz = float(a.sz) * 0.95
	a.mo = float(a.mo) - 8.0
	a.eng = false
	G.changed.emit()
	return ""


static func _enemy_in(pid: int, o: String) -> bool:
	for a in G.armies.values():
		if a.p == pid and G.at_war(a.o, o):
			return true
	return false


static func split(id: int) -> String:
	var a: Dictionary = G.armies[id]
	if float(a.sz) < 4.0:
		return L.t("Army too small to split.")
	var h: float = float(a.sz) / 2.0
	a.sz = h
	a.mx = float(a.mx) / 2.0
	var b := new_army(a.o, a.t, h, a.sk, a.p)
	b.mo = a.mo
	b.sp = a.sp
	G.changed.emit()
	return ""


static func merge(ids: Array) -> String:
	if ids.size() < 2:
		return L.t("Select 2+ armies of the same type in the same province.")
	var first: Dictionary = G.armies[ids[0]]
	var tot: float = 0.0
	var mx: float = 0.0
	var sk: float = 0.0
	for id in ids:
		var a: Dictionary = G.armies[id]
		if a.t != first.t or a.p != first.p or a.o != first.o:
			return L.t("Select 2+ armies of the same type in the same province.")
		tot += float(a.sz)
		mx += float(a.mx)
		sk += float(a.sk) * float(a.sz)
	first.sk = sk / maxf(tot, 0.1)
	first.sz = tot
	first.mx = mx
	for i in range(1, ids.size()):
		G.armies.erase(ids[i])
	G.sel_armies = [first.id]
	G.changed.emit()
	return ""


static func disband(id: int) -> void:
	G.armies.erase(id)
	G.sel_armies.erase(id)
	G.changed.emit()


static func recruit(t: String) -> String:
	if not G.can_govern():
		return G.gov_error()
	var c: Dictionary = G.countries[G.player]
	var u: Dictionary = Tables.UTYPES[t]
	var cost: float = float(u.sz) * float(u.cost) * 12.0
	if float(c.treasury) < cost:
		return L.t("Not enough treasury (%s needed).") % G.fmt_m(cost)
	var pend := 0.0
	for r in G.recruit_q:
		if r.o == G.player:
			pend += float(r.sz)
	if float(c.troops) + pend + float(u.sz) > float(c.pop) * 12.0:
		return L.t("Manpower exhausted.")
	c.treasury = float(c.treasury) - cost
	G.recruit_q.append({"o": G.player, "t": t, "sz": float(u.sz), "ready": G.day + 10})
	G.say(L.t("Recruiting a new %s (ready in 10 days).") % L.t(u.name))
	G.changed.emit()
	return ""


static func train(id: int) -> String:
	if not G.can_govern():
		return G.gov_error()
	var a: Dictionary = G.armies[id]
	var c: Dictionary = G.countries[G.player]
	if float(a.sk) >= 5.0:
		return L.t("Already elite.")
	if G.prov_ctl(a.p) != a.o:
		return L.t("Training needs the army in your own territory.")
	var cost: float = float(a.sz) * float(Tables.UTYPES[a.t].cost) * 4.0
	if float(c.treasury) < cost:
		return L.t("Not enough treasury (%s needed).") % G.fmt_m(cost)
	c.treasury = float(c.treasury) - cost
	a.train = 12
	a.st = "train"
	a.path = []
	G.changed.emit()
	return ""


static func research(t: String) -> String:
	if not G.can_govern():
		return G.gov_error()
	var c: Dictionary = G.countries[G.player]
	if c.research.has("t"):
		return L.t("Research already in progress.")
	var lvl: int = int(c.tech.get(t, 0))
	if lvl >= 5:
		return L.t("Maximum level.")
	var cost: float = (lvl + 1) * (300.0 + float(c.gdp) * 0.05)
	if float(c.treasury) < cost:
		return L.t("Not enough treasury (%s needed).") % G.fmt_m(cost)
	c.treasury = float(c.treasury) - cost
	c.research = {"t": t, "d": 25 * (lvl + 1)}
	G.say(L.t("Research started: %s.") % L.t(Tables.TECHS[t]))
	G.changed.emit()
	return ""


static func use_tactic(id: int, key: String) -> String:
	var a: Dictionary = G.armies[id]
	var tdef: Dictionary = Tables.TACTICS[key]
	if int(a.cd) > 0:
		return L.t("Tactics on cooldown (%d days).") % int(a.cd)
	if float(a.sp) < float(tdef.sup) + 5.0:
		return L.t("Not enough supply.")
	var here: Array = []
	for b in G.armies.values():
		if b.p == a.p and b.o == a.o:
			here.append(b)
	match key:
		"flank":
			var ok: bool = here.size() >= 2 or a.t in ["arm", "mech", "sf"]
			if not ok:
				return L.t("Needs 2+ armies in the province or an armored army.")
		"barrage":
			var ok2 := false
			for b in here:
				if b.t == "art":
					ok2 = true
			if not ok2:
				return L.t("Needs an artillery army here.")
		"airsup":
			var ok3 := false
			for b in G.armies.values():
				if b.o == a.o and b.t == "air" and W.pos(b.p).distance_to(W.pos(a.p)) <= AIR_RANGE and float(b.sp) > 15.0:
					b.sp = float(b.sp) - 8.0
					ok3 = true
					break
			if not ok3:
				return L.t("No air wing in range.")
		"blitz":
			if not (a.t in ["arm", "mech"]):
				return L.t("Only armor or mechanized armies can blitz.")
			a.mo = float(a.mo) - 5.0
	a.tac = key
	a.tac_d = int(tdef.dur)
	a.cd = int(tdef.cd)
	a.sp = float(a.sp) - float(tdef.sup)
	G.clog(L.t("%s used %s.") % [uname(a), L.t(tdef.name)])
	G.changed.emit()
	return ""


static func strike(id: int, pid: int) -> String:
	var a: Dictionary = G.armies[id]
	if int(a.cd2) > 0:
		return L.t("Not ready (%d days).") % int(a.cd2)
	var d: float = W.pos(a.p).distance_to(W.pos(pid))
	var rng: float = AIR_RANGE
	var k := 0.05
	if a.t == "navy":
		rng = SEA_RANGE
		k = 0.04
		if int(W.provs[pid].coast) == 0:
			return L.t("Fleets can only hit coastal provinces.")
	elif a.t == "msl":
		rng = MSL_RANGE
		k = 0.12
	if d > rng * (1.0 + 0.05 * tech_level(a.o, a.t)):
		return L.t("Target is out of range.")
	if float(a.sp) < 20.0:
		return L.t("Not enough supply.")
	_apply_strike(a, pid, k)
	G.changed.emit()
	return ""


static func _apply_strike(a: Dictionary, pid: int, k: float) -> int:
	var hit := 0
	var rng: RandomNumberGenerator = G.rng
	for b in G.armies.values():
		if b.p == pid and G.at_war(a.o, b.o) and Tables.UTYPES[b.t].land:
			var dmg: float = float(a.sz) * k * (0.6 + 0.2 * float(a.sk)) * (1.0 + 0.07 * tech_level(a.o, a.t)) * rng.randf_range(0.7, 1.3) * 3.0
			b.sz = maxf(0.5, float(b.sz) - dmg)
			b.mo = float(b.mo) - 4.0
			b.sp = float(b.sp) - 5.0
			hit += 1
			if b.o == G.player:
				G.casualties += dmg * 1000.0
			elif a.o == G.player:
				G.enemy_casualties += dmg * 1000.0
	a.cd2 = 5 if a.t == "msl" else 2
	a.sp = float(a.sp) - (10.0 if a.t != "msl" else 0.0)
	if a.t == "msl":
		a.sz = maxf(0.5, float(a.sz) - 0.5)
		var owner: String = G.prov_owner(pid)
		if G.countries.has(owner):
			G.countries[owner].gdp = float(G.countries[owner].gdp) * 0.9985
	elif a.t == "air" and rng.randf() < 0.3:
		a.sz = maxf(1.0, float(a.sz) - 0.2)
	if a.o == G.player or G.prov_owner(pid) == G.player:
		G.clog(L.t("%s struck %s (%d armies hit).") % [uname(a), G.pname(pid), hit])
	return hit


# ------------------------------------------------------------------ daily simulation
static func daily() -> void:
	var rng: RandomNumberGenerator = G.rng
	# recruit queue
	for r in G.recruit_q.duplicate():
		if G.day >= int(r.ready):
			G.recruit_q.erase(r)
			var owned: Array = G.owned.get(r.o, [])
			if owned.is_empty():
				continue
			var c: Dictionary = G.countries[r.o]
			var gdppc: float = float(c.gdp) / maxf(float(c.pop), 0.1)
			var p: int = int(W.countries[c.idx].cap) if G.prov_owner(int(W.countries[c.idx].cap)) == r.o else int(owned[0])
			var a := new_army(r.o, r.t, r.sz, clampf(1.2 + gdppc / 30.0, 1.0, 3.0), p)
			if r.o == G.player:
				G.say(L.t("New army ready: %s.") % uname(a))
	# movement
	for a in G.armies.values():
		if int(a.train) > 0:
			a.train = int(a.train) - 1
			if int(a.train) == 0:
				a.sk = minf(5.0, float(a.sk) + 0.5)
				a.st = "idle"
				if a.o == G.player:
					G.say(L.t("%s finished training (skill %.1f).") % [uname(a), float(a.sk)])
			continue
		if int(a.cd) > 0:
			a.cd = int(a.cd) - 1
		if int(a.cd2) > 0:
			a.cd2 = int(a.cd2) - 1
		if int(a.tac_d) > 0:
			a.tac_d = int(a.tac_d) - 1
		if a.path.is_empty() or a.eng:
			continue
		var nxt: int = int(a.path[0])
		if not can_enter(a.o, nxt):
			a.path = []
			a.st = "idle"
			continue
		a.prog = float(a.prog) + 1.0 / step_days(a, a.p, nxt)
		if float(a.prog) >= 1.0:
			a.prog = 0.0
			a.p = nxt
			var ctl2: String = G.prov_ctl(nxt)
			if not friendly_or_enemy(a.o, ctl2):
				G.add_rel(a.o, ctl2, -2.0)
				a.sp = maxf(0.0, float(a.sp) - 4.0)
			a.path.pop_front()
			if a.path.is_empty():
				a.st = "idle"
	# group by province (only armies of countries that are at war can fight / occupy)
	var warset := {}
	for w in G.wars:
		for m in w.sa:
			warset[m] = true
		for m in w.sb:
			warset[m] = true
	var by_prov := {}
	for a in G.armies.values():
		if warset.has(a.o):
			if not by_prov.has(a.p):
				by_prov[a.p] = []
			by_prov[a.p].append(a)
	if warset.is_empty():
		G.prov_op.clear()
	var old_battles: Dictionary = G.battles
	G.battles = {}
	var dead: Array = []
	for pid in by_prov:
		var list: Array = by_prov[pid]
		if list.size() < 2:
			for a in list:
				a.eng = false
			_occupation(pid, list)
			continue
		var land: Array = []
		for a in list:
			if Tables.UTYPES[a.t].land:
				land.append(a)
			else:
				a.eng = false
		var fought := _battle(pid, land, dead, rng)
		if fought:
			var sides := {}
			for a in land:
				sides[a.o] = float(sides.get(a.o, 0.0)) + float(a.sz)
			G.battles[pid] = {"sides": sides}
			if not old_battles.has(pid):
				var involves := false
				for a in land:
					if a.o == G.player:
						involves = true
				if involves:
					G.clog(L.t("Battle began in %s.") % G.pname(pid))
					G.battle_alert.emit(pid)
		else:
			for a in land:
				a.eng = false
		_occupation(pid, list)
	for id in dead:
		G.armies.erase(id)
		G.sel_armies.erase(id)
	# supply, morale, reinforcement, upkeep
	var slow: bool = G.day % 5 != 0
	for a in G.armies.values():
		if int(a.train) > 0:
			continue
		if slow and not warset.has(a.o):
			continue
		var ctl: String = G.prov_ctl(a.p)
		var friendly: bool = ctl == a.o or G.is_ally(a.o, ctl)
		var c: Dictionary = G.countries[a.o]
		if friendly:
			a.sp = minf(100.0, float(a.sp) + 3.0)
			if not a.eng:
				a.mo = minf(100.0, float(a.mo) + 0.8)
				if float(a.sz) < float(a.mx) and float(c.treasury) > 0.0:
					a.sz = minf(float(a.mx), float(a.sz) + float(a.mx) * 0.008)
		else:
			a.sp = maxf(0.0, float(a.sp) - 1.2)
		if float(a.sp) < 20.0:
			a.sz = maxf(0.5, float(a.sz) * 0.996)
			a.mo = maxf(0.0, float(a.mo) - 0.5)
	# research
	for id in G.countries:
		var c: Dictionary = G.countries[id]
		if not c.alive:
			continue
		if c.research.has("t"):
			c.research.d = int(c.research.d) - 1
			if int(c.research.d) <= 0:
				c.tech[c.research.t] = int(c.tech.get(c.research.t, 0)) + 1
				if id == G.player:
					G.say(L.t("Research complete: %s level %d.") % [L.t(Tables.TECHS[c.research.t]), int(c.tech[c.research.t])])
				c.research = {}
		elif id != G.player and rng.randf() < 0.002 and float(c.treasury) > float(c.gdp) * 50.0:
			var keys: Array = Tables.TECHS.keys()
			var t: String = keys[rng.randi() % keys.size()]
			if int(c.tech.get(t, 0)) < 4:
				c.research = {"t": t, "d": 40 * (int(c.tech.get(t, 0)) + 1)}
	if G.day % 2 == 0:
		_ai(by_prov)
	if G.day % 5 == 0:
		recompute_power()


static func _def_mult(a: Dictionary, pid: int) -> float:
	var ctl: String = G.prov_ctl(pid)
	if a.o == ctl or G.is_ally(a.o, ctl):
		return float(W.terrain(pid)[1]) * (1.0 + 0.15 * W.fort(pid))
	return 1.0


static func _battle(pid: int, land: Array, dead: Array, rng: RandomNumberGenerator) -> bool:
	var fought := false
	var atk := {}
	var dfn := {}
	for a in land:
		atk[a.id] = power_of(a, true)
		dfn[a.id] = power_of(a, false) * _def_mult(a, pid)
	var loss := {}
	var ratio := {}
	for x in land:
		var e_atk := 0.0
		for e in land:
			if G.at_war(x.o, e.o):
				e_atk += float(atk[e.id])
		if e_atk <= 0.0:
			x.eng = false
			continue
		fought = true
		x.eng = true
		var r: float = e_atk / maxf(float(dfn[x.id]), 1.0)
		ratio[x.id] = r
		loss[x.id] = float(x.sz) * clampf(0.035 * r, 0.002, 0.12) * rng.randf_range(0.85, 1.15)
	for x in land:
		if not loss.has(x.id):
			continue
		var l: float = loss[x.id]
		x.sz = maxf(0.0, float(x.sz) - l)
		var r2: float = ratio[x.id]
		if r2 > 1.3:
			x.mo = float(x.mo) - 2.5
		elif r2 < 0.7:
			x.mo = minf(100.0, float(x.mo) + 1.0)
		else:
			x.mo = float(x.mo) - 0.5
		x.sk = minf(5.0, float(x.sk) + 0.004 * clampf(r2, 0.3, 2.0))
		x.sp = maxf(0.0, float(x.sp) - 2.0)
		if x.o == G.player:
			G.casualties += l * 1000.0
		else:
			for y in land:
				if y.o == G.player and G.at_war(y.o, x.o):
					G.enemy_casualties += l * 1000.0 / maxf(1.0, land.size())
					break
		if float(x.sz) < 2.0:
			dead.append(x.id)
			if x.o == G.player:
				G.say(L.t("%s was destroyed in %s!") % [uname(x), G.pname(pid)])
		elif float(x.mo) < 15.0:
			var best := -1
			for n in W.provs[pid].nb:
				var ctl: String = G.prov_ctl(n)
				if (ctl == x.o or G.is_ally(x.o, ctl)) and not _enemy_in(n, x.o):
					best = n
					break
			if best >= 0:
				x.p = best
				x.path = []
				x.st = "idle"
				x.eng = false
				x.mo = 30.0
				x.sz = float(x.sz) * 0.93
				if x.o == G.player:
					G.say(L.t("%s routed from %s!") % [uname(x), G.pname(pid)])
			else:
				x.sz = float(x.sz) * 0.8
	return fought


static func _occupation(pid: int, list: Array) -> void:
	var ctl: String = G.prov_ctl(pid)
	var friendly := false
	var best: Dictionary = {}
	for a in list:
		if not Tables.UTYPES[a.t].land or int(a.train) > 0:
			continue
		if a.o == ctl or G.is_ally(a.o, ctl):
			friendly = true
		elif G.at_war(a.o, ctl):
			if best.is_empty() or float(a.sz) > float(best.sz):
				best = a
	if friendly or best.is_empty():
		if G.prov_op.has(pid):
			G.prov_op.erase(pid)
		return
	var rate: float = maxf(8.0, 28.0 - 5.0 * W.fort(pid) - 2.0 * (float(W.terrain(pid)[1]) - 1.0) * 10.0)
	var op: float = float(G.prov_op.get(pid, 0.0)) + rate
	if op >= 100.0:
		G.prov_op.erase(pid)
		G.set_ctl(pid, best.o)
	else:
		G.prov_op[pid] = op


# ------------------------------------------------------------------ AI
static func _ai(by_prov: Dictionary) -> void:
	var budget := 60
	var rng: RandomNumberGenerator = G.rng
	var enemy_cache := {}
	for a in G.armies.values():
		if a.o == G.player or int(a.train) > 0:
			continue
		var ws: Array = G.wars_of(a.o)
		if ws.is_empty():
			continue
		var t: Dictionary = Tables.UTYPES[a.t]
		if not t.land:
			if int(a.cd2) == 0 and rng.randf() < 0.25 and float(a.sp) > 25.0:
				_ai_strike(a, by_prov)
			continue
		if a.st != "idle" or a.eng or budget <= 0:
			continue
		budget -= 1
		var tgt := _find_target(a, by_prov)
		if tgt.size() > 0:
			a.path = tgt
			a.st = "move"
			a.prog = 0.0


static func _ai_strike(a: Dictionary, by_prov: Dictionary) -> void:
	var rng: float = AIR_RANGE if a.t == "air" else (SEA_RANGE if a.t == "navy" else MSL_RANGE)
	var best := -1
	var bestv := 0.0
	for pid in by_prov:
		var v := 0.0
		for b in by_prov[pid]:
			if G.at_war(a.o, b.o) and Tables.UTYPES[b.t].land:
				v += float(b.sz)
		if v > bestv and W.pos(a.p).distance_to(W.pos(pid)) <= rng:
			if a.t != "navy" or int(W.provs[pid].coast) == 1:
				bestv = v
				best = pid
	if best >= 0:
		_apply_strike(a, best, 0.05 if a.t == "air" else (0.04 if a.t == "navy" else 0.12))


static func _find_target(a: Dictionary, by_prov: Dictionary) -> Array:
	var o: String = a.o
	var start: int = a.p
	var parent := {}
	parent[start] = -1
	var queue: Array = [start]
	var depth := {}
	depth[start] = 0
	var qi := 0
	var found := -1
	var my_pow: float = power_of(a, true)
	while qi < queue.size() and found < 0:
		var cur: int = queue[qi]
		qi += 1
		var d: int = depth[cur]
		if d > 0:
			var ctl: String = G.prov_ctl(cur)
			var enemy_ctl: bool = G.at_war(o, ctl)
			var enemy_pow := 0.0
			if by_prov.has(cur):
				for b in by_prov[cur]:
					if G.at_war(o, b.o) and Tables.UTYPES[b.t].land:
						enemy_pow += power_of(b, false)
			if (enemy_ctl or (enemy_pow > 0.0 and (ctl == o or G.is_ally(o, ctl)))) and enemy_pow < my_pow * 1.4:
				found = cur
				break
		if d >= 7:
			continue
		var nbs: Array = W.provs[cur].nb + W.provs[cur].sea
		for n in nbs:
			if parent.has(n) or not can_enter(o, n):
				continue
			parent[n] = cur
			depth[n] = d + 1
			queue.append(n)
	if found < 0:
		return []
	var path: Array = []
	var c := found
	while c != start:
		path.push_front(c)
		c = parent[c]
	return path
