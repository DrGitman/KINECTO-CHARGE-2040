#include "StatusLight.h"

namespace kinecto {
namespace thermal {

RgbColor statusColorFor(State state, uint32_t nowMs, uint32_t blinkHalfPeriodMs) {
  switch (state) {
    case State::Off: return kLightOff;
    case State::Auto: return kAutoColor;
    case State::Cool: return kCoolColor;
    case State::Warm: return kWarmColor;
    case State::Fault: {
      if (blinkHalfPeriodMs == 0) {
        return kFaultColor;
      }
      const bool lit = (nowMs / blinkHalfPeriodMs) % 2 == 0;
      return lit ? kFaultColor : kLightOff;
    }
  }
  return kFaultColor;
}

}  // namespace thermal
}  // namespace kinecto
