#include <unity.h>

#include "ModeButton.h"
#include "ThermalConfig.h"

using namespace kinecto::thermal;

namespace {

ModeButton makeButton() { return ModeButton(kButtonDebounceMs, kButtonHoldMs); }

ButtonAction holdFor(ModeButton& button, uint32_t fromMs, uint32_t durationMs) {
  ButtonAction seen = ButtonAction::None;
  for (uint32_t t = fromMs; t <= fromMs + durationMs; t += 10) {
    const ButtonAction action = button.update(true, t);
    if (action != ButtonAction::None) seen = action;
  }
  return seen;
}

ButtonAction releaseAt(ModeButton& button, uint32_t atMs) {
  button.update(false, atMs);
  return button.update(false, atMs + kButtonDebounceMs);
}

}  // namespace

void setUp() {}
void tearDown() {}

void test_short_press_fires_on_release() {
  ModeButton button = makeButton();
  TEST_ASSERT_TRUE(holdFor(button, 0, 300) == ButtonAction::None);
  TEST_ASSERT_TRUE(releaseAt(button, 310) == ButtonAction::ShortPress);
}

void test_bounce_shorter_than_debounce_is_ignored() {
  ModeButton button = makeButton();
  button.update(true, 0);
  button.update(false, 5);
  TEST_ASSERT_TRUE(button.update(false, 5 + kButtonDebounceMs) == ButtonAction::None);
}

void test_hold_fires_once_and_release_is_silent() {
  ModeButton button = makeButton();
  TEST_ASSERT_TRUE(holdFor(button, 0, kButtonHoldMs + 500) == ButtonAction::Hold2s);
  TEST_ASSERT_TRUE(releaseAt(button, kButtonHoldMs + 600) == ButtonAction::None);
}

void test_works_across_millis_wrap() {
  ModeButton button = makeButton();
  const uint32_t nearWrap = 0xFFFFFF00u;
  holdFor(button, nearWrap, 200);
  TEST_ASSERT_TRUE(releaseAt(button, nearWrap + 300) == ButtonAction::ShortPress);
}

int main(int, char**) {
  UNITY_BEGIN();
  RUN_TEST(test_short_press_fires_on_release);
  RUN_TEST(test_bounce_shorter_than_debounce_is_ignored);
  RUN_TEST(test_hold_fires_once_and_release_is_silent);
  RUN_TEST(test_works_across_millis_wrap);
  return UNITY_END();
}
