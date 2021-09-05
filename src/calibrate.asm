; 12-Bit DAC 1V Calibration
;
; The accuracy of the DAC seems to depend on its power source.
; Connect a meter to CV out. The target is 1V.
; If the CV is lower than 1V, use F1 and F3 to raise the voltage
; If the CV is higher than 1V, use F7 and F5 to lower the voltage
; When the meter reads 1V (or as close as possible to it),
; press RETURN. This will set the calibration in the interface, and
; store the calibration value to EEPROM for the next power cycle.
;
; Dependency --
; Note that the MIDI KERNAL is included at the end of this file
KEYDOWN     = $c5
CALIB       = $fa               ; Current calibration value (2 bytes)
BURN        = $fc               ; Value as MIDI data bytes (2 bytes)
PRTFIX      = $ddcd             ; Decimal display routine (A,X)
CHROUT      = $ffd2             ; Character out

; Key Adjust Constants
F1          = 39                ; Coarse up
F3          = 47                ; Fine up
F5          = 55                ; Fine down
F7          = 63                ; Coarse down
RETURN      = 15                ; Write to EEPROM and exit

* = $1800
Main:       jsr SETOUT          ; Configure MIDI output
            lda #$0f            ; Set channel to CV
            jsr SETCH           ; ,,
            lda #$00            ; Starting point for calibration is
            sta CALIB           ; $0400. This is just a guess, based on
            lda #$04            ; a few samples of the DAC.
            sta CALIB+1         ; ,,
show:       ldx CALIB           ; Show current DAC value
            lda CALIB+1         ; ,,
            jsr PRTFIX          ; ,,
            lda #$0d            ; ,,
            jsr CHROUT          ; ,,
send:       ldx CALIB           ; CALIB is a 16-bit value with a 12-bit range.
            txa                 ;   It needs to be converted to 7-bit MIDI data
            asl                 ; Send bit 7 of low byte over to the MSB
            lda CALIB+1         ; ,,
            rol                 ; ,,
            and #%00011111      ; Keep 5 bits (the other 7 will be in the LSB)
            tay                 ; PITCHB expects MSB in Y
            jsr PITCHB          ; Send CV with MIDI LSB in X and MSB in Y    
-debounce:  lda KEYDOWN         ; Debounce key
            cmp #$40            ; ,,
            bne debounce        ; ,,
adjust:     lda KEYDOWN         ; Wait for key press
            cmp #$40            ; ,,
            beq adjust          ; ,,
            cmp #RETURN         ; If RETURN has been pressed, commit the
            beq commit          ;   new CV value to EEPROM
            ldy #4              ; Check for each of the adjustment keys (F1-F7)
search:     cmp KeyTable,y      ; ,,
            beq found           ; ,, If the key has been found, do adjustment
            dey                 ; ,,
            bpl search          ; ,,
            bmi adjust          ; If the pressed key isn't on the list, go back
found:      lda LowAdd,y        ; Get the fine or coarse adjustment values from
            clc                 ;   the table, depending on the key index, and
            adc CALIB           ;   adjust the 16-bit calibration value as
            sta CALIB           ;   indicated in the table
            lda HighAdd,y       ;   ,,
            adc CALIB+1         ;   ,,
            sta CALIB+1         ;   ,,
            jmp show            ; Show the new voltage
commit:     lda CALIB           ; Convert the 16-bit calibration value into
            sta BURN            ;   two 7-bit values for sending over MIDI
            asl                 ;   ,,
            lda CALIB+1         ;   ,,     
            rol                 ;   ,,
            and #%00011111      ;   ,,
            sta BURN+1          ;   ,,
            ldy #4              ; Send the system exclusive header for
-loop:      lda SysEx,y         ;   calibration commit
            jsr MIDIOUT         ;   ,,
            dey                 ;   ,,
            bpl loop            ;   ,,
            lda BURN            ; Send the calibration values
            jsr MIDIOUT         ; ,,
            lda BURN+1          ; ,,
            jsr MIDIOUT         ; ,,
            lda #$f7            ; End of exclusive and return
            jmp MIDIOUT         ; ,,

#include "midikernal.asm"

KeyTable:   .byte F1,F3,F5,F7
LowAdd:     .byte $20,$01,$ff,$e0
HighAdd:    .byte $00,$00,$ff,$ff
SysEx:      .byte $63,$76,$62,$7d,$f0
