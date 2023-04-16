#!/usr/bin/env python

import roswell.usbclient as usbclient
import array

def write_byte(addr, value):
	c.write_cart(addr, value.to_bytes(1, 'little'))

def read_byte(addr):
	return c.read_cart(addr, 1)[0]

def read_word(addr):
	tmp = c.read_cart(addr, 2)
	return (tmp[1] << 8) | tmp[0]

def read_string(addr, len, encoding):
	return c.read_cart(addr, len).tobytes().decode(encoding, 'replace').strip("\x00")

def wakeup():
	write_byte(0x2400, 0x09)
	dummy = read_byte(0x2400)
	write_byte(0x2401, 0x28)
	write_byte(0x2401, 0x84)
	write_byte(0x2400, 0x06)
	write_byte(0x2400, 0x39)

def read_reset(bank):
	write_byte(bank << 16 | 0xAAAA, 0xAA)
	write_byte(bank << 16 | 0x5554, 0x55)
	write_byte(bank << 16 | 0xAAAA, 0xF0)

def save(filename, data):
	with open(filename, 'wb') as f:
		data.tofile(f)
		print("wrote %s successfully" % filename)

def dump(base):
	index = read_byte(base + 0)
	if index == 0xFF:
		return

	first_flash_block = read_byte(base + 0x01)
	first_sram_block  = read_byte(base + 0x02)
	flash_blocks      = read_word(base + 0x03) >> 2
	sram_blocks       = read_word(base + 0x05) >> 4
	title             = read_string(base + 0x13, 44, 'shift-jis')

	first_bank = 0xC0 + (first_flash_block << 3)
	last_bank = first_bank + (flash_blocks << 3) - 1
	data = c.read_banks(first_bank, last_bank, 0x0000, 0xFFFF)
	save(title + ".sfc", data)

	sram_start = first_sram_block << 11
	sram_end = sram_start + (sram_blocks << 11)
	data = sram[sram_start:sram_end]
	save(title + ".srm", data)

c = usbclient.USBClient()
c.open()
print("opened USB device successfully")

tmp = read_byte(0x2400)
if tmp == 0x7D:
	wakeup()
elif tmp != 0x2A:
	print("SF memory is not detected")
	sys.exit()

print("SF memory is detected")

#HIROM:ALL
write_byte(0x2400, 0x04)
read_reset(0xC0)
read_reset(0xE0)

sram = c.read_banks(0x20, 0x23, 0x6000, 0x7FFF)
for base in range(0xC60000, 0xC70000, 0x2000):
	dump(base)
