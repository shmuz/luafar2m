# Makefile

include ../../config.mak

OUT= Out$(DIRBIT)
MYCFLAGS  = -DBUILD_DLL -DFAR_DONT_USE_INTERNALS
MYLDFLAGS = -luuid
TARGET = ../../$(LUAFARDLL)

OBJ = \
  $(OUT)/farflags.o    \
  $(OUT)/farcolor.o    \
  $(OUT)/farkeys.o     \
  $(OUT)/exported.o    \
  $(OUT)/lregex.o      \
  $(OUT)/service.o     \
  $(OUT)/slnunico.o    \
  $(OUT)/lutf8lib.o    \
  $(OUT)/ustring.o     \
  $(OUT)/util.o        \
  $(OUT)/mytimer.o     \
  $(OUT)/luamacro.o    \
  $(OUT)/bit64.o       \
  $(OUT)/lusercontrol.o

ifneq ($(USE_LUAJIT),1)
  OBJ += $(OUT)/bit.o
endif

.PHONY: directories all
all: directories $(TARGET)
directories: $(OUT)

$(TARGET): $(OBJ)
	$(CC) -o $@ $^ $(LDFLAGS)

$(OUT):
	mkdir -p $@

$(OUT)/%.o : %.c
	$(CC) $(CFLAGS) -c $< -o $@

farflags.c: $(INC_FAR)/farplug-wide.h
	$(LUAEXE) makeflags.lua '$<' > $@

farcolor.c: $(INC_FAR)/farcolor.h
	$(LUAEXE) makefarkeys.lua '$<' > $@

farkeys.c: $(INC_FAR)/farkeys.h
	$(LUAEXE) makefarkeys.lua '$<' > $@

# Dependencies
$(OUT)/*.o        : $(INC_FAR)/farplug-wide.h luafar.h ustring.h util.h
$(OUT)/service.o  : version.h

# (end of Makefile)
