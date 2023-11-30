// MIDI Bridge for the Beige Maze MIDI Interface
// Install on Arduino Nano

// Data lines (bits 0 - 7)
// Start at bit 7 (pin 3), and end at bit 0 (pin 10)
const int UPORT7 = 3;

// Control lines
const int VCB1 = 11;
const int VCB2 = 2;
const int LED = 13;

// Misc.
int curr_dir;            // Current data direction (1=IN 0=OUT)
int last_time;           // millis() time of most recent MIDI IN

void setup()
{
    Serial.begin(31250);
    //Serial.begin(9600); // Diagnostics
    pinMode(LED, INPUT);
    setMIDIOut();
    last_in = 0;
}

void loop() 
{    
    // MIDI In
    if (Serial.available()) {
        int c = Serial.read();
        sendIntoPort(c);
        last_in = millis();
    }

    // MIDI Out
    if (curr_dir) {
        // If MIDI has been coming from RX, temporarily set the
        // CB2 pin to read. CB2 will go high when the interrupt
        // acknowledges the port read, and that's when we need to
        // go back to MIDI OUT.
        //
        // As a failsafe, revert to MIDI OUT if it's been some amount
        // of time since the last MIDI IN byte.
        pinMode(VCB2, INPUT);
        if (digitalRead(VCB2) == HIGH || millis() - last_in > 1000) setMIDIOut();
        else pinMode(VCB2, OUTPUT);
    }
    if (!curr_dir && digitalRead(VCB2) == LOW) {
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

void sendIntoPort(int c)
{
    if (!curr_dir) setMIDIIn();
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

void setMIDIIn()
{
    digitalWrite(LED, HIGH);
    for (int b = 0; b < 8; b++) pinMode(UPORT7 + b, OUTPUT);
    pinMode(VCB2, OUTPUT); // Transitions from high to low when data sent
    digitalWrite(VCB2, HIGH);
    curr_dir = 1;
}

void setMIDIOut()
{
    digitalWrite(LED, LOW);
    for (int b = 0; b < 8; b++) pinMode(UPORT7 + b, INPUT);
    pinMode(VCB1, OUTPUT); // Set LOW to acknowledge data received
    pinMode(VCB2, INPUT); // Reads LOW when data received
    curr_dir = 0;
}
