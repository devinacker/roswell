#!/usr/bin/env python

from __future__ import print_function
import roswell.usbclient as usbclient
from usb.core import array, USBError
from struct import pack
import time
import re

test_cmd = 3
test_addr = 0xc00000
test_size = 0x10000
test_write = 0 #0x10000

c = usbclient.USBClient()

rc = c.write(b"\x08" + pack("B", test_cmd) + pack("<I", test_addr) + pack("<H", test_size & 0xffff))
print("wrote %u bytes" % rc)

start = time.perf_counter()
data = c.read(test_size)
print("read back %u bytes in %.2f sec:" % (len(data), time.perf_counter() - start))

for addr in range(0, min(256, len(data)), 16):
	ss = data[addr:addr+16]
	print("%06X | " % (test_addr+addr), end='')
	for char in ss:
		print("%02X " % char, end='')
	print(" | ", re.sub(r'[\x00-\x1f]', '.', ss.tobytes().decode('ascii', 'replace')))
if len(data) > 256:
	print("(and %u more bytes)" % (len(data) - 256))

if test_write:
	start = time.perf_counter()
	rc = c.write("\x66"*test_write)
	print("wrote %u bytes in %.2f sec" % (rc, time.perf_counter() - start))
