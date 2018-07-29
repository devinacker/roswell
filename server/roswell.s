.include "libSFX.i"

.include "usb.i"
.include "memctl.i"
.include "cartinfo.i"

;-------------------------------------------------------------------------------
.segment "ZEROPAGE"

To218x: .res 8

;-------------------------------------------------------------------------------
.segment "LORAM"

; store some test data from cartridge banks
TestData: .res 16*16

Tilemap: .res 32*32*2

;-------------------------------------------------------------------------------
.segment "RODATA"
incbin	FontTiles, "data/font.png.tiles.lz4"
incbin	FontPalette, "data/font.png.palette"

InfoText:
.asciiz "Roswell USB server v0.1"

;-------------------------------------------------------------------------------
.segment "CODE"

VRAM_TILEMAP       = $0000
VRAM_CHARSET       = $2000

proc Main
	; load main server code
	memcpy __RAMCODE_RUN__, __RAMCODE_LOAD__, __RAMCODE_SIZE__

	; decompress and load font
	LZ4_decompress FontTiles, EXRAM, y
	VRAM_memcpy VRAM_CHARSET, EXRAM, y
	CGRAM_memcpy 0, FontPalette, sizeof_FontPalette
	
	; set background color
	CGRAM_setcolor_rgb 0, 0,0,0
		
	; set up screen (mode 0, all 8x8 tiles)
	lda #bgmode(BG_MODE_0, BG3_PRIO_NORMAL, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8)
	sta BGMODE
	; set up layer 1 (with 1x1 playfield)
	lda #bgsc(VRAM_TILEMAP, SC_SIZE_32X32)
	sta BG1SC
	
	; set up tileset
	ldx #bgnba(VRAM_CHARSET, 0, 0, 0)
	stx BG12NBA
	
	; enable layer 1 only
	lda #tm(ON, OFF, OFF, OFF, OFF)
	sta TM
	
	; turn on screen
	lda #inidisp(ON, DISP_BRIGHTNESS_MAX)
	sta INIDISP
	WAIT_vbl

	; enable joypad polling
	lda #$01
	sta NMITIMEN

	jsr UFOEnable

	lda #$0a
	sta To218x+7

	; set LoROM, 32 Mbit DRAM, no SRAM
	lda #$40
	sta UFO_SRAM_SIZE
	sta To218x+0
	lda #$55
	sta UFO_DRAM_SIZE
	sta To218x+2
	lda #$01
	sta UFO_MAP_ROM
	sta To218x+4
	; firmware mode already set, enable DRAM only (ignores mapping)
	stz UFO_MAP_SEL
	stz To218x+5
	
	jmp entry
;-------------------------------------------------------------------------------
.segment "RAMCODE"

entry:
	break
	jsr GetCartInfo
	jsr USBInit

	; show info line
	ldy #$40
	ldx #.loword(InfoText)
	jsr PrintString
	; show copier ROM name
	ldy #$80
	ldx #.loword(UnitTitle)
	jsr PrintString
	
	; show cart title and mapping
	ldy #$140
	ldx #.loword(CartTitle)
	jsr PrintString
	
	; if any ROM actually exists:
	lda ROMNumBanks
	beq PrintRAM
	
PrintROM:
	; "ROM: "
	ldy #$180
	lda #$52 ;'R'
	sta Tilemap,y
	iny
	iny
	lda #$4F ;'O'
	sta Tilemap,y
	iny
	iny
	lda #$4D ;'M'
	sta Tilemap,y
	iny
	iny
	lda #$3A ;':'
	sta Tilemap,y
	iny
	iny
	lda #$20 ;' '
	sta Tilemap,y
	iny
	iny

	lda #$24 ;'$'
	sta Tilemap,y
	iny
	iny
	lda ROMStartBank
	jsr PrintByte
	lda #$2D ;'-'
	sta Tilemap,y
	iny
	iny
	lda ROMNumBanks
	clc
	adc ROMStartBank
	dec
	jsr PrintByte
	lda #$3A ;':'
	sta Tilemap,y
	iny
	iny
	lda ROMStartPage
	jsr PrintByte
	lda #$00
	jsr PrintByte
	lda #$2D ;'-'
	sta Tilemap,y
	iny
	iny
	lda ROMNumPages
	clc
	adc ROMStartPage
	dec
	jsr PrintByte
	lda #$FF
	jsr PrintByte

PrintRAM:
	; TODO

	; Main loop
loop:

:	bit $4212
	bmi :-
:	bit $4212
	bpl :-
	; in vblank - update tilemap
	jsr VBL

	; end
	bra loop
endproc

;-------------------------------------------------------------------------------
proc VBL
	VRAM_memcpy VRAM_TILEMAP, Tilemap, 32*32*2
	jsr GetJoy
:	jsr USBProcess
	bcc :- ; test
	jsr MemCtrlTest
	
	rts
endproc

;-------------------------------------------------------------------------------
proc GetJoy
:	lda     HVBJOY                  ;Wait for joypad read-out
	and     #1
	bne     :-

	RW_push set:a16
	ldx     z:SFX_joy1cont
	lda     JOY1L
	sta     z:SFX_joy1cont
	txa
	eor     z:SFX_joy1cont
	and     z:SFX_joy1cont
	sta     z:SFX_joy1trig
	RW_pull
	rts
endproc

;-------------------------------------------------------------------------------
proc MemCtrlTest
.ifdef MEM_CTL_TEST
	; use joypad to update vals
	ldx #0
	
	lda z:SFX_joy1cont
	and #$20 ; L
	beq :+
	ldx #1
:	lda z:SFX_joy1cont+1
	and #$10 ; start
	beq :+
	ldx #2
:	lda z:SFX_joy1cont+1
	and #$40 ; Y
	beq :+
	ldx #3
:	lda z:SFX_joy1cont
	and #$40 ;X
	beq :+
	ldx #4
:	lda z:SFX_joy1cont+1
	and #$80 ;B
	beq :+
	ldx #5
:	lda z:SFX_joy1cont
	and #$80 ; A
	beq :+
	ldx #6
:	lda z:SFX_joy1cont
	and #$10 ; R
	beq :+
	ldx #7
:
	lda z:SFX_joy1trig+1
	and #$08 ;up
	beq :+
	lda z:To218x,x
	clc
	adc #$10
	sta z:To218x,x
	sta $2184,x
:	lda z:SFX_joy1trig+1
	and #$04 ;down
	beq :+
	lda z:To218x,x
	sec
	sbc #$10
	sta z:To218x,x
	sta $2184,x
:	lda z:SFX_joy1trig+1
	and #$02 ; left
	beq :+
	lda z:To218x,x
	dec
	sta z:To218x,x
	sta $2184,x
:	lda z:SFX_joy1trig+1
	and #$01 ; right
	beq :+
	lda z:To218x,x
	inc
	sta z:To218x,x
	sta $2184,x
:

	; set up map mode (temp)
	lda z:To218x+7
	sta $218b
	lda z:To218x+6
	sta $218a

	; populate test data
	memcpy TestData+$00, $008000, 16
	memcpy TestData+$10, $018000, 16
	memcpy TestData+$20, $028000, 16
	memcpy TestData+$30, $038000, 16
	memcpy TestData+$40, $048000, 16
	memcpy TestData+$50, $058000, 16
	memcpy TestData+$60, $068000, 16
	memcpy TestData+$70, $078000, 16
	memcpy TestData+$80, $088000, 16
	memcpy TestData+$90, $098000, 16
	memcpy TestData+$a0, $0a8000, 16
	memcpy TestData+$b0, $0b8000, 16
	memcpy TestData+$c0, $0c8000, 16
	memcpy TestData+$d0, $0d8000, 16
	memcpy TestData+$e0, $0e8000, 16
	memcpy TestData+$f0, $0f8000, 16

	; display mapping registers
	ldy #0
	ldx #0
:	lda z:To218x,x
	jsr PrintByte
	iny
	iny
	inx
	cpx #8
	bcc :-

	; display USB cable status, last command, last interrupt
	lda USBConnect
	jsr PrintByte
	iny
	iny
	lda USBCommand
	jsr PrintByte
	iny
	iny
	lda USBStatus
	jsr PrintByte
	
	; show values read from UFO registers
	ldy #$40
	ldx #0
:	lda $2184,x
	jsr PrintByte
	iny
	iny
	inx
	cpx #$0c
	bcc :-
		
	; restore memory
	jsr UFOEnable
		
	; show cartridge test data
	ldy #$80
	ldx #0
:	lda TestData,x
	jsr PrintByte
	inx
	cpx #16*16
	bcc :-
.endif ; MEM_CTL_TEST
	rts
endproc

;-------------------------------------------------------------------------------
proc PrintString
:	lda a:0,x
	beq :+
	sta Tilemap,y
	inx
	iny
	iny
	bra :-
:	rts
endproc

;-------------------------------------------------------------------------------
ByteTbl: .byte "0123456789ABCDEF"

proc PrintByte
	phx
	xba
	lda #0
	xba
	pha
	lsr
	lsr
	lsr
	lsr
	tax
	lda ByteTbl,x
	sta Tilemap,y
	iny
	lda #0
	sta Tilemap,y
	iny
	
	pla
	and #$0f
	tax
	lda ByteTbl,x
	sta Tilemap,y
	iny
	lda #0
	sta Tilemap,y
	iny
	
	plx
	rts
endproc
