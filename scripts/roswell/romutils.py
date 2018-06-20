
from __future__ import print_function
from math import floor, ceil, log
import struct

valid_megabits = [4, 8, 10, 12, 16, 24, 32]

# -----------------------------------------------------------------------------
def score_header(data, offset):
	"""
	Get a score representing how likely a cartridge header is to be valid.
	This is basically copied from bsnes-plus
	"""
	# get cartridge header and vector table
	header = data[offset:offset+0x40]
	score = 0
	
	reset_vector = struct.unpack("<H", header[0x3c:0x3e])[0]
	if reset_vector < 0x8000:
		# reset vector must be between $008000-00ffff
		return 0
	
	complement   = struct.unpack("<H", header[0x1c:0x1e])[0]
	checksum     = struct.unpack("<H", header[0x1e:0x20])[0]
	# valid checksums?
	if checksum != 0 and complement != 0 and checksum + complement == 0xffff:
		score += 4

	# various initial opcodes and how to score them
	reset_opcodes = [
		# most likely opcodes
		(8, [0x78, 0x18, 0x38, 0x9c, 0x4c, 0x5c]),
		# plausible opcodes
		(4, [0xc2, 0xe2, 0xad, 0xae, 0xac, 0xaf, 0xa9, 0xa2, 0xa0, 0x20, 0x22]),
		# implausible opcodes
		(-4, [0x40, 0x60, 0x6b, 0xcd, 0xec, 0xcc]),
		# least likely opcodes
		(-8, [0x00, 0x02, 0xdb, 0x42, 0xff]),
	]
	reset_op = struct.unpack("B", data[(offset & ~0x7fff) | (reset_vector & 0x7fff)])[0]
	for opcodes in reset_opcodes:
		if reset_op in opcodes[1]:
			score += opcodes[0]
			break

	# check detected mapper (clear out ROM speed bit)
	mapper = ~0x10 & struct.unpack("B", header[0x15])[0]
	if offset == 0x7fc0 and mapper == 0x20:
		score += 2 # LoROM
	elif offset == 0xffc0 and mapper == 0x21:
		score += 2 # HiROM
		
	# company ID
	if header[0x1a] == b'\x33':
		score += 2
	# ROM size / RAM size / chipset / region
	if struct.unpack("B", header[0x16])[0] < 0x08:
		score += 1
	if struct.unpack("B", header[0x17])[0] < 0x10:
		score += 1
	if struct.unpack("B", header[0x18])[0] < 0x08:
		score += 1
	if struct.unpack("B", header[0x19])[0] < 14:
		score += 1
	
	return score
	
# -----------------------------------------------------------------------------
def get_header(data, megabits):
	header_ufo = bytearray(b'\x00' * 64)
	header_lo  = data[0x7fc0:0x7fe0]
	header_hi  = data[0xffc0:0xffe0]
	
	header_ufo[0x0]  = megabits
	# ROM size as closest power of two
	header_ufo[0x11] = int(2**ceil(log(megabits, 2)))
	header_ufo[0x8:0x10] = b"SFCUFOSD"
	
	score_lo = score_header(data, 0x7fc0)
	score_hi = score_header(data, 0xffc0)
	
	is_lorom = True
	rom_bits = b'\x00\x00'
	ram_bits = b'\x10\x00'
	
	if score_lo <= 0 and score_hi <= 0:
		# unable to detect ROM mapping
		raise ValueError("No valid ROM type detected")
		
	elif score_lo >= score_hi:
		# LoROM
		print("LoROM (mode 20) detected")
		
		ram_bits = b'\x10\x3f'
		
		# ROM mapping
		if megabits == 4:
			rom_bits = b'\x05\x2a'
		elif megabits == 8:
			rom_bits = b'\x15\x28'
		elif megabits <= 16:
			rom_bits = b'\x55\x20'
		else:
			rom_bits = b'\x55\x00'
			ram_bits = b'\x60\x3f'
		
		header_ufo[32:] = header_lo
		
	else:
		# HiROM
		is_lorom = False
		print("HiROM (mode 21) detected")
		
		ram_bits = b'\x00\x2c'
		
		# ROM mapping
		if megabits == 4:
			rom_bits = b'\x09\x00'
		elif megabits == 8:
			rom_bits = b'\x25\x00'
		elif megabits == 10:
			rom_bits = b'\x37\x00'
		elif megabits == 12:
			rom_bits = b'\x3d\x00'
		elif megabits == 16:
			rom_bits = b'\x95\x00'
		elif megabits == 24:
			rom_bits = b'\xf5\x00'
		else:
			rom_bits = b'\x55\x00'
			ram_bits = b'\x80\x2c'
			
		header_ufo[32:] = header_hi
	
	# ROM mapping
	header_ufo[0x02] = is_lorom
	header_ufo[0x17] = is_lorom
	header_ufo[0x13:0x15] = rom_bits
	
	# SRAM (max 128kb / 1 Mbit)
	sram_size = header_ufo[0x38]
	sram_byte = 0
	if sram_size > 0 and sram_size <= 7:
		# other size & mapping info
		if sram_size == 1:
			sram_byte = 1
		elif sram_size <= 3:
			sram_byte = 2
		elif sram_size <= 5:
			sram_byte = 3
		else:
			sram_byte = 7
			if is_lorom and megabits <= 16:
				# if megabits > 16 then ram_bits was already set appropriately
				ram_bits = b'\x20\x3f'
				
		header_ufo[0x12]      = sram_byte
		header_ufo[0x15:0x17] = ram_bits
	
	# region
	region = header_ufo[0x39]
	if region >= 2 and region <= 12:
		header_ufo[0x18] = b'\x02' # PAL ROM
	
	# expansion chip
	chipset = header_ufo[0x36]
	if chipset >= 0x03:
		header_ufo[0x19] = b'\xff'
	
#	print(repr(header_ufo))
	return bytes(header_ufo)

# -----------------------------------------------------------------------------
def mirror_rom(data, size):
	# if not a power of 2, split into 2 unevenly-sized ROMs
	firstsize = int(2**floor(log(len(data), 2)))
	# pad the second ROM with the remainder of the first ROM
	data += data[len(data) - firstsize:firstsize]
	# double up until we get to the desired size
	while len(data) < size:
		data *= 2
	return data[:size]

# -----------------------------------------------------------------------------
def format_rom(path):
	data = b''
	megabits = 4
	
	with open(path, 'rb') as rom:
		# get ROM data
		data = rom.read()
		
	totalsize = len(data)
	
	if totalsize < 0x8000:
		raise ValueError("ROM must be at least 32kb")
	elif totalsize > 0x400000:
		raise ValueError("ROM cannot be larger than 4Mb (32Mbit)")
	elif totalsize % 0x8000 == 0x200:
		# remove copier header
		data = data[0x200:]
		
	# mirror ROM to appropriate size
	for size in valid_megabits:
		bytesize = size * 0x20000
		if (totalsize <= bytesize):
			megabits = size
			data = mirror_rom(data, bytesize)
			totalsize = len(data)
			break
	
	print("%u Mbit, %u bytes" % (megabits, totalsize))
	
	# generate a new copier header (needed for transfer) based on ROM properties
	header = get_header(data, megabits)
	
	return (data, header)
