; This is a demonstration of the MIDI KERNAL

VOLUME      = $900e             ; Volume Register
VOICE       = $900b             ; Middle Voice Register

LAST_NOTE   = $fe               ; Last note played

* = $1600
Install:    lda #<ISR
            sta $0318
            lda #>ISR
            sta $0319
            jsr SETIN
            
Main:       jsr GETMSG          ; Has a complete MIDI message been received?
            bcc Main            ; ,,
            cmp #ST_NOTEON
            beq NoteOnH
            cmp #ST_NOTEOFF
            beq NoteOffH
            bne Main
            
NoteOffH:   cpx LAST_NOTE
            bne Main
            lda #0
            sta VOICE
            jmp Main
            
NoteOnH:    txa                 ; Put note number in A
            sta LAST_NOTE       ; Store last note for Note Off
            cmp #85             ; Check the range for the VIC-20 frequency
            bcs Main            ;   table. We're allowing note #s 48-85 in
            cmp #48             ;   this simple demo
            bcc Main            ;   ,,
            ;sec                ; Know carry is set from previous cmp
            sbc #48             ; Subtract 48 to get frequency table index
            tax                 ; X is the index in frequency table
            tya                 ; Put the velocity in A
            lsr                 ; Shift 0vvvvvvv -> 00vvvvvv
            lsr                 ;       00vvvvvv -> 000vvvvv
            lsr                 ;       000vvvvv -> 0000vvvv
            bne setvol          ; Make sure it's at least 1
            lda #1              ; ,,
setvol:     sta VOLUME          ; Set volume based on high 4 bits of velocity
            lda FreqTable,x     ; A is the frequency to play
            sta VOICE           ; Play the voice
            jmp Main            ; Back for more MIDI messages
            

ISR:        pha
            txa
            pha
            tya
            pha
            jsr CHKMIDI         ; Is this a MIDI-based interrupt?
            bne midi            ;   If so, handle MIDI input
            jmp $feb2
midi:       jsr MAKEMSG
            jmp $ff56

; Frequency numbers VIC-20
; 135 = Note #48
; Between 48 and 85
FreqTable:  .byte 135,143,147,151,159,163,167,175,179,183,187,191
            .byte 195,199,201,203,207,209,212,215,217,219,221,223
            .byte 225,227,228,229,231,232,233,235,236,237,238,239
            .byte 240,241

#include "midikernal.asm"
