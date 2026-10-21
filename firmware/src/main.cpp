#include <Arduino.h>
#include <Wire.h>

#include "GpioLoadOutputs.h"
#include "ModeButton.h"
#include "PinMap.h"
#include "SerialAdapters.h"
#include "StatusLight.h"
#include "ThermalConfig.h"
#include "ThermalController.h"
#include "Tmp117Sensor.h"

using namespace kinecto;

namespace {

constexpr uint32_t kSerialBaud = 115200;
// SIMULATED start time, 2026-10-15T07:30:00Z, same as the thermal.json sample.
constexpr int64_t kSimulatedStartEpoch = 1792049400;

GpioLoadOutputs loads(pins::kHeaterGate, pins::kBlowerGate);
Tmp117Sensor insideSensor(Wire, pins::kTmp117InsideAddress);
Tmp117Sensor ambientSensor(Wire, pins::kTmp117AmbientAddress);
SerialEventSink events(Serial);
SerialLogger logger(Serial);
SimulatedClock simClock(kSimulatedStartEpoch);

thermal::ThermalController controller(
    thermal::ControllerDependencies{insideSensor, ambientSensor, loads, events, simClock, logger},
    thermal::kDefaultLimits, thermal::kMissesBeforeSilent);
thermal::ModeButton modeButton(thermal::kButtonDebounceMs, thermal::kButtonHoldMs);

uint32_t lastTickMs = 0;

void showStatus(uint32_t nowMs) {
  const thermal::RgbColor color =
      thermal::statusColorFor(controller.state(), nowMs, thermal::kFaultBlinkHalfPeriodMs);
  neopixelWrite(pins::kStatusLed, color.red, color.green, color.blue);
}

}  // namespace

void setup() {
  loads.begin();
  pinMode(pins::kModeButton, INPUT_PULLUP);
  Serial.begin(kSerialBaud);
  Wire.begin(pins::kI2cSda, pins::kI2cScl);

  controller.start();
  lastTickMs = millis();
}

void loop() {
  const uint32_t nowMs = millis();

  const bool pressed = digitalRead(pins::kModeButton) == LOW;
  controller.handleButton(modeButton.update(pressed, nowMs));

  if (nowMs - lastTickMs >= thermal::kSensorPeriodMs) {
    lastTickMs = nowMs;
    controller.tick();
  }

  showStatus(nowMs);
}
