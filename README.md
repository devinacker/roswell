Roswell
=======

This is a project to create some useful documentation and tools for curious owners of "Super UFO Pro 8" backup units for the SNES. (That means the current SD card / USB version, not the identically-named floppy disk version made in the 90s.)

Currently available:
* `loadrom.py` - send ROM to unit over USB (will add valid header as necessary)
* `shell.py` - interactive command shell for inspecting, dumping, and modifying memory contents
* `clienttest.py` - test script: retrieve and show region of cart memory (also test r/w speed)
* `dumptest.py` - test script: dump ROM and SRAM images from a cart
* `np_dir.py` - show directory of SF Memory (Nintendo Power)
* `np_dump.py` - dump individual ROM and SRAM images from SF Memory (Nintendo Power)
* `np_dump_all.py` - dump whole Flash and SRAM images from SF Memory (Nintendo Power)

The `loadrom` script is to be used with the USB transfer option on the Super UFO main menu. Other scripts communicate with the server program after it's running on the console.

The `server` directory contains the source for the SNES-side server program (requres libSFX).

Documentation so far:
* `header.txt` - copier header format for ROM dumps and USB uploads
* `regs.txt` - hardware register ($218x) info
* `usb_upload.txt` - USB upload protocol
* `usb_client.txt` - command protocol for the SNES-side server
* `ch37*ds1.pdf` - USB chip datasheets

[PyUSB](https://github.com/pyusb/pyusb) is required for any included tools that involve USB. On Windows you'll also need to use [Zadig](https://zadig.akeo.ie) to install WinUSB compatibility for the existing  Super UFO Pro USB driver.
