.include "libSFX.i"

.include "usb.i"
.include "memctl.i"

.feature force_range

;-------------------------------------------------------------------------------
.segment "ZEROPAGE"

USBConnect:   .res 1
USBCommand:   .res 1
USBStatus:    .res 1
; TODO: work out better what these flags are actually supposed to do
USBReadBusy:  .res 1
USBWriteBusy: .res 1

USBAddress: .res 4
USBParam:   .res 2

USBReadAddr:  .res 3
USBWriteAddr: .res 3
; distance into read/write ptr
USBWriteSize: .res 2

;-------------------------------------------------------------------------------
.segment "LORAM"

USBChipVer: .res 1
USBReadSize: .res 1
USBCmdSize: .res 1
; read/write callbacks
USBRead:  .res 2
USBWrite: .res 2
; R/W memory control
USBMemMapSel:  .res 1
USBMemMapCart: .res 1

;-------------------------------------------------------------------------------
.segment "RAMCODE"

proc USBInit
	lda #$ff
	sta USBChipVer
	
	jsr USBReset
	
	lda #GET_IC_VER
	sta USB_CMD
	sta USBCommand
	nop
	lda USB_DATA
	and #$7f
	sta USBChipVer
	
	lda #CHECK_EXIST
	sta USB_CMD
	sta USBCommand
	lda #$55
	sta USB_DATA
	eor #$ff
	cmp USB_DATA
	bne err
	lda #CHECK_EXIST
	sta USB_CMD
	sta USBCommand
	lda #$aa
	sta USB_DATA
	eor #$ff
	cmp USB_DATA
	bne err

	; set USB VID/PID
	lda #SET_USB_ID
	sta USB_CMD
	sta USBCommand
	lda #<UFO_VENDOR_ID
	sta USB_DATA
	lda #>UFO_VENDOR_ID
	sta USB_DATA
	lda #<UFO_PRODUCT_ID
	sta USB_DATA
	lda #>UFO_PRODUCT_ID
	sta USB_DATA
	WAIT_vbl
	
	; set USB to internal firmware/USB device mode
	lda #SET_USB_MODE
	sta USB_CMD
	sta USBCommand
	WAIT_vbl
	lda #$02
	sta USB_DATA
	jsr USBRtnStatus
	bcs err
	
ok:
;	WAIT_vbl
;	CGRAM_setcolor_rgb 0, 0,20,0
	clc
	rts
err:
;	WAIT_vbl
;	CGRAM_setcolor_rgb 0, 20,0,0
	sec
	rts
endproc

;-------------------------------------------------------------------------------
proc USBReset
	; reset USB
	lda #RESET_ALL
	sta USB_CMD
	sta USBCommand

	; set up I/O callbacks
	ldx #ReadIdle
	stx USBRead
	ldx #WriteIdle
	stx USBWrite
	
	; wait for USB to come alive
	WAIT_frames 5
	rts
endproc

;-------------------------------------------------------------------------------
proc USBUnlock
	lda #UNLOCK_USB
	sta USB_CMD
	sta USBCommand
	rts
.endproc

;-------------------------------------------------------------------------------
proc USBRtnStatus
	ldx #$80
:	lda USB_DATA
	cmp #CMD_RET_ABORT
	beq err
	cmp #CMD_RET_SUCCESS
	beq ok
	dex
	bpl :-
	; timeout = assume error
err:
	sec
	rts
ok:
	clc
	rts
endproc

;-------------------------------------------------------------------------------
proc USBProcess
.if 0
	; make sure USB is actually mapped in
	lda #CHECK_EXIST
	sta USB_CMD
	sta USBCommand
	lda SFX_tick
	sta USB_DATA
	eor #$ff
	cmp USB_DATA
	beq :+
	stz USBConnect
	sec
	rts
:
.endif

	lda USB_STATUS
	and #USB_STATUS_CONNECTED
	beq :+
	; cable connection present
	lda #$ff
:	sta USBConnect

	; test interrupt status
	bit USB_CMD
	bpl :+
	clc
	rts	
	
	; handle USB interrupt
:	lda #GET_STATUS
	sta USB_CMD
	sta USBCommand
	nop
	lda USB_DATA
	sta USBStatus
	
	cmp #USB_INT_EP2_OUT
	bne :+
	; go to read complete callback
	jmp (USBRead)
	
:	cmp #USB_INT_EP2_IN
	bne :+
	; go to write complete callback
	jmp (USBWrite)

	; otherwise release buffer
:	
end:
	jsr USBUnlock
	
	; wait to make sure previous interrupt is clear
	; TODO: adjust this again?
	ldx #$0080
:	bit USB_CMD
	bpl :+
	clc
	rts	
:	dex
	bne :--
	
	jmp USBProcess
endproc


;-------------------------------------------------------------------------------
TestOutput: .byte "Hello world!"

proc CmdSysInfo
	; just a test...
	ldx #TestOutput
	lda #^TestOutput
	stx USBAddress
	sta USBAddress+2
	ldx #12
	stx USBParam
	jmp WriteBulkStart
endproc

;-------------------------------------------------------------------------------
proc CmdRunCart
	jmp BootCartridge
endproc

;-------------------------------------------------------------------------------
proc CmdReboot
	jmp BootUFO
endproc

;-------------------------------------------------------------------------------
proc CmdReadCart
	stz USBMemMapCart
	; cart always mapped to banks $80+
	lda #$80
	tsb USBAddress+2
	beq :+
	; map upper half of cart if address is in bank $80+
	sta USBMemMapCart
:	lda #MAP_SEL_CART
	sta USBMemMapSel
	jmp WriteBulkStart
endproc

;-------------------------------------------------------------------------------
proc CmdReadSystem
	lda #MAP_SEL_DRAM
	sta USBMemMapSel
	stz USBMemMapCart
	jmp WriteBulkStart
endproc

;-------------------------------------------------------------------------------
proc CmdWriteCart
	; TODO: temp. unmap most/all of DRAM to avoid clobbering it
	stz USBMemMapCart
	; cart always mapped to banks $80+
	lda #$80
	tsb USBAddress+2
	beq :+
	; map upper half of cart if address is in bank $80+
	sta USBMemMapCart
:	lda #MAP_SEL_CART
	sta USBMemMapSel
	jmp ReadBulkStart
endproc

;-------------------------------------------------------------------------------
proc CmdWriteSystem
	lda #MAP_SEL_DRAM
	sta USBMemMapSel
	stz USBMemMapCart
	jmp ReadBulkStart
endproc

;-------------------------------------------------------------------------------
proc CmdJumpCart
	jsr DRAMDisable
	jsr UFODisable
	ldx USBParam
	txa
	jml [USBAddress]
endproc

;-------------------------------------------------------------------------------
proc CmdJumpSystem
	jsr DRAMEnable
	ldx USBParam
	txa
	jml [USBAddress]
endproc

;-------------------------------------------------------------------------------
proc CmdCallCart
	jsr DRAMDisable
	jsr UFODisable
	phk
	per (:+)-1
	ldx USBParam
	txa
	jml [USBAddress]
:	jsr UFOEnable
	jsr DRAMEnable
	clc
	rts
endproc

;-------------------------------------------------------------------------------
proc CmdCallSystem
	jsr DRAMEnable
	phk
	per (:+)-1
	ldx USBParam
	txa
	jml [USBAddress]
:	clc
	rts
endproc

;-------------------------------------------------------------------------------
USBCommands:
.addr CmdSysInfo
.addr CmdRunCart
.addr CmdReboot
.addr CmdReadCart
.addr CmdReadSystem
.addr CmdWriteCart
.addr CmdWriteSystem
.addr CmdJumpCart
.addr CmdJumpSystem
.addr CmdCallCart
.addr CmdCallSystem
NUM_COMMANDS = (*-USBCommands)>>1

;-------------------------------------------------------------------------------
; callback for USB reads while idle
proc ReadIdle
	; clear error/busy flag
	stz USBReadBusy
	
	; clear memory map settings from last read/write
	stz USBMemMapSel
	stz USBMemMapCart
	stz UFO_MAP_MODE
	
	lda #RD_USB_DATA
	sta USB_CMD
	sta USBCommand
	nop
	; make sure input command is the right size
	lda USB_DATA
	sta USBReadSize
	bne :+
	; no data = done
	jmp USBProcess
	
:	; make sure the size stated in the command is also correct
	lda USB_DATA
	sta USBCmdSize
	cmp #8
	bne err_size
	; get the command byte
	lda USB_DATA ; make sure it's a valid command
	cmp #NUM_COMMANDS
	bcs err_cmd
	pha
	; get address bytes
	lda USB_DATA
	sta USBAddress
	lda USB_DATA
	sta USBAddress+1
	lda USB_DATA
	sta USBAddress+2
	lda USB_DATA
	sta USBAddress+3
	; get parameter bytes
	lda USB_DATA
	sta USBParam
	lda USB_DATA
	sta USBParam+1

	; run command
	lda #0
	xba
	pla
	asl
	tax
	jmp (.loword(USBCommands),x)
	
err_size:
err_cmd:
	; read out the rest of the crap
	; (TODO: maybe keep handling the rest of a bulk transfer here instead of 
	;  to USBProcess every time, to make extra sure previous data is ignored)
	ldx #64
:	lda USB_DATA
	nop
	dex
	bne :-
	
	jmp USBProcess
endproc

;-------------------------------------------------------------------------------
proc ReadBulkStart
	ldx USBAddress
	stx USBReadAddr
	lda USBAddress+2
	sta USBReadAddr+2
	
	lda USBReadSize
	cmp #USB_BUF_SIZE
	bne :+
	
	; there's more
	; set busy flag
	lda #USB_STATUS_BUSY
	tsb USBReadBusy
	ldx #ReadBulkCont
	stx USBRead
	
:	sec
	sbc USBCmdSize
	beq end

	; start copy
	jsr DoRead
end:	
	jmp USBProcess
endproc

;-------------------------------------------------------------------------------
proc ReadBulkCont
	lda #RD_USB_DATA
	sta USB_CMD
	sta USBCommand
	nop
	
	ldx USB_DATA
	cpx #USB_BUF_SIZE
	beq cont

	; 0-63 bytes = end transfer now
	lda #USB_STATUS_BUSY
	trb USBReadBusy
	ldy #ReadIdle
	sty USBRead
	
	cpx #0
	beq end
	
cont:
	; start copy
	jsr DoRead
end:	
	jmp USBProcess
endproc

;-------------------------------------------------------------------------------
; X = byte count (1-64)
proc DoRead
	
	lda USBMemMapSel
	sta UFO_MAP_SEL
	lda USBMemMapCart
	sta UFO_MAP_GAME
	ldy USBReadAddr
	
	phb
	phd
	lda USBReadAddr+2
	pha
	plb
	pea $2100
	pld

	lda #0
	xba
	txa
	dec
	asl
	tax
	jmp (looptab,x)
	
looptab:
.repeat 64, i
	.addr loop+((63-i)*6)
.endrep
loop:
.repeat 64
	lda z:$8c ; USB_DATA
	sta a:0,y
	iny
.endrep
	
	pld
	plb
	
	sty USBReadAddr
	lda #MAP_SEL_DRAM
	sta UFO_MAP_SEL
	stz UFO_MAP_GAME
	
	rts
endproc

;-------------------------------------------------------------------------------
; callback for USB writes while idle
proc WriteIdle
	; clear error/busy flag
	stz USBWriteBusy
	jsr USBUnlock
	jmp USBProcess
endproc

;-------------------------------------------------------------------------------
proc WriteBulkStart
	ldx USBAddress
	stx USBWriteAddr
	lda USBAddress+2
	sta USBWriteAddr+2
	
	ldx USBParam
	stx USBWriteSize
	beq :+ ; param 0 = send full 64k bytes
	cpx #USB_BUF_SIZE+1
	bcc short
	
	; there's more
	; start w/ full size transfer
:	RW a16
	txa
	sec
	sbc #USB_BUF_SIZE
	sta USBWriteSize
	RW a8
	
	; set busy flag
	lda #USB_STATUS_BUSY
	tsb USBWriteBusy
	ldx #WriteBulkCont
	stx USBWrite
	
	ldx #USB_BUF_SIZE
	; 0-63 bytes
short:	
	jsr DoWrite
end:
	; only unlock buffer when writing in response to an interrupt
;	jsr USBUnlock
	jmp USBProcess
endproc

;-------------------------------------------------------------------------------
proc WriteBulkCont
	ldx USBWriteSize
	cpx #USB_BUF_SIZE+1
	bcs cont

	; 0-64 bytes = end transfer now
	lda #USB_STATUS_BUSY
	trb USBWriteBusy
	ldy #WriteIdle
	sty USBWrite

	bra write
	
cont:
	; 64+ bytes: keep going
	RW a16
	txa
	sec
	sbc #USB_BUF_SIZE
	sta USBWriteSize
	RW a8

	ldx #USB_BUF_SIZE
	
write:
	jsr DoWrite
end:
	jsr USBUnlock
	jmp USBProcess
endproc

;-------------------------------------------------------------------------------
; X = byte count (0-64)
proc DoWrite
	lda #WR_USB_DATA7
	sta USB_CMD
	sta USBCommand
	
	lda USBMemMapSel
	sta UFO_MAP_SEL
	lda USBMemMapCart
	sta UFO_MAP_GAME
	ldy USBWriteAddr
	
	phb
	phd
	lda USBWriteAddr+2
	pha
	plb
	pea $2100
	pld

	lda #0
	xba
	txa
	sta z:<USB_DATA
	asl
	tax
	jmp (looptab,x)
	; 0 = end transfer, else write 1-64 bytes
looptab:
.repeat 65, i
	.addr loop+((64-i)*6)
.endrep
loop:
.repeat 64
	; TODO: how to return open bus if it's there?
	; with this loop, unmapped memory would just return all zeroes (not ideal...)
	lda a:0,y
	sta z:$8c ; USB_DATA
	iny
.endrep

	pld
	plb

	sty USBWriteAddr
	lda #MAP_SEL_DRAM
	sta UFO_MAP_SEL
	stz UFO_MAP_GAME
	
	rts
endproc