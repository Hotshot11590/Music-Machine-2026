// SheetScreen: everything drawn in the window.
//   top:    controller and sound status, the note being played, the next note
//   middle: the current line of music (solid box = playing, outline = next)
//           and the following line for reading ahead
//   bottom: bow meter and keys

final color BG = #14121F, PANEL = #FFFFFF, TEXT = #F4F1FF, DIM = #9D97B8, OFF = #3A3452;
final color RED = #FF5C7A, ORANGE = #FFB84D, YELLOW = #FFE45C, GREEN = #5CE08A, BLUE = #5CC8FF;
final color HIGHLIGHT = #7B5CFF;
final color[] BUTTON_COLORS = { RED, YELLOW, BLUE };

final float SCALE = 0.873;  // line images are drawn at this size
final int LINE_X = 20;      // left edge of the line images
final int CURRENT_Y = 150;  // top of the current line
final int AHEAD_Y = 395;    // top of the next line

PFont uiFont, bigFont;

void loadFonts() {
  uiFont = createFont("Segoe UI", 16, true);
  bigFont = createFont("Segoe UI Bold", 44, true);
}

void drawScreen() {
  background(BG);
  textFont(uiFont);
  textAlign(LEFT, BASELINE);
  noStroke();

  drawStatus();
  if (loadError != null) {
    fill(RED);
    textSize(18);
    text("Could not load the music: " + loadError, 24, 120);
    return;
  }

  int nowIdx = player.idx - 1;  // the note being played (-1 before the first press)
  NoteEvent now = (nowIdx >= 0) ? events.get(nowIdx) : null;
  NoteEvent next = (player.idx < events.size()) ? events.get(player.idx) : null;
  int current = lineOfNote[max(0, nowIdx)];

  drawHeader(now, next);
  drawLinePanel(current, CURRENT_Y, true);
  fill(DIM);
  textSize(13);
  String ahead = "NEXT LINE";
  if (current + 1 < sheetLines.size()) {
    SheetLine nextLine = sheetLines.get(current + 1);
    ahead += "   (measure " + nextLine.firstMeasure + ", page " + nextLine.page + ")";
  }
  text(ahead, LINE_X, AHEAD_Y - 8);
  drawLinePanel(current + 1, AHEAD_Y, false);
  drawBowMeter();
  drawHelp();
}

void drawStatus() {
  textSize(13);
  if (connected()) {
    fill(GREEN);
    text("Controller: connected to " + PORT_NAME, 24, 26);
  } else {
    fill(ORANGE);
    text("Controller: " + portStatus, 24, 26);
  }
  fill(sound.ok ? GREEN : RED);
  text("Sound: " + sound.status, 24, 46);
}

// Left: the note being played. Right: how many buttons the next note needs.
void drawHeader(NoteEvent now, NoteEvent next) {
  textSize(15);
  fill(DIM);
  if (now != null) {
    text("PLAYING      measure " + now.measure + "   |   page " + now.page + "   |   note " + player.idx + " of " + events.size(), 24, 80);
  } else {
    text("READY: the first press plays the outlined note", 24, 80);
  }

  textFont(bigFont);
  fill(TEXT);
  text(now != null ? join(now.names, "   ") : "-", 22, 132);
  textFont(uiFont);

  // three circles: filled = needed for the next note, white ring = held down now
  int needed = (next == null) ? 0 : min(3, next.names.length);
  for (int i = 0; i < 3; i++) {
    float cx = 1000 + i * 70;
    float cy = 98;
    boolean lit = i < needed;
    strokeWeight(4);
    stroke(lit ? BUTTON_COLORS[i] : OFF);
    fill(lit ? BUTTON_COLORS[i] : BG);
    ellipse(cx, cy, 46, 46);
    if (buttonDown[i]) {
      noFill();
      stroke(TEXT);
      strokeWeight(3);
      ellipse(cx, cy, 60, 60);
    }
    noStroke();
    fill(lit ? BG : DIM);
    textSize(18);
    textAlign(CENTER, CENTER);
    text(i + 1, cx, cy - 2);
    textAlign(LEFT, BASELINE);
  }
  textSize(14);
  if (next != null) {
    fill(DIM);
    text("NEXT: " + join(next.names, " ") + "   (" + buttonsText(needed) + ")", 977, 140);
  } else {
    fill(GREEN);
    text("End of Section 1  (R = start again)", 977, 140);
  }
}

// One line of music on a white panel. The current line fades the notes
// already played; the line after it is faded as a whole.
void drawLinePanel(int li, int y, boolean current) {
  float panelH = 228 * SCALE + 16;
  fill(PANEL);
  rect(LINE_X - 10, y, 1260, panelH, 8);
  if (li >= sheetLines.size()) {
    fill(#8A84A3);
    textSize(16);
    text("(end of Section 1)", LINE_X + 10, y + 40);
    return;
  }
  SheetLine line = sheetLines.get(li);
  float imgY = y + 8;
  image(line.img, LINE_X, imgY, line.img.width * SCALE, line.img.height * SCALE);

  int nowIdx = player.idx - 1;
  int nextIdx = player.idx;
  boolean nowHere = nowIdx >= 0 && lineOfNote[nowIdx] == li;
  boolean nextHere = nextIdx < events.size() && lineOfNote[nextIdx] == li;

  if (!current) {
    fill(255, 90);  // see-through white = faded
    rect(LINE_X - 10, y, 1260, panelH, 8);
  } else if (nowHere) {
    float nowLeft = LINE_X + line.noteX[nowIdx - line.firstNote] * SCALE - 12;
    fill(255, 160);
    rect(LINE_X, imgY, nowLeft - LINE_X - 4, line.img.height * SCALE);
  }

  if (nowHere) drawNoteBox(line, nowIdx, imgY, true);
  if (nextHere) drawNoteBox(line, nextIdx, imgY, false);
}

// A box around one note: solid with its names for the note being played,
// a thin outline for the next one.
void drawNoteBox(SheetLine line, int note, float imgY, boolean playing) {
  float boxX = LINE_X + line.noteX[note - line.firstNote] * SCALE - 12;
  float boxW = 44;
  float boxTop = imgY + (line.staffTop - 40) * SCALE;
  float boxBottom = imgY + (line.staffBottom + 40) * SCALE;
  String names = join(events.get(note).names, " ");
  textSize(13);

  if (playing) {
    fill(red(HIGHLIGHT), green(HIGHLIGHT), blue(HIGHLIGHT), 45);
    stroke(HIGHLIGHT);
    strokeWeight(3);
    rect(boxX, boxTop, boxW, boxBottom - boxTop, 8);
    noStroke();
    fill(HIGHLIGHT);
    rect(boxX, boxTop - 22, textWidth(names) + 12, 20, 5);
    fill(255);
    text(names, boxX + 6, boxTop - 7);
  } else {
    noFill();
    stroke(red(HIGHLIGHT), green(HIGHLIGHT), blue(HIGHLIGHT), 150);
    strokeWeight(2);
    rect(boxX, boxTop, boxW, boxBottom - boxTop, 8);
    noStroke();
    fill(red(HIGHLIGHT), green(HIGHLIGHT), blue(HIGHLIGHT), 170);
    text("next", boxX + 6, boxBottom + 16);
  }
}

// Bow meter: hand position (white marker) and bow speed (green while sounding).
void drawBowMeter() {
  float x = 24, y = 640, w = 600;
  textSize(13);
  fill(DIM);
  text("BOW", x, y - 6);
  fill(OFF);
  rect(x + 40, y - 18, w, 8, 4);
  fill(TEXT);
  rect(x + 40 + (bowPos / BOW_MAX) * (w - 10), y - 22, 10, 16, 3);
  fill(OFF);
  rect(x + 40, y - 4, w, 8, 4);
  fill(player.isSounding() ? GREEN : DIM);
  rect(x + 40, y - 4, min(1, player.speed / FULL_SPEED) * w, 8, 4);
  fill(DIM);
  text((player.isSounding() ? "SOUNDING" : "silent") + "   speed " + int(player.speed), x + w + 60, y + 2);
}

void drawHelp() {
  textSize(13);
  fill(DIM);
  text("Keys:  Left/Right = back/skip one note    R = start again", 24, 676);
}

String buttonsText(int noteCount) {
  if (noteCount == 1) return "1 button";
  return noteCount + " buttons";
}
