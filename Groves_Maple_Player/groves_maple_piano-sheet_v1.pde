/*
  MUSIC MACHINE STARTER 2: JOYSTICK
  Processing sketch

  What it does:
  Tilt the joystick away from the center and loop.wav plays.
  Left-right changes the pitch, up to one octave each way.
  Up-down changes the volume. Let go and the sound stops.

  Before you run it:
  1. Install the Sound library: Sketch > Import Library > Manage Libraries,
     search for "Sound", and install the one by The Processing Foundation.
  2. Upload the board code in the starter2_joystick_board folder.
  3. Close the Arduino Serial Monitor. Only one program can use the board at a time.
  4. Leave the joystick alone when the sketch starts. Its first reading becomes the center.

  Keys:
  Space bar (hold)  plays loop.wav without the board, so you can test your sound
  C                 sets the center again, if sound plays while you are not touching the stick
*/

import processing.serial.*;
import processing.sound.*;

// ---------- SETTINGS ----------
String  PORT_MATCH = "";          // part of your board's port name, like "usbserial". Leave it "" to search automatically.
int     BAUD       = 115200;      // must match Serial.begin() in the board code
String  LOOP_FILE  = "loop.wav";  // played by the joystick, over and over
float   OCTAVES    = 1.0;         // how far left-right bends the pitch, in octaves each way
float   QUIETEST   = 0.15;        // volume with the stick all the way down, from 0 to 1
float   LOUDEST    = 1.0;         // volume with the stick all the way up, from 0 to 1
int     DEAD_ZONE  = 250;         // how far the stick moves from center before sound starts
boolean FLIP_LR    = false;       // change to true if left and right come out backwards
boolean FLIP_UD    = false;       // change to true if up and down come out backwards
// ------------------------------

Serial board;
SoundFile loopSound;

int lr = 0;                 // the latest left-right number from the board, 0 to 4095
int ud = 0;                 // the latest up-down number from the board, 0 to 4095
int lrCenter = 2048;        // what the stick reads at rest
int udCenter = 2048;
boolean centered = false;   // true once the center has been set
float volume = 0;           // the loop's volume right now
String status = "";

void setup() {
  size(640, 480);
  loopSound = new SoundFile(this, LOOP_FILE);
  loopSound.amp(0);         // silent until the stick moves
  loopSound.loop();
  connect();                // finds and opens the board (see the bottom of this sketch)
}

// Runs each time a full line arrives from the board.
void serialEvent(Serial p) {
  String line = p.readStringUntil('\n');
  if (line == null) return;
  line = trim(line);

  if (line.startsWith("LR:")) {            // RECEIVE: a line like LR:1520,UD:3100 arrives here
    String[] parts = split(line, ',');     // splits it into "LR:1520" and "UD:3100"
    if (parts.length == 2 && parts[1].startsWith("UD:")) {
      lr = int(parts[0].substring(3));     // the number after "LR:"
      ud = int(parts[1].substring(3));     // the number after "UD:"
      if (!centered) setCenter();          // the first reading is the resting position
    }
  }
}

void draw() {
  background(240, 236, 228);

  float x = 0;                             // -1 is full left, 0 is center, 1 is full right
  float y = 0;                             // -1 is full down, 0 is center, 1 is full up
  float targetVolume = 0;

  if (centered) {
    x = position(lr, lrCenter);
    y = position(ud, udCenter);
    if (FLIP_LR) x = -x;
    if (FLIP_UD) y = -y;

    boolean atRest = abs(lr - lrCenter) < DEAD_ZONE && abs(ud - udCenter) < DEAD_ZONE;
    if (!atRest) {
      loopSound.rate(pow(2, x * OCTAVES));             // USE: LR sets the pitch (0.5 is an octave down, 2 is an octave up)
      targetVolume = map(y, -1, 1, QUIETEST, LOUDEST); // USE: UD sets the volume
    }
  }

  if (keyPressed && key == ' ') {          // test the sound without the board
    loopSound.rate(1);
    targetVolume = 0.8;
  }

  volume = lerp(volume, targetVolume, 0.3);  // ease toward the new volume so it does not click
  loopSound.amp(volume);

  drawScreen(x, y);
}

// Turns a reading from 0 to 4095 into a position from -1 to 1, with 0 at the center.
float position(int value, int center) {
  float p;
  if (value < center) {
    p = (value - center) / (float) center;
  } else {
    p = (value - center) / (float) (4095 - center);
  }
  return constrain(p, -1, 1);
}

void setCenter() {
  lrCenter = constrain(lr, 1, 4094);
  udCenter = constrain(ud, 1, 4094);
  centered = true;
}

void drawScreen(float x, float y) {
  float cx = width / 2;
  float cy = height / 2 + 30;

  // The circle is the joystick's range. The dot is where the stick is.
  noFill();
  stroke(22, 40, 59);
  strokeWeight(3);
  circle(cx, cy, 300);
  noStroke();
  fill(47, 110, 144);
  circle(cx + x * 150, cy - y * 150, 36);

  fill(22, 40, 59);
  textSize(16);
  text(status, 20, 20, width - 40, 60);
  text("LR: " + lr + "    UD: " + ud, 20, height - 24);
}

void keyPressed() {
  if ((key == 'c' || key == 'C') && centered) setCenter();
}

// ---------- CONNECT TO THE BOARD ----------
// Finds the board's port by its name and opens it.
// You should not need to change this part. To choose the port yourself,
// set PORT_MATCH in the settings at the top.

void connect() {
  String[] ports = Serial.list();
  println("Ports on this computer:");
  printArray(ports);

  String name = findPort(ports);
  if (name == null) {
    status = "No board found. Check that the board is plugged in with a data cable. The ports on this computer are listed in the console below.";
    return;
  }

  try {
    board = new Serial(this, name, BAUD);
    board.bufferUntil('\n');          // run serialEvent() each time a full line arrives
    status = "Connected to " + name;
  } catch (Exception e) {
    status = "Found " + name + " but could not open it. Close the Arduino Serial Monitor, then run this sketch again.";
  }
}

String findPort(String[] ports) {
  // Your setting comes first.
  if (PORT_MATCH.length() > 0) {
    for (String p : ports) {
      if (p.contains(PORT_MATCH)) return p;
    }
    return null;
  }

  // Common names for this board on a Mac, then on Linux.
  String[] guesses = { "cu.usbserial", "cu.SLAB_USBtoUART", "cu.wchusbserial", "cu.usbmodem", "ttyUSB", "ttyACM" };
  for (String g : guesses) {
    for (String p : ports) {
      if (p.contains(g)) return p;
    }
  }

  // On Windows the board is usually the last COM port in the list.
  for (int i = ports.length - 1; i >= 0; i--) {
    if (ports[i].startsWith("COM")) return ports[i];
  }
  return null;
}
