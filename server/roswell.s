.include "libSFX.i"

.include "usb.i"
.include "memctl.i"

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
.byte 2, 2, "Roswell USB host v0.0"

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

	break
	jsr USBInit

	lda #$0a
	sta To218x+7

	jmp loop
;-------------------------------------------------------------------------------
.segment "RAMCODE"
	; Main loop
loop:
	jsr USBProcess

.if 0
:	bit $4212
	bmi :-
:	bit $4212
	bpl :-
	; in vblank - update tilemap
	jsr VBL
.endif 

	; end
	bra loop
endproc

;-------------------------------------------------------------------------------
proc VBL
	VRAM_memcpy VRAM_TILEMAP, Tilemap, 32*32*2
	jsr GetJoy
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
.if 0
	; write mapping registers
	lda To218x+7
	sta $218b
	ldx #0
:	lda To218x,x
	sta $2184,x
	nop
	nop
	nop
	nop
	inx
	cpx #7
	bcc :-
.endif

	; populate test data
	memcpy TestData+$00, $008000, 16
	memcpy TestData+$10, $108000, 16
	memcpy TestData+$20, $208000, 16
	memcpy TestData+$30, $308000, 16
	memcpy TestData+$40, $408000, 16
	memcpy TestData+$50, $508000, 16
	memcpy TestData+$60, $608000, 16
	memcpy TestData+$70, $708000, 16
	memcpy TestData+$80, $808000, 16
	memcpy TestData+$90, $908000, 16
	memcpy TestData+$a0, $a08000, 16
	memcpy TestData+$b0, $b08000, 16
	memcpy TestData+$c0, $c08000, 16
	memcpy TestData+$d0, $d08000, 16
	memcpy TestData+$e0, $e08000, 16
	memcpy TestData+$f0, $f08000, 16
		
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
	
	; show cartridge test data
	ldy #$80
	ldx #0
:	lda TestData,x
	jsr PrintByte
	inx
	cpx #16*16
	bcc :-

	rts
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
