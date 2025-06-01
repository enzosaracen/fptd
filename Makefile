TOP := top
RTL_SRCS := rtl/top.v rtl/main.v
SIM_SRC := sim/sim.cc

OBJDIR := obj
EXE := $(OBJDIR)/V$(TOP)

SDL_CFLG := $(shell pkg-config --cflags sdl2)
SDL_LDLIB := $(shell pkg-config --libs sdl2)

all: $(EXE)

$(EXE): $(RTL_SRCS) $(SIM_SRC) | $(OBJDIR)
	verilator --cc $(RTL_SRCS) --exe $(SIM_SRC) \
	          --top-module $(TOP) \
			  -O3 --x-assign fast --x-initial fast --noassert \
	          -CFLAGS  "$(SDL_CFLG) -std=c++17" \
	          -LDFLAGS "$(SDL_LDLIB)" \
	          -Mdir $(OBJDIR) --build -Wno-WIDTH -Wno-UNSIGNED \

$(OBJDIR):
	mkdir -p $@

run: $(EXE)
	./$<

clean:
	rm -rf $(OBJDIR) *.fst *.vcd
.PHONY: all run clean
