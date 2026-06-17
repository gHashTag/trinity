#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * Golden ratio φ = (1 + √5) / 2
 */
#define PHI 1.6180339887498948482

/**
 * φ² = φ + 1
 */
#define PHI_SQ 2.6180339887498948482

/**
 * 1/φ = φ - 1
 */
#define PHI_INV 0.6180339887498948482

/**
 * 1/φ² = 2 - φ
 */
#define PHI_INV_SQ 0.3819660112501051518

/**
 * π
 */
#define PI 3.14159265358979323846

/**
 * e (Euler's number)
 */
#define E 2.71828182845904523536

/**
 * √2
 */
#define SQRT2 1.4142135623730950488

/**
 * √3
 */
#define SQRT3 1.7320508075688772935

/**
 * √5
 */
#define SQRT5 2.2360679774997896964

/**
 * φ² + 1/φ² = 3 = TRINITY
 */
#define TRINITY 3

/**
 * γ (Euler-Mascheroni constant)
 */
#define GAMMA 0.5772156649015328606

/**
 * ln(φ)
 */
#define LN_PHI 0.48121182505960347

/**
 * Phoenix constant = φ⁴
 */
#define PHOENIX 6.8541019662496845

/**
 * Golden angle in degrees = 360/φ²
 */
#define GOLDEN_ANGLE_DEG 137.50776405003785

/**
 * Golden angle in radians = 2π/φ²
 */
#define GOLDEN_ANGLE_RAD 2.3999632297286533

/**
 * α_φ = φ³/2 ≈ 0.118033988749895
 */
#define ALPHA_PHI 0.118033988749895

/**
 * Fibonacci numbers context (opaque)
 */
typedef struct FibonacciContext {
  uint8_t _private[0];
} FibonacciContext;

/**
 * Continued fraction approximation result
 */
typedef struct ContinuedFraction {
  /**
   * Numerator
   */
  long numerator;
  /**
   * Denominator
   */
  long denominator;
  /**
   * Approximation value
   */
  double value;
  /**
   * Error from actual value
   */
  double error;
} ContinuedFraction;

/**
 * All sacred constants in one struct
 */
typedef struct SacredConstants {
  double phi;
  double phi_sq;
  double phi_inv;
  double phi_inv_sq;
  double alpha_phi;
  double pi;
  double e;
  double sqrt2;
  double sqrt3;
  double sqrt5;
  double gamma;
  double ln_phi;
  double phoenix;
  long trinity;
  double golden_angle_deg;
  double golden_angle_rad;
} SacredConstants;

/**
 * Get φ (golden ratio)
 */
double trios_sacred_phi(void);

/**
 * Get φ²
 */
double trios_sacred_phi_sq(void);

/**
 * Get 1/φ (phi inverse)
 */
double trios_sacred_phi_inv(void);

/**
 * Get 1/φ²
 */
double trios_sacred_phi_inv_sq(void);

/**
 * Get α_φ = φ³/2
 */
double trios_sacred_alpha_phi(void);

/**
 * Validate Trinity identity: φ² + 1/φ² = 3
 *
 * Returns true if identity holds within floating point tolerance.
 */
bool trios_sacred_validate_trinity(void);

/**
 * Calculate nth Fibonacci number
 */
uint64_t trios_sacred_fibonacci(uint32_t n);

/**
 * Create Fibonacci context for sequence generation
 */
struct FibonacciContext *trios_sacred_fibonacci_context_new(void);

/**
 * Free Fibonacci context
 */
void trios_sacred_fibonacci_context_free(struct FibonacciContext *_ctx);

/**
 * Get next Fibonacci number from context
 */
uint64_t trios_sacred_fibonacci_next(struct FibonacciContext *_ctx);

/**
 * Reset Fibonacci context
 */
void trios_sacred_fibonacci_reset(struct FibonacciContext *_ctx);

/**
 * Calculate φ^n (phi power)
 */
double trios_sacred_phi_power(int32_t n);

/**
 * Calculate φ^(-n) (phi inverse power)
 */
double trios_sacred_phi_inv_power(int32_t n);

/**
 * Calculate continued fraction approximation of φ
 *
 * After n iterations, returns numerator/denominator approximation.
 */
struct ContinuedFraction trios_sacred_phi_cfrac(uint32_t n);

/**
 * Get continued fraction coefficients for φ
 *
 * Returns array of length `n` with all ones (φ has all-ones CF).
 */
int32_t trios_sacred_phi_cfrac_coeffs(uintptr_t n, int32_t *coeffs);

/**
 * Calculate golden ratio from continued fraction coefficients
 */
double trios_sacred_cfrac_to_phi(const int32_t *coeffs, uintptr_t n);

/**
 * Golden angle in degrees
 */
double trios_sacred_golden_angle_deg(void);

/**
 * Golden angle in radians
 */
double trios_sacred_golden_angle_rad(void);

/**
 * Phoenix constant (φ⁴)
 */
double trios_sacred_phoenix(void);

/**
 * Get all mathematical constants as a struct
 */
struct SacredConstants trios_sacred_constants(void);

/**
 * Get last error
 */
const char *trios_sacred_last_error(void);

/**
 * Get version
 */
const char *trios_sacred_version(void);

/**
 * Get build info
 */
const char *trios_sacred_build_info(void);
