#pragma once

#include <stddef.h>

#include "ThermalTypes.h"

namespace kinecto {
namespace thermal {

constexpr size_t kEventJsonMaxLength = 256;

// Writes one event as a single JSON line matching an entry of "events" in thermal.json.
// Returns the length written, or 0 if the buffer is too small.
size_t formatEventJson(const ThermalEvent& event, char* buffer, size_t bufferSize);

}  // namespace thermal
}  // namespace kinecto
