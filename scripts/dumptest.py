#!/usr/bin/env python

from __future__ import print_function
import roswell.usbclient as usbclient

c = usbclient.USBClient()

c.open()
print("opened USB device successfully")
title = c.read_cart(0xffc0, 21).tostring().strip()
print("cartridge title:", title)
if title == "":
	title = "unnamed"

# cart writing example
c.write_cart(0x2220, b"\x00\x01\x02\x03")

#data = c.read_banks(0xc0, 0xff, 0x0000, 0xffff)
data = c.read_banks(0x00, 0x07, 0x8000, 0xffff)
with open("%s.sfc" % title, 'wb') as f:
	data.tofile(f)
	print("wrote %s.sfc successfully" % title)
#data = c.read_banks(0x40, 0x40, 0x0000, 0x1fff)
data = c.read_banks(0x70, 0x73, 0x0000, 0x7fff)
with open("%s.srm" % title, 'wb') as f:
	data.tofile(f)
	print("wrote %s.srm successfully" % title)
