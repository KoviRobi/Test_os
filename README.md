Test OS
=======

This is just a simple project I have been working on, at the moment it is not even an OS. Most of the inspiration is from [JamesM's kernel development tutorials](http://www.jamesmolloy.co.uk/tutorial_html/index.html) and [Alex Chadwick's Baking Pi tutorials](http://www.cl.cam.ac.uk/projects/raspberrypi/tutorials/os/). Also, the Raspberry Pi is loaded from the UART via [raspbootin/raspbootcom](https://github.com/mrvn/raspbootin). Also, note that I use an UART like [this](http://www.amazon.co.uk/gp/product/B008AGDTA4) (note, at the time of writing this, the page had some smart watch for images, which is wrong, it should have a cable from USB to four wires (white, green, red, black).

The next thing to do with the project would be:
* Virtual memory
* Memory allocation
* Improve English
* Improve typography

The last two points should not be ignored, especially given that this whole project is also a (perhaps somewhat lacking) attempt at literate programming. It also needs typographic work as I am not really familiar with plain TeX or good typographic practices at the moment. Also, don't expect caches for the moment, that is second year material for me.

Compilation
-----------
You need the following software

* Gnu Make (perhaps others work)
* Shell with the `test` builtin (for make)
* CWEB (included in TeXlive)
* (plain) TeX (e.g. pdftex to make PDF files)
* arm-none-eabi-{gcc, ld, objcopy} (used GCC 4.9.0 and binutils 2.24, not sure about other cross compilers, this depends on calling assembly from C and vice versa, so if your compiler does name-mangling, you may have to do a bit of renaming)
* find (used GNU findutils)

Just running `make` ought to work, with the caveat that you may need to run it twice, as Make caches the directories and in the first round we generate the source files from the CWEB files (the reason I am not using patterns for the source files is that some CWEB files generate source files not directly related by name).

Also, you may choose not to use raspbootin/raspbootcom, in which case `stage3_transfer` can fail normally (indeed you can remove it from the prequisite of the target `all`). In this case, to transfer the kernel to the Pi, you just need to copy the kernel.img to the SD card for the Raspberry Pi.

Wishlist
--------
Here are some features that I will probably not implement, but would be nice:

* SD Card
* USB driver
* Display (very low priority, but possible)

The last two can be obtained/hacked into this from Alex Chadwick's tutorials.
