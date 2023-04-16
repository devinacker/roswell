#!/usr/bin/env python

import roswell.usbclient as usbclient
import sys

def write_byte(addr, value):
	c.write_cart(addr, value.to_bytes(1, 'little'))

def read_byte(addr):
	return c.read_cart(addr, 1)[0]

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

def show_hidden(bank):
	write_byte(bank << 16, 0x38)
	write_byte(bank << 16, 0xD0)
	write_byte(bank << 16, 0x71)
	while True:
		dummy = read_byte(bank << 16 | 0x0004)
		if dummy & 0x80:
			break
	write_byte(bank << 16, 0x72)
	write_byte(bank << 16, 0x75)

def save(filename, data):
	with open(filename, 'wb') as f:
		data.tofile(f)
		print("wrote %s successfully" % filename)

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

# dump boot sector in bank $C0
show_hidden(0xC0)
data = c.read_cart(0xC0FF00, 256)
save("bootsect_C0.bin", data)

# dump boot sector in bank $E0
show_hidden(0xE0)
data = c.read_cart(0xE0FF00, 256)
save("bootsect_E0.bin", data)

# dump $0000-FFFF in banks $C0-FF
read_reset(0xC0)
read_reset(0xE0)
data = c.read_banks(0xC0, 0xFF, 0x0000, 0xFFFF)
save("np.sfc", data)

# dump $6000-7FFF in banks $20-23
data = c.read_banks(0x20, 0x23, 0x6000, 0x7FFF)
save("np.srm", data)
