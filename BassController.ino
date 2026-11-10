// ESP32 Bass — controller side (Adafruit HUZZAH32 ESP32 Feather)
//
// Joystick up/down  = strum: each flick up or down plucks the string once.
//                     A faster flick plays louder.
// Joystick left/right (held while you flick) = which string: left E, center A, right D.
// Buttons           = frets 1, 2, 3. The highest pressed fret wins, like a real neck.
//                     Changing frets while a note rings slides to the new note (hammer-on / pull-off).
//
// Sends one text line per event over USB serial (115200) to the Processing sketch BassSynth:
//   P <string> <fret> <velocity>   pluck
//   H <string> <fret>              fret changed while the string is still ringing
//   S <string> <fret>              what's selected (for the on-screen display)

// ---- Pins ---------------------------------------------------------------------------------
// A2 (GPIO34) and A3 (GPIO39) are ADC1 inputs: steady readings, and they keep working if you
// ever turn on Wi-Fi/Bluetooth (the ADC2 pins don't).
const int PIN_STRUM  = A2;               // joystick U/D output
const int PIN_STRING = A3;               // joystick L/R output
const int FRET_PINS[3] = {14, 32, 33};   // fret 1, 2, 3 (labeled 14/A6, 32/A7, 33/A9)
// Avoid 12 (must be low at boot) and 34/36/39 (input-only, no pull-up) for buttons.

// ---- Feel -----------------------------------------------------------------------------------
const int  STRUM_ENTER   = 1100;  // how far from center (of ±2048) counts as a strum
const int  STRUM_EXIT    = 500;   // must come back this close to center before the next strum
const int  STRING_SIDE   = 700;   // how far left/right picks the E or D string
const bool INVERT_STRING = false; // set true if left and right come out swapped
const unsigned long RING_MS = 1800;   // how long a note counts as ringing (for hammer-ons)
const unsigned long DEBOUNCE_MS = 15;

// ---- State ----------------------------------------------------------------------------------
int centerY = 2048, centerX = 2048;
enum Zone { CENTER, UP, DOWN };
Zone zone = CENTER;
unsigned long leftCenterAt = 0;   // when the stick left center on this stroke (for velocity)
bool movingOut = false;

int ringingString = -1;
int ringingFret = 0;
unsigned long pluckedAt = 0;

int shownString = -1, shownFret = -1;

int fretRaw = 0, fretStable = 0;
unsigned long fretChangedAt = 0;

int readAverage(int pin, int samples) {
  long total = 0;
  for (int i = 0; i < samples; i++) total += analogRead(pin);
  return total / samples;
}

int readFret() {
  for (int i = 2; i >= 0; i--) {
    if (digitalRead(FRET_PINS[i]) == LOW) return i + 1;  // pressed connects the pin to GND
  }
  return 0;  // open string
}

int readString() {
  int dx = readAverage(PIN_STRING, 4) - centerX;
  if (INVERT_STRING) dx = -dx;
  if (dx < -STRING_SIDE) return 0;  // E
  if (dx >  STRING_SIDE) return 2;  // D
  return 1;                         // A
}

// Faster flick -> louder: ~5 ms is a hard strum, ~120 ms a gentle one.
int velocityFor(unsigned long ms) {
  ms = constrain(ms, 5, 120);
  return map(ms, 5, 120, 127, 35);
}

void setup() {
  Serial.begin(115200);
  analogReadResolution(12);  // 0–4095
  for (int pin : FRET_PINS) pinMode(pin, INPUT_PULLUP);

  // Don't touch the stick for the first half second: this learns where "center" is.
  delay(500);
  centerY = readAverage(PIN_STRUM, 64);
  centerX = readAverage(PIN_STRING, 64);
  Serial.printf("# ready, center Y=%d X=%d\n", centerY, centerX);
}

void loop() {
  unsigned long now = millis();

  // Frets, debounced.
  int raw = readFret();
  if (raw != fretRaw) {
    fretRaw = raw;
    fretChangedAt = now;
  }
  if (raw != fretStable && now - fretChangedAt >= DEBOUNCE_MS) {
    fretStable = raw;
    if (ringingString >= 0 && now - pluckedAt < RING_MS && fretStable != ringingFret) {
      ringingFret = fretStable;
      Serial.printf("H %d %d\n", ringingString, fretStable);
    }
  }

  // Strum.
  int dy = readAverage(PIN_STRUM, 4) - centerY;
  int distance = abs(dy);

  if (zone == CENTER) {
    if (distance > STRUM_EXIT && !movingOut) {
      movingOut = true;
      leftCenterAt = now;
    } else if (distance <= STRUM_EXIT) {
      movingOut = false;
    }
    if (distance > STRUM_ENTER) {
      zone = dy > 0 ? UP : DOWN;
      int string = readString();
      int velocity = velocityFor(now - leftCenterAt);
      ringingString = string;
      ringingFret = fretStable;
      pluckedAt = now;
      Serial.printf("P %d %d %d\n", string, fretStable, velocity);
    }
  } else if (distance < STRUM_EXIT) {
    zone = CENTER;  // back at rest: ready for the next stroke
    movingOut = false;
  }

  // Tell the display what's selected (only when it changes).
  int string = readString();
  if (string != shownString || fretStable != shownFret) {
    shownString = string;
    shownFret = fretStable;
    Serial.printf("S %d %d\n", string, fretStable);
  }

  delay(1);  // ~1 kHz loop: quick enough to time a flick
}
