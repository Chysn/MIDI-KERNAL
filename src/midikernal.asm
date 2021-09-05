;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;                                   MIDI KERNAL
;                    MIDI Routines for VIC-20 User Port Projects
;                             (c)2021, Jason Justian
;                  
; Release 1 - September 2, 2021
; Assembled with XA
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Copyright (c) 2021, Jason Justian
;
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MIDI COMMAND DOCUMENTATION
; Example
;     jsr SETOUT                ; SETOUT and SETCH don't need to be done for
;     lda #CHANNEL              ;   each command invocation, only when they need
;     jsr SETCH                 ;   to be changed
;     ldx #DATA1                ; Range of DATA1 is 0 - 127
;     ldy #DATA2                ; Range of DATA2 is 0 - 127
;     jsr ROUTINE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;    ROUTINE    ;     DESCRIPTION       ;     DATA1 (x)     ;     DATA2  (y)     
;---------------;-----------------------;-------------------;-------------------
; NOTEON        ; Note On               ; Note Number       ; Velocity
; NOTEOFF       ; Note Off              ; Note Number       ; Velocity
; POLYPRES      ; Polyphonic Pressure   ; Note Number       ; Pressure Amount
; CONTROLC      ; Control Change        ; Controller Number ; Control Amount
; PROGRAMC      ; Program Change        ; Program Number    ; (unused)
; CHPRES        ; Channel Pressure      ; Pressure Amount   ; (unused)
; PITCHB        ; Pitch Bend            ; Amount - LSB      ; Amount - MSB
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; LABEL DEFINITIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; VIA Registers
DDR         = $9112             ; Data Direction Register
UPORT       = $9110             ; User Port
PCR         = $911c             ; Peripheral Control Register
IFLAG       = $911d             ; Interrupt flag register

; Memory Locations
MIDICH      = $fe               ; MIDI channel

; MIDI Status Message Constants
ST_NOTEON   = $90               ; Note On
ST_NOTEOFF  = $80               ; Note Off
ST_POLYPR   = $a0               ; Poly Pressure
ST_CONTROLC = $b0               ; Control Change
ST_PROGRAMC = $c0               ; Program Change
ST_CHPR     = $d0               ; Channel Pressure
ST_PITCHB   = $e0               ; Pitch Bend

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MIDI KERNAL JUMP TABLE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SETOUT:     jmp _SETOUT         ; Set MIDI port to output mode
SETIN:      jmp _SETIN          ; Set MIDI port to input mode
SETCH:      jmp _SETCH          ; Set MIDI channel
MIDIOUT:    jmp _MIDIOUT        ; Send next MIDI byte to stream
MIDIIN:     jmp _MIDIIN         ; Get next MIDI byte in stream
NOTEON:     jmp _NOTEON         ; Note on
NOTEOFF:    jmp _NOTEOFF        ; Note off
POLYPRES:   jmp _POLYPRES       ; Poly pressure
CONTROLC:   jmp _CONTROLC       ; Control change
PROGRAMC:   jmp _PROGRAMC       ; Program change
CHPRES:     jmp _CHPRES         ; Channel pressure
PITCHB:     jmp _PITCHB         ; Pitch bend

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MIDI ROUTINE IMPLEMENTATIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SETOUT
; Prepare port for MIDI output
; Preparations - None
; Registers Affected - A
_SETOUT:    lda #%11111111      ; Set DDR for input on all lines
            sta DDR             ; ,,
            lda #%10000000      ; Set PCR for output handshaking mode
            sta PCR             ; ,,
            rts

; SETIN
; Prepare port for MIDI input
; Preparations - TBA
; Registers Affected - TBA
_SETIN:     rts

; SETCH
; Set MIDI channel
; Preparations - A=MIDI channel ($00 - $0f)
; Registers Affected - A
_SETCH:     and #%00001111      ; Constrain to 0-15
            sta MIDICH
            rts

; MIDIOUT
; Send byte to MIDI port
; Preparations - A=MIDI byte
; Registers Affected - None
_MIDIOUT:   sta UPORT           ; Write to port
            lda #%00010000      ; Wait for bit 4 of the interrupt flag
-wait:      bit IFLAG           ;   to be set, indicating acknowledgement
            beq wait            ;   of MIDI message by the interface
            rts

; MIDIIN
; Receive byte from MIDI port
; Preparations - None
; Registers Affected - A
_MIDIIN:    lda UPORT
            rts

; NOTEON
; Send Note On command
; Preparations - Set X with note number and Y with velocity
; Registers Affected - A
_NOTEON:    lda #ST_NOTEON      ; Specify Note On status
MIDICMD:    ora MIDICH          ; Generic endpoint for a typical
            jsr MIDIOUT         ;   three-byte MIDI command
            txa                 ;   with Data 1 in X, and
            and #%01111111      ;   ,, (constrain to 0-127)
            jsr MIDIOUT         ;   ,,
            tya                 ;   Data 2 in Y
            and #%01111111      ;   ,, (constrain to 0-127)
            jmp MIDIOUT         ;   ,,
            
; NOTEOFF
; Send Note Off command
; Preparations - Set X with note number and Y with velocity
; Registers Affected - A   
_NOTEOFF:   lda #ST_NOTEOFF
            jmp MIDICMD

; POLYPRES
; Send Polyphonic Pressure command
; Preparations - Set X with note number and Y with pressure
; Registers Affected - A            
_POLYPRES:  lda #ST_POLYPR
            jmp MIDICMD
            
; CONTROLC
; Send Continuous Control command
; Preparations - Set X with controller number and Y with amount
; Registers Affected - A
_CONTROLC:  lda #ST_CONTROLC
            jmp MIDICMD
            
; PROGRAMC
; Send Program Change command
; Preparations - Set X with new program number
; Registers Affected - A
_PROGRAMC:  lda #ST_PROGRAMC
MIDICMD2:   ora MIDICH          ; Generic endpoint for a two-byte
            jsr MIDIOUT         ;   MIDI command
            txa                 ;   ,,
            and #%01111111      ;   ,, (constrain to 0-127)
            jmp MIDIOUT         ;   ,,
            
; CHPRES
; Send Channel Pressure command
; Preparations - Set X with pressure amount
; Registers Affected - A
_CHPRES:    lda #ST_CHPR
            jmp MIDICMD2 
            
; PITCHB
; Send Pitch Bend command
; Preparations - Set X with LSB (0-127) and Y with MSB (0-127)
; Registers Affected - A
_PITCHB:    lda #ST_PITCHB
            jmp MIDICMD
