## What is it

This repository contains plugins and macros for [far2m](https://github.com/shmuz/far2m)
written in [Lua](https://www.lua.org/) 5.1 programming language.

## How to build plugins

- Make sure that `FARSOURCE` in CMakeLists.txt points to the far2m source directory.
```
   mkdir _build && cd _build
   cmake ..
   make
```

## Installation

- Make sure that far2m is already installed.
```
   cd _build
   sudo make install
```
