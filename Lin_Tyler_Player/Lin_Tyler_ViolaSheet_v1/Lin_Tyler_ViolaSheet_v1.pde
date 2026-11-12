// Rainbow Road viola - sheet music view
//
// Turns the ESP32 controller into a viola:
//   buttons = which notes: each press plays the next note of the part,
//             and more buttons held = more notes of a chord
//   bow (ultrasonic sensor) = when the notes sound, and how loud
// Sound only plays while a button is held AND the bow is moving.
//
// Tabs:
//   viola_sheet   setup, main loop, USB input, keys (this tab)
//   Notes         reads the part from data/viola_notes.txt
//   Player        decides which notes play and when
//   Sheet         loads the score images
//   SheetScreen   draws the window
//   Sound         sends notes to the computer's synthesizer (MIDI)

import processing.serial.*;
import javax.sound.midi.*;
import java.util.*;

// Settings
final String PORT_NAME = "COM7";   // the ESP32's USB port (Arduino IDE > Tools > Port)
final int BAUD = 115200;           // must match Serial.begin() on the ESP32
final int GM_VIOLA = 41;           // General MIDI instrument number for viola
final int NOTE_VELOCITY = 96;      // how hard notes start (0-127)
final int CHORD_WINDOW_MS = 100;   // buttons pressed this close together form one chord
final int DEBOUNCE_MS = 30;        // ignore button "bounce" shorter than this
final int RELEASE_MS = 300;        // the sound stops this long after every button is let go
final int BOW_MAX = 4095;          // the ESP32 sends bow positions from 0 to 4095
final int SPEED_WINDOW_MS = 60;    // bow speed is measured over this much time
final int STOP_SPEED = 350;        // slower than this counts as "bow not moving"
final int BOW_HOLD_MS = 1000;      // the note keeps going this long after the bow stops
final float FULL_SPEED = 6000;     // bow speed that gives full volume
final int QUIET_EXPRESSION = 80;   // volume of the slowest bowing (0-127)
final float VOLUME_GLIDE = 0.02;   // how fast the volume follows the bow (smaller = smoother)

ArrayList<NoteEvent> events = new ArrayList<NoteEvent>();  // the whole part
String loadError = null;
Player player;
Sound sound;
Serial port;
String portStatus = "";
int lastDataMs = -100000;          // when the last line from the ESP32 arrived

boolean[] buttonDown = new boolean[3];
int[] releaseMs = new int[3];      // when each button was last let go
int lastPressMs = -100000;         // when the last note started
float bowPos = 0;                  // latest bow position, for the meter

void setup() {
  size(1280, 720);
  surface.setTitle("Rainbow Road viola");
  loadFonts();
  try {
    events = loadEvents("viola_notes.txt");
    loadSheet("sheet_lines.txt");
  } catch (Exception e) {
    loadError = e.getMessage();
  }
  sound = new Sound(GM_VIOLA, QUIET_EXPRESSION);
  player = new Player(events, sound);

  try {
    port = new Serial(this, PORT_NAME, BAUD);
    portStatus = "No data on " + PORT_NAME + " yet (code uploaded? Serial Monitor closed?)";
  } catch (Exception e) {
    portStatus = PORT_NAME + " not found: check the USB cable, or change PORT_NAME";
  }
}

// Runs about 60 times per second.
void draw() {
  int now = millis();

  // Handle every complete line the ESP32 sent since the last frame.
  while (port != null && port.available() > 0) {
    String line = port.readStringUntil('\n');
    if (line == null) break;  // only half a line so far: the rest comes next frame
    handleLine(line, now);
  }

  player.checkRelease(now);
  drawScreen();
}

// A state line looks like "S 12345 2048 100": time, bow position, buttons 1/2/3.
void handleLine(String line, int now) {
  String[] parts = splitTokens(trim(line));
  if (parts.length != 4 || !parts[0].equals("S") || parts[3].length() != 3) return;

  lastDataMs = now;
  for (int b = 0; b < 3; b++) {
    buttonChange(b, parts[3].charAt(b) == '1', now);
  }
  bowPos = int(parts[2]);
  player.bow(int(parts[1]), bowPos);
}

// Called for each button on every line. A new press plays the next note right
// away; a button pressed within CHORD_WINDOW_MS of it joins that chord instead.
void buttonChange(int b, boolean down, int now) {
  if (down == buttonDown[b]) return;  // no change
  buttonDown[b] = down;
  player.setButtonsHeld(buttonCount() > 0, now);

  if (!down) {
    releaseMs[b] = now;
    return;
  }
  if (now - releaseMs[b] < DEBOUNCE_MS) return;  // bounce, not a real press

  if (now - lastPressMs <= CHORD_WINDOW_MS) {
    player.changeChord(buttonCount());
  } else {
    player.press(buttonCount());
    lastPressMs = now;
  }
}

int buttonCount() {
  int count = 0;
  for (int b = 0; b < 3; b++) {
    if (buttonDown[b]) count++;
  }
  return count;
}

// True while the ESP32 has sent data in the last 2 seconds.
boolean connected() {
  return millis() - lastDataMs < 2000;
}

// Keys for moving through the part: Left/Right = back/skip one note, R = start over.
void keyPressed() {
  if (keyCode == RIGHT) player.jump(player.idx + 1);
  if (keyCode == LEFT) player.jump(player.idx - 1);
  if (key == 'r' || key == 'R') player.jump(0);
}

// When the window closes: stop the sound and free the USB port.
public void exit() {
  player.silence();
  sound.close();
  if (port != null) port.stop();
  super.exit();
}
