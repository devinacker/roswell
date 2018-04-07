.global UFOEnable,  UFODisable
.global DRAMEnable, DRAMDisable
.global BootUFO, BootCartridge

UFO_MAP_GAME = $002187
UFO_MAP_SEL  = $002189
UFO_MAP_MODE = $00218a
UFO_MAP_EN   = $00218b

MAP_SEL_DRAM = $00
MAP_SEL_CART = $03

MAP_MODE_UFO    = $00
MAP_MODE_UPDATE = $0A
MAP_MODE_GAME   = $FF

MAP_ENABLE = $0A