#include "Tmp117Sensor.h"

namespace kinecto {

namespace {
constexpr uint8_t kTemperatureRegister = 0x00;
constexpr uint8_t kRegisterSizeBytes = 2;
// TMP117 datasheet: 1 LSB = 7.8125 m°C.
constexpr float kCelsiusPerLsb = 0.0078125f;
}  // namespace

Tmp117Sensor::Tmp117Sensor(TwoWire& bus, uint8_t address) : bus_(bus), address_(address) {}

thermal::TemperatureReading Tmp117Sensor::read() {
  uint16_t raw = 0;
  if (!readRegister(kTemperatureRegister, raw)) {
    return thermal::failedReading();
  }
  return thermal::validReading(static_cast<int16_t>(raw) * kCelsiusPerLsb);
}

bool Tmp117Sensor::readRegister(uint8_t reg, uint16_t& value) {
  bus_.beginTransmission(address_);
  bus_.write(reg);
  if (bus_.endTransmission(false) != 0) {
    return false;
  }
  if (bus_.requestFrom(address_, kRegisterSizeBytes) != kRegisterSizeBytes) {
    return false;
  }
  const uint8_t high = bus_.read();
  const uint8_t low = bus_.read();
  value = static_cast<uint16_t>((high << 8) | low);
  return true;
}

}  // namespace kinecto
