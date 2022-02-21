## What is it

This repository contains LuaFAR2L library for writing plugins
for Far2L in Lua 5.1 programming language.
It also contains a few luafar plugins and various utilities
for Far2L written in Lua.

## Prerequisites

Lua 5.1

## How to build

1. In the Far2L installation tree create a directory under Plugins,
   e.g. `Plugins/_luafar_` and unpack this package there.

2. Edit the first line in config.mak (`FARSOURCE`)
   to point to Far2L source tree on your disk.

3. Execute `make`.

## User permissions

If Far2L installation is under $HOME then no permission setting is required.
However if Far2L is installed under `/usr/lib` then the following actions
may be needed:

- Enter `far2l/Plugins` directory
- Execute `sudo chmod -R 777 ./_luafar_`
- Restart Far2L
