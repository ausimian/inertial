.PHONY: all nif svr

UNAME=$(shell uname)
TARGET_DIR=$(MIX_APP_PATH)/priv
TARGET_NIF=$(TARGET_DIR)/inertial_nif.so

CFLAGS=-Werror -Wfatal-errors -Wall -Wextra -O2 -flto -std=c11 -pedantic
SRCS=

ERL_INTERFACE_INCLUDE_DIR ?= $(shell elixir --eval 'IO.puts(Path.join([:code.root_dir(), "usr", "include"]))')

SYMFLAGS=-fvisibility=hidden
ifeq ($(UNAME), Linux)
	CFLAGS+=-D__STDC_WANT_LIB_EXT2__=1
	SYMFLAGS+=
	SRCS+=c_src/linux.c
else ifeq ($(UNAME), Darwin)
	SRCS+=c_src/darwin.c
	SYMFLAGS+=-undefined dynamic_lookup
else
	$(error "Unsupported platform")
endif

all: nif
	@:

clean:
	rm -f $(TARGET_NIF)

nif: $(TARGET_NIF)

$(TARGET_NIF): $(SRCS)
	@mkdir -p $(TARGET_DIR)
	$(CC) $(CFLAGS) -I${ERL_INTERFACE_INCLUDE_DIR} $(SYMFLAGS) -fPIC -shared -o $@ $?
