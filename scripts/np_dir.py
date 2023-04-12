#!/usr/bin/env python

from __future__ import print_function
import roswell.usbclient as usbclient

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

def read_dir(base):
	index = read_byte(base + 0)
	if index == 0xFF:
		return

	print("")
	print("Directory index        : %d" % index)
	print("First FLASH block      : %d" % read_byte(base + 0x0001))
	print("First SRAM block       : %d" % read_byte(base + 0x0002))
	print("Number of FLASH blocks : %d" % (read_word(base + 0x0003) >> 2))
	print("Number of SRAM blocks  : %d" % (read_word(base + 0x0005) >> 4))
	print("Gamecode               : %s" % read_string(base + 0x0007, 12, 'ascii'))
	print("Title                  : %s" % read_string(base + 0x0013, 44, 'shift-jis'))
	print("Date                   : %s" % read_string(base + 0x01BF, 10, 'ascii'))
	print("Time                   : %s" % read_string(base + 0x01C9, 8, 'ascii'))
	print("Law                    : %s" % read_string(base + 0x01D1, 8, 'ascii'))

c = usbclient.USBClient()
c.open()
print("opened USB device successfully")

tmp = read_byte(0x2400)
if tmp == 0x7D:
	wakeup()
elif tmp != 0x2A:
	print("SF memory is not detected")
	exit

print("SF memory is detected")

#HIROM:ALL
write_byte(0x2400, 0x04)
read_reset(0xC0)

for base in range(0xC60000, 0xC70000, 0x2000):
	read_dir(base)
