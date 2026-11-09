#!/usr/bin/env python3
"""Builds data/ for WORLD ORDER from Natural Earth (public domain).
Usage: python3 tools/build_world.py <dir with the 3 ne_10m_*.geojson files>
Needs: pip install shapely mapbox_earcut numpy"""
import json, sys, math, os
import numpy as np, shapely
from shapely.geometry import shape, Point, Polygon, MultiPolygon
from shapely.strtree import STRtree
import mapbox_earcut as earcut

SRC = sys.argv[1] if len(sys.argv) > 1 else "."
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data")
TOL = 0.045      # simplification tolerance in degrees
Q = 100.0        # quantisation (0.01 deg)

a0 = json.load(open(f"{SRC}/ne_10m_admin_0_countries.geojson"))["features"]
a1 = json.load(open(f"{SRC}/ne_10m_admin_1_states_provinces.geojson"))["features"]
pp = json.load(open(f"{SRC}/ne_10m_populated_places_simple.geojson"))["features"]

# ---- countries (group dependencies under their sovereign, keyed by SOVEREIGNT name)
SOVT = ("Sovereign country", "Country", "Sovereignty")
by_sov = {}
for f in a0:
    p = f["properties"]
    if p["ADM0_A3"] == "ATA":
        continue
    by_sov.setdefault(p["SOVEREIGNT"], []).append(p)
sov = {}
adm_to_sov = {}
for name, ps in by_sov.items():
    mains = [p for p in ps if p["TYPE"] in SOVT and (p["NAME_EN"] == name or p["NAME"] == name)] or [p for p in ps if p["TYPE"] in SOVT] or ps
    m = max(mains, key=lambda p: p["POP_EST"] or 0)
    cid = m["ADM0_A3"]
    sov[cid] = {"id": cid, "name": m["NAME_EN"] or m["NAME"], "ar": m["NAME_AR"] or m["NAME_EN"], "cont": m["CONTINENT"], "sub": m["SUBREGION"],
                "pop": sum(max(0, p["POP_EST"] or 0) for p in ps), "gdp": sum(max(0, p["GDP_MD"] or 0) for p in ps),
                "main": any(p["TYPE"] in SOVT for p in ps)}
    for p in ps:
        adm_to_sov[p["ADM0_A3"]] = cid
keep = {k for k, g in sov.items() if g["main"] and g["pop"] > 1000}
for k, g in sov.items():
    if g["pop"] > 800000:
        keep.add(k)
print("countries", len(keep))

# ---- provinces
raw = []   # (country, name, ar, geom)
have = set()
for f in a1:
    p = f["properties"]
    c = adm_to_sov.get(p["adm0_a3"])
    if c not in keep or f["geometry"] is None:
        continue
    g = shapely.make_valid(shape(f["geometry"]))
    raw.append([c, p["name"] or p["name_en"] or "?", p.get("name_ar") or p["name"], g])
    have.add(c)
for f in a0:
    p = f["properties"]
    c = adm_to_sov.get(p["ADM0_A3"])
    if c in keep and c not in have and p["ADM0_A3"] != "ATA":
        raw.append([c, p["NAME_EN"], p["NAME_AR"] or p["NAME_EN"], shapely.make_valid(shape(f["geometry"]))])
print("provinces raw", len(raw))

def polys(g):
    if g.geom_type == "Polygon":
        return [g]
    if g.geom_type in ("MultiPolygon", "GeometryCollection"):
        out = []
        for x in g.geoms:
            out += polys(x)
        return out
    return []

# drop tiny island parts
geoms = []
for r in raw:
    ps = polys(r[3])
    ps.sort(key=lambda x: -x.area)
    big = [x for x in ps if x.area > 0.02] or ps[:1]
    geoms.append(MultiPolygon(big))
print("simplifying...")
try:
    simp = list(shapely.coverage_simplify(np.array(geoms, dtype=object), TOL))
except Exception as e:
    print("coverage_simplify failed:", e)
    simp = [g.simplify(TOL, preserve_topology=True) for g in geoms]
simp = [shapely.set_precision(shapely.make_valid(g), 1.0 / Q) for g in simp]
for i, g in enumerate(simp):
    if g.is_empty or g.area < 1e-9:
        simp[i] = shapely.set_precision(shapely.make_valid(geoms[i].simplify(TOL * 0.5, preserve_topology=True)), 1.0 / Q)
        if simp[i].is_empty:
            simp[i] = geoms[i]

# ---- build arrays
prov = []
verts = []        # list of (x,y) int
tris = []
vcount = 0
tcount = 0
by_country = {}
for i, (r, g) in enumerate(zip(raw, simp)):
    ps = [x for x in polys(g) if not x.is_empty and x.area > 0.0003]
    if not ps:
        ps = polys(geoms[i])[:1]
    v0, t0 = vcount, tcount
    rings = []
    for poly in ps:
        rs = [poly.exterior] + list(poly.interiors)
        arr = []
        ends = []
        pvstart = vcount
        for k, ring in enumerate(rs):
            c = np.array(ring.coords)[:-1]
            if len(c) < 3:
                continue
            rings.append([vcount, len(c), 1 if k else 0])
            arr.append(c)
            vcount += len(c)
            ends.append(vcount - pvstart)
        if not arr or not (len(arr[0]) >= 3):
            continue
        allc = np.concatenate(arr)
        tri = earcut.triangulate_float64(allc, np.array(ends, dtype=np.uint32))
        tri = np.array(tri, dtype=np.int64) + pvstart
        tris.append(tri)
        tcount += len(tri)
        verts.append(np.round(allc * Q).astype(np.int32))
    p = Polygon() if not ps else g
    c = shapely.centroid(g) if not g.is_empty else Point(0, 0)
    rp = shapely.point_on_surface(g) if not g.is_empty else Point(0, 0)
    mid = rp.y
    prov.append({"n": r[1], "ar": r[2], "c": r[0], "cx": round(rp.x, 2), "cy": round(rp.y, 2),
                 "area": g.area * math.cos(math.radians(mid)), "v0": v0, "vn": vcount - v0, "t0": t0, "tn": tcount - t0,
                 "rings": rings, "bb": [round(x, 2) for x in g.bounds], "nb": [], "coast": 1})
    by_country.setdefault(r[0], []).append(i)

# ---- adjacency + coast
print("adjacency...")
tree = STRtree(simp)
share = [0.0] * len(simp)
for i, g in enumerate(simp):
    for j in tree.query(g):
        j = int(j)
        if j <= i:
            continue
        try:
            L = g.boundary.intersection(simp[j].boundary).length
        except Exception:
            L = 0
        if L > 0.004:
            prov[i]["nb"].append(j)
            prov[j]["nb"].append(i)
            share[i] += L
            share[j] += L
for i, g in enumerate(simp):
    per = g.boundary.length
    prov[i]["coast"] = 1 if per - share[i] > 0.08 else 0

# ---- land components + sea links (amphibious / airlift routes between landmasses)
print("sea links...")
comp = [-1] * len(prov)
nc = 0
for i in range(len(prov)):
    if comp[i] >= 0:
        continue
    stack = [i]
    comp[i] = nc
    while stack:
        k = stack.pop()
        for j in prov[k]["nb"]:
            if comp[j] < 0:
                comp[j] = nc
                stack.append(j)
    nc += 1
coastal = [i for i in range(len(prov)) if prov[i]["coast"]]
cx = np.array([prov[i]["cx"] for i in coastal])
cy = np.array([prov[i]["cy"] for i in coastal])
cc = np.array([comp[i] for i in coastal])
for p_ in prov:
    p_["sea"] = []
for a_, i in enumerate(coastal):
    d = np.hypot((cx - cx[a_]) * math.cos(math.radians(cy[a_])), cy - cy[a_])
    d[cc == cc[a_]] = 999
    order = np.argsort(d)[:3]
    for o in order:
        if d[o] < 12.0:
            j = coastal[int(o)]
            if j not in prov[i]["sea"]:
                prov[i]["sea"].append(j)
            if i not in prov[j]["sea"]:
                prov[j]["sea"].append(i)

# ---- country outlines
print("outlines...")
crings = []
cidx = {}
countries = []
for k in sorted(keep):
    ids = by_country.get(k, [])
    if not ids:
        continue
    u = shapely.unary_union([simp[i] for i in ids])
    u = shapely.set_precision(u, 1.0 / Q)
    rings = []
    for poly in polys(u):
        for ring in [poly.exterior] + list(poly.interiors):
            c = np.round(np.array(ring.coords) * Q).astype(np.int32)
            rings.append([sum(len(x) for x in crings), len(c)])
            crings.append(c)
    tot = sum(prov[i]["area"] for i in ids) or 1.0
    for i in ids:
        prov[i]["w"] = round(prov[i]["area"] / tot, 5)
    rp = max(ids, key=lambda i: prov[i]["area"])
    g = sov[k]
    cidx[k] = len(countries)
    countries.append({"id": k, "n": g["name"], "ar": g["ar"], "pop": round(g["pop"] / 1e6, 3), "gdp": round(g["gdp"] / 1000.0, 2),
                      "cont": g["cont"], "sub": g["sub"], "provs": ids, "rings": rings, "cx": prov[rp]["cx"], "cy": prov[rp]["cy"],
                      "cap": rp})
for i, p in enumerate(prov):
    p["c"] = cidx[p["c"]]
    p.pop("area", None)

# ---- cities & capitals
print("cities...")
cities = []
capprov = {}
for f in pp:
    p = f["properties"]
    c = adm_to_sov.get(p["adm0_a3"])
    if c not in cidx:
        continue
    x, y = f["geometry"]["coordinates"]
    pop = p.get("pop_max") or 0
    cap = 1 if (p.get("adm0cap") or 0) == 1 else 0
    if pop < 350000 and not cap:
        continue
    pt = Point(x, y)
    pid = None
    for j in tree.query(pt):
        if simp[int(j)].contains(pt):
            pid = int(j)
            break
    if cap and pid is not None and prov[pid]["c"] == cidx[c]:
        if c not in capprov or pop > capprov[c][1]:
            capprov[c] = (pid, pop, x, y, p["name"])
    cities.append([round(x, 2), round(y, 2), int(pop), cidx[c], cap, p["name"], -1 if pid is None else pid])
for c in countries:
    if c["id"] in capprov:
        c["cap"] = capprov[c["id"][0:3]][0]
        c["capxy"] = [round(capprov[c["id"]][2], 2), round(capprov[c["id"]][3], 2)]
        c["capname"] = capprov[c["id"]][4]
cities.sort(key=lambda r: -r[2])
cities = cities[:2600]

os.makedirs(OUT, exist_ok=True)
V = np.concatenate(verts).astype("<i4") if verts else np.zeros(0, "<i4")
T = np.concatenate(tris).astype("<i4")
C = np.concatenate(crings).astype("<i4")
V.tofile(f"{OUT}/verts.bin")
T.tofile(f"{OUT}/tris.bin")
C.tofile(f"{OUT}/crings.bin")
json.dump({"countries": countries, "provs": prov, "cities": cities}, open(f"{OUT}/world.json", "w"), ensure_ascii=False, separators=(",", ":"))
print("verts", len(V) // 2, "tris", len(T) // 3, "provs", len(prov), "countries", len(countries), "cities", len(cities))
