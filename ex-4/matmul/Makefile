export THREADS_PER_BLOCK ?= 16

CC = nvcc
CFLAGS += --fmad=false -O3 -lssl -lcrypto
FINGERPRINT := c2 7e d9 cf fe 74 66 3f 6a d2 e9 db 0c 65 04 a1 01 a9 1b d1
MAKEFLAGS += -s -r

.PHONY: run clean

matmul: matmul.cu
	$(CC) $(CFLAGS) -o $@ $<

run: matmul
	exec 3>&1; stdbuf -o0 ./matmul | tee >(cat - >&3) | grep -q "$(FINGERPRINT)"

clean:
	$(RM) -f matmul
