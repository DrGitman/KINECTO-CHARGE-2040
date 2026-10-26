# Thermal firmware (ESP32-C3)

Owner: Member D (Thermal Comfort).

SIMULATED: there is no physical prototype. The firmware targets an ESP32-C3 DevKitM-1 simulated in Wokwi. Pins and I2C addresses follow `docs/contracts/pinmap.md`, the event log follows `docs/contracts/thermal.json`.

## Layout

| Path | Content |
|---|---|
| `lib/thermal_core/` | Platform-free logic: state machine, safety rules, MODE button, sensor monitor, event JSON, status light colours |
| `src/` | Arduino adapters (TMP117 over I2C, MOSFET gates, WS2812, serial) and `main.cpp` |
| `test/` | Host unit tests for `thermal_core`, run with fakes instead of hardware |
| `diagram.json`, `wokwi.toml` | Wokwi circuit and project config |
| `wokwi/chips/` | SIMULATED TMP117 custom chip (C, built to WebAssembly) |
| `wokwi/scenarios/` | `wokwi-cli` automation scenarios |

## Behaviour

- Power-on state is OFF with heater and blower OFF.
- Short press on MODE cycles OFF, AUTO, COOL, WARM, OFF. A 2 s hold returns to OFF.
- AUTO heats below `warm_below_c` until `warm_below_c + hysteresis_c`, and cools above `cool_above_c` until `cool_above_c - hysteresis_c`.
- COOL runs the blower continuously. WARM heats up to `warm_max_c` and resumes below `warm_max_c - hysteresis_c`.
- After a mode change, regulation starts on the next sensor tick (1 s).
- FAULT always wins. Three missed reads in a row on either sensor, or an inside temperature at or above `cutoff_c`, force both loads OFF. A short press clears FAULT to OFF only once the cause is gone.
- The `heater_over_limit` fault means the inside temperature reached the heater cutoff (`cutoff_c`). It is reported whatever load is running, including when only the blower is on.
- Heater and blower are never ON at the same time.

## Serial output

115200 baud. Each event is one JSON line starting with `{`, in the format of an entry of `events` in `thermal.json`. Log lines start with `[`. Timestamps start from a fixed SIMULATED date (2026-10-15T07:30:00Z) because there is no RTC.

## Commands

Run from `firmware/`, with PlatformIO Core installed.

```bash
pio test -e native    # unit tests on the host
pio run -e esp32c3    # firmware build for the ESP32-C3
```

## Wokwi simulation

The circuit follows `docs/contracts/pinmap.md`: two TMP117 chips on one I2C bus (inside at 0x48 with ADD0 to GND, ambient at 0x49 with ADD0 to 3V3), the MODE button on GPIO4, the heater and blower gates on GPIO5 and GPIO10 shown as LEDs with their 10 kΩ pull-downs, and the on-board WS2812 on GPIO8 as the status light.

Each TMP117 has two controls: `temperature` (-10 to 50 °C) and `offline` (1 makes the chip stop answering, to trigger a sensor FAULT).

The TMP117 chip needs clang and lld. `build_chips.sh` downloads `wokwi-api.h` on the first run. The header and the `.wasm` are not committed.

```bash
wokwi/build_chips.sh   # builds wokwi/chips/tmp117.chip.wasm
pio run -e esp32c3     # builds the firmware Wokwi loads
```

Then either:

- VS Code with the Wokwi extension: open `diagram.json` and start the simulator.
- `wokwi-cli` (needs `WOKWI_CLI_TOKEN` in the environment, never in the repo):

```bash
wokwi-cli . --scenario wokwi/scenarios/thermal_modes.test.yaml --timeout 60000
```

The scenario walks through OFF, AUTO heating, AUTO cooling, a sensor FAULT and its clearing, then the 42.0 °C cutoff FAULT, and finally a 2 s hold back to OFF.
