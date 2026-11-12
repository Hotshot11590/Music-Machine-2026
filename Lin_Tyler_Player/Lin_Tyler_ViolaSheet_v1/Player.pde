// Player: decides which notes play and when.
//   Buttons (press, changeChord) pick WHICH notes.
//   The bow (bow) decides WHEN they sound and HOW LOUD.
// Sound only plays while a button is held and the bow is moving.

class Player {
  ArrayList<NoteEvent> events;
  Sound out;
  int idx = 0;  // the next note in the part

  NoteEvent lastEvent = null;                              // the note or chord being played
  ArrayList<Integer> fingered = new ArrayList<Integer>();  // which of its notes the buttons chose
  ArrayList<Integer> sounding = new ArrayList<Integer>();  // notes playing right now

  boolean buttonsHeld = false;
  int allUpTime = 0;                     // when the last button was let go
  boolean bowing = false;                // bow moving (or only just stopped)
  float speed = 0;                       // bow speed (units per second)
  float expression = QUIET_EXPRESSION;   // volume (0-127)
  float smoothPos = 0;                   // bow position with the wobble smoothed out
  float lastTime = -1;                   // time of the last reading (-1 = none yet)
  float lastMoveTime = -1;               // last time the bow was moving (-1 = not yet)
  ArrayDeque<float[]> history = new ArrayDeque<float[]>();  // recent {time, position} pairs

  Player(ArrayList<NoteEvent> events, Sound out) {
    this.events = events;
    this.out = out;
  }

  // ------------------------------------------------------------ buttons
  // Move to the next note and pick its notes: one per button held.
  void press(int buttonCount) {
    if (idx >= events.size()) return;  // end of the part
    lastEvent = events.get(idx);
    idx++;
    fingered = notesForButtons(lastEvent.midis, buttonCount);
    if (bowing && buttonsHeld) restartSound();
  }

  // A button joined the chord that just started: start its extra notes too.
  void changeChord(int buttonCount) {
    if (lastEvent == null) return;
    fingered = notesForButtons(lastEvent.midis, buttonCount);
    if (!(bowing && buttonsHeld)) return;
    for (int note : fingered) {
      if (!sounding.contains(note)) {
        out.send(ShortMessage.NOTE_ON, note, NOTE_VELOCITY);
        sounding.add(note);
      }
    }
  }

  void setButtonsHeld(boolean held, int now) {
    if (buttonsHeld && !held) allUpTime = now;
    buttonsHeld = held;
  }

  // Called every frame. Once every button has been up for RELEASE_MS, the
  // sound stops. Moving a finger to the next button is quicker than that,
  // so the notes connect without a gap.
  void checkRelease(int now) {
    if (!buttonsHeld && isSounding() && now - allUpTime >= RELEASE_MS) silence();
  }

  boolean isSounding() {
    return !sounding.isEmpty();
  }

  // Jump to a position in the part (arrow keys and R).
  void jump(int newIdx) {
    idx = constrain(newIdx, 0, events.size());
    lastEvent = null;
    fingered.clear();
    silence();
  }

  // ---------------------------------------------------------------- bow
  // Called for every reading from the ESP32: time (ms) and bow position (0-4095).
  void bow(float time, float pos) {
    // First reading, or the ESP32 restarted (its time went backwards): start fresh.
    if (lastTime < 0 || time < lastTime) {
      smoothPos = pos;
      lastTime = time;
      history.clear();
      lastMoveTime = -1;
      speed = 0;
      bowing = false;
      silence();
      return;
    }
    lastTime = time;

    // 1. Smooth the position: move 40% of the way toward each new reading.
    smoothPos += 0.4 * (pos - smoothPos);

    // 2. Speed = distance moved over the last SPEED_WINDOW_MS / time taken.
    history.addLast(new float[] { time, smoothPos });
    while (history.size() > 2 && time - history.peekFirst()[0] > SPEED_WINDOW_MS) {
      history.removeFirst();
    }
    float[] oldest = history.peekFirst();
    if (time > oldest[0]) {
      speed = abs(smoothPos - oldest[1]) / ((time - oldest[0]) / 1000.0);
    } else {
      speed = 0;
    }

    // 3. Moving? A short pause (turning the bow around) keeps the note going.
    if (speed > STOP_SPEED) lastMoveTime = time;
    boolean shouldSound = lastMoveTime >= 0 && time - lastMoveTime <= BOW_HOLD_MS;

    // 4. Volume follows speed, gliding instead of jumping.
    float level = constrain((speed - STOP_SPEED) / (FULL_SPEED - STOP_SPEED), 0, 1);
    float targetVolume = QUIET_EXPRESSION + (127 - QUIET_EXPRESSION) * sqrt(level);
    int before = int(expression);
    expression += VOLUME_GLIDE * (targetVolume - expression);
    if (int(expression) != before) {
      out.send(ShortMessage.CONTROL_CHANGE, 11, int(expression));  // 11 = expression (volume)
    }

    // 5. Start or stop the sound when the bow starts or stops.
    if (shouldSound && !bowing) {
      bowing = true;
      if (buttonsHeld) restartSound();
    } else if (!shouldSound && bowing) {
      bowing = false;
      silence();
    }
  }

  // -------------------------------------------------------------- sound
  // Stop whatever is playing, then start the chosen notes.
  void restartSound() {
    silence();
    for (int note : fingered) {
      out.send(ShortMessage.NOTE_ON, note, NOTE_VELOCITY);
    }
    sounding = new ArrayList<Integer>(fingered);
  }

  void silence() {
    for (int note : sounding) {
      out.send(ShortMessage.NOTE_OFF, note, 0);
    }
    sounding.clear();
  }
}
