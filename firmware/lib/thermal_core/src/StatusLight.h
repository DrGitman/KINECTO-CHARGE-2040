#pragma once

#include <stdint.h>

#include "ThermalTypes.h"

namespace kinecto {
namespace thermal {

struct RgbColor {
  uint8_t red;
  uint8_t green;
  uint8_t blue;
};

inline bool operator==(const RgbColor& a, const RgbColor& b) {
  return a.red == b.red && a.green == b.green && a.blue == b.blue;
}

// Placeholder colours from the shared palette until design/ui-thermal/ defines them.
constexpr RgbColor kLightOff{0x00, 0x00, 0x00};
constexpr RgbColor kAutoColor{0x6A, 0x55, 0xB0};   // Member D
constexpr RgbColor kCoolColor{0x2E, 0x6B, 0x62};   // Teal
constexpr RgbColor kWarmColor{0xF0, 0xA0, 0x20};   // Orange
constexpr RgbColor kFaultColor{0xC0, 0x39, 0x2B};  // Alert

RgbColor statusColorFor(State state, uint32_t nowMs, uint32_t blinkHalfPeriodMs);

}  // namespace thermal
}  // namespace kinecto
