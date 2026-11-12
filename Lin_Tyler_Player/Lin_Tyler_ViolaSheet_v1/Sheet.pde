// Sheet: the score images and where each note sits on them.
// data/sheet/line_00.png ... line_36.png are the lines of the viola part.
// data/sheet_lines.txt says which notes each image holds and the x position
// of each one, so the highlight box can be drawn on the right note.

class SheetLine {
  PImage img;
  int page;          // page of the score
  int firstMeasure;  // measure number at the start of the line
  int firstNote;     // position in viola_notes.txt of the line's first note
  int noteCount;     // how many notes the line holds
  float staffTop;    // y of the top staff line in the image
  float staffBottom; // y of the bottom staff line
  float[] noteX;     // x of each note in the image, in playing order
}

ArrayList<SheetLine> sheetLines = new ArrayList<SheetLine>();
int[] lineOfNote;  // for every note in the part: which line it is on

void loadSheet(String file) throws Exception {
  String[] rows = loadStrings(file);
  if (rows == null) throw new Exception(file + " is missing from the data folder");

  for (String row : rows) {
    row = trim(row);
    if (row.length() == 0 || row.startsWith("#")) continue;
    // line page firstMeasure firstNote noteCount staffTop staffBottom x,x,x...
    String[] p = splitTokens(row);
    SheetLine line = new SheetLine();
    line.img = loadImage("sheet/line_" + nf(int(p[0]), 2) + ".png");
    if (line.img == null) throw new Exception("sheet/line_" + p[0] + ".png is missing");
    line.page = int(p[1]);
    line.firstMeasure = int(p[2]);
    line.firstNote = int(p[3]);
    line.noteCount = int(p[4]);
    line.staffTop = float(p[5]);
    line.staffBottom = float(p[6]);
    line.noteX = float(split(p[7], ','));
    sheetLines.add(line);
  }

  // Note number -> line number, for finding the line to show.
  lineOfNote = new int[events.size()];
  for (int li = 0; li < sheetLines.size(); li++) {
    SheetLine line = sheetLines.get(li);
    for (int k = 0; k < line.noteCount; k++) {
      int note = line.firstNote + k;
      if (note < lineOfNote.length) lineOfNote[note] = li;
    }
  }
}
