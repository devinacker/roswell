.global UFOEnable,  UFODisable
.global DRAMEnable, DRAMDisable
.global BootUFO, BootCartridge

UFO_SRAM_SIZE= $002184 ; SRAM size/mapping, DRAM size (high bits)
UFO_MAP_SRAM = $002185 ; SRAM mapping
UFO_DRAM_SIZE= $002186 ; DRAM size (lowest bits)
UFO_MAP_GAME = $002187 ; DRAM/cart mapping
UFO_MAP_ROM  = $002188 ; LoROM/HiROM
UFO_MAP_SEL  = $002189 ; game select
UFO_MAP_MODE = $00218a ; BIOS/update/game mode select
UFO_MAP_EN   = $00218b ; mapper enable

MAP_SEL_DRAM = $00
MAP_SEL_CART = $03

MAP_MODE_UFO    = $00
MAP_MODE_UPDATE = $0A
MAP_MODE_GAME   = $FF

MAP_ENABLE = $0A
