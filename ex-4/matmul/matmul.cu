#include <cuda.h>
#include <openssl/sha.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>

#define N 8192 // dimension of the matrices
#define cudaCheck(e)                                                       \
  do {                                                                     \
    cudaError_t error = (e);                                               \
    if (error != cudaSuccess) {                                            \
      fprintf(stderr, "CUDA error at line %d (%s): %s\n", __LINE__,        \
              __func__, error, cudaGetErrorString(error));                 \
      exit(1);                                                             \
    }                                                                      \
  } while (0)

const unsigned int RAND_SEED = 2306212; // My student ID is SY2306212
const size_t size = N * N * sizeof(double);
double A[N][N], B[N][N], C[N][N];

__global__ void cudaMatmul( //! line:cuda-kernel
    double *d_C, double *d_A, double *d_B) {
  int i = blockIdx.y * blockDim.y + threadIdx.y; //! line:cuda-blk-th-1
  int j = blockIdx.x * blockDim.x + threadIdx.x; //! line:cuda-blk-th-2

  if (i < N && j < N) {
    double sum = 0.0f;
    for (int k = 0; k < N; k++) {
      sum += d_A[i * N + k] * d_B[k * N + j];
    }
    d_C[i * N + j] = sum;
  }
}

int main() {
  struct timeval time;
  double *d_A, *d_B, *d_C;
  size_t th_per_blk;
  char *th_per_blk_s = getenv("THREADS_PER_BLOCK");
  th_per_blk = th_per_blk_s ? atoi(th_per_blk_s) : 16;
  th_per_blk = th_per_blk > 0 ? th_per_blk : 16;

  srand(RAND_SEED);
  for (int i = 0; i < N; i++)
    for (int j = 0; j < N; j++) {
      A[i][j] = (double)rand() / RAND_MAX;
      B[i][j] = (double)rand() / RAND_MAX;
      C[i][j] = 0.0;
    }

  puts("Performing matrix multiplication");
  gettimeofday(&time, NULL);
  double start = time.tv_sec + time.tv_usec / 1e6;
  cudaCheck(cudaMalloc((void **)&d_A, size)); //! line:cuda-malloc-1
  cudaCheck(cudaMalloc((void **)&d_B, size)); //! line:cuda-malloc-2
  cudaCheck(cudaMalloc((void **)&d_C, size)); //! line:cuda-malloc-3

  cudaCheck(cudaMemcpy(d_A, A, size,             //! line:cuda-memcpy-1
                       cudaMemcpyHostToDevice)); //! line:cuda-memcpy-2
  cudaCheck(cudaMemcpy(d_B, B, size,             //! line:cuda-memcpy-3
                       cudaMemcpyHostToDevice)); //! line:cuda-memcpy-4

  dim3 threadsPerBlock(th_per_blk, th_per_blk);          //! line:cuda-tpb
  dim3 blocksPerGrid((N + th_per_blk - 1) / th_per_blk,  //! line:cuda-bpg-1
                     (N + th_per_blk - 1) / th_per_blk); //! line:cuda-bpg-2

  cudaMatmul<<<blocksPerGrid, threadsPerBlock>>>( //! line:cuda-matmul-1
      d_C,                                        //! line:cuda-matmul-2
      d_A,                                        //! line:cuda-matmul-3
      d_B);                                       //! line:cuda-matmul-4

  cudaCheck(cudaGetLastError());      //! line:cuda-check-last-err
  cudaCheck(cudaDeviceSynchronize()); //! line:cuda-sync

  cudaCheck(cudaMemcpy(C, d_C, size,             //! line:cuda-memcpy-5
                       cudaMemcpyDeviceToHost)); //! line:cuda-memcpy-6

  cudaCheck(cudaFree(d_A)); //! line:cuda-free-1
  cudaCheck(cudaFree(d_B)); //! line:cuda-free-2
  cudaCheck(cudaFree(d_C)); //! line:cuda-free-3

  gettimeofday(&time, NULL);
  double end = time.tv_sec + time.tv_usec / 1e6;
  printf("Elapsed time: %.6f seconds, SHA1: ", end - start);

  unsigned char hash[SHA_DIGEST_LENGTH];
  SHA1((const unsigned char *)C, sizeof(C), hash);
  for (int i = 0; i < SHA_DIGEST_LENGTH; i++)
    printf("%02x%c", hash[i], i + 1 < SHA_DIGEST_LENGTH ? ' ' : '\n');
  return 0;
}
