/*
 * =============================================================================
 * sketch_mar6a.ino — Hall / magnet sensor + LED + relay “door unlock” demo (ESP32)
 * =============================================================================
 *
 * PURPOSE
 *   Reads a digital signal from a hall-effect (or reed-style) sensor to tell
 *   whether a magnet is near the sensor (“touching” / coupled) or not. Drives
 *   an LED to match that state and, on each pass through the loop, runs a timed
 *   relay pulse that simulates unlocking a door (or driving another load).
 *
 * HARDWARE NOTES
 *   - hallPin: connect your sensor’s digital output per its datasheet. Many boards
 *     output LOW when the magnetic field exceeds a threshold (magnet present) and
 *     HIGH otherwise — but parts vary. If “open” and “closed” messages look swapped,
 *     invert the tests in loop() or rewire per your module’s truth table.
 *   - ledPin: often GPIO2 on ESP32 dev boards has an onboard LED (active HIGH).
 *   - relayPin: drives a relay module; HIGH = relay energized (check whether your
 *     module is active-HIGH or active-LOW and add inversion if needed).
 *
 * BEHAVIOR SUMMARY
 *   - setup: serial at 115200, pins configured, relay starts OFF (door “locked”).
 *   - loop: read sensor → print + LED → short delay → then always run a fixed
 *     “unlock” sequence (relay on for unlockTime, then off, then a long pause).
 *     This pattern is useful for bench testing; for production you would usually
 *     trigger the relay only on specific events (e.g. magnet + button), not every
 *     loop iteration.
 *
 * MERGING WITH OTHER SKETCHES
 *   All GPIO numbers below are placeholders: change `hallPin`, `ledPin`, and
 *   `relayPin` to any valid ESP32 pins that match your wiring. When you combine
 *   this logic with `sketch_mar29a.ino` / `box_websocket.ino` in one firmware,
 *   assign each sensor, LED, relay, and box switch to different pins so nothing
 *   conflicts.
 */

// --- Pin map (values are optional — set to match your wiring / merged sketch) ---
const int hallPin = 17;   // Digital input: hall sensor output (see datasheet for levels)
const int ledPin = 2;     // Optional indicator LED (many ESP32 boards use GPIO2)
const int relayPin = 18;  // Output to relay module input

// How long the relay stays energized while “unlocked” (milliseconds).
const int unlockTime = 5000;

void setup() {
  // USB serial monitor — use 115200 baud on the PC side.
  Serial.begin(115200);

  // Sensor: plain INPUT assumes the hall module drives the line strongly.
  // If the line floats when idle, add INPUT_PULLUP or external pull resistors.
  pinMode(hallPin, INPUT);

  pinMode(ledPin, OUTPUT);
  pinMode(relayPin, OUTPUT);

  // Start with relay de-energized so the door (or load) begins in “locked” state.
  digitalWrite(relayPin, LOW);
}

void loop() {
  // Read once per iteration: HIGH/LOW depends on sensor + magnet position.
  int sensorState = digitalRead(hallPin);

  // This sketch assumes LOW means the magnetic condition you treat as “box opened”
  // (e.g. magnet present / reed closed). Change LOW/HIGH here if your sensor is opposite.
  if (sensorState == LOW) {
    Serial.println("Box opened");
    digitalWrite(ledPin, HIGH); // LED on while this condition is true
  } else {
    Serial.println("Box closed");
    digitalWrite(ledPin, LOW);
  }

  delay(200);

  // --- Timed “unlock” simulation (runs every loop after the sensor read above) ---
  // In a real project you might only call this when a card reader, button, or
  // valid state transition occurs — not unconditionally every cycle.
  Serial.println("Unlocking door...");

  digitalWrite(relayPin, HIGH); // Energize relay (unlock strike, motor, etc.)
  delay(unlockTime);            // Hold unlocked for this duration

  digitalWrite(relayPin, LOW);  // De-energize relay — back to locked

  Serial.println("Door locked.");

  // Pause before the next full cycle (reduces Serial spam and relay wear during tests).
  delay(10000);
}
