; MIDI Monitor
; MIDI Monitor is a wAx plug-in that shows complete MIDI messages
; using between 1 and 3 bytes of hex.

; Memory
STATUS      = $0247
DATA_1      = $0248
DATA_2      = $0249
SIZE        = $024a

; wAx API
EFADDR      = $a6               ; Effective Address
X_PC        = $03               ; External Persistent Counter
Buff2Byte   = $a003             ; Get 8-bit hex number from input buffer to A
CharGet     = $a006             ; Get character from input buffer to A
CharOut     = $a009             ; Write character in A to output buffer
Hex         = $a00c             ; Write value in A to output buffer 8-bit hex
IncAddr     = $a00f             ; Increment Effective Address, store value in A
IncPC       = $a012             ; Increment Persistent Counter
Lookup      = $a015             ; Lookup 6502 instruction with operand in A
PrintBuff   = $a018             ; Flush output buffer to screen
ResetIn     = $a01b             ; Reset input buffer index
ResetOut    = $a01e             ; Reset output buffer index
ShowAddr    = $a021             ; Write Effective Address to output buffer
ShowPC      = $a024             ; Write Persistent Counter to output buffer
EAtoPC      = $a027             ; Copy Effective Address to Persistent Counter
PrintStr    = $a02a             ; Print String at A/Y

; System Routines
ISCNTC      = $ffe1             ; Check Stop key

* = $1800
; Installation routine
Install:    lda #<ISR           ; Set the location of the NMI interrupt service
            sta $0318           ;   routine, which will capture incoming MIDI
            lda #>ISR           ;   messages. Note the lack of SEI/CLI here.
            sta $0319           ;   They would do no good for the NMI.
            jsr SETIN           ; Prepare hardware for MIDI input
            ; Fall through to Main

Main:       jsr ISCNTC          ; Check STOP key
            beq stop            ; ,,
            jsr GETMSG          ; Has a complete MIDI message been received?
            bcc Main            ;   If not, just go back and wait
            stx DATA_1          ; Store message data
            sty DATA_2          ; ,,
            sta STATUS          ; ,,
            cmp #$f0            ; If it's a system message, skip to message
            bcs build           ;   build without adding channel
            jsr GETCH           ; Add channel if it's a channel message
            ora STATUS          ; ,,
            sta STATUS          ; ,,
build:      jsr MSGSIZE         ; Get message size
            sta SIZE            ; ,,
            jsr ResetOut
            lda STATUS
            jsr Hex
            lda SIZE            ; No data bytes expected, so go to output
            beq out             ; ,,
            lda #" "            ; Show the first data byte
            jsr CharOut         ; ,,
            lda DATA_1          ; ,,
            jsr Hex             ; ,,
            lda SIZE            ; This was a one-data-byte message, so go to
            cmp #1              ;   output
            beq out             ;   ,,
            lda #" "            ; Show the second data byte
            jsr CharOut         ; ,,
            lda DATA_2          ; ,,
            jsr Hex             ; ,,
out:        jsr PrintBuff       ; Print buffer
            jmp Main            ; Go back for more MIDI           
stop:       rts

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
            lda $900f           ; Flash screen for diagnostics
            ora #$55            ; ,,
            sta $900f           ; ,,
            jmp $ff56           ; Restore registers and return from interrupt

#include "./src/midikernal.asm"