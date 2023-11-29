; SysEx Receive

; Memory
LISTEN      = $fa
STORAGE     = $6000
PT_ST       = $01

* = $1800
; Installation routine
Install:    lda #<ISR           ; Set the location of the NMI interrupt service
            sta $0318           ;   routine, which will capture incoming MIDI
            lda #>ISR           ;   messages. Note the lack of SEI/CLI here.
            sta $0319           ;   They would do no good for the NMI.
            clc                 ; Clear sysex listen flag
            ror LISTEN          ; ,,
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
midi:       jsr MIDIIN
            cmp #$f0            ; If sysex, 
            bne ch_eos          ;   initialize storage pointer
            lda #<STORAGE       ;   ,,
            sta PT_ST           ;   ,,
            lda #>STORAGE       ;   ,,
            sta PT_ST+1         ;   ..
            sec                 ;   and set sysex listen flag
            ror LISTEN          ;   ,,
            jmp ch_catch        ;   Capture the sysex start byte
ch_eos:     cmp #$80            ; If some other status byte, then
            bcc ch_catch        ;   clear the sysex listen flag
            clc                 ;   ,,
            ror LISTEN          ;   ,,
            jmp sy_store        ; Store end of sysex status
ch_catch:   bit LISTEN          ; If sysex listen flag is on, store the byte to
            bpl r_isr           ;   specified memory
sy_store:   ldx #0              ; Clear X to use as indirect index
            sta (PT_ST,x)       ; Save data byte
            inc PT_ST           ; Increment storage pointer
            bne r_isr           ; ,,
            inc PT_ST+1         ; ,,
r_isr:      jmp $ff56           ; Restore registers and return from interrupt

#include "./src/midikernal.asm"