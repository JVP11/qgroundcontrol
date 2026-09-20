# ASTHRA

**Advanced Strategic Tactical Humanitarian Response Analyser**

ASTHRA is a ground control station for one drone or a swarm. Each USB radio is its own vehicle. You load a KML land file, set each drone’s area %, then split, survey, and upload. ASTHRA never auto-arms.

This repository is the ASTHRA GCS. It is based on [QGroundControl](https://github.com/mavlink/qgroundcontrol) (MAVLink / Qt).

[![License](https://img.shields.io/badge/license-GPL--3.0%20%2F%20Apache--2.0-blue.svg)](LICENSE-GPL)

---

## What it does

- Connects **N drones** over USB (and UDP when each craft has a unique SYSID)
- Treats **each Pixhawk cable as one drone**, even if two boards both use SYS 2
- Ignores extra composite USB ports on the same board (one board ≠ two drones)
- **Split land:** load KML → set percents that total 100 → draw split on the map
- Builds a lawnmower survey per piece and uploads it to the matching vehicle
- Keeps the map and telemetry visible while the swarm panel is open
- Does **not** arm motors. Arm from the left column or multi-vehicle panel when you are ready to fly

---

## Operator path (swarm)

1. Plug each flight controller USB cable.
2. Run ASTHRA (`./run_asthra.sh`).
3. Open **SWARM**.
4. **Load KML file** (the land polygon).
5. Set each drone’s **%** so the sum is **100**.
6. **Draw split on map**.
7. Make survey waypoints and **Upload to each drone**.
8. Arm yourself, then start uploaded missions.

PreArm battery / GPS messages come from the autopilot, not from a failed GCS link.

---

## Run (Linux)

Need Qt 6, a Release build, and display access.

```bash
./run_asthra.sh --build
```

Or, if already built:

```bash
./run_asthra.sh
```

Binary: `build/Release/ASTHRA`.

Fleet checks (no hardware):

```bash
python3 tools/tests/test_asthra_fleet.py
```

---

## Layout

| Path | Purpose |
|------|---------|
| `run_asthra.sh` | Build/launch ASTHRA |
| `src/UI/ASTHRA/` | Swarm panel, telemetry, status strip |
| `src/Comms/` | USB radios, one vehicle per cable |
| `src/Vehicle/` | Multi-vehicle (including same SYSID on dedicated links) |
| `tools/tests/test_asthra_fleet.py` | Split / fleet / upload identity tests |
| `docs/` | Upstream QGC developer docs |

---

## License

Same dual license as QGroundControl: [LICENSE-GPL](LICENSE-GPL) and [LICENSE-APACHE](LICENSE-APACHE). Keep those notices when you ship or fork.

Upstream project: https://github.com/mavlink/qgroundcontrol
