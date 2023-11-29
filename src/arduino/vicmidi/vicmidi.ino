// Data lines (bits 0 - 7)
// Start at bit 7 (pin 3), and end at bit 0 (pin 10)
const int UPORT7 = 3;

// Control lines
const int VCB1 = 11;
const int VCB2 = 2;

// Misc.
int curr_dir;            // Current data direction (1=IN 0=OUT)
const int LEDPIN = 13;
int last_in;             // millis() of most recent serial read

void setup() {
    Serial.begin(31250);
    //Serial.begin(9600); // Diagnostics
    pinMode(LEDPIN, OUTPUT);
    setMIDIOut();
    last_in = 0;
}

void loop() 
{    
    // MIDI In
    if (Serial.available()) {
        int c = Serial.read();
        last_in = millis();
        sendIntoPort(c);
    }

    // MIDI Out
    if (curr_dir && (millis() - last_in > 100)) setMIDIOut();
    if (!curr_dir && !digitalRead(VCB2)) {
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
    last_in = millis();
}

void setMIDIIn()
{
    digitalWrite(LEDPIN, HIGH);
    for (int b = 0; b < 8; b++) pinMode(UPORT7 + b, OUTPUT);
    pinMode(VCB2, OUTPUT); // Transitions from high to low when data sent
    digitalWrite(VCB2, HIGH);
    curr_dir = 1;
}

void setMIDIOut()
{
    digitalWrite(LEDPIN, LOW);
    for (int b = 0; b < 8; b++) pinMode(UPORT7 + b, INPUT);
    pinMode(VCB1, OUTPUT); // Set LOW to acknowledge data received
    pinMode(VCB2, INPUT); // Reads LOW when data received
    curr_dir = 0;
    last_in = 0; // Reset last IN
}
