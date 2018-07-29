.include "libSFX.i"
.include "memctl.i"
.include "cartinfo.i"

;-------------------------------------------------------------------------------
.segment "ZEROPAGE"

ROMStartBank: .res 1
ROMNumBanks:  .res 1
ROMStartPage: .res 1
ROMNumPages:  .res 1

RAMStartBank: .res 1
RAMNumBanks:  .res 1
RAMStartPage: .res 1
RAMNumPages:  .res 1

MapperType:   .res 1

; temp. for checking mirroring
CheckBankMin: .res 1
CheckPageMin: .res 1
CheckBankMax: .res 1
CheckPageMax: .res 1

;-------------------------------------------------------------------------------
.segment "LORAM"

UnitTitle: .res 30
CartTitle: .res 22

;-------------------------------------------------------------------------------
.segment "RAMCODE"
;                123456789012345678901
nocart: .asciiz "No cartridge detected"

proc GetCartInfo
	stz z:ROMNumBanks
	stz z:RAMNumBanks
	stz z:MapperType

	; get title of current copier unit
	memcpy UnitTitle, $008004, 29
	stz UnitTitle+29
	
	; map in cartridge
	jsr DRAMDisable
	jsr UFODisable
	
	; cartridge present?
	phb
	lda #$00
	pha
	plb
	ldx $fffc
	plb
	cpx #$8000
	bcc :+
	cpx #$ffff
	bne :++
	
:	; nope
	memcpy CartTitle, nocart, 21
	stz CartTitle+21
	sec
	jmp EndCartInfo

:	; cartridge found
	memcpy CartTitle, $00ffc0, 21
	stz CartTitle+21
	
	; TODO: check for special cart types (BS-X, etc.) here
	; and for any special memory mapping chips like SA-1
	
	; see if this is HiROM (upper 32k of bank C0 is present/unique)
CheckHiROM:
	lda #$c0
	xba
	lda #$c0
	ldx #$0000
	ldy #$8000
	jsr BanksMirror
	bcs CheckLoROM
	lda #$c0
	ldx #$0000
	jsr BankIsOpenBus
	bcs CheckLoROM
	; bank $C0 appears to be fully mapped now
	lda #$c0
	sta z:ROMStartBank
	lda #$40
	sta z:ROMNumBanks ; TODO: account for ExHiROM
	stz z:ROMStartPage
	stz z:ROMNumPages ; 0 = 256 pages
	bra CheckROMSize
	
CheckLoROM:
	lda #$80
	sta z:ROMStartBank
	sta z:ROMNumBanks
	sta z:ROMStartPage
	sta z:ROMNumPages
	; see if bank $80 can be considered a mirror of $00
	ldx #$8000
	jsr BankIsOpenBus
	bcc CheckROMSize
	; check $00-3F only
	stz z:ROMStartBank
	lsr z:ROMNumBanks

	; TODO: attempt actual size detection here
CheckROMSize:
	break
	lda z:ROMStartBank
	sta z:CheckBankMin
	lda z:ROMNumBanks
	sta z:CheckBankMax
	
	lda z:ROMStartPage
	sta z:CheckPageMin
	lda z:ROMNumPages
	sta z:CheckPageMax
	
	jsr CheckBankRange
	
	lda z:CheckBankMax
	sta z:ROMNumBanks

	lda z:CheckPageMax
	sta z:ROMNumPages
	lda z:CheckPageMin
	sta z:ROMStartPage

	clc
EndCartInfo:
	jsr UFOEnable
	jsr DRAMEnable
	rts
endproc

;-------------------------------------------------------------------------------
proc CheckBankRange
	; first get the actual # of pages in the first bank
	jsr CheckPageRange

	; Check the current bank range for mirroring/open bus to try to determine
	; the actual mapping size
	; see if we can cut the current range in half
	; current start bank
@start:
	lda z:CheckPageMin
	xba
	lda #0
	tax
	tay
	stx ZPAD+8
	
	; new possible end bank
	lda z:CheckBankMax
	lsr
	clc
	adc z:CheckBankMin
	sta ZPAD+10
	
	xba
	lda z:CheckBankMin
	jsr PagesMirror
	bcs :+
	; doesn't appear to mirror but make sure it's not open bus
	ldx ZPAD+8
	lda ZPAD+10
	; check first page of bank only; page range is already known
	jsr PageIsOpenBus 
	bcc @end
	
:	; banks mirror - narrow the range and start over
	lsr z:CheckBankMax
	bne @start ; if there are still any banks to check
	
@end:
	; TODO: work upwards if current banks don't match
	; (only needed for oddly sized ROMs)
	rts
endproc

;-------------------------------------------------------------------------------
proc CheckPageRange
	; see if we can cut the current range in half
	; current start page
	lda z:CheckPageMin
	xba
	lda #0
	tax
	stx ZPAD+8
	
	; new possible end page
	lda z:CheckPageMax
	lsr
	clc
	adc z:CheckPageMin
	xba
	lda #0
	tay
	sty ZPAD+10
	
	lda z:CheckBankMin
	xba
	lda z:CheckBankMin
	jsr PagesMirror
	bcs :+
	; doesn't appear to mirror but make sure it's not open bus
	ldx ZPAD+10
	lda z:CheckBankMin
	jsr PageIsOpenBus
	bcc @end
	
:	; pages mirror - narrow the range and start over
	lsr z:CheckPageMax
	bne CheckPageRange ; if there are still any pages to check
	
@end:
	; pages don't mirror; we're done
	rts
endproc

;-------------------------------------------------------------------------------
PageIsOpenBus:
	stx ZPAD
	sta ZPAD+2
	stx ZPAD+3
	sta ZPAD+5
proc _PageIsOpenBus
	ldy #$7f
:	lda [ZPAD],y
	cmp ZPAD+2
	clc
	bne @end
	lda [ZPAD+3],y
	cmp ZPAD+5
	clc
	bne @end
	dey
	bpl :-
	; if we reach here then the page is open bus
	sec
@end:
	rts
endproc

;-------------------------------------------------------------------------------
; check 4 pages (32k LoROM segment or HiROM upper/lower segment
proc BankIsOpenBus
	stx ZPAD
	sta ZPAD+2
	stx ZPAD+3
	sta ZPAD+5
	lda #$80
	tsb ZPAD+3
	ldx #4
:	jsr _PageIsOpenBus
	bcs @end
	lda ZPAD+1
	adc #$20
	sta ZPAD+1
	lda ZPAD+4
	adc #$20
	sta ZPAD+4
	dex
	bne :-
	; if we reach here then none of the pages we checked are open bus
	clc
@end:
	rts
endproc

;-------------------------------------------------------------------------------
PagesMirror:
	stx ZPAD
	sta ZPAD+2
	sty ZPAD+3
	xba
	sta ZPAD+5
proc _PagesMirror
	ldy #$ff
:	lda [ZPAD],y
	cmp [ZPAD+3],y
	clc
	bne @end
	dey
	bpl :-
	; if we reach here then the pages mirror
	sec
@end:
	rts
endproc

;-------------------------------------------------------------------------------
proc BanksMirror
	stx ZPAD
	sta ZPAD+2
	sty ZPAD+3
	xba
	sta ZPAD+5
	ldx #4
:	jsr _PagesMirror
	bcs @end
	lda ZPAD+1
	adc #$20
	sta ZPAD+1
	lda ZPAD+4
	adc #$20
	sta ZPAD+4
	dex
	bne :-
	; if we reach here then none of the pages we checked mirror each other
	clc
@end:
	rts
endproc

;-------------------------------------------------------------------------------
proc PageIsWritable
	; TODO ...
	sec
@end:
	rts
endproc
