export SLURM_BATCH ?= 1x1

CC = mpicc
CFLAGS += -Wall -Wextra -O3 -lssl -lcrypto -std=c99
FINGERPRINT := c2 7e d9 cf fe 74 66 3f 6a d2 e9 db 0c 65 04 a1 01 a9 1b d1
MAKEFLAGS += -s -r

.PHONY: run clean

matmul: matmul.c
	$(CC) $(CFLAGS) -o $@ $<

run: SHELL := $(shell which bash)
run: matmul
	exec 3>&1; stdbuf -o0 ./matmul.slurm.run | tee >(cat - >&3) | grep -q "$(FINGERPRINT)"

clean:
	$(RM) -f machinefile.* matmul matmul.*.out matmul.*.err
