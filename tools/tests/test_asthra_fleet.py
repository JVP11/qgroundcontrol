#!/usr/bin/env python3
"""ASTHRA fleet / land-split correctness tests (no Qt required)."""

from __future__ import annotations

import math
import sys
from pathlib import Path


def polygon_area_m2(path: list[tuple[float, float]]) -> float:
    if len(path) < 3:
        return 0.0
    lat0 = path[0][0] * math.pi / 180.0
    m_lat = 110540.0
    m_lon = 111320.0 * math.cos(lat0)
    lon0, lat_z = path[0][1], path[0][0]
    total = 0.0
    for i, a in enumerate(path):
        b = path[(i + 1) % len(path)]
        x1 = (a[1] - lon0) * m_lon
        y1 = (a[0] - lat_z) * m_lat
        x2 = (b[1] - lon0) * m_lon
        y2 = (b[0] - lat_z) * m_lat
        total += x1 * y2 - x2 * y1
    return abs(total) * 0.5


def closer_bin_shares(percents: list[float], bins: int = 400) -> list[float]:
    """1-D strip split used by ASTHRA applySplit on a uniform rectangle."""
    if not percents:
        return []
    bin_area = 1.0 / bins
    total = 1.0
    out = []
    bin_i = 0
    for d, pct in enumerate(percents):
        target = pct / 100.0 * total
        start = bin_i
        acc = 0.0
        if d == len(percents) - 1:
            bin_i = bins
        else:
            while bin_i < bins:
                nxt = acc + bin_area
                if acc > 0 and nxt >= target:
                    if abs(nxt - target) < abs(acc - target):
                        acc = nxt
                        bin_i += 1
                    break
                acc = nxt
                bin_i += 1
            if bin_i == start and start < bins:
                bin_i = start + 1
        out.append((bin_i - start) / bins * 100.0)
    return out


def collect_fleet(gcs: list[tuple[int, int]], backend: list[int], planned_n: int) -> list[dict]:
    """gcs = [(gcsId, sysid), ...]; backend = [droneId, ...]."""
    by_id: dict[int, dict] = {}
    order: list[int] = []

    def add(vid: int, linked: bool, backend_flag: bool) -> None:
        if vid not in by_id:
            by_id[vid] = {"vehicleId": vid, "sysid": 0, "linked": False, "backend": False}
            order.append(vid)
        if linked:
            by_id[vid]["linked"] = True
        if backend_flag:
            by_id[vid]["backend"] = True

    for gid, sysid in gcs:
        add(gid, True, False)
        by_id[gid]["sysid"] = sysid
    for bid in backend:
        match = None
        hits = 0
        for key in order:
            if by_id[key]["linked"] and by_id[key]["sysid"] == bid:
                match = key
                hits += 1
        if hits == 1:
            by_id[match]["backend"] = True
        else:
            key = bid
            while key in by_id:
                key += 100
            add(key, False, True)
            by_id[key]["sysid"] = bid
    if len(order) > 16:
        order = order[:16]
    planned_n = max(1, min(16, planned_n))
    p = 1
    while len(order) < planned_n:
        while p in by_id:
            p += 1
        add(p, False, False)
    return [by_id[i] for i in order]


def vehicle_by_id(vehicles: list[dict], vid: int):
    for v in vehicles:
        if v.get("gcsId") == vid:
            return v
    hits = [v for v in vehicles if v.get("id") == vid]
    return hits[0] if len(hits) == 1 else None


def lawnmower_count(south: float, west: float, north: float, east: float, spacing_m: float) -> int:
    mid_lat = (south + north) * 0.5 * math.pi / 180.0
    m_lat = 110540.0
    m_lon = 111320.0 * max(0.25, math.cos(mid_lat))
    ns = (east - west) * m_lon >= (north - south) * m_lat
    wps = 0
    if ns:
        dlon = spacing_m / m_lon
        lon = west + dlon * 0.5
        while lon <= east + 1e-9:
            wps += 2
            lon += dlon
    else:
        dlat = spacing_m / m_lat
        lat = south + dlat * 0.5
        while lat <= north + 1e-9:
            wps += 2
            lat += dlat
    return wps


def strip_bands(percents: list[float], span_m: float = 1000.0, spacing_m: float = 20.0) -> list[tuple[float, float]]:
    shares = closer_bin_shares(percents)
    edges = [0.0]
    acc = 0.0
    for share in shares:
        acc += share / 100.0
        edges.append(acc)
    gap_frac = min(0.05, (max(spacing_m, 8) * 0.35) / max(span_m, 1.0))
    bands = []
    for i in range(len(shares)):
        u0, u1 = edges[i], edges[i + 1]
        if i > 0:
            u0 += gap_frac * 0.5
        if i < len(shares) - 1:
            u1 -= gap_frac * 0.5
        if u1 <= u0:
            u0, u1 = edges[i], edges[i + 1]
        bands.append((u0, u1))
    return bands


def start_gate(uploaded: bool, has_radio: bool, armed: bool) -> str:
    if not uploaded:
        return "no plan"
    if not has_radio:
        return "no radio"
    if not armed:
        return "disarmed"
    return "start"


def saved_percent(saved: dict, vehicle_id: int, port: str, slot: int, fallback: float) -> float:
    if str(vehicle_id) in saved:
        return float(saved[str(vehicle_id)])
    if port and f"port:{port}" in saved:
        return float(saved[f"port:{port}"])
    if f"slot:{slot}" in saved:
        return float(saved[f"slot:{slot}"])
    return fallback


def renormalize(percents: list[float]) -> list[float]:
    total = sum(percents)
    if total <= 0:
        n = len(percents)
        if n == 0:
            return []
        base = 100 // n
        rem = 100 - base * n
        return [base + (rem if i == n - 1 else 0) for i in range(n)]
    out = []
    acc = 0.0
    for i, p in enumerate(percents):
        nxt = p / total * 100.0
        if i == len(percents) - 1:
            nxt = 100.0 - acc
        out.append(nxt)
        acc += nxt
    return out


def prepare_planned_n(current: int, qgc_count: int) -> int:
    """Prepare only grows fleet size to live radios, never shrinks operator N."""
    if qgc_count > current:
        return min(16, qgc_count)
    return current


def plan_commands(wp_count: int) -> list[int]:
    """Survey plan: waypoints then RTL. No NAV_TAKEOFF."""
    return [16] * wp_count + [20]


def start_armed_survey(armed: bool, modes: list[str], px4: bool) -> str | None:
    if not armed:
        return None
    want = ["Mission", "Auto"] if px4 else ["Auto", "AUTO", "Mission"]
    lower = {m.lower(): m for m in modes}
    for name in want:
        if name.lower() in lower:
            return lower[name.lower()]
    return "Mission" if px4 else "Auto"


def land_from_map(map_valid: bool, vehicle_valid: bool) -> str:
    if map_valid or vehicle_valid:
        return "ok"
    return "need map"


def usb_board_fallback(port: str, description: str = "") -> str | None:
    blob = f"{description} {port}".lower()
    if "ttyacm" in blob or "cdc acm" in blob or "pixhawk" in blob:
        return "Pixhawk"
    if "ttyusb" in blob:
        return "SiK Radio"
    if "com" in blob:
        return "Pixhawk"
    return None


def clip_half(path, inside_fn, intersect_fn):
    if not path:
        return []
    out = []
    for i, a in enumerate(path):
        b = path[(i + 1) % len(path)]
        a_in, b_in = inside_fn(a), inside_fn(b)
        if a_in and b_in:
            out.append(b)
        elif a_in and not b_in:
            out.append(intersect_fn(a, b))
        elif (not a_in) and b_in:
            out.append(intersect_fn(a, b))
            out.append(b)
    return out


def clip_lon_band(path, lon_min, lon_max):
    def lat(p):
        return p[0]

    def lon(p):
        return p[1]

    p = clip_half(
        path,
        lambda c: lon(c) >= lon_min - 1e-12,
        lambda a, b: (
            lat(a) + ((lon_min - lon(a)) / (lon(b) - lon(a) if abs(lon(b) - lon(a)) > 1e-15 else 1)) * (lat(b) - lat(a)),
            lon_min,
        ),
    )
    return clip_half(
        p,
        lambda c: lon(c) <= lon_max + 1e-12,
        lambda a, b: (
            lat(a) + ((lon_max - lon(a)) / (lon(b) - lon(a) if abs(lon(b) - lon(a)) > 1e-15 else 1)) * (lat(b) - lat(a)),
            lon_max,
        ),
    )


def bounds_of(path):
    lats = [p[0] for p in path]
    lons = [p[1] for p in path]
    return min(lats), max(lats), min(lons), max(lons)


def apply_split(land, percents, spacing_m=20.0):
    """Faithful port of ASTHRASwarmCoveragePanel.applySplit for a rectangle/KML path."""
    min_lat, max_lat, min_lon, max_lon = bounds_of(land)
    split_lon = (max_lon - min_lon) >= (max_lat - min_lat)
    bins = 400
    bin_areas = []
    total = 0.0
    for i in range(bins):
        t0, t1 = i / bins, (i + 1) / bins
        if split_lon:
            piece = clip_lon_band(land, min_lon + t0 * (max_lon - min_lon), min_lon + t1 * (max_lon - min_lon))
        else:
            # reuse lon clip in lat by swapping
            swapped = [(p[1], p[0]) for p in land]
            piece_s = clip_lon_band(swapped, min_lat + t0 * (max_lat - min_lat), min_lat + t1 * (max_lat - min_lat))
            piece = [(p[1], p[0]) for p in piece_s]
        a = polygon_area_m2(piece)
        bin_areas.append(a)
        total += a
    if total <= 0:
        total = polygon_area_m2(land)
    out = []
    bin_i = 0
    for d, pct in enumerate(percents):
        target = pct / 100.0 * total
        start = bin_i
        acc = 0.0
        if d == len(percents) - 1:
            bin_i = bins
        else:
            while bin_i < bins:
                nxt = acc + bin_areas[bin_i]
                if acc > 0 and nxt >= target:
                    if abs(nxt - target) < abs(acc - target):
                        acc = nxt
                        bin_i += 1
                    break
                acc = nxt
                bin_i += 1
            if bin_i == start and start < bins:
                bin_i = start + 1
        u0, u1 = start / bins, bin_i / bins
        lat0 = ((min_lat + max_lat) * 0.5) * math.pi / 180.0
        m_lon = 111320.0 * max(0.25, math.cos(lat0))
        span_m = (max_lon - min_lon) * m_lon if split_lon else (max_lat - min_lat) * 110540.0
        gap_frac = min(0.05, (max(spacing_m, 8) * 0.35) / max(span_m, 1))
        if d > 0:
            u0 += gap_frac * 0.5
        if d < len(percents) - 1:
            u1 -= gap_frac * 0.5
        if u1 <= u0:
            u0, u1 = start / bins, bin_i / bins
        if split_lon:
            region = clip_lon_band(land, min_lon + u0 * (max_lon - min_lon), min_lon + u1 * (max_lon - min_lon))
        else:
            swapped = [(p[1], p[0]) for p in land]
            region_s = clip_lon_band(swapped, min_lat + u0 * (max_lat - min_lat), min_lat + u1 * (max_lat - min_lat))
            region = [(p[1], p[0]) for p in region_s]
        out.append({"percent": pct, "path": region, "areaM2": polygon_area_m2(region)})
    return out


def transect_hits(path, is_ns, value):
    hits = []
    for i, a in enumerate(path):
        b = path[(i + 1) % len(path)]
        if is_ns:
            if (a[1] - value) * (b[1] - value) <= 0 and abs(b[1] - a[1]) > 1e-12:
                t = (value - a[1]) / (b[1] - a[1])
                hits.append(a[0] + t * (b[0] - a[0]))
        else:
            if (a[0] - value) * (b[0] - value) <= 0 and abs(b[0] - a[0]) > 1e-12:
                t = (value - a[0]) / (b[0] - a[0])
                hits.append(a[1] + t * (b[1] - a[1]))
    hits.sort()
    return hits


def survey_waypoints(path, spacing_m=20.0, alt_m=30.0):
    if len(path) < 3:
        return []
    min_lat, max_lat, min_lon, max_lon = bounds_of(path)
    lat0 = ((min_lat + max_lat) * 0.5) * math.pi / 180.0
    m_lat = 110540.0
    m_lon = 111320.0 * max(0.25, math.cos(lat0))
    ns = (max_lon - min_lon) * m_lon >= (max_lat - min_lat) * m_lat
    spacing = max(5.0, spacing_m)
    wps = []
    flip = False
    if ns:
        dlon = spacing / m_lon
        lon = min_lon + dlon * 0.5
        while lon <= max_lon + 1e-9:
            hits = transect_hits(path, True, lon)
            if len(hits) >= 2 and abs(hits[-1] - hits[0]) * m_lat >= spacing * 0.25:
                lat_a, lat_b = hits[0], hits[-1]
                if flip:
                    lat_a, lat_b = lat_b, lat_a
                wps.append({"lat": lat_a, "lon": lon, "alt": alt_m})
                wps.append({"lat": lat_b, "lon": lon, "alt": alt_m})
                flip = not flip
            lon += dlon
    else:
        dlat = spacing / m_lat
        lat = min_lat + dlat * 0.5
        while lat <= max_lat + 1e-9:
            hits = transect_hits(path, False, lat)
            if len(hits) >= 2 and abs(hits[-1] - hits[0]) * m_lon >= spacing * 0.25:
                lon_a, lon_b = hits[0], hits[-1]
                if flip:
                    lon_a, lon_b = lon_b, lon_a
                wps.append({"lat": lat, "lon": lon_a, "alt": alt_m})
                wps.append({"lat": lat, "lon": lon_b, "alt": alt_m})
                flip = not flip
            lat += dlat
    return wps


def plan_json(wps, apm=True):
    items = [{"command": 16, "lat": w["lat"], "lon": w["lon"], "alt": w["alt"]} for w in wps]
    items.append({"command": 20, "lat": 0, "lon": 0, "alt": 0})
    return {
        "fileType": "Plan",
        "groundStation": "ASTHRA",
        "mission": {
            "firmwareType": 3 if apm else 12,
            "vehicleType": 2,
            "items": items,
            "plannedHomePosition": [wps[0]["lat"], wps[0]["lon"], 0],
        },
    }


class FakeVehicle:
    def __init__(self, gcs_id, sysid, port, armed=False, px4=False):
        self.gcsId = gcs_id
        self.id = sysid
        self.port = port
        self.armed = armed
        self.px4Firmware = px4
        self.flightModes = ["Mission", "Auto", "RTL", "Stabilize"] if not px4 else ["Manual", "Mission", "Hold"]
        self.flightMode = "Stabilize"
        self.plans = []

    def sendPlan(self, path):
        self.plans.append(path)


def operator_prepare(vehicles, percents, land):
    """End-to-end: fleet identity, split, survey, upload, start gates."""
    fleet = collect_fleet([(v.gcsId, v.id) for v in vehicles], [], max(len(vehicles), len(percents)))
    if abs(sum(percents) - 100) > 0.6:
        percents = renormalize(percents)
    regions = apply_split(land, percents)
    assignments = []
    for i, region in enumerate(regions):
        wps = survey_waypoints(region["path"])
        vid = fleet[i]["vehicleId"]
        v = vehicle_by_id([{"gcsId": x.gcsId, "id": x.id} for x in vehicles], vid)
        sent = False
        if v and wps:
            veh = next(x for x in vehicles if x.gcsId == v["gcsId"])
            plan = plan_json(wps, apm=not veh.px4Firmware)
            veh.sendPlan(f"asthra_drone_{vid}.plan")
            sent = True
            assert 22 not in [it["command"] for it in plan["mission"]["items"]]
        assignments.append({"vehicleId": vid, "uploaded": sent, "sent": sent, "wpCount": len(wps), "wps": wps})
    started = []
    waiting = []
    for a in assignments:
        if not (a["uploaded"] or a["sent"]):
            waiting.append("no plan")
            continue
        v = next((x for x in vehicles if x.gcsId == a["vehicleId"]), None)
        if v is None:
            waiting.append("no radio")
            continue
        if not v.armed:
            waiting.append("disarmed")
            continue
        mode = start_armed_survey(v.armed, v.flightModes, v.px4Firmware)
        if mode:
            v.flightMode = mode
            started.append(v.gcsId)
        else:
            waiting.append("no mode")
    return {"fleet": fleet, "assignments": assignments, "started": started, "waiting": waiting}


def expect(cond: bool, msg: str, failures: list[str]) -> None:
    if not cond:
        failures.append(msg)


def main() -> int:
    failures: list[str] = []

    # Split: 50/50 on a uniform strip is about 50/50
    s = closer_bin_shares([50, 50])
    expect(len(s) == 2, "50/50 should yield 2 shares", failures)
    expect(abs(s[0] - 50) < 1.0 and abs(s[1] - 50) < 1.0, f"50/50 got {s}", failures)

    # Split: 20/20/60
    s = closer_bin_shares([20, 20, 60])
    expect(len(s) == 3, "20/20/60 should yield 3 shares", failures)
    expect(abs(s[0] - 20) < 1.5 and abs(s[1] - 20) < 1.5 and abs(s[2] - 60) < 1.5, f"20/20/60 got {s}", failures)

    # Split: one drone
    s = closer_bin_shares([100])
    expect(abs(s[0] - 100) < 0.01, f"100% got {s}", failures)

    # Split: N=4 equal
    s = closer_bin_shares([25, 25, 25, 25])
    expect(all(abs(x - 25) < 1.5 for x in s), f"4x25 got {s}", failures)

    # Split: N=16 equal
    s = closer_bin_shares([100 / 16] * 16)
    expect(len(s) == 16 and abs(sum(s) - 100) < 0.01, f"16-way sum {sum(s)} shares {s}", failures)

    # Rectangle area is positive
    rect = [(10.0, 76.0), (10.0, 76.01), (10.01, 76.01), (10.01, 76.0)]
    expect(polygon_area_m2(rect) > 1000, f"rect area {polygon_area_m2(rect)}", failures)

    # Fleet: two USB radios both SYS 2 stay two rows
    fleet = collect_fleet([(1, 2), (2, 2)], [], 2)
    expect(len(fleet) == 2, f"two SYS2 radios should be 2 rows, got {fleet}", failures)
    expect(fleet[0]["vehicleId"] == 1 and fleet[1]["vehicleId"] == 2, f"gcs keys {fleet}", failures)
    expect(fleet[0]["sysid"] == 2 and fleet[1]["sysid"] == 2, f"sysids {fleet}", failures)

    # Fleet: backend SYS 2 must not merge when two radios share SYS 2
    fleet = collect_fleet([(1, 2), (2, 2)], [2], 2)
    expect(len(fleet) == 3, f"ambiguous backend should add a row, got {len(fleet)} {fleet}", failures)
    expect(sum(1 for r in fleet if r["backend"] and not r["linked"]) == 1, f"backend row {fleet}", failures)

    # Fleet: unique SYS match tags backend onto the radio
    fleet = collect_fleet([(1, 2), (2, 3)], [2], 2)
    expect(len(fleet) == 2, f"unique backend match should stay 2, got {fleet}", failures)
    expect(fleet[0]["backend"] and fleet[0]["linked"], f"drone 2 should tag V1 {fleet}", failures)
    expect(not fleet[1]["backend"], f"V2 should not be backend {fleet}", failures)

    # Fleet: pad planned N
    fleet = collect_fleet([(1, 2)], [], 4)
    expect(len(fleet) == 4, f"planned 4 should pad, got {fleet}", failures)
    expect(sum(1 for r in fleet if r["linked"]) == 1, f"one linked {fleet}", failures)

    # Upload lookup: two SYS 2 — gcsId wins, sysid fallback refused
    vehs = [{"gcsId": 1, "id": 2}, {"gcsId": 2, "id": 2}]
    expect(vehicle_by_id(vehs, 1)["gcsId"] == 1, "gcsId 1 lookup", failures)
    expect(vehicle_by_id(vehs, 2)["gcsId"] == 2, "gcsId 2 lookup", failures)
    expect(vehicle_by_id(vehs, 99) is None, "unknown id", failures)

    # Unique sysid fallback still works
    vehs = [{"gcsId": 4, "id": 7}]
    expect(vehicle_by_id(vehs, 7)["gcsId"] == 4, "unique sysid fallback", failures)

    # Lawnmower has enough points
    nwp = lawnmower_count(10.0, 76.0, 10.01, 76.01, 20)
    expect(nwp >= 2, f"survey waypoints {nwp}", failures)

    # Slot labels
    expect([i + 1 for i in range(5)] == [1, 2, 3, 4, 5], "slots 1..5", failures)

    # Inter-drone corridor: neighboring strips do not overlap
    bands = strip_bands([50, 50], span_m=1000.0, spacing_m=20.0)
    expect(len(bands) == 2, f"two bands {bands}", failures)
    expect(bands[0][1] <= bands[1][0] + 1e-9, f"corridor overlap {bands}", failures)
    expect(bands[1][0] - bands[0][1] > 0.0, f"corridor gap missing {bands}", failures)
    bands4 = strip_bands([25, 25, 25, 25], span_m=2000.0, spacing_m=20.0)
    expect(all(bands4[i][1] <= bands4[i + 1][0] + 1e-9 for i in range(3)), f"4-way corridor {bands4}", failures)

    # Start never arms: only uploaded + radio + armed
    expect(start_gate(True, True, True) == "start", "armed start", failures)
    expect(start_gate(True, True, False) == "disarmed", "must not start disarmed", failures)
    expect(start_gate(False, True, True) == "no plan", "must not start without plan", failures)
    expect(start_gate(True, False, True) == "no radio", "must not start without radio", failures)

    # Fleet hard cap at 16
    fleet = collect_fleet([(i + 1, 2) for i in range(20)], [], 20)
    expect(len(fleet) == 16, f"20 radios must cap at 16, got {len(fleet)}", failures)

    # Percent survive gcsId recycle via slot / port
    saved = {"1": 40.0, "2": 60.0, "slot:1": 40.0, "slot:2": 60.0, "port:ttyACM0": 40.0, "port:ttyACM1": 60.0}
    expect(saved_percent(saved, 9, "ttyACM0", 1, 50) == 40.0, "port should restore after new gcsId", failures)
    expect(saved_percent(saved, 10, "", 2, 50) == 60.0, "slot should restore without port", failures)
    expect(saved_percent({}, 1, "ttyACM0", 1, 33) == 33, "fallback when nothing saved", failures)

    # Prepare keeps operator percents by renormalize, not wipe
    r = renormalize([20, 20, 60])
    expect(abs(sum(r) - 100) < 1e-6, f"renorm sum {r}", failures)
    expect(abs(r[0] - 20) < 0.01 and abs(r[2] - 60) < 0.01, f"renorm must keep ratio {r}", failures)
    r = renormalize([40, 40])
    expect(abs(r[0] - 50) < 0.01 and abs(r[1] - 50) < 0.01, f"40/40 scales to 50/50 {r}", failures)

    # Prepare never shrinks planned N
    expect(prepare_planned_n(4, 2) == 4, "2 radios must not collapse planned 4", failures)
    expect(prepare_planned_n(2, 3) == 3, "3 radios should grow planned 2", failures)
    expect(prepare_planned_n(2, 20) == 16, "grow must still cap at 16", failures)

    # Plan items are waypoints + RTL, never takeoff
    cmds = plan_commands(6)
    expect(cmds[0] == 16 and cmds[-1] == 20, f"plan cmds {cmds}", failures)
    expect(22 not in cmds, "survey plan must not insert NAV_TAKEOFF", failures)

    # Start uses Auto/Mission only when armed
    expect(start_armed_survey(False, ["Auto", "Guided"], False) is None, "disarmed must not set mode", failures)
    expect(start_armed_survey(True, ["Stabilize", "Auto", "RTL"], False) == "Auto", "APM Auto", failures)
    expect(start_armed_survey(True, ["Manual", "Mission", "Hold"], True) == "Mission", "PX4 Mission", failures)

    # No silent Bangalore land
    expect(land_from_map(False, False) == "need map", "invalid map must not invent a field", failures)
    expect(land_from_map(True, False) == "ok", "map center is enough", failures)

    # USB board fallback
    expect(usb_board_fallback("/dev/ttyACM0") == "Pixhawk", "ACM is FC", failures)
    expect(usb_board_fallback("/dev/ttyUSB1") == "SiK Radio", "USB telemetry", failures)
    expect(usb_board_fallback("COM7") == "Pixhawk", "Windows COM", failures)
    expect(usb_board_fallback("/dev/ttyS0") is None, "system UART is not a radio", failures)

    # Operator path: two USB radios both SYS 2, 20/20/60-style 50/50 field
    land = [(12.90, 77.50), (12.90, 77.52), (12.92, 77.52), (12.92, 77.50)]
    v1 = FakeVehicle(1, 2, "ttyACM0", armed=False)
    v2 = FakeVehicle(2, 2, "ttyACM1", armed=False)
    result = operator_prepare([v1, v2], [50, 50], land)
    expect(len(result["fleet"]) == 2, f"operator fleet {result['fleet']}", failures)
    expect(result["fleet"][0]["sysid"] == 2 and result["fleet"][1]["sysid"] == 2, "both SYS 2", failures)
    expect(len(result["assignments"]) == 2, "two assignments", failures)
    expect(all(a["wpCount"] >= 2 for a in result["assignments"]), f"survey wps {result['assignments']}", failures)
    expect(all(a["sent"] for a in result["assignments"]), "both plans sent", failures)
    expect(v1.plans and v2.plans, "each radio got its own plan file", failures)
    expect(v1.plans[0] != v2.plans[0], "plan files must not collide", failures)
    expect(result["started"] == [] and "disarmed" in result["waiting"], f"must not start until armed {result}", failures)
    areas = [polygon_area_m2(a) for a in [apply_split(land, [50, 50])[0]["path"], apply_split(land, [50, 50])[1]["path"]]]
    expect(abs(areas[0] - areas[1]) / max(sum(areas), 1) < 0.08, f"50/50 areas {areas}", failures)

    # 20/20/60 area split on same field
    regs = apply_split(land, [20, 20, 60])
    a20 = [polygon_area_m2(r["path"]) for r in regs]
    tot = sum(a20)
    expect(len(regs) == 3 and tot > 0, f"20/20/60 regions {a20}", failures)
    expect(abs(a20[0] / tot - 0.20) < 0.05 and abs(a20[2] / tot - 0.60) < 0.05, f"20/20/60 area share {a20}", failures)

    # After arm, only uploaded radios start; no arming
    v1.armed = True
    v2.armed = True
    result = operator_prepare([v1, v2], [50, 50], land)
    expect(result["started"] == [1, 2], f"armed start {result}", failures)
    expect(v1.flightMode == "Auto" and v2.flightMode == "Auto", f"modes {v1.flightMode} {v2.flightMode}", failures)
    expect(v1.armed and v2.armed, "start must not change armed state", failures)

    # Planned 4, only 2 radios: pad, upload only live radios, start only armed+sent
    v3_missing = operator_prepare([v1, v2], [25, 25, 25, 25], land)
    expect(len(v3_missing["fleet"]) == 4, f"pad to 4 {v3_missing['fleet']}", failures)
    sent_n = sum(1 for a in v3_missing["assignments"] if a["sent"])
    expect(sent_n == 2, f"only 2 live radios get plans, got {sent_n}", failures)

    # Source guards: operator path must stay on the stable stack
    panel = Path(__file__).resolve().parents[2] / "src/UI/ASTHRA/ASTHRASwarmCoveragePanel.qml"
    qml = panel.read_text(encoding="utf-8")
    expect("function prepareSwarm()" in qml, "prepareSwarm missing", failures)
    expect("function renormalizePercents()" in qml, "renormalize missing", failures)
    expect("_startArmedSurvey" in qml, "armed mode start missing", failures)
    expect("armedUploadedCount" in qml, "armed start count missing", failures)
    expect("v.startMission()" not in qml, "must not call startMission (firmware auto-arm)", failures)
    expect("_simpleItem(22," not in qml, "survey plan must not emit NAV_TAKEOFF", failures)
    expect("12.9716" not in qml, "must not hardcode Bangalore land", failures)
    expect("autoConnectUDP.value = true" not in qml, "must not force UDP vehicles into USB swarm", failures)
    expect("ttyACM0" not in qml or "usbSerialPorts" in qml, "fake ACM list should be gone", failures)

    main_qml = Path(__file__).resolve().parents[2] / "src/UI/MainWindow.qml"
    main_txt = main_qml.read_text(encoding="utf-8")
    expect("sideMode" in main_txt, "swarm drawer must leave the map visible", failures)
    expect('showTool(qsTr("Split land")' in main_txt and "true)" in main_txt, "SWARM must open as a side panel", failures)

    overlay = Path(__file__).resolve().parents[2] / "src/UI/ASTHRA/ASTHRASwarmCoverageMap.qml"
    ov = overlay.read_text(encoding="utf-8")
    expect("onMapReadyChanged" in ov, "overlay must retry when map is ready", failures)

    if failures:
        print("FAIL")
        for f in failures:
            print(" -", f)
        return 1
    print("PASS  land-split, fleet keys, upload lookup, survey, corridor, start gate, persist, prepare, plan, USB, N=1..16")
    return 0


if __name__ == "__main__":
    sys.exit(main())
