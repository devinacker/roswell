
import usb.core, usb.util

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
		