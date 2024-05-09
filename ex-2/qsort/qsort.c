#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>

#define N (1 << 29) // size of the array

const unsigned int RAND_SEED = 2306212; // My student ID is SY2306212
double A[N];

struct mp_qsort_args {
  int start;
  size_t len;
  size_t nproc;
};

void *mp_qsort_entry(struct mp_qsort_args *args) {
  // forward declaration
  void mp_qsort(int start, size_t len, size_t nproc);
  mp_qsort(args->start, args->len, args->nproc);
  return NULL;
}

void mp_qsort(int start, size_t len, size_t nproc) {
  if (len <= 1)
    return;
  double pivot = A[start + len / 2];
  size_t i = start, j = start + len - 1;
  while (i <= j) {
    while (A[i] < pivot)
      i++;
    while (A[j] > pivot)
      j--;
    if (i <= j) {
      double tmp = A[i];
      A[i] = A[j];
      A[j] = tmp;
      i++;
      j--;
    }
  }

  if (nproc > 1) {
    pthread_t th;
    size_t left_len = j - start + 1;
    size_t left_nproc = (size_t)(nproc * ((double)left_len / len));
    void *(*entry)(void *) = (void *(*)(void *))mp_qsort_entry;
    struct mp_qsort_args args = {
        .start = start,
        .len = left_len,
        .nproc = left_nproc,
    };
    pthread_create(&th, NULL, entry, &args); //! line:pthread-qsort-create
    mp_qsort(i, start + len - i, nproc - left_nproc);
    pthread_join(th, NULL); //! line:pthread-qsort-join
  } else {
    mp_qsort(start, j - start + 1, 1);
    mp_qsort(i, start + len - i, 1);
  }
}

int main(void) {
  int i;
  size_t nproc;
  struct timeval time;
  srand(RAND_SEED);
  for (i = 0; i < N; i++)
    A[i] = (double)rand() / RAND_MAX;
  char *nproc_s = getenv("PTHREAD_NUM");
  nproc = nproc_s ? atoi(nproc_s) : 1;
  nproc = nproc > 0 ? nproc : 1;

  printf("Performing quick sort (pthread num=%lu)\n", nproc);
  gettimeofday(&time, NULL);
  double start = time.tv_sec + time.tv_usec / 1e6;
  mp_qsort(0, N, nproc);
  gettimeofday(&time, NULL);
  double end = time.tv_sec + time.tv_usec / 1e6;

  puts("Verifying order of the array");
  for (i = 1; i < N; i++)
    if (A[i - 1] > A[i])
      return 1;

  printf("Elapsed time: %.6f seconds\n", end - start);
  return 0;
}
