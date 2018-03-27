#!/usr/bin/env python

from __future__ import print_function
import roswell.usbclient as usbclient
import roswell.romutils  as romutils
import sys
import time

# -----------------------------------------------------------------------------
def write_rom(path):

	data, header = romutils.format_rom(path)
	totalsize = len(data)

	client = usbclient.USBClient()
	start = time.clock()

	# begin with empty string
	print("starting transfer...")
	client.write("")
	
	# send header (64 bytes)
	print("writing header...")
	client.write(header)

	# write the data
	cursize = 0
	while cursize < totalsize:
		print("written %u bytes" % cursize, end='\r')
		cursize += client.write(data[cursize:cursize+32768])
		
	# end with another empty string
	client.write("")
	print("written %u bytes" % cursize)
	print("finished writing successfully in %.2f sec" % (time.clock() - start))


# -----------------------------------------------------------------------------
if __name__ == "__main__":
	if len(sys.argv) != 2:
		print("Usage: %s filename" % sys.argv[0])
	else:
		try:
			write_rom(sys.argv[1])
		except Exception as e:
			sys.stderr.write("Sending ROM failed: %s" % e)
