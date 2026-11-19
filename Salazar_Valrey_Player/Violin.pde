// Violin — hold a button to bow a string, move your hand to finger it.
//   Buttons 1-4 = G, D, A, E strings. Hold two to play both at once.
//   Hand near the sensor = higher notes, no hand = the open string.
//   C       calibrate: for 3 seconds, move your hand from closest to farthest
//   S       switch between snapping to scale notes and smooth sliding
// No board plugged in? Hold keys 1-4 to bow and move the mouse left/right to finger.
// Sound goes out through Java's built-in audio, so no extra libraries are needed.

import processing.serial.*;
import javax.sound.sampled.*;

final int BAUD = 115200;
final String[] STRING_NAMES = {"G", "D", "A", "E"};
final int[] OPEN_MIDI = {55, 62, 69, 76};   // G3, D4, A4, E5
final int[] G_MAJOR = {7, 9, 11, 0, 2, 4, 6};  // pitch classes in G major
final String[] NOTE_NAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"};
final int STEPS = 8;  // open string up to the octave

Serial port;
String status = "";
int[][] notes = new int[4][STEPS];   // MIDI note for each finger step on each string
final int RATE = 44100;
float[] oscFreq = new float[4];   // set by draw(), played by audioLoop()
float[] oscAmp = new float[4];
float[] amp = new float[4];

float nearCm = 5, farCm = 50;   // hand range, changed by calibration
float handCm = -1;
int lastReading = -10000;       // millis() of the last hand reading
int boardMask = 0;              // buttons held on the ESP32
boolean[] keyHeld = new boolean[4];
float pos = 0;                  // 0 = open string .. 1 = octave, smoothed
float bend = 0;                 // smoothed pitch offset in scale steps
boolean snap = true;

boolean calibrating = false;
int calStart;
float calMin, calMax;

void setup() {
  size(1000, 600);
  pixelDensity(displayDensity());
  textAlign(CENTER, CENTER);
  for (int s = 0; s < 4; s++) {
    int m = OPEN_MIDI[s];
    for (int i = 0; i < STEPS; i++) {
      while (!inScale(m)) m++;
      notes[s][i] = m;
      m++;
    }
  }
  thread("audioLoop");
  openPort();
}

// One saw wave per string, mixed and softened by a low-pass filter so it
// sounds string-like, then streamed to the speakers.
void audioLoop() {
  try {
    AudioFormat fmt = new AudioFormat(RATE, 16, 1, true, false);
    SourceDataLine speaker = AudioSystem.getSourceDataLine(fmt);
    // Same as speaker.open(fmt, 4096) — Processing's parser rejects the word "open" here.
    SourceDataLine.class.getMethod("open", AudioFormat.class, int.class).invoke(speaker, fmt, 4096);
    speaker.start();
    byte[] buf = new byte[512];
    float[] phase = new float[4];
    float[] level = new float[4];
    float filtered = 0;
    float cutoff = 1 - exp(-TWO_PI * 2200 / RATE);
    while (true) {
      for (int k = 0; k < buf.length; k += 2) {
        float mix = 0;
        for (int s = 0; s < 4; s++) {
          level[s] += (oscAmp[s] - level[s]) * 0.002;  // smooth volume changes, no clicks
          phase[s] += oscFreq[s] / RATE;
          if (phase[s] >= 1) phase[s] -= 1;
          mix += (phase[s] * 2 - 1) * level[s];
        }
        filtered += (mix - filtered) * cutoff;
        int v = (int)(constrain(filtered, -1, 1) * 32767);
        buf[k] = (byte)v;
        buf[k + 1] = (byte)(v >> 8);
      }
      speaker.write(buf, 0, buf.length);
    }
  } catch (Exception e) {
    status = "No audio output: " + e.getMessage();
  }
}

boolean inScale(int midi) {
  for (int pc : G_MAJOR) if (midi % 12 == pc) return true;
  return false;
}

float midiFreq(float m) { return 440 * pow(2, (m - 69) / 12.0); }
String noteName(int m) { return NOTE_NAMES[m % 12] + (m / 12 - 1); }

void openPort() {
  // Only the cu. ports — opening the matching tty. one too gives "Port busy".
  for (String name : Serial.list()) {
    if (name.startsWith("/dev/cu.usbserial") || name.startsWith("/dev/cu.SLAB") || name.startsWith("/dev/cu.wchusbserial")) {
      try {
        port = new Serial(this, name, BAUD);
        port.bufferUntil('\n');
        status = "ESP32 on " + name;
        return;
      } catch (Exception e) {
        status = "Couldn't open " + name + " (close the Arduino Serial Monitor)";
      }
    }
  }
  if (port == null && status.equals("")) status = "No ESP32 found — hold keys 1-4 and move the mouse to play";
}

void serialEvent(Serial p) {
  String line = p.readStringUntil('\n');
  if (line == null) return;
  String[] parts = split(trim(line), ',');
  if (parts.length < 2) return;
  try {
    float cm = Float.parseFloat(parts[0]);
    boardMask = Integer.parseInt(parts[1]);
    if (cm > 0) {
      handCm = cm;
      lastReading = millis();
      if (calibrating) {
        calMin = min(calMin, cm);
        calMax = max(calMax, cm);
      }
    }
  } catch (NumberFormatException e) { }
}

void keyPressed() {
  if (key >= '1' && key <= '4') keyHeld[key - '1'] = true;
  else if (key == 'c' || key == 'C') {
    calibrating = true;
    calStart = millis();
    calMin = 9999;
    calMax = 0;
  } else if (key == 's' || key == 'S') {
    snap = !snap;
  }
}

void keyReleased() {
  if (key >= '1' && key <= '4') keyHeld[key - '1'] = false;
}

boolean bowed(int s) {
  return (boardMask >> s & 1) == 1 || keyHeld[s];
}

boolean handPresent() {
  return millis() - lastReading < 250;
}

// How far up the string the finger is: 0 = open string, 1 = the octave.
float target() {
  if (port == null || !handPresent()) {
    if (port == null && mouseX > 0) return constrain(map(mouseX, 100, width - 100, 0, 1), 0, 1);
    return 0;
  }
  return constrain(map(handCm, farCm, nearCm, 0, 1), 0, 1);
}

float stringMidi(int s) {
  float f = bend;
  if (snap) return notes[s][round(f)];
  int i = min(floor(f), STEPS - 2);
  return lerp(notes[s][i], notes[s][i + 1], f - i);
}

void draw() {
  background(24, 18, 16);

  if (calibrating && millis() - calStart > 3000) {
    calibrating = false;
    if (calMax - calMin > 5) {
      nearCm = calMin;
      farCm = calMax;
    }
  }

  pos += (target() - pos) * 0.25;
  bend += (pos * (STEPS - 1) - bend) * (snap ? 0.5 : 0.25);

  // Sound: each bowed string fades in, with a little vibrato.
  float vibrato = 0.08 * sin(millis() * 0.033);
  for (int s = 0; s < 4; s++) {
    boolean on = bowed(s) && !calibrating;
    amp[s] += ((on ? 0.3 : 0) - amp[s]) * (on ? 0.15 : 0.08);
    oscFreq[s] = midiFreq(stringMidi(s) + vibrato * amp[s] * 3);
    oscAmp[s] = amp[s];
  }

  drawViolin();

  fill(180);
  textSize(13);
  text(status, width / 2, 24);
  text("Buttons 1-4 = G D A E strings    C = calibrate (" + nf(nearCm, 0, 1) + "–" + nf(farCm, 0, 1) + " cm)    S = " + (snap ? "snap to notes" : "smooth slide"), width / 2, height - 24);
  if (calibrating) {
    fill(255, 200, 80);
    textSize(22);
    text("Calibrating… move your hand from closest to farthest (" + (3 - (millis() - calStart) / 1000) + ")", width / 2, 110);
  }
}

void drawViolin() {
  float left = 120, right = width - 100;
  float top = height / 2 - 90, gap = 60;
  int step = snap ? round(bend) : -1;

  // Fingerboard
  noStroke();
  fill(30, 22, 18);
  rect(left - 30, top - 30, right - left + 50, gap * 3 + 60, 16);

  // Finger position markers
  for (int i = 0; i < STEPS; i++) {
    float x = map(i, 0, STEPS - 1, left, right);
    stroke(i == step ? color(255, 210, 120, 160) : color(70, 55, 45));
    strokeWeight(i == step ? 3 : 1);
    line(x, top - 30, x, top + gap * 3 + 30);
  }

  // Strings: E at the top like looking down at a violin, G at the bottom
  for (int s = 0; s < 4; s++) {
    float y = top + (3 - s) * gap;
    float a = amp[s] / 0.3;
    color c = lerpColor(color(150, 140, 130), color(255, 225, 160), a);

    // Glow while bowed
    if (a > 0.02) {
      noStroke();
      fill(255, 200, 120, 40 * a);
      rect(left - 30, y - 14 * a, right - left + 50, 28 * a);
    }

    stroke(c);
    strokeWeight(map(s, 0, 3, 3.5, 1.5));
    noFill();
    beginShape();
    for (float x = left - 30; x <= right + 20; x += 5) {
      float t = (x - left + 30) / (right - left + 50);
      vertex(x, y + sin(t * PI) * sin(frameCount * 1.3 + s) * 8 * a);
    }
    endShape();

    // String label and note names along it
    textSize(18);
    fill(c);
    text(STRING_NAMES[s], left - 60, y);
    textSize(10);
    for (int i = 0; i < STEPS; i++) {
      fill(i == step && a > 0.1 ? color(255, 230, 160) : color(110, 95, 80));
      text(noteName(notes[s][i]), map(i, 0, STEPS - 1, left, right) + 14, y - 12);
    }

    // Finger on each bowed string
    if (a > 0.05) {
      float fx = map(bend, 0, STEPS - 1, left, right);
      noStroke();
      fill(255, 90, 120, 90 * a);
      ellipse(fx, y, 44, 44);
      fill(255, 90, 120, 255 * a);
      ellipse(fx, y, 16, 16);
    }
  }

  // Bow sweeps back and forth while anything is sounding
  float total = 0;
  for (int s = 0; s < 4; s++) total = max(total, amp[s] / 0.3);
  float bowY = top - 70 + sin(millis() * 0.004) * 4;
  float bowShift = sin(millis() * 0.0025) * 120 * total;
  stroke(200, 170, 120, 50 + 205 * total);
  strokeWeight(4);
  line(width / 2 - 250 + bowShift, bowY, width / 2 + 250 + bowShift, bowY);
  stroke(240, 235, 220, 50 + 205 * total);
  strokeWeight(1.5);
  line(width / 2 - 245 + bowShift, bowY + 6, width / 2 + 245 + bowShift, bowY + 6);

  // Readout: notes currently sounding and hand distance
  String playing = "";
  for (int s = 0; s < 4; s++) if (bowed(s)) playing += (playing.length() > 0 ? " + " : "") + noteName(round(stringMidi(s)));
  textSize(34);
  fill(playing.length() > 0 ? color(255, 225, 160) : color(90));
  text(playing.length() > 0 ? playing : "hold a button to bow", width / 2, 70);
  textSize(14);
  fill(160);
  text(handPresent() ? nf(handCm, 0, 1) + " cm" : "no hand — open string", width / 2, top + gap * 3 + 60);
}
