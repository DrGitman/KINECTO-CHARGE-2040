#include <string.h>
#include <unity.h>

#include "EventFormatter.h"
#include "SensorMonitor.h"
#include "StatusLight.h"
#include "ThermalConfig.h"

using namespace kinecto::thermal;

namespace {
constexpr int64_t kSampleEpoch = 1792049400;  // 2026-10-15T07:30:00Z
}

void setUp() {}
void tearDown() {}

void test_event_matches_thermal_json_entry() {
  const ThermalEvent event{kSampleEpoch,         State::Auto, Reason::AutoHeatOn, validReading(18.6f),
                           validReading(13.6f), LoadState{true, false}, Fault::None};
  char line[kEventJsonMaxLength];
  TEST_ASSERT_TRUE(formatEventJson(event, line, sizeof(line)) > 0);
  TEST_ASSERT_EQUAL_STRING(
      "{\"ts\":\"2026-10-15T07:30:00Z\",\"state\":\"AUTO\",\"reason\":\"auto_heat_on\","
      "\"inside_c\":18.6,\"ambient_c\":13.6,\"heater_on\":true,\"blower_on\":false,"
      "\"fault\":null}",
      line);
}

void test_fault_event_has_null_inside_and_fault_name() {
  const ThermalEvent event{kSampleEpoch,         State::Fault, Reason::SensorError, failedReading(),
                           validReading(29.6f), kAllLoadsOff, Fault::InsideSensorSilent};
  char line[kEventJsonMaxLength];
  formatEventJson(event, line, sizeof(line));
  TEST_ASSERT_NOT_NULL(strstr(line, "\"inside_c\":null"));
  TEST_ASSERT_NOT_NULL(strstr(line, "\"fault\":\"inside_sensor_silent\""));
}

void test_too_small_buffer_returns_zero() {
  const ThermalEvent event{kSampleEpoch, State::Off, Reason::PowerOn, validReading(18.6f),
                           validReading(13.5f), kAllLoadsOff, Fault::None};
  char line[16];
  TEST_ASSERT_EQUAL(0, formatEventJson(event, line, sizeof(line)));
  TEST_ASSERT_EQUAL_STRING("", line);
}

void test_sensor_monitor_rejects_implausible_values() {
  SensorMonitor monitor(kMissesBeforeSilent);
  monitor.record(validReading(kMaxPlausibleC + 1.0f));
  TEST_ASSERT_FALSE(monitor.latest().valid);
  monitor.record(validReading(21.0f));
  TEST_ASSERT_TRUE(monitor.latest().valid);
  TEST_ASSERT_FALSE(monitor.isSilent());
}

void test_status_light_blinks_red_in_fault_only() {
  TEST_ASSERT_TRUE(statusColorFor(State::Fault, 0, kFaultBlinkHalfPeriodMs) == kFaultColor);
  TEST_ASSERT_TRUE(statusColorFor(State::Fault, kFaultBlinkHalfPeriodMs, kFaultBlinkHalfPeriodMs) ==
                   kLightOff);
  TEST_ASSERT_TRUE(statusColorFor(State::Warm, kFaultBlinkHalfPeriodMs, kFaultBlinkHalfPeriodMs) ==
                   kWarmColor);
  TEST_ASSERT_TRUE(statusColorFor(State::Off, 0, kFaultBlinkHalfPeriodMs) == kLightOff);
}

int main(int, char**) {
  UNITY_BEGIN();
  RUN_TEST(test_event_matches_thermal_json_entry);
  RUN_TEST(test_fault_event_has_null_inside_and_fault_name);
  RUN_TEST(test_too_small_buffer_returns_zero);
  RUN_TEST(test_sensor_monitor_rejects_implausible_values);
  RUN_TEST(test_status_light_blinks_red_in_fault_only);
  return UNITY_END();
}
