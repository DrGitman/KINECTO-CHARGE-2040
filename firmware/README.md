# Thermal firmware (ESP32-C3)

Owner: Member D (Thermal Comfort).

SIMULATED: there is no physical prototype. The firmware targets an ESP32-C3 DevKitM-1 simulated in Wokwi. Pins and I2C addresses follow `docs/contracts/pinmap.md`, the event log follows `docs/contracts/thermal.json`.

## Layout

| Path | Content |
|---|---|
| `lib/thermal_core/` | Platform-free logic: state machine, safety rules, MODE button, sensor monitor, event JSON, status light colours |
| `src/` | Arduino adapters (TMP117 over I2C, MOSFET gates, WS2812, serial) and `main.cpp` |
| `test/` | Host unit tests for `thermal_core`, run with fakes instead of hardware |

## Behaviour

- Power-on state is OFF with heater and blower OFF.
- Short press on MODE cycles OFF, AUTO, COOL, WARM, OFF. A 2 s hold returns to OFF.
- AUTO heats below `warm_below_c` until `warm_below_c + hysteresis_c`, and cools above `cool_above_c` until `cool_above_c - hysteresis_c`.
- COOL runs the blower continuously. WARM heats up to `warm_max_c` and resumes below `warm_max_c - hysteresis_c`.
- After a mode change, regulation starts on the next sensor tick (1 s).
- FAULT always wins. Three missed reads in a row on either sensor, or an inside temperature at or above `cutoff_c`, force both loads OFF. A short press clears FAULT to OFF only once the cause is gone.
- Heater and blower are never ON at the same time.

## Serial output

115200 baud. Each event is one JSON line starting with `{`, in the format of an entry of `events` in `thermal.json`. Log lines start with `[`. Timestamps start from a fixed SIMULATED date (2026-10-15T07:30:00Z) because there is no RTC.

## Commands

Run from `firmware/`, with PlatformIO Core installed.

```bash
pio test -e native    # unit tests on the host
pio run -e esp32c3    # firmware build for the ESP32-C3
```
