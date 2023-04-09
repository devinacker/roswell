#!/usr/bin/env python

from __future__ import print_function
import roswell.usbclient as usbclient
import loadrom
import sys
import re
from fnmatch import fnmatch

client = usbclient.USBClient()

cmds = dict()

def cmd(func):
	cmds[func.__name__] = func

def find_cmd(name):
	if name in cmds.keys():
		return cmds[name]
	
	_name = name
	err = "no such command '%s'" % name
	while len(_name) > 0:
		matches = [n for n in cmds.keys() if fnmatch(n, _name + '*')]
		if len(matches) == 0:
			_name = _name[:-1]
			continue
		elif _name == name:
			if len(matches) == 1:
				return cmds[matches[0]]
			else:
				err = "'%s is ambiguous" % name
				break
		else:
			break
	
	if len(matches) > 0:
		err += "\ndid you mean: %s" % ", ".join(matches)
	raise NameError(err)

def parse_addr(addr):
	try:
		banks, addrs = addr.split(':')
		
		if '-' in banks:
			bank0, bank1 = banks.split('-')
			bank0 = int(bank0, 16)
			bank1 = int(bank1, 16)
		else:
			bank0 = bank1 = int(banks, 16)
		
		if '-' in addrs:
			addr0, addr1 = addrs.split('-')
			addr0 = int(addr0, 16)
			addr1 = int(addr1, 16)
		else:
			addr0 = addr1 = int(addrs, 16)
			
		return bank0, bank1, addr0, addr1
	except ValueError:
		raise ValueError("invalid address range syntax")

@cmd
def help(name=""):
	"""
	help [cmdname]
	
	Provides help for available commands.
	If cmdname is empty, lists all available commands.
	Otherwise, prints information about a specific command.
	It seems like you may have known that already.
	"""
	if len(name) == 0:
		print("\nList of commands:\nType 'help cmdname' for more info.")
		print("Shorter, non-ambiguous names can be used as shortcuts.")
		for n in sorted(cmds.keys()):
			print("\t", n)
	else:
		print(find_cmd(name).__doc__)

@cmd
def read(addrs):
	"""
	read addrs
	
	Read data from the specified addresses and display the results
	as a hex dump.
	
	'addrs' can be in the following formats:
	
	single address in bank
		00:8000
	address range in bank
		00:8000-ffff
	single address in multiple banks
		00-ff:8000
	address range in multiple banks
		00-ff:8000-ffff
	"""
	
	bank0, bank1, addr0, addr1 = parse_addr(addrs)
	nbanks   = 1 + bank1 - bank0
	banksize = 1 + addr1 - addr0
	data = memoryview(client.read_banks(bank0, bank1, addr0, addr1).tobytes())

	for bank in range(0, nbanks):
		bankdata = data[(banksize*bank):(banksize*(bank+1))]
		for addr in range(0, banksize, 16):
			ss = bankdata[addr:addr+16]
			print("%02X:%04X | " % (bank0+bank, addr0+addr), end='')
			for char in ss:
				print("%02X " % char, end='')
			print(" | ", re.sub(r'[\x00-\x1f]', '.', ss.tobytes().decode('ascii', 'replace')))

@cmd 
def write(addr, *data):
	"""
	write addr data
	
	Write data starting at a single address.
	'addr' is a single bank:address, and 'data' can be any number
	of hexadecimal bytes separated by spaces.
	
	example:
	write 7e:0000 00 01 02 03 04 05 06
	"""
	try:
		addr = int(addr.replace(':', '', 1), 16)
	except ValueError:
		raise ValueError("invalid address syntax")
	
	data = "".join([chr(int(b, 16)) for b in data])
	client.write_cart(addr, data)

@cmd
def load(path):
	"""
	load path
	
	Send a ROM to the Super UFO via USB.
	Must be using the USB transfer mode in the normal firmware.
	"""
	loadrom.write_rom(path, client)

@cmd
def save(addrs, path):
	"""
	save addrs path
	
	Read data from the specified addresses and save the results
	to a file at 'path'.
	
	For the format of 'addrs', see the 'read' command.
	"""
	
	data = client.read_banks(*parse_addr(addrs))
	with open(path, 'wb') as f:
		f.write(data)
	print("saved %s to %s" % (addrs, path))

@cmd
def quit():
	"""
	quit
	
	Quits. What did you expect?
	"""
	sys.exit()

if __name__ == "__main__":
	print("Roswell interactive shell\nType 'help' for commands")
	while True:
		inputs = input("\n>").split()
		if len(inputs) > 0:
			try:
				find_cmd(inputs[0])(*inputs[1:])
			except Exception as e:
				print(e)
			except KeyboardInterrupt:
				pass
