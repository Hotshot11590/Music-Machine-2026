/*
  Lesson 4: three foil pads, three drums
  Each pad sends its own word to Processing.

  Pad wiring (sockets on the right edge of the board):
    kick   -> 27
    snare  -> 33  (the socket right after 27)
    hi-hat -> 32  (skip 15, then the next one)
*/

// ---------- SETTINGS ----------
const int   PAD_COUNT = 3;
const int   PAD_PIN[PAD_COUNT]     = { 27,     33,      32      };  // NEW: one pin per pad
const char* PAD_WORD[PAD_COUNT]    = { "kick", "snare", "hihat" };  // NEW: one word per pad
int         TOUCH_LIMIT[PAD_COUNT] = { 500,    500,     500     };  // NEW: below this = hit. Tune each pad.
const int   LIGHT_PIN = 13;     // red light: on while any pad is touched

// Tuning mode: set to true to see all three pads as lines in Tools > Serial Plotter.
// No drum words are sent in tuning mode. Set back to false when done.
const bool  TUNING = false;
// ------------------------------

bool wasTouched[PAD_COUNT] = { false, false, false };
unsigned long lastChange[PAD_COUNT] = { 0, 0, 0 };

void setup() {
  Serial.begin(115200);
  pinMode(LIGHT_PIN, OUTPUT);
}

void loop() {
  bool anyTouched = false;

  if (TUNING) {
    // Prints like: kick:950 snare:940 hihat:960
    for (int i = 0; i < PAD_COUNT; i++) {
      Serial.print(PAD_WORD[i]); Serial.print(":"); Serial.print(touchRead(PAD_PIN[i]));
      Serial.print(i < PAD_COUNT - 1 ? " " : "\n");
    }
    delay(100);
    return;
  }

  for (int i = 0; i < PAD_COUNT; i++) {                        // NEW: check each pad in turn
    bool isTouched = (touchRead(PAD_PIN[i]) < TOUCH_LIMIT[i]); // READ this pad
    if (isTouched) anyTouched = true;

    if (isTouched != wasTouched[i] && millis() - lastChange[i] > 30) {
      lastChange[i] = millis();
      wasTouched[i] = isTouched;
      if (isTouched) {
        Serial.println(PAD_WORD[i]);                           // SEND this pad's word
      }
    }
  }

  digitalWrite(LIGHT_PIN, anyTouched ? HIGH : LOW);
}
