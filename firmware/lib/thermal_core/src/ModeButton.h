#pragma once

#include <stdint.h>

#include "ThermalTypes.h"

namespace kinecto {
namespace thermal {

// Debounces the MODE button. ShortPress fires on release, Hold2s fires once while still held.
class ModeButton {
 public:
  ModeButton(uint32_t debounceMs, uint32_t holdMs);

  ButtonAction update(bool pressed, uint32_t nowMs);

 private:
  uint32_t debounceMs_;
  uint32_t holdMs_;
  bool lastRaw_;
  bool stablePressed_;
  bool holdReported_;
  uint32_t lastRawChangeMs_;
  uint32_t pressStartMs_;
};

}  // namespace thermal
}  // namespace kinecto
