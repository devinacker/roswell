#!/usr/bin/env python

from __future__ import print_function
import roswell.usbclient as usbclient
from usb.core import array, USBError
from struct import pack
import time
import re

c = usbclient.USBClient()

def readcart(addr, size):
	assert(0 <= size <= 0x10000)
	c.write(b"\x08\x03" + pack("<I", addr) + pack("<H", size & 0xffff))
	return c.read(size)

def readbanks(bank0, bank1, addr0, addr1):
	assert(bank0 <= bank1 and bank0 >= 0 and bank1 < 256)
	if bank0 != bank1:
		print("dump $%02x-%02x:%04x-%04x" % (bank0, bank1, addr0, addr1))
	else:
		print("dump $%02x:%04x-%04x" % (bank0, addr0, addr1))
	start = time.clock()
	data = array.array('B')
	for i in range(bank0, bank1+1):
		print("reading $%02x:%04x-%04x" % (i, addr0, addr1), end='\r')
		data += readcart(i<<16|addr0, addr1-addr0+1)
	print("read back %u bytes in %.2f sec        " % (len(data), time.clock() - start))
	return data

c.open()
print("opened USB device successfully")
title = readcart(0xffc0, 21).tostring().strip()
print("cartridge title:", title)
if title == "":
	title = "unnamed"

#data = readbanks(0xc0, 0xff, 0x0000, 0xffff)
data = readbanks(0x00, 0x07, 0x8000, 0xffff)
with open("%s.sfc" % title, 'wb') as f:
	data.tofile(f)
	print("wrote %s.sfc successfully" % title)
#data = readbanks(0x40, 0x40, 0x0000, 0x1fff)
data = readbanks(0x70, 0x73, 0x0000, 0x7fff)
with open("%s.srm" % title, 'wb') as f:
	data.tofile(f)
	print("wrote %s.srm successfully" % title)
