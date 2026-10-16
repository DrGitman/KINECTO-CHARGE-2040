#include <unity.h>

#include "ThermalController.h"
#include "ThermalFakes.h"

using namespace kinecto::thermal;
using namespace kinecto::thermal::testing;

namespace {

FakeSensor inside;
FakeSensor ambient;
FakeLoads loads;
FakeEvents events;
FakeClock clock;
FakeLogger logger;
ThermalController* controller = nullptr;

ThermalController* makeController(const ThermalLimits& limits) {
  return new ThermalController(
      ControllerDependencies{inside, ambient, loads, events, clock, logger}, limits,
      kMissesBeforeSilent);
}

void startWith(float insideC) {
  inside.set(insideC);
  controller->start();
}

void tickWith(float insideC) {
  inside.set(insideC);
  controller->tick();
}

void pressMode(int times) {
  for (int i = 0; i < times; i++) controller->handleButton(ButtonAction::ShortPress);
}

void assertLastEvent(State state, Reason reason) {
  TEST_ASSERT_EQUAL_STRING(toString(state), toString(events.last().state));
  TEST_ASSERT_EQUAL_STRING(toString(reason), toString(events.last().reason));
}

}  // namespace

void setUp() {
  inside = FakeSensor();
  ambient = FakeSensor();
  loads = FakeLoads();
  events = FakeEvents();
  logger = FakeLogger();
  controller = makeController(kDefaultLimits);
}

void tearDown() {
  delete controller;
  controller = nullptr;
}

void test_power_on_is_off_with_loads_off() {
  startWith(18.0f);
  TEST_ASSERT_EQUAL(1, events.count);
  assertLastEvent(State::Off, Reason::PowerOn);
  TEST_ASSERT_FALSE(loads.heaterOn);
  TEST_ASSERT_FALSE(loads.blowerOn);
}

void test_off_never_heats_even_when_cold() {
  startWith(5.0f);
  tickWith(5.0f);
  TEST_ASSERT_FALSE(loads.heaterOn);
  TEST_ASSERT_EQUAL(1, events.count);
}

void test_mode_button_cycles_off_auto_cool_warm_off() {
  startWith(22.0f);
  pressMode(1);
  assertLastEvent(State::Auto, Reason::ModeButton);
  pressMode(1);
  assertLastEvent(State::Cool, Reason::ModeButton);
  pressMode(1);
  assertLastEvent(State::Warm, Reason::ModeButton);
  pressMode(1);
  assertLastEvent(State::Off, Reason::ModeButton);
}

void test_hold_returns_to_off_from_any_mode() {
  startWith(22.0f);
  pressMode(2);
  controller->handleButton(ButtonAction::Hold2s);
  assertLastEvent(State::Off, Reason::ModeHold2s);
}

void test_hold_in_off_publishes_nothing() {
  startWith(22.0f);
  controller->handleButton(ButtonAction::Hold2s);
  TEST_ASSERT_EQUAL(1, events.count);
}

void test_auto_heats_on_next_tick_with_hysteresis() {
  startWith(18.6f);
  pressMode(1);
  TEST_ASSERT_FALSE(loads.heaterOn);

  tickWith(18.6f);
  assertLastEvent(State::Auto, Reason::AutoHeatOn);
  TEST_ASSERT_TRUE(loads.heaterOn);

  tickWith(19.5f);
  TEST_ASSERT_TRUE(loads.heaterOn);

  tickWith(19.8f);
  assertLastEvent(State::Auto, Reason::AutoHeatOff);
  TEST_ASSERT_FALSE(loads.heaterOn);
}

void test_auto_cools_with_hysteresis() {
  startWith(22.0f);
  pressMode(1);
  tickWith(26.1f);
  assertLastEvent(State::Auto, Reason::AutoCoolOn);
  TEST_ASSERT_TRUE(loads.blowerOn);

  tickWith(25.5f);
  TEST_ASSERT_TRUE(loads.blowerOn);

  tickWith(25.3f);
  assertLastEvent(State::Auto, Reason::AutoCoolOff);
  TEST_ASSERT_FALSE(loads.blowerOn);
}

void test_auto_to_cool_keeps_blower_running() {
  startWith(22.0f);
  pressMode(1);
  tickWith(26.1f);
  pressMode(1);
  assertLastEvent(State::Cool, Reason::ModeButton);
  TEST_ASSERT_TRUE(events.last().loads.blowerOn);
}

void test_cool_runs_blower_continuously() {
  startWith(20.0f);
  pressMode(2);
  tickWith(20.0f);
  assertLastEvent(State::Cool, Reason::CoolBlowerOn);
  TEST_ASSERT_TRUE(loads.blowerOn);
  TEST_ASSERT_FALSE(loads.heaterOn);
}

void test_cool_to_warm_cuts_blower_then_heats_next_tick() {
  startWith(20.0f);
  pressMode(2);
  tickWith(20.0f);
  pressMode(1);
  assertLastEvent(State::Warm, Reason::ModeButton);
  TEST_ASSERT_FALSE(loads.blowerOn);
  TEST_ASSERT_FALSE(loads.heaterOn);

  tickWith(20.0f);
  assertLastEvent(State::Warm, Reason::WarmHeatOn);
  TEST_ASSERT_TRUE(loads.heaterOn);
  TEST_ASSERT_FALSE(loads.bothEverOn);
}

void test_warm_stops_at_comfort_ceiling_with_hysteresis() {
  startWith(25.0f);
  pressMode(3);
  tickWith(25.0f);
  TEST_ASSERT_TRUE(loads.heaterOn);

  tickWith(30.0f);
  assertLastEvent(State::Warm, Reason::WarmHeatOff);
  TEST_ASSERT_FALSE(loads.heaterOn);

  tickWith(29.5f);
  TEST_ASSERT_FALSE(loads.heaterOn);

  tickWith(29.2f);
  assertLastEvent(State::Warm, Reason::WarmHeatOn);
  TEST_ASSERT_TRUE(loads.heaterOn);
}

void test_cutoff_forces_fault_and_heater_off() {
  startWith(25.0f);
  pressMode(3);
  tickWith(25.0f);
  TEST_ASSERT_TRUE(loads.heaterOn);

  tickWith(42.0f);
  assertLastEvent(State::Fault, Reason::OverCutoff);
  TEST_ASSERT_EQUAL_STRING("heater_over_limit", toString(events.last().fault));
  TEST_ASSERT_FALSE(loads.heaterOn);
  TEST_ASSERT_FALSE(loads.blowerOn);
}

void test_single_missed_read_holds_outputs() {
  startWith(18.0f);
  pressMode(1);
  tickWith(18.0f);
  inside.fail();
  controller->tick();
  TEST_ASSERT_EQUAL_STRING("AUTO", toString(controller->state()));
  TEST_ASSERT_TRUE(loads.heaterOn);
}

void test_three_missed_inside_reads_trip_fault() {
  startWith(18.0f);
  pressMode(1);
  tickWith(18.0f);
  inside.fail();
  for (int i = 0; i < kMissesBeforeSilent; i++) controller->tick();

  assertLastEvent(State::Fault, Reason::SensorError);
  TEST_ASSERT_EQUAL_STRING("inside_sensor_silent", toString(events.last().fault));
  TEST_ASSERT_FALSE(events.last().inside.valid);
  TEST_ASSERT_FALSE(loads.heaterOn);
}

void test_silent_ambient_sensor_trips_fault() {
  startWith(22.0f);
  pressMode(1);
  ambient.fail();
  for (int i = 0; i < kMissesBeforeSilent; i++) controller->tick();
  TEST_ASSERT_EQUAL_STRING("ambient_sensor_silent", toString(controller->fault()));
}

void test_fault_ignores_mode_changes_and_hold() {
  startWith(22.0f);
  pressMode(1);
  tickWith(45.0f);
  const size_t countInFault = events.count;
  controller->handleButton(ButtonAction::Hold2s);
  tickWith(45.0f);
  TEST_ASSERT_EQUAL(countInFault, events.count);
  TEST_ASSERT_EQUAL_STRING("FAULT", toString(controller->state()));
}

void test_fault_clear_refused_while_still_over_cutoff() {
  startWith(22.0f);
  pressMode(1);
  tickWith(45.0f);
  pressMode(1);
  TEST_ASSERT_EQUAL_STRING("FAULT", toString(controller->state()));
  TEST_ASSERT_TRUE(logger.warnCount > 0);
}

void test_fault_clears_to_off_when_sensors_recover() {
  startWith(22.0f);
  pressMode(1);
  inside.fail();
  for (int i = 0; i < kMissesBeforeSilent; i++) controller->tick();

  tickWith(25.9f);
  pressMode(1);
  assertLastEvent(State::Off, Reason::FaultClearedModeButton);
  TEST_ASSERT_EQUAL_STRING(nullptr, toString(events.last().fault));
  TEST_ASSERT_FALSE(loads.heaterOn);
}

void test_invalid_limits_lock_loads_off() {
  const ThermalLimits overlapping{42.0f, 25.0f, 24.0f, 30.0f, 0.7f};
  delete controller;
  controller = makeController(overlapping);
  startWith(10.0f);
  pressMode(1);
  tickWith(10.0f);
  TEST_ASSERT_EQUAL_STRING("OFF", toString(controller->state()));
  TEST_ASSERT_FALSE(loads.heaterOn);
}

void test_heater_and_blower_never_on_together_over_a_day() {
  startWith(10.0f);
  pressMode(1);
  const float profile[] = {10.0f, 18.0f, 19.8f, 24.0f, 27.0f, 25.0f, 18.0f, 30.0f, 12.0f};
  for (float t : profile) tickWith(t);
  pressMode(1);
  tickWith(20.0f);
  pressMode(1);
  tickWith(20.0f);
  TEST_ASSERT_FALSE(loads.bothEverOn);
}

int main(int, char**) {
  UNITY_BEGIN();
  RUN_TEST(test_power_on_is_off_with_loads_off);
  RUN_TEST(test_off_never_heats_even_when_cold);
  RUN_TEST(test_mode_button_cycles_off_auto_cool_warm_off);
  RUN_TEST(test_hold_returns_to_off_from_any_mode);
  RUN_TEST(test_hold_in_off_publishes_nothing);
  RUN_TEST(test_auto_heats_on_next_tick_with_hysteresis);
  RUN_TEST(test_auto_cools_with_hysteresis);
  RUN_TEST(test_auto_to_cool_keeps_blower_running);
  RUN_TEST(test_cool_runs_blower_continuously);
  RUN_TEST(test_cool_to_warm_cuts_blower_then_heats_next_tick);
  RUN_TEST(test_warm_stops_at_comfort_ceiling_with_hysteresis);
  RUN_TEST(test_cutoff_forces_fault_and_heater_off);
  RUN_TEST(test_single_missed_read_holds_outputs);
  RUN_TEST(test_three_missed_inside_reads_trip_fault);
  RUN_TEST(test_silent_ambient_sensor_trips_fault);
  RUN_TEST(test_fault_ignores_mode_changes_and_hold);
  RUN_TEST(test_fault_clear_refused_while_still_over_cutoff);
  RUN_TEST(test_fault_clears_to_off_when_sensors_recover);
  RUN_TEST(test_invalid_limits_lock_loads_off);
  RUN_TEST(test_heater_and_blower_never_on_together_over_a_day);
  return UNITY_END();
}
