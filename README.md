## What is it

This repository contains a few plugins
for my [Far2L fork](https://github.com/shmuz/far2l)
written in [Lua](https://www.lua.org/) 5.1 programming language.
It also contains various utilities for Far2L written in Lua.

## Prerequisites

Either LuaJIT 2.1 or Lua 5.1 (configurable in `config.mak`)

## How to build

1. Unpack this package into `Plugins/luafar` directory.

2. Edit the first line in config.mak (`FARSOURCE`)
   to point to Far2L source tree on your disk.

3. Execute `make`.
