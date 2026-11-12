// Notes: reads the part from data/viola_notes.txt.
// Each line is one press: a measure number, then the notes, lowest first.
//   59 C4 F4 A4   measure 59, a 3-note chord
// "# page N" lines say which score page the next notes are on; other # lines are comments.

class NoteEvent {
  int measure;
  int page;
  String[] names;  // e.g. {"C4", "F4", "A4"}
  int[] midis;     // the same notes as MIDI numbers, e.g. {60, 65, 69}
}

ArrayList<NoteEvent> loadEvents(String file) throws Exception {
  String[] lines = loadStrings(file);
  if (lines == null) throw new Exception(file + " is missing from the data folder");

  ArrayList<NoteEvent> list = new ArrayList<NoteEvent>();
  int page = 0;
  for (String line : lines) {
    line = trim(line);
    if (line.startsWith("# page")) page = int(trim(line.substring(6)));
    if (line.length() == 0 || line.startsWith("#")) continue;

    String[] parts = splitTokens(line);
    NoteEvent e = new NoteEvent();
    e.measure = int(parts[0]);
    e.page = page;
    e.names = subset(parts, 1);  // everything after the measure number
    e.midis = new int[e.names.length];
    for (int i = 0; i < e.names.length; i++) {
      e.midis[i] = noteToMidi(e.names[i]);
      if (e.midis[i] < 0) throw new Exception("'" + e.names[i] + "' is not a note name");
    }
    list.add(e);
  }
  return list;
}

// Note name -> MIDI number. Middle C (C4) is 60, and each half step adds 1.
//   "C4" -> 60, "F#3" -> 54, "Bb3" -> 58. Returns -1 if it isn't a note name.
int noteToMidi(String name) {
  int[] stepsAboveC = { 9, 11, 0, 2, 4, 5, 7 };  // A, B, C, D, E, F, G
  int letter = "ABCDEFG".indexOf(name.charAt(0));
  if (letter < 0) return -1;
  int shift = 0;
  if (name.charAt(1) == '#') shift = 1;   // sharp
  if (name.charAt(1) == 'b') shift = -1;  // flat
  int octave = int(name.substring(name.length() - 1));
  return 12 * (octave + 1) + stepsAboveC[letter] + shift;
}

// Which notes a press plays: one per button held, lowest first.
// 3 buttons play every note (including 4-note chords).
ArrayList<Integer> notesForButtons(int[] midis, int buttonCount) {
  int count = min(buttonCount, midis.length);
  if (buttonCount >= 3) count = midis.length;
  ArrayList<Integer> chosen = new ArrayList<Integer>();
  for (int i = 0; i < count; i++) {
    chosen.add(midis[i]);
  }
  return chosen;
}
