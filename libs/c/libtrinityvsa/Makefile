# libtrinityvsa Makefile

CC = gcc
CFLAGS = -O3 -Wall -Wextra -I include
LDFLAGS = -lm

# SIMD flags
SIMD_FLAGS = -mavx2

SRC = src/trinity_vsa.c
OBJ = trinity_vsa.o
STATIC_LIB = libtrinityvsa.a
SHARED_LIB = libtrinityvsa.so

.PHONY: all static shared clean test

all: static shared

static: $(STATIC_LIB)

shared: $(SHARED_LIB)

$(STATIC_LIB): $(SRC)
	$(CC) $(CFLAGS) $(SIMD_FLAGS) -c $(SRC) -o $(OBJ)
	ar rcs $(STATIC_LIB) $(OBJ)
	rm -f $(OBJ)

$(SHARED_LIB): $(SRC)
	$(CC) $(CFLAGS) $(SIMD_FLAGS) -fPIC -shared $(SRC) -o $(SHARED_LIB) $(LDFLAGS)

test: static
	$(CC) $(CFLAGS) -I include examples/basic.c -L. -ltrinityvsa $(LDFLAGS) -o test_basic
	./test_basic
	rm -f test_basic

clean:
	rm -f $(OBJ) $(STATIC_LIB) $(SHARED_LIB) test_basic

install: static shared
	install -d $(DESTDIR)/usr/local/lib
	install -d $(DESTDIR)/usr/local/include
	install -m 644 $(STATIC_LIB) $(DESTDIR)/usr/local/lib/
	install -m 755 $(SHARED_LIB) $(DESTDIR)/usr/local/lib/
	install -m 644 include/trinity_vsa.h $(DESTDIR)/usr/local/include/
