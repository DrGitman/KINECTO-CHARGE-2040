# Pin map: thermal module (ESP32-C3)

Owner: Member D (Thermal Comfort). Changes by pull request only, reviewed by the owner.

SIMULATED: there is no physical prototype. The board below is simulated in Wokwi on an ESP32-C3 DevKitM-1. The two TMP117 sensors are Wokwi custom chips that follow the TMP117 I2C register map.

## GPIO assignment

| GPIO | Signal | Direction | Connected to | Notes |
|---|---|---|---|---|
| 6 | I2C_SDA | bidirectional | TMP117 inside + TMP117 ambient | 4.7 kΩ pull-up to 3.3 V |
| 7 | I2C_SCL | output | TMP117 inside + TMP117 ambient | 4.7 kΩ pull-up to 3.3 V |
| 5 | HEATER_GATE | output | Heater MOSFET gate | 10 kΩ pull-down, so the heater is OFF at boot |
| 10 | BLOWER_GATE | output | Blower MOSFET gate | 10 kΩ pull-down, so the blower is OFF at boot |
| 4 | MODE_BUTTON | input | Cuff MODE button to GND | Active low, internal pull-up |
| 8 | STATUS_LED | output | On-board WS2812 RGB LED | Strapping pin, used as output only after boot |
| 0 | BATT_SENSE | analog in (ADC1) | Thermal LiPo through a 100 kΩ / 100 kΩ divider | 4.2 V full charge reads 2.1 V |
| 1 | BUFFER_SENSE | analog in (ADC1) | Energy buffer through a divider | Provided for Member B. Divider values to confirm with Member B |
| 3 | BLOWER_ISENSE | analog in (ADC1) | Blower current shunt | Shunt value to confirm with Member C (harness) |

Not used: GPIO2 and GPIO9 (strapping pins, GPIO9 is the BOOT button), GPIO18 and GPIO19 (USB), GPIO20 and GPIO21 (UART0, serial log).

## I2C devices

| Device | Address | ADD0 pin | Placement |
|---|---|---|---|
| TMP117 inside | 0x48 | GND | Inner lining, measures the microclimate inside the jacket |
| TMP117 ambient | 0x49 | V+ | Outer collar, away from the body and the electronics |

Both sensors share one bus. No I2C multiplexer is needed: the TMP117 address is set by its ADD0 pin.

## Power

- The thermal module runs from its own LiPo 3.7 V 2000 mAh (about 7.4 Wh), with protection and a fuse.
- Harvested energy never powers the heater or the blower. BUFFER_SENSE only reads the energy buffer for telemetry.
- Heater and blower are 5 V loads switched by logic-level MOSFETs (3.3 V gate drive) from the 5 V boost converter.

## Safety rules the firmware must follow

- Heater and blower are OFF at power-on (state OFF).
- Heater and blower are never ON at the same time.
- Heater cutoff: the heater is forced OFF when the inside temperature reaches 42.0 °C (`limits.cutoff_c` in `thermal.json`).
- FAULT always wins: on a sensor read error or an inside temperature at or above the cutoff, the firmware enters FAULT, forces the heater OFF and blinks the status light red.

## Status light

| State | Light |
|---|---|
| OFF | off |
| AUTO | steady, auto colour |
| COOL | steady, cool colour |
| WARM | steady, warm colour |
| FAULT | blinking red |

Exact colours are defined by the mode UI (`design/ui-thermal/`).
