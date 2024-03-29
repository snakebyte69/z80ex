# Z80Ex from https://sourceforge.net/projects/z80ex/ #

## ZiLOG Z80 CPU emulator ##

Features:
---------

- precise opcode emulation (documented & undocumented)
- exact timings for each opcode (including I/O operations)
- full support for all interrupt modes
- any number of virtual CPUs may be created
- portable: written in pure ANSI C
- builds as a library with simple callback-based API
- disassembler included  


Building and installing:
------------------------

to build and install using CMake build system, refer to INSTALL.cmake
to build and install using GNU Make, refer to INSTALL.gmake

# macOS #
- % sudo make
- % sudo make install

Usage intro:
------------

emulator:

include <z80ex/z80ex.h> in your sources,
link with "libz80ex" (-lz80ex).

for (rather subtle) API documentation see "z80ex.h".

disassembler:

include <z80ex/z80ex_dasm.h> in your sources,
link with "libz80ex_dasm" (-lz80ex_dasm).

for API documentation see "z80ex_dasm.h".
also you may look at "dasm.c" from the "examples" directory


_____________________________
yours, Pigmaker57 aka Boo-boo
pigmaker57@kahoh57.info
