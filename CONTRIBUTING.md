# Contributing to ASTHRA

Thank you for working on ASTHRA. This is operator-facing flight software. Changes that affect arming, vehicle identity, or mission upload need extra care.

## Rules

- Do not auto-arm from the swarm panel.
- Do not treat two USB interfaces on the same Pixhawk as two drones.
- Keep telemetry visible while the land-split panel is open.
- Land split is KML (or an explicit map square), then percents totaling 100, then split.

## Checks

```bash
python3 tools/tests/test_asthra_fleet.py
```

Build target: `ASTHRA` (`./run_asthra.sh --build`).

## License

Contributions follow the existing QGroundControl dual license in this tree.
