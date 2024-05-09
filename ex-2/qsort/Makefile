export PTHREAD_NUM ?= $(shell nproc)

CFLAGS += -Wall -Wextra -O3
MAKEFLAGS += -s -r

.PHONY: run clean

qsort: qsort.c
	$(CC) $(CFLAGS) -o $@ $<

run: qsort
	./qsort

clean:
	$(RM) -f qsort
