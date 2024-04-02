#include <gmpxx.h>
#include <iomanip>
#include <iostream>
#include <omp.h>
#include <openssl/sha.h>

#define P (1 << 17)
#define MPF_SET(mp, val, prec)                                             \
  do {                                                                     \
    mp.set_prec(prec);                                                     \
    mp = val;                                                              \
  } while (0)

// XPOW[i] = X^(2 * i + 1), FACT[i] = (2 * i + 1)!
mpf_class X, Y, R, XPOW[P], FACT[P];

int main(void) {
  int i;
  MPF_SET(X, 0.2306212, P); // My student ID is SY2306212
  MPF_SET(Y, 0.0, P);

  double start = omp_get_wtime();
  // init FACT & XPOW
  std::cout << "Calculating FACT & XPOW..." << std::endl;
  MPF_SET(FACT[0], 1, P);
  MPF_SET(XPOW[0], X, P);
#pragma omp sections //! line:omp-fact-powx
  {
#pragma omp section
    for (i = 1; i < P; i++)
      MPF_SET(FACT[i], FACT[i - 1] * (2 * i) * (2 * i + 1), P);
#pragma omp section
    for (i = 1; i < P; i++)
      MPF_SET(XPOW[i], XPOW[i - 1] * X * X, P);
  }
  // calculate Y = sin(X) = X - X^3/3! + X^5/5! - X^7/7! + ...
  std::cout << "Calculating Y..." << std::endl;
  mpf_class local_sum;
  MPF_SET(local_sum, 0.0, P);
#pragma omp parallel firstprivate(local_sum) shared(Y) //! line:omp-sincal
  {
#pragma omp for private(i)
    for (i = 0; i < P; i++)
      local_sum += (1 - ((i & 1) << 1)) * XPOW[i] / FACT[i];
#pragma omp critical
    Y += local_sum;
  }
  double end = omp_get_wtime();
  std::cout << "Elapsed time: " << end - start << " seconds, SHA1: ";

  unsigned char hash[SHA_DIGEST_LENGTH];
  std::ostringstream oss;
  oss << std::setprecision(P) << Y;
  std::string result = oss.str();
  SHA1((const unsigned char *)result.c_str(), result.length(), hash);
  for (i = 0; i < SHA_DIGEST_LENGTH; i++) {
    std::cout << std::hex << std::setw(2) << std::setfill('0')
              << (int)hash[i] << (i < SHA_DIGEST_LENGTH - 1 ? " " : "\n");
  }

  return 0;
}
