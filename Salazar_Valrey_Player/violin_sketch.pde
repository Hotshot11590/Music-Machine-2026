// Violin controller - Processing sketch
// Needs the Sound library (Sketch > Import Library > Manage Libraries > "Sound")
// Close the Arduino Serial Monitor before running this.
//
// CONTROLS
//   4 buttons ........ 4 notes of the scale
//   Joystick left/mid/right ... picks which group of 4 notes (12 notes total)
//   Joystick up/down . pitch bend (slide like a real violin string)
//   Joystick click ... hold for +1 octave
//   Dial 1 ........... volume
//   Slider ........... vibrato depth
//   Dial 2 ........... tone brightness (mellow -> bright)
//   LED .............. lights when you play the current practice target

import processing.serial.*;
import processing.sound.*;

// ---------- SETTINGS YOU CAN EDIT ----------
final int PORT_INDEX = 0;                  // check the console list on first run
final int ROOT = 60;                       // MIDI note of scale degree 0 (60 = middle C; violin lowest is 55)
final int[] SCALE = {0, 2, 4, 5, 7, 9, 11}; // major scale. Change to match your song's key/mode.

// Practice mode: enter YOUR transcription here as scale degrees (0 = ROOT, 1 = next scale note, ...
// up to 11). Leave empty for free play.
int[] MELODY = {};
// -------------------------------------------

Serial port;
int[] btn = new int[4];
int joyX = 2048, joyY = 2048, joySW = 0, volRaw = 2048, slideRaw = 0, dialRaw = 4095;

final float[] HARM = {1.0, 0.5, 0.33, 0.25, 0.2, 0.12};  // sawtooth-ish = string-like
SinOsc[] oscs = new SinOsc[HARM.length];
float env = 0, curFreq = 440;
boolean ledOn = false;
int melodyPos = 0;
boolean wasHeld = false;
int lastDegree = -1;

void setup() {
  size(640, 360);
  println(Serial.list());
  port = new Serial(this, Serial.list()[PORT_INDEX], 115200);
  port.bufferUntil('\n');
  for (int i = 0; i < oscs.length; i++) {
    oscs[i] = new SinOsc(this);
    oscs[i].amp(0);
    oscs[i].play();
  }
  textAlign(CENTER, CENTER);
}

void serialEvent(Serial p) {
  String s = p.readStringUntil('\n');
  if (s == null) return;
  String[] t = split(trim(s), ',');
  if (t.length != 11 || !t[0].equals("D")) return;
  for (int i = 0; i < 4; i++) btn[i] = int(t[i + 1]);
  joyX = int(t[5]); joyY = int(t[6]); joySW = int(t[7]);
  volRaw = int(t[8]); slideRaw = int(t[9]); dialRaw = int(t[10]);
}

int degreeToMidi(int degree) {
  return ROOT + 12 * (degree / SCALE.length) + SCALE[degree % SCALE.length];
}

String noteName(int midi) {
  String[] n = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"};
  return n[midi % 12] + (midi / 12 - 1);
}

void draw() {
  background(25, 20, 40);

  // which button is held (first one wins)
  int held = -1;
  for (int i = 3; i >= 0; i--) if (btn[i] == 1) held = i;

  // joystick X picks the bank of 4 notes
  float jx = joyX / 4095.0;
  int bank = (jx < 0.33) ? 0 : (jx > 0.66) ? 2 : 1;

  int degree = held < 0 ? -1 : bank * 4 + held;
  int midi = held < 0 ? 0 : degreeToMidi(degree) + (joySW == 1 ? 12 : 0);

  // pitch bend (+/- 2 semitones) with a small dead zone
  float by = (joyY - 2048) / 2048.0;
  if (abs(by) < 0.1) by = 0;
  float bend = by * 2;

  // vibrato
  float depth = slideRaw / 4095.0 * 0.6;
  float vib = sin(TWO_PI * 5.5 * millis() / 1000.0) * depth;

  if (held >= 0) {
    float target = 440 * pow(2, (midi + bend + vib - 69) / 12.0);
    curFreq = (env < 0.05) ? target : lerp(curFreq, target, 0.35);  // small glide between notes
    env += (1 - env) * 0.25;
  } else {
    env *= 0.85;   // release
  }

  float vol = volRaw / 4095.0;
  float bright = map(dialRaw, 0, 4095, 0.3, 1.0);
  float norm = 0; for (float h : HARM) norm += h;
  for (int i = 0; i < oscs.length; i++) {
    oscs[i].freq(curFreq * (i + 1));
    oscs[i].amp(env * vol * 0.8 * (HARM[i] * pow(bright, i)) / norm);
  }

  // practice mode
  boolean match = false;
  if (MELODY.length > 0) {
    int target = MELODY[melodyPos % MELODY.length];
    match = (held >= 0 && degree == target);
    if (held >= 0 && !wasHeld && match) melodyPos++;   // advance on a correct new press
  }
  wasHeld = held >= 0;
  if (match != ledOn) { ledOn = match; port.write(ledOn ? 'L' : 'l'); }

  // display
  fill(255);
  textSize(48);
  text(held >= 0 ? noteName(midi) : "-", width / 2, 90);
  textSize(16);
  text("bank " + (bank + 1) + "   bend " + nf(bend, 1, 2) + "   vibrato " + nf(depth, 1, 2)
       + "   volume " + nf(vol, 1, 2), width / 2, 160);
  if (MELODY.length > 0) {
    int tdeg = MELODY[melodyPos % MELODY.length];
    text("Next target: bank " + (tdeg / 4 + 1) + ", button " + (tdeg % 4 + 1)
         + "  (" + noteName(degreeToMidi(tdeg)) + ")   step " + (melodyPos % MELODY.length + 1)
         + "/" + MELODY.length, width / 2, 220);
  } else {
    text("Free play. Add scale degrees to MELODY to practice a song.", width / 2, 220);
  }
}
