.include "libSFX.i"
.include "memctl.i"

UFO_BANK_SET = $00218a
UFO_BANK_EN  = $00218b

;-------------------------------------------------------------------------------
.segment "CODE"

proc EnableUFO ; map BIOS and R/W DRAM, enable registers
	lda #$0a
	sta UFO_BANK_EN
	stz UFO_BANK_SET
	stz UFO_BANK_EN
	rts
endproc

;-------------------------------------------------------------------------------
proc DisableUFO ; map DRAM only, disable registers
	lda #$0a
	sta UFO_BANK_EN
	inc UFO_BANK_SET
	stz UFO_BANK_EN
	rts
endproc
