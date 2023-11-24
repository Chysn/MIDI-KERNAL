
// Data lines (bits 0 - 7)
// Start at bit 7 (pin 3), and end at bit 0 (pin 10)
const int UPORT7 = 3;

// Control lines
const int VCB1 = 11;
const int VCB2 = 2;

// Switch
const int MIDI_SEL = 13;     // MIDI In/Out Selector (MIDI In when HIGH)
int curr_sel = 0;            // Current MIDI selection (0 = out, 1 = in)

/* This is the starting point for DAC steps-per-volt calibration. It's experimentally-determined
 *  with my Nano and my meter, but I've noticed that it varies according to power supply. So
 *  in real life, you'll want to calibrate your interface
 */
const int DEFAULT_VOLT_REF = 876; // Calibration of DAC at 1V

void setup() {
    Serial.begin(31250);
    //Serial.begin(9600); // Diagnostics

    // Get current MIDI direction
    pinMode(MIDI_SEL, INPUT);
    setMIDIDirection();
}

void loop() {
    if (digitalRead(MIDI_SEL) != curr_sel) {
        setMIDIDirection();
    }
    
    if (curr_sel) {
        // MIDI In
        if (Serial.available()) {
            int c = Serial.read();
            sendOut(c);
        }
    } else {
        // MIDI Out
        if (!digitalRead(VCB2)) {
            int out = 0;
            int val = 256;
            for (int i = 0; i < 8; i++)
            {
                val /= 2; // Power of 2, descending
                int b = 7 - i; // b is bit number
                int pin = i + UPORT7; // Physical pin number
                out += digitalRead(pin) * val;
            }
            Serial.write(out);
            digitalWrite(VCB1, LOW);  // Acknowledge with transition on CB1
            digitalWrite(VCB1, HIGH);
        }
    }
}

void sendOut(int c)
{
    int v = 128;
    digitalWrite(VCB2, HIGH);
    for (int b = 0; b < 8; b++)
    {
        digitalWrite(UPORT7 + b, (c & v) ? HIGH : LOW);
        v /= 2;
    }
    // Transition on CB2 pin to set interrupt flag
    digitalWrite(VCB2, LOW);
}

void setMIDIDirection()
{
    curr_sel = digitalRead(MIDI_SEL);
    if (curr_sel) {
        // If switch is conducting, then MIDI IN is selected
        for (int b = 0; b < 8; b++) pinMode(UPORT7 + b, OUTPUT);
        pinMode(VCB2, OUTPUT); // Transitions from high to low when data sent
        digitalWrite(VCB2, HIGH);
        //Serial.print("MIDI IN\n");
    } else {
        for (int b = 0; b < 8; b++) pinMode(UPORT7 + b, INPUT);
        pinMode(VCB1, OUTPUT); // Set LOW to acknowledge data received
        pinMode(VCB2, INPUT); // Reads LOW when data received
        //Serial.print("MIDI OUT\n");
    }
}
