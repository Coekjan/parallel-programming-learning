#include <omp.h>
#include <openssl/sha.h>
#include <stdio.h>
#include <stdlib.h>

#define N 8192 // dimension of the matrices

const unsigned int RAND_SEED = 2306212; // My student ID is SY2306212
double A[N][N], B[N][N], C[N][N];

int main(void) {
  int i, j, k;
  srand(RAND_SEED);
  for (i = 0; i < N; i++)
    for (j = 0; j < N; j++) {
      A[i][j] = (double)rand() / RAND_MAX;
      B[i][j] = (double)rand() / RAND_MAX;
      C[i][j] = 0.0;
    }

  puts("Performing matrix multiplication");
  double start = omp_get_wtime();
#pragma omp parallel for private(i, j, k) //! line:omp-matmul
  for (i = 0; i < N; i++)
    for (k = 0; k < N; k++)
      for (j = 0; j < N; j++)
        C[i][j] += A[i][k] * B[k][j];
  double end = omp_get_wtime();
  printf("Elapsed time: %.6f seconds, SHA1: ", end - start);

  unsigned char hash[SHA_DIGEST_LENGTH];
  SHA1((void *)C, sizeof(C), hash);
  for (i = 0; i < SHA_DIGEST_LENGTH; i++)
    printf("%02x%c", hash[i], i + 1 < SHA_DIGEST_LENGTH ? ' ' : '\n');

  return 0;
}
