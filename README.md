Roswell
=======

This is a project to create some useful documentation and tools for curious owners of "Super UFO Pro 8" backup units for the SNES. (Currently, that only means the current SD card / USB version, not the identically-named floppy disk and parallel port version made in the 90s.)

Currently available:
* `loadrom.py` - send ROM to unit over USB (will add valid header as necessary)

Documentation so far:
* `header.txt` - copier header format for ROM dumps and USB uploads
* `usb_upload.txt` - USB upload protocol

[PyUSB](https://github.com/pyusb/pyusb) is required for any included tools that involve USB.
