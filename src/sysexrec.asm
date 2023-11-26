; SysEx Receive

; Memory
STATUS      = $fa
DATA_1      = $fb
DATA_2      = $fc
SIZE        = $fd
STORAGE     = $6000
PT_ST       = $01

* = $1800
; Installation routine
Install:    lda #<ISR           ; Set the location of the NMI interrupt service
            sta $0318           ;   routine, which will capture incoming MIDI
            lda #>ISR           ;   messages. Note the lack of SEI/CLI here.
            sta $0319           ;   They would do no good for the NMI.
            lda #<STORAGE       ; Initialize storage pointer
            sta PT_ST           ; ,,
            lda #>STORAGE       ; ,,
            sta PT_ST+1         ; ,,
            jmp SETIN           ; Prepare hardware for MIDI input

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
            jsr GETMSG          ; See if there's a complete message
            bcc r_isr           ; Return if no new message
            cmp #ST_SYSEX       ; If not sysex, skip it
            bne r_isr           ; ,,
            txa                 ; A is now the data byte
            ldx #0              ; Clear X to use as indirect index
            sta (PT_ST,x)       ; Save data byte
            inc PT_ST           ; Increment storage pointer
            bne r_isr           ; ,,
            inc PT_ST+1         ; ,,
r_isr:      jmp $ff56           ; Restore registers and return from interrupt

#include "midikernal.asm"