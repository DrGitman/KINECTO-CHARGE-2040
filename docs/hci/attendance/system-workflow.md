# How Kinecto attendance works

## Purpose

The attendance system records when a student enters and leaves a class. The student taps the tag in their jacket cuff at the classroom reader. The tap is intentional. The jacket is not used to track the student around campus.

## Tap IN

A registered tag is read at a classroom reader. The system checks which session is open in that room, whether the student belongs to the module and whether the tap has already been recorded. A valid Tap IN records the student's arrival time and updates the lecturer's register.

## Tap OUT

When the student leaves, they tap again. The system records Tap OUT against the same session. A Tap OUT without a matching Tap IN is rejected and can be reviewed by the lecturer.

## Missed taps

If the tag cannot be read, the lecturer can mark the student present by hand. The lecturer must choose a reason. The correction is saved with the lecturer's name and time. A student who finds a mistake can send a message to the lecturer, but cannot change the register.

## Three ways to test or record a tap

The browser Tap Station lets us choose a sample tag and press Tap IN or Tap OUT. Unity simulates the cuff moving close to a classroom reader. A physical NFC reader is planned for later. All three should eventually use the same backend validation rules.

## Current state

The browser simulation works locally. Unity, Render and a real NFC reader are not connected to this version. The current browser records are not shared between different computers.
