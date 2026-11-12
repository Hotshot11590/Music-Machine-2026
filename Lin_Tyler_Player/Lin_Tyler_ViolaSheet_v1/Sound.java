// Sound: sends notes to the computer's synthesizer using MIDI messages.
//   NOTE_ON / NOTE_OFF  start / stop a note
//   PROGRAM_CHANGE      pick the instrument (41 = viola)
//   CONTROL_CHANGE      change a setting, such as volume
// This is a plain Java tab because Processing's editor misreads the word
// "open" in device.open().

import javax.sound.midi.*;

public class Sound {
  MidiDevice device;  // the synthesizer
  Receiver rx;        // where MIDI messages are sent
  public boolean ok = false;
  public String status = "No sound output";

  public Sound(int instrument, int startVolume) {
    try {
      // Windows' built-in synthesizer responds quickly, so it is the first choice.
      for (MidiDevice.Info info : MidiSystem.getMidiDeviceInfo()) {
        if (info.getName().contains("Microsoft GS Wavetable")) {
          MidiDevice d = MidiSystem.getMidiDevice(info);
          if (d.getMaxReceivers() != 0) {
            d.open();
            device = d;
            break;
          }
        }
      }
      if (device == null) {  // not found (e.g. on a Mac): use Java's own synthesizer
        device = MidiSystem.getSynthesizer();
        device.open();
      }
      rx = device.getReceiver();

      send(ShortMessage.PROGRAM_CHANGE, instrument, 0);    // viola sound
      send(ShortMessage.CONTROL_CHANGE, 7, 115);           // 7 = overall volume
      send(ShortMessage.CONTROL_CHANGE, 11, startVolume);  // 11 = expression (changed by the bow)
      ok = true;
      status = device.getDeviceInfo().getName() + " (viola)";
    } catch (Exception e) {
      status = "Sound problem: " + e.getMessage();
    }
  }

  // Send one MIDI message on channel 0, to play immediately (-1).
  public void send(int command, int data1, int data2) {
    if (rx == null) return;
    try {
      rx.send(new ShortMessage(command, 0, data1, data2), -1);
    } catch (InvalidMidiDataException e) {
      System.out.println("bad MIDI message: " + e.getMessage());
    }
  }

  public void close() {
    if (device != null) device.close();
  }
}
