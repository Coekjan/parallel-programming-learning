#include <assert.h>
#include <mpi.h>
#include <openssl/sha.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>

#define N 8192 // dimension of the matrices

const unsigned int RAND_SEED = 2306212; // My student ID is SY2306212

double *A, *B, *C, *A_local, *C_local;

int main(int argc, char **argv) {
  int rank, size, i, j, k;
  struct timeval time;
  srand(RAND_SEED);

  MPI_Init(&argc, &argv);               //! line:mpi-init
  MPI_Comm_rank(MPI_COMM_WORLD, &rank); //! line:mpi-rank
  MPI_Comm_size(MPI_COMM_WORLD, &size); //! line:mpi-size

  int rows_per_proc = N / size;
  assert(N % size == 0);

  B = (double *)malloc(N * N * sizeof(double));
  if (rank == 0) {
    A = (double *)malloc(N * N * sizeof(double));
    C = (double *)malloc(N * N * sizeof(double));
    for (i = 0; i < N; i++)
      for (j = 0; j < N; j++) {
        A[i * N + j] = (double)rand() / RAND_MAX;
        B[i * N + j] = (double)rand() / RAND_MAX;
      }
  }

  A_local = (double *)malloc(N * rows_per_proc * sizeof(double));
  C_local = (double *)malloc(N * rows_per_proc * sizeof(double));

  gettimeofday(&time, NULL);
  double start = time.tv_sec + time.tv_usec / 1e6;

  if (rank == 0) {
    printf("Broadcasting B & Scattering A to (mpi size=%d, col/proc=%d)\n",
           size, rows_per_proc);
  }
  MPI_Bcast(B, N * N, MPI_DOUBLE, 0, MPI_COMM_WORLD); //! line:mpi-bcast
  MPI_Scatter(A, N * rows_per_proc, MPI_DOUBLE,       //! line:mpi-scatter-1
              A_local, N * rows_per_proc, MPI_DOUBLE, //! line:mpi-scatter-2
              0, MPI_COMM_WORLD);                     //! line:mpi-scatter-3

  memset(C_local, 0, N * rows_per_proc * sizeof(double));

  for (i = 0; i < rows_per_proc; i++)
    for (k = 0; k < N; k++)
      for (j = 0; j < N; j++)
        C_local[i * N + j] += A_local[i * N + k] * B[k * N + j];

  if (rank == 0) {
    puts("Gathering C\n");
  }
  MPI_Gather(C_local, N * rows_per_proc, MPI_DOUBLE, //! line:mpi-gather-1
             C, N * rows_per_proc,                   //! line:mpi-gather-2
             MPI_DOUBLE, 0, MPI_COMM_WORLD);         //! line:mpi-gather-3

  gettimeofday(&time, NULL);
  double end = time.tv_sec + time.tv_usec / 1e6;

  if (rank == 0) {
    printf("Elapsed time: %.6f seconds, SHA1: ", end - start);
    unsigned char hash[SHA_DIGEST_LENGTH];
    SHA1((void *)C, sizeof(double) * N * N, hash);
    for (i = 0; i < SHA_DIGEST_LENGTH; i++)
      printf("%02x%c", hash[i], i + 1 < SHA_DIGEST_LENGTH ? ' ' : '\n');

    free(A);
    free(C);
  }

  free(B);
  free(A_local);
  free(C_local);

  MPI_Finalize(); //! line:mpi-finalize
  return 0;
}
