.include "libSFX.i"
.include "memctl.i"

;-------------------------------------------------------------------------------
.segment "ZEROPAGE"

;-------------------------------------------------------------------------------
.segment "RAMCODE"

;-------------------------------------------------------------------------------
proc UFOEnable ; map BIOS and R/W DRAM, enable registers
	lda #MAP_ENABLE
	sta UFO_MAP_EN
	stz UFO_MAP_MODE
	rts
endproc

;-------------------------------------------------------------------------------
proc UFODisable ; map game only, disable registers
	inc UFO_MAP_MODE
	stz UFO_MAP_EN
	rts
endproc

;-------------------------------------------------------------------------------
proc DRAMEnable ; enable DRAM/SRAM in game banks
	stz UFO_MAP_SEL
	rts
endproc

;-------------------------------------------------------------------------------
proc DRAMDisable ; disable DRAM/SRAM in game banks (access cartridge only)
	lda #MAP_SEL_CART
	sta UFO_MAP_SEL
	rts
endproc

;-------------------------------------------------------------------------------
proc BootUFO
	jsr UFOEnable
	jsr DRAMEnable
	jml Reboot ; get into bank $00
endproc

;-------------------------------------------------------------------------------
proc BootCartridge
	jsr DRAMDisable
	jsr UFODisable
	jml Reboot ; get into bank $00
endproc

;-------------------------------------------------------------------------------
proc Reboot
	phk
	plb
	pea $0000
	pld
	ldx #$01ff
	txs
	rep #%11001010 ; set E, M, X, I and clear all other flags
	sep #%00110101
	xce
	jmp ($fffc)
endproc
