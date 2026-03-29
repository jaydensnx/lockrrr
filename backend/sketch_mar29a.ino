/*
 * =============================================================================
 * sketch_mar29a.ino — Box open/closed reporter (HTTP POST) for ESP32
 * =============================================================================
 *
 * PURPOSE
 *   Reads a digital input (reed or limit switch) wired to a GPIO and reports
 *   whether a box is OPEN or CLOSED to a remote HTTPS endpoint. Each update
 *   is sent as a JSON POST body: {"open":true} or {"open":false}.
 *
 * HARDWARE (typical)
 *   - Connect one side of the switch to GND and the other to BOX_PIN (default 4).
 *   - INPUT_PULLUP holds the pin HIGH when the switch is open; closing the switch
 *     pulls it LOW (common for reed switches with NO contact to GND).
 *   - If your physical wiring is inverted, swap OPEN_LEVEL and CLOSED_LEVEL.
 *
 * NETWORK
 *   - Requires Wi‑Fi (station mode). Fill in WIFI_SSID and WIFI_PASSWORD.
 *   - SERVER_URL must be HTTPS if you use TLS on nginx; the sketch uses
 *     WiFiClientSecure with setInsecure() for quick testing (no CA bundle).
 *     For production, pin your server certificate or use setCACert().
 *
 * SERVER
 *   - Your backend should accept POST with Content-Type: application/json and
 *     optionally validate X-API-Key to match API_KEY below.
 *   - Optional remote unlock: the firmware can GET SERVER_UNLOCK_URL periodically.
 *     Your Digital Ocean app should return JSON such as {"unlock":true} when you
 *     want the ESP32 to pulse the lock (clear or set false after the device polls
 *     so it does not re-trigger forever — your server’s responsibility).
 *
 * FLOW (summary)
 *   setup()  → Serial, pin mode, Wi‑Fi connect
 *   loop()   → If Wi‑Fi down, retry periodically; else read pin, debounce,
 *              map to logical open/closed, send POST when state is new or retry.
 *
 * MERGING WITH OTHER SKETCHES
 *   `BOX_PIN` is optional: use any GPIO that fits your board and wiring. When you
 *   merge this sketch with `sketch_mar6a.ino` or `box_websocket.ino`, give each
 *   peripheral (hall sensor, relay, box switch, etc.) its own pin so there are
 *   no duplicate assignments.
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>

// --- Wi‑Fi credentials (replace before upload) ---
const char *WIFI_SSID = "YOUR_WIFI_SSID";
const char *WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// --- HTTPS endpoint that receives JSON POST (full URL including path) ---
// Example: https://yourdomain.com/api/box/state
const char *SERVER_URL = "https://yourdomain.com/api/box/state";

// GET endpoint: server signals “unlock now” (JSON body must include unlock:true).
// Example: https://yourdomain.com/api/box/command — implement on your backend.
const char *SERVER_UNLOCK_URL = "https://yourdomain.com/api/box/command";

// Shared secret; your nginx/app should reject requests without this header.
const char *API_KEY = "change-this-to-a-long-random-string";

// --- GPIO for box switch (optional pin — change if merging with other sketches) ---
const int BOX_PIN = 4;

// Locking mechanism output (relay, strike, etc.) — optional pin; wire when hardware exists.
// const int UNLOCK_PIN = 18;
// const unsigned long UNLOCK_PULSE_MS = 3000; // how long to hold unlock active (example)

// After debouncing, digitalRead == OPEN_LEVEL means "box open" (we send open:true).
// digitalRead == CLOSED_LEVEL means "box closed" (we send open:false).
const int CLOSED_LEVEL = LOW;
const int OPEN_LEVEL = HIGH;

// Ignore pin jitter for this many ms after the last raw change (prevents bounce).
const unsigned long DEBOUNCE_MS = 50;

// When Wi‑Fi is lost, how long to wait before trying connectWifi() again.
const unsigned long WIFI_RETRY_MS = 5000;

// State machine & sync tracking (see loop() comments).
int lastStableState = -1;       // Last debounced logical state (-1 = unknown at boot)
unsigned long lastDebounceTime = 0;
int lastRawReading = -1;        // Previous raw digitalRead for debounce edge detect
int lastSentToServer = -1;      // Last value successfully acknowledged by server (0 or 1)
unsigned long lastSendAttempt = 0;

// Minimum gap between automatic retries after a failed send (not after a new lid event).
const unsigned long SEND_RETRY_MS = 10000;

// How often to ask the server whether it wants us to unlock (avoid hammering DO).
const unsigned long UNLOCK_POLL_MS = 5000;

unsigned long lastUnlockPoll = 0;

void setup() {
  Serial.begin(115200);
  pinMode(BOX_PIN, INPUT_PULLUP);

  // When you add a relay or strike, configure UNLOCK_PIN here, e.g.:
  // pinMode(UNLOCK_PIN, OUTPUT);
  // digitalWrite(UNLOCK_PIN, LOW);

  // Station only: ESP32 joins your router; it is not an access point.
  WiFi.mode(WIFI_STA);
  connectWifi();
}

/*
 * Blocks up to ~20s while associating with the AP. On failure, loop() will retry.
 */
void connectWifi() {
  Serial.print("Connecting to Wi-Fi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 20000) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("Wi-Fi OK, IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("Wi-Fi failed — will retry in loop.");
  }
}

/*
 * Opens one HTTPS request: POST JSON body, checks 2xx. New connection each call
 * (simple; not as efficient as a persistent WebSocket — see box_websocket.ino).
 */
bool sendStateToServer(int state) {
  if (WiFi.status() != WL_CONNECTED) {
    return false;
  }

  HTTPClient http;
  WiFiClientSecure client;
  // Skips certificate validation — convenient for dev; use setCACert in production.
  client.setInsecure();

  if (!http.begin(client, SERVER_URL)) {
    Serial.println("http.begin failed");
    return false;
  }

  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-API-Key", API_KEY);

  // state 1 → open box → {"open":true}; state 0 → {"open":false}
  String body = "{\"open\":";
  body += (state == 1 ? "true" : "false");
  body += "}";

  int code = http.POST(body);
  Serial.printf("HTTP %d\n", code);
  if (code > 0) {
    Serial.println(http.getString());
  }
  http.end();
  return code >= 200 && code < 300;
}

/*
 * Polls the server for an unlock instruction. Your API should return HTTP 200 and a
 * JSON body that includes unlock set to true when the operator requests open, e.g.
 *   {"unlock":true}
 * After the ESP32 acts, your server should flip unlock back to false (or use a
 * one-shot id) so the same command is not applied every poll.
 *
 * Parsing is intentionally minimal (substring match) so you do not need ArduinoJson.
 */
bool serverRequestsUnlock() {
  if (WiFi.status() != WL_CONNECTED) {
    return false;
  }

  HTTPClient http;
  WiFiClientSecure client;
  client.setInsecure();

  if (!http.begin(client, SERVER_UNLOCK_URL)) {
    return false;
  }

  http.addHeader("X-API-Key", API_KEY);
  int code = http.GET();
  String body = http.getString();
  http.end();

  if (code < 200 || code >= 300) {
    return false;
  }

  // Expect {"unlock":true} (space optional). Tighten further if your API adds other booleans.
  if (body.indexOf("\"unlock\":true") >= 0) {
    return true;
  }
  if (body.indexOf("\"unlock\": true") >= 0) {
    return true;
  }
  return false;
}

/*
 * Drives the physical lock. Uncomment when UNLOCK_PIN and hardware are ready.
 */
void performUnlockFromServerCommand() {
  Serial.println("Server requested unlock — run lock hardware here.");

  // --- Locking mechanism (uncomment when wired) ---
  // digitalWrite(UNLOCK_PIN, HIGH);
  // delay(UNLOCK_PULSE_MS);
  // digitalWrite(UNLOCK_PIN, LOW);
}

void loop() {
  // --- Wi‑Fi watchdog: do not hammer sensor logic while disconnected ---
  if (WiFi.status() != WL_CONNECTED) {
    static unsigned long lastTry = 0;
    if (millis() - lastTry >= WIFI_RETRY_MS) {
      lastTry = millis();
      connectWifi();
    }
    delay(200);
    return;
  }

  // --- Poll Digital Ocean for “unlock” command (independent of lid sensor) ---
  if (millis() - lastUnlockPoll >= UNLOCK_POLL_MS) {
    lastUnlockPoll = millis();
    if (serverRequestsUnlock()) {
      performUnlockFromServerCommand();
    }
  }

  // --- Raw read and debounce: wait until pin is stable for DEBOUNCE_MS ---
  int reading = digitalRead(BOX_PIN);

  if (reading != lastRawReading) {
    lastDebounceTime = millis();
    lastRawReading = reading;
  }

  if (millis() - lastDebounceTime < DEBOUNCE_MS) {
    return;
  }

  // Map pin level to 1 = open, 0 = closed (adjust OPEN_LEVEL/CLOSED_LEVEL if needed).
  int logical = (reading == OPEN_LEVEL) ? 1 : 0;

  bool stateJustChanged = false;
  if (logical != lastStableState) {
    lastStableState = logical;
    stateJustChanged = true;
    Serial.printf("Box state changed: %s\n", logical == 1 ? "OPEN (1)" : "CLOSED (0)");
  }

  // Already synced to server for this logical state — nothing to do.
  if (logical == lastSentToServer) {
    return;
  }

  // Throttle retries: after a failed POST, wait SEND_RETRY_MS unless the user
  // just moved the lid (stateJustChanged), so new events are not delayed.
  if (!stateJustChanged && millis() - lastSendAttempt < SEND_RETRY_MS && lastSendAttempt != 0) {
    return;
  }
  lastSendAttempt = millis();

  if (sendStateToServer(logical)) {
    lastSentToServer = logical;
  } else {
    Serial.println("Send failed; retrying later.");
  }
}
