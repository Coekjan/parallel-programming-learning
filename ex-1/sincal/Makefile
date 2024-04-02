export OMP_NUM_THREADS ?= $(shell nproc)

CXXFLAGS += -Wall -Wextra -O3 -fopenmp -lgmp -lgmpxx -lssl -lcrypto
FINGERPRINT := fe 7f 57 6e d1 72 ab 38 6b 4d 29 0e 15 30 7f 45 4e 25 69 d0
MAKEFLAGS += -s -r

.PHONY: run clean

sincal: sincal.cpp
	$(CXX) $(CXXFLAGS) -o $@ $<

run: sincal
	exec 3>&1; stdbuf -o0 ./sincal | tee >(cat - >&3) | grep -q "$(FINGERPRINT)"

clean:
	$(RM) -f sincal
