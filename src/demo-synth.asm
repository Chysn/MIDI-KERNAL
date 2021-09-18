; This is a demonstration of the MIDI KERNAL for MIDI input
; It shows how MIDI messages are constructed in an interrupt (via MAKEMSG)
; and handed off to a main loop (via GETMSG), and subsequently handled by
; looking at the message data in A,X, and Y
;
; Note that the MIDI KERNAL is included at the bottom of this file, so make
; sure it's available to the assembler.

; VIC Registers
VOLUME      = $900e             ; Volume Register
VOICE       = $900b             ; Middle Voice Register

; Program Memory
LAST_NOTE   = $fe               ; Last note played

* = $1600
; Installation routine
Install:    lda #<ISR           ; Set the location of the NMI interrupt service
            sta $0318           ;   routine, which will capture incoming MIDI
            lda #>ISR           ;   messages. Note the lack of SEI/CLI here.
            sta $0319           ;   They would do no good for the NMI.
            jsr SETIN           ; Prepare hardware for MIDI input
 
; Main Loop
; Waits for a complete MIDI message, and then dispatches the message to
; message handlers. This dispatching code and the handlers are pretty barbaric.
; In real life, you probably won't be able to use relative jumps for everything.
Main:       jsr GETMSG          ; Has a complete MIDI message been received?
            bcc Main            ;   If not, just go back and wait
            cmp #ST_NOTEON      ; Is the message a Note On?
            beq NoteOnH         ; If so, handle it
            cmp #ST_NOTEOFF     ; Is it a Note Off?
            beq NoteOffH        ; If so, handle it
            bne Main            ; Go back and wait for more

; Note Off Handler            
NoteOffH:   cpx LAST_NOTE       ; X is the note. Is it the last one played?
            bne Main            ; If not, leave it alone
            lda #0              ; Otherwise, silence the voice
            sta VOICE           ; ,,
            jmp Main            ; Go get more MIDI

; Note On Handler  
; For the purposes of this demo, we're just accepting notes on any channel.
; In a real application, you'll probably want to check channel numbers, either
; for accept/reject purposes, or to further dispatch messages. That code would
; look something like this:
;     jsr GETCH
;     cmp #LISTEN_CH
;     beq ch_ok
;     jmp Main   
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
            

; NMI Interrupt Service Routine
; If the interrupt is from a byte from the User Port, add it to the MIDI message
; Otherwise, just go back to the normal NMI (to handle STOP/RESTORE, etc.)
ISR:        pha                 ; NMI does not automatically save registers like
            txa                 ;   IRQ does, so that needs to be done
            pha                 ;   ,,
            tya                 ;   ,,
            pha                 ;   ,,
            jsr CHKMIDI         ; Is this a MIDI-based interrupt?
            bne midi            ;   If so, handle MIDI input
            jmp $feb2           ; Back to normal NMI, after register saves
midi:       jsr MAKEMSG         ; Add the byte to a MIDI message
            jmp $ff56           ; Restore registers and return from interrupt

; Frequency numbers VIC-20
; 135 = Note #48
; Between 48 and 85
FreqTable:  .byte 135,143,147,151,159,163,167,175,179,183,187,191
            .byte 195,199,201,203,207,209,212,215,217,219,221,223
            .byte 225,227,228,229,231,232,233,235,236,237,238,239
            .byte 240,241

#include "midikernal.asm"
