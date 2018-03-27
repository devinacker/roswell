
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
	
	def read(self, size_or_buffer, timeout=None):
		self.open()
		return self._usb_in.read(size_or_buffer, timeout)
	
	def write(self, data, timeout=None):
		self.open()
		return self._usb_out.write(data, timeout)
		