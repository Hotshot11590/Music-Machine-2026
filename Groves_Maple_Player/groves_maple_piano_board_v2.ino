/*
  HONKY TONK PIANO: 7 chord buttons
  Board code for the Adafruit HUZZAH32 (ESP32 Feather)

  What it does:
  When a button is pressed, sends one line to your laptop, like:   P,3
  (the number is the button, 0 to 6)

  Wiring (everything on the breadboard):
  Each button: one leg -> the pin below, the other leg -> GND rail (-).
  No resistors needed. Connect one board GND pin to the GND rail.

  Button 0 -> pin 14     Button 4 -> pin 27
  Button 1 -> pin 32     Button 5 -> pin 21
  Button 2 -> pin 15     Button 6 -> pin 13
  Button 3 -> pin 33
  (These are the numbers printed on the board.)
*/

// ---------- SETTINGS ----------
const int NUM_BUTTONS = 7;
const int BUTTON_PINS[NUM_BUTTONS] = {14, 32, 15, 33, 27, 21, 13};
const unsigned long DEBOUNCE_MS = 20;   // ignore flicker shorter than this
// ------------------------------

bool lastState[NUM_BUTTONS];
unsigned long lastChange[NUM_BUTTONS];

void setup() {
  Serial.begin(115200);
  for (int i = 0; i < NUM_BUTTONS; i++) {
    pinMode(BUTTON_PINS[i], INPUT_PULLUP);   // reads HIGH at rest, LOW when pressed
    lastState[i] = HIGH;
  }
}

void loop() {
  for (int i = 0; i < NUM_BUTTONS; i++) {
    bool state = digitalRead(BUTTON_PINS[i]);
    if (state != lastState[i] && millis() - lastChange[i] > DEBOUNCE_MS) {
      lastChange[i] = millis();
      lastState[i] = state;
      if (state == LOW) {            // just pressed
        Serial.print("P,");          // SEND: a line like P,3
        Serial.println(i);
      }
    }
  }
}