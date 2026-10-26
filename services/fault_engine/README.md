# Kinecto Care fault engine

Second line of defence for the jacket. Every 10 s the engine reads the last 10 min of telemetry, runs six rules and opens the faults the jacket did not flag itself. A fault that is already open, or already in the jacket's `fault_flags`, is never opened again. The engine never closes faults: the repair flow does.

Everything here is SIMULATED. Telemetry comes from the Virtual Lab jacket `KC-SIM-0001` (one sample every 5 s). Comfort only, not medical.

## Rules

Thresholds live in `rules_config.json`. They are assumptions, not measured values.

| Fault code | Opens when |
| --- | --- |
| `body_sensor_offline` | inside sensor silent (`body_c` null) for 3 samples in a row |
| `heater_over_limit` | one sample at or above the 42 °C cutoff, or heater on above 30 °C for 60 s |
| `blower_current_spike` | blower draw above 500 mA for 2 samples |
| `buffer_not_charging` | walking, brisk walking or running for 5 min with no harvest gain |
| `battery_hot` | thermal battery at or above 45 °C for 2 samples |
| `cuff_tag_unreadable` | cuff tag unreadable for 3 samples |

Fault codes match the Virtual Lab `fault_flags`, so the app shows "Inside sensor silent" for `body_sensor_offline`.

## Layout

- `fault_engine/rules.py`: pure rules, one function per fault.
- `fault_engine/engine.py`: one tick, with the telemetry source, fault repository and clock injected.
- `fault_engine/telemetry_dto.py`: validates a Virtual Lab payload and maps it to a `TelemetrySample`.
- `fault_engine/adapters.py`: JSONL replay source, in-memory repository, replay clock.
- `samples/heater_over_limit.jsonl`: SIMULATED replay of the lab "Heater over limit" scenario (ambient 18 °C, heater stuck on from 10:01, the lab cuts the inside sensor above 40 °C and only flags `heater_over_limit`).

The Supabase adapter comes in a later pull request, once the shared schema is agreed.

## Run

```bash
cd services/fault_engine
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
.venv/bin/python -m pytest
.venv/bin/python -m fault_engine replay samples/heater_over_limit.jsonl
```

The replay opens one fault, `body_sensor_offline`, that the jacket never flagged.
