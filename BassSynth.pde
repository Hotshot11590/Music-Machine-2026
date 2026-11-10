// ESP32 Bass — sound side (Processing 4 + the Sound library)
//
// Listens to the BassController sketch over USB serial and plays a plucked bass string.
// The tone is synthesized with Karplus-Strong (a burst of noise looping through a short,
// slowly damped delay line), the classic way to fake a plucked string. Every note is
// pre-rendered once at startup, so playing is instant.
//
// No board plugged in? Press 1, 2, 3 to pluck E, A, D open, to check your speakers.
// Close the Arduino IDE's Serial Monitor first: only one program can use the port.

import processing.serial.*;
import processing.sound.*;

final int[]    OPEN_MIDI = {28, 33, 38};   // E1, A1, D2: the bottom three bass strings
final String[] STRING_NAMES = {"E", "A", "D"};
final int      FRETS = 4;                  // open + 3 buttons
final int      RATE = 44100;
final float    NOTE_SECONDS = 3.0;
final String[] NOTE_NAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"};

AudioSample[][] notes = new AudioSample[STRING_NAMES.length][FRETS];
AudioSample[] ringing = new AudioSample[STRING_NAMES.length];
float[] ringAmp = new float[STRING_NAMES.length];
int[] ringFret = new int[STRING_NAMES.length];
int[] ringStartMs = new int[STRING_NAMES.length];

Serial port;
String portName = "";
int selectedString = 1, selectedFret = 0;
String lastEvent = "";

void setup() {
  size(900, 420);
  textFont(createFont("SansSerif", 16));
  for (int s = 0; s < STRING_NAMES.length; s++) {
    for (int f = 0; f < FRETS; f++) {
      notes[s][f] = new AudioSample(this, pluck(midiToFreq(OPEN_MIDI[s] + f)), RATE);
    }
  }
  connect();
}

// ---- Serial ---------------------------------------------------------------------------------

void connect() {
  String[] ports = Serial.list();
  println("Serial ports:");
  printArray(ports);
  // The HUZZAH32 shows up through its CP2104 USB chip as usbserial or SLAB_USBtoUART.
  for (String p : ports) {
    if (p.startsWith("/dev/cu.") && (p.contains("usbserial") || p.contains("SLAB") || p.contains("usbmodem"))) {
      portName = p;
      break;
    }
  }
  if (portName.isEmpty()) {
    println("No ESP32 found. Plug it in and restart, or set portName by hand.");
    return;
  }
  try {
    port = new Serial(this, portName, 115200);
    port.bufferUntil('\n');
  } catch (RuntimeException e) {
    println("Couldn't open " + portName + " (is the Serial Monitor open?): " + e.getMessage());
    port = null;
  }
}

void serialEvent(Serial p) {
  String line = p.readStringUntil('\n');
  if (line == null) return;
  line = trim(line);
  if (line.isEmpty() || line.startsWith("#")) {
    if (!line.isEmpty()) println(line);
    return;
  }
  String[] parts = splitTokens(line);
  try {
    if (parts[0].equals("P") && parts.length >= 4) {
      pluckString(int(parts[1]), int(parts[2]), int(parts[3]));
    } else if (parts[0].equals("H") && parts.length >= 3) {
      hammer(int(parts[1]), int(parts[2]));
    } else if (parts[0].equals("S") && parts.length >= 3) {
      selectedString = constrain(int(parts[1]), 0, STRING_NAMES.length - 1);
      selectedFret = constrain(int(parts[2]), 0, FRETS - 1);
    }
  } catch (Exception e) {
    println("Bad line: " + line);
  }
}

// ---- Playing --------------------------------------------------------------------------------

void pluckString(int s, int f, int velocity) {
  if (s < 0 || s >= STRING_NAMES.length || f < 0 || f >= FRETS) return;
  if (ringing[s] != null) ringing[s].stop();  // re-plucking a string cuts its last note
  float amp = map(constrain(velocity, 1, 127), 1, 127, 0.15, 1.0);
  AudioSample note = notes[s][f];
  note.amp(amp);
  note.play();
  ringing[s] = note;
  ringAmp[s] = amp;
  ringFret[s] = f;
  ringStartMs[s] = millis();
  lastEvent = "Pluck " + noteName(s, f) + "  (velocity " + velocity + ")";
}

// Fret changed while the string rings: switch to the new note, a bit quieter, like a hammer-on.
void hammer(int s, int f) {
  if (s < 0 || s >= STRING_NAMES.length || f < 0 || f >= FRETS || ringing[s] == null) return;
  float elapsed = (millis() - ringStartMs[s]) / 1000.0;
  if (elapsed > NOTE_SECONDS - 0.2) return;
  int previous = ringFret[s];
  ringing[s].stop();
  float amp = ringAmp[s] * 0.65 * (1 - elapsed / NOTE_SECONDS);
  AudioSample note = notes[s][f];
  note.amp(max(0.05, amp));
  note.cue(min(elapsed, NOTE_SECONDS - 0.3));  // pick up the decay where the old note was
  note.play();
  ringing[s] = note;
  ringAmp[s] = amp;
  ringFret[s] = f;
  lastEvent = (f > previous ? "Hammer-on " : "Pull-off ") + noteName(s, f);
}

void keyPressed() {
  if (key >= '1' && key <= '3') {
    selectedString = key - '1';
    pluckString(selectedString, 0, 100);
  }
}

// ---- Synthesis ------------------------------------------------------------------------------

float midiToFreq(int midi) {
  return 440 * pow(2, (midi - 69) / 12.0);
}

String noteName(int s, int f) {
  int midi = OPEN_MIDI[s] + f;
  return NOTE_NAMES[midi % 12] + (midi / 12 - 1);
}

// Karplus-Strong plucked string.
float[] pluck(float freq) {
  int n = int(RATE * NOTE_SECONDS);
  float[] out = new float[n];
  int period = max(2, round(RATE / freq));
  float[] line = new float[period];

  // Excite with smoothed noise: a fingertip rather than a pick, for a rounder bass tone.
  float smooth = 0, mean = 0;
  for (int i = 0; i < period; i++) {
    smooth += 0.35 * (random(-1, 1) - smooth);
    line[i] = smooth;
    mean += smooth;
  }
  mean /= period;
  for (int i = 0; i < period; i++) line[i] -= mean;

  // Damping per trip round the loop, so every note fades to ~3% over NOTE_SECONDS.
  float decay = pow(0.03, 1.0 / (freq * NOTE_SECONDS));
  int idx = 0;
  float peak = 0;
  for (int i = 0; i < n; i++) {
    int next = (idx + 1) % period;
    out[i] = line[idx];
    line[idx] = decay * 0.5 * (line[idx] + line[next]);  // averaging = losing the highs, like a real string
    idx = next;
    peak = max(peak, abs(out[i]));
  }

  // Normalize, then fade the last 0.25 s so notes never end with a click.
  int fade = int(RATE * 0.25);
  for (int i = 0; i < n; i++) {
    out[i] *= 0.9 / max(peak, 1e-6);
    if (i > n - fade) out[i] *= (n - i) / (float) fade;
  }
  return out;
}

// ---- Display --------------------------------------------------------------------------------

void draw() {
  background(24, 26, 30);
  float left = 140, right = width - 40;
  float fretW = (right - left) / 4.0;

  // Frets (open + 3) and labels.
  for (int f = 0; f <= FRETS; f++) {
    float x = left + f * fretW;
    stroke(f == 0 ? 210 : 90);
    strokeWeight(f == 0 ? 6 : 3);
    line(x, 70, x, 330);
    if (f < FRETS) {
      fill(140);
      noStroke();
      textAlign(CENTER);
      text(f == 0 ? "open" : "fret " + f, x + fretW / 2, 355);
    }
  }

  // Strings: thick to thin, vibrating while they ring.
  for (int s = 0; s < STRING_NAMES.length; s++) {
    float y = 300 - s * 100;
    float age = (millis() - ringStartMs[s]) / 1000.0;
    boolean live = ringing[s] != null && ringing[s].isPlaying();
    float wobble = live ? ringAmp[s] * 10 * exp(-age * 1.5) : 0;
    boolean selected = s == selectedString;

    fill(selected ? color(255, 210, 90) : 160);
    noStroke();
    textAlign(RIGHT, CENTER);
    textSize(28);
    text(STRING_NAMES[s], left - 30, y);

    noFill();
    stroke(selected ? color(255, 210, 90) : color(190, 180, 160));
    strokeWeight(6 - s * 1.5);
    beginShape();
    for (float x = left; x <= right; x += 6) {
      float t = (x - left) / (right - left);
      vertex(x, y + wobble * sin(PI * t) * sin(millis() * 0.09 + s));
    }
    endShape();

    // Where the finger is.
    int f = live ? ringFret[s] : (selected ? selectedFret : -1);
    if (f > 0) {
      noStroke();
      fill(selected ? color(255, 210, 90) : 200);
      circle(left + (f - 0.5) * fretW, y, 22);
    }
  }

  fill(200);
  textSize(16);
  textAlign(LEFT);
  text(port != null ? "Connected: " + portName : "No ESP32 connected (keys 1–3 pluck E, A, D)", 20, 30);
  textAlign(RIGHT);
  text(lastEvent, width - 20, 30);
  textAlign(LEFT);
  fill(140);
  text("Selected: " + noteName(selectedString, selectedFret), 20, 400);
}
