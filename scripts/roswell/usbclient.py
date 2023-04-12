from __future__ import print_function
import usb.core, usb.util
from struct import pack
from usb.core import array, USBError
import time

SUPERUFO_VENDOR  = 0x1292
SUPERUFO_PRODUCT = 0x4653

class USBClient(object):
	
	def __init__(self):
		self.close()
	
	def open(self):
		if not self._usb_dev:
			self._usb_dev = usb.core.find(idVendor=SUPERUFO_VENDOR, idProduct=SUPERUFO_PRODUCT)
			if not self._usb_dev:
				self.close()
				raise ValueError("SuperUFO USB device not found")

			self._usb_dev.set_configuration()

			# get an endpoint instance
			cfg = self._usb_dev.get_active_configuration()
			intf = cfg[(0,0)]

			self._usb_out = usb.util.find_descriptor(
				intf,
				custom_match = lambda e: \
					usb.util.endpoint_direction(e.bEndpointAddress) == \
					usb.util.ENDPOINT_OUT)
			if not self._usb_out:
				self.close()
				raise ValueError("Unable to open output endpoint")
			
			self._usb_in = usb.util.find_descriptor(
				intf,
				custom_match = lambda e: \
					usb.util.endpoint_direction(e.bEndpointAddress) == \
					usb.util.ENDPOINT_IN)
			if not self._usb_in:
				self.close()
				raise ValueError("Unable to open input endpoint")
				
	def close(self):
		self._usb_dev = None
		self._usb_in  = None
		self._usb_out = None
	
	def read(self, size_or_buffer, timeout=None, block_size=1024):
		self.open()
		block_size &= ~63

		if isinstance(size_or_buffer, int):
			data = usb.core.array.array('B')
			size = min(size_or_buffer, 0x10000)
			# TODO: speed up SNES-side USB transactions to make this more manageable
			while len(data) < size:
				data += self._usb_in.read(min(block_size, size - len(data)), timeout)
			return data
		else:
			# TODO :eehhh
			return self._usb_in.read(size_or_buffer, timeout)
	
	def write(self, data, timeout=None, block_size=512):
		self.open()
		block_size &= ~63
		
		size = 0
		# TODO: speed up SNES-side USB transactions to make this more manageable
		for pos in range(0, len(data), block_size):
			size += self._usb_out.write(data[pos:pos+block_size], timeout)
		return size
		
	def read_cart(self, addr, size):
		assert(0 < size <= 0x10000)
		self.write(b"\x08\x03" + pack("<I", addr) + pack("<H", size & 0xffff))
		return self.read(size)
	
	def write_cart(self, addr, data):
		assert(0 < len(data) <= 0x10000)
		cmd = b"\x08\x05" + pack("<I", addr) + b"\x00\x00"
		return self.write(cmd + data) - len(cmd)

	def read_banks(self, bank0, bank1, addr0, addr1):
		assert(bank0 <= bank1 and bank0 >= 0 and bank1 < 256)
		if bank0 != bank1:
			#print("dump $%02x-%02x:%04x-%04x" % (bank0, bank1, addr0, addr1))
			pass
		else:
			#print("dump $%02x:%04x-%04x" % (bank0, addr0, addr1))
			pass
		start = time.perf_counter()
		data = array.array('B')
		for i in range(bank0, bank1+1):
			print("reading $%02x:%04x-%04x" % (i, addr0, addr1), end='\r')
			data += self.read_cart(i<<16|addr0, addr1-addr0+1)
		print("read back %u bytes in %.2f sec        " % (len(data), time.perf_counter() - start))
		return data
