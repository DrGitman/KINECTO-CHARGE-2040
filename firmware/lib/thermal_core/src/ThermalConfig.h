#pragma once

#include <stdint.h>

namespace kinecto {
namespace thermal {

struct ThermalLimits {
  float cutoffC;
  float warmBelowC;
  float coolAboveC;
  float warmMaxC;
  float hysteresisC;
};

// Mirrors "limits" in docs/contracts/thermal.json. Keep both in sync.
constexpr ThermalLimits kDefaultLimits{42.0f, 19.0f, 26.0f, 30.0f, 0.7f};

// AUTO heat and cool bands must not overlap, and WARM must stay below the cutoff.
constexpr bool isValid(const ThermalLimits& limits) {
  return limits.hysteresisC > 0.0f &&
         limits.warmBelowC + limits.hysteresisC < limits.coolAboveC - limits.hysteresisC &&
         limits.warmBelowC < limits.warmMaxC &&
         limits.warmMaxC < limits.cutoffC;
}

static_assert(isValid(kDefaultLimits), "kDefaultLimits are inconsistent");

constexpr uint32_t kSensorPeriodMs = 1000;
constexpr uint8_t kMissesBeforeSilent = 3;
constexpr uint32_t kButtonDebounceMs = 30;
constexpr uint32_t kButtonHoldMs = 2000;
constexpr uint32_t kFaultBlinkHalfPeriodMs = 500;

// Plausible range of the jacket microclimate. Anything outside is treated as a read error.
constexpr float kMinPlausibleC = -40.0f;
constexpr float kMaxPlausibleC = 125.0f;

}  // namespace thermal
}  // namespace kinecto
