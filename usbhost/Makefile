# Name
name		:= ../roswell
debug		:= 1

libsfx_packages := LZ4

derived_files   += data/font.png.tiles data/font.png.palette
derived_files   += data/font.png.tiles.lz4
data/font.png.palette: palette_flags = -C 4
data/font.png.tiles: tiles_flags = -B 2 --no-discard --no-flip

# Include libSFX.make
libsfx_dir	:= ../../../libSFX
include $(libsfx_dir)/libSFX.make
