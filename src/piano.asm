; This is a demonstration of the MIDI KERNAL
; Play keys to send MIDI Note On commands, and release them to send Note Off
; Recognized keys are
;     A  S  D  F  G  H  J  K
; which play a C major scale from Middle C (#60)

; Memory
KEYDOWN     = $c5               ; Which key is being held?
LASTKEY     = $fa               ; What key was played last?

* = $1600
Start:      jmp Main

#include "./src/midikernal.asm"

Main:       lda #<ISR           ; Set the location of the NMI interrupt service
            sta $0318           ;   routine, which will capture incoming MIDI
            lda #>ISR           ;   messages. Note the lack of SEI/CLI here.
            sta $0319           ;   They would do no good for the NMI.
            lda #0              ; Channel 1
            jsr SETCH           ; ,,
start:      lda KEYDOWN         ; Wait for a key press
            cmp #$40            ; ,,
            beq start           ; ,,
            sta LASTKEY         ; Take note of key press
            cmp #39             ; If F1 is pressed, alternate between
            bne keyboard        ;   channel 1 and channel 16 (MIDI/CV)
            lda #$0f            ;   ,,
            eor MIDIST          ;   ,,
            jsr SETCH           ;   ,,
            lda $900f           ; Toggle color to indicate channel
            eor #$55            ;   change
            sta $900f           ;   ,,
            jmp end 
keyboard:   ldy #7              ; Search the keyboard table for a valid
search:     lda KeyTable,y      ;   note
            cmp LASTKEY         ; Is this table entry the key pressed?
            beq found           ; If so, go play the note
            dey                 ; Keep searching all 8 table entries
            bpl search          ; ,,
            bmi start           ; The pressed key isn't here, so wait again
found:      lda NoteTable,y     ; Get the MIDI note number at found index
            tax                 ; Set X for Note On call
            ldy #100            ; Set Y as velocity
            jsr NOTEON          ; Send Note On command at specified channel
end:        lda KEYDOWN         ; Keep playing the note until the key is
            cmp LASTKEY         ;   released
            beq end             ;   ,,
            jsr NOTEOFF         ; Once the key is released, send Note Off
            jmp start           ; Back to note start
            
; NMI Interrupt Service Routine
; If the interrupt is from a byte from the User Port, add it to the MIDI message
; Otherwise, just go back to the normal NMI (to handle STOP/RESTORE, etc.)
;
; Even though this is a MIDI OUT application, the MIDI IN ISR must still be
; implemented, or CB2 interrupts will not be handled properly and the application
; will crash.
ISR:        pha                 ; NMI does not automatically save registers like
            txa                 ;   IRQ does, so that needs to be done
            pha                 ;   ,,
            tya                 ;   ,,
            pha                 ;   ,,
            jsr CHKMIDI         ; Is this a MIDI-based interrupt?
            bne midi            ;   If so, handle MIDI input
            jmp $feb2           ; Back to normal NMI, after register saves
midi:       inc $900f           ; Flash screen color when there's MIDI input
            jmp $ff56           ; Restore registers and return from interrupt
            
; Key codes for A,S,D,F,G,H,J,K            
KeyTable:   .byte 17,41,18,42,19,43,20,44

; Note numbers for C Major from Middle C
NoteTable:  .byte 60,62,64,65,67,69,71,72
