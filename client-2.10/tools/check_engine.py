#!/usr/bin/env python3
"""Checks that libGTASA.so is the official GTA SA engine this client is made for.

The client patches the engine at fixed addresses, so only this exact version
works. Modified copies (for example ones with code injected to quit the game)
are rejected. Usage: check_engine.py path/to/libGTASA.so
"""
import hashlib
import sys

# SHA-256 of the engine's code (bytes 0x40-0x810e98, after the ELF header,
# which differs between stripped and unstripped copies)
EXPECTED_CODE = "f91aae2d82c6fbfa55c8bea72faa003571a45113114c92cafd631d7607df2d23"
CODE_START, CODE_END = 0x40, 0x810E98

data = open(sys.argv[1], "rb").read()
if data[:5] != b"\x7fELF\x02":
    sys.exit("libGTASA.so is not a 64-bit Android library")
if hashlib.sha256(data[CODE_START:CODE_END]).hexdigest() != EXPECTED_CODE:
    sys.exit("libGTASA.so is not the official engine this client needs "
             "(different game version, or a modified copy)")
print("libGTASA.so: official engine, OK")
