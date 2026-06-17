#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * Maximum number of validation errors per context
 */
#define MAX_ERRORS 64

/**
 * Maximum length of error message
 */
#define MAX_ERROR_LEN 256

/**
 * Maximum number of validation rules
 */
#define MAX_RULES 32

/**
 * Validation result code
 */
typedef enum ValidationCode {
  /**
   * Validation passed
   */
  Pass = 0,
  /**
   * Validation failed
   */
  Fail = 1,
  /**
   * Validation skipped (rule not applicable)
   */
  Skip = 2,
  /**
   * Validation error (internal)
   */
  Error = 3,
  /**
   * Toxic change detected
   */
  Toxic = 4,
} ValidationCode;

/**
 * Validation rule type
 */
typedef enum ValidationRuleType {
  /**
   * Numeric range [min, max]
   */
  Range = 0,
  /**
   * Exact value match
   */
  Exact = 1,
  /**
   * Non-null/zero check
   */
  NotNull = 2,
  /**
   * String pattern (regex-like)
   */
  Pattern = 3,
  /**
   * Custom validator function
   */
  Custom = 4,
  /**
   * Conformance vector check
   */
  Conformance = 5,
  /**
   * Sacred physics invariant
   */
  SacredInvariant = 6,
} ValidationRuleType;

/**
 * Validation severity level
 */
typedef enum ValidationSeverity {
  /**
   * Informational — no action needed
   */
  Info = 0,
  /**
   * Warning — potential issue
   */
  Warning = 1,
  /**
   * Error — validation failed
   */
  Error = 2,
  /**
   * Critical — system invariant violated
   */
  Critical = 3,
} ValidationSeverity;

/**
 * Validation rule definition
 */
typedef struct ValidationRule {
  /**
   * Rule type
   */
  enum ValidationRuleType rule_type;
  /**
   * Minimum value (for range checks)
   */
  double min_value;
  /**
   * Maximum value (for range checks)
   */
  double max_value;
  /**
   * Expected value (for exact match)
   */
  double expected_value;
  /**
   * Tolerance for floating-point comparison
   */
  double tolerance;
  /**
   * Whether this rule is active
   */
  bool active;
  /**
   * Field name this rule applies to
   */
  char field[MAX_ERROR_LEN];
} ValidationRule;

/**
 * Single validation error
 */
typedef struct ValidationError {
  /**
   * Error severity
   */
  enum ValidationSeverity severity;
  /**
   * Rule that triggered the error
   */
  enum ValidationRuleType rule_type;
  /**
   * Error code
   */
  enum ValidationCode code;
  /**
   * Error message (null-terminated)
   */
  char message[MAX_ERROR_LEN];
  /**
   * Field/parameter name (null-terminated)
   */
  char field[MAX_ERROR_LEN];
  /**
   * Expected value (if applicable)
   */
  double expected;
  /**
   * Actual value (if applicable)
   */
  double actual;
} ValidationError;

/**
 * Validation context — holds state for a validation session
 */
typedef struct ValidationContext {
  /**
   * Number of rules in this context
   */
  uintptr_t rule_count;
  /**
   * Number of errors collected
   */
  uintptr_t error_count;
  /**
   * Overall result code
   */
  enum ValidationCode result;
  /**
   * Maximum severity seen
   */
  enum ValidationSeverity max_severity;
  /**
   * Rules array
   */
  struct ValidationRule rules[MAX_RULES];
  /**
   * Errors array
   */
  struct ValidationError errors[MAX_ERRORS];
} ValidationContext;

/**
 * Create a new validation context
 */
struct ValidationContext trios_validation_context_new(void);

/**
 * Reset a validation context for reuse
 */
void trios_validation_context_reset(struct ValidationContext *ctx);

/**
 * Get overall pass/fail status
 */
bool trios_validation_passed(const struct ValidationContext *ctx);

/**
 * Get number of errors
 */
uintptr_t trios_validation_error_count(const struct ValidationContext *ctx);

/**
 * Get maximum severity
 */
enum ValidationSeverity trios_validation_max_severity(const struct ValidationContext *ctx);

/**
 * Add a range validation rule
 */
bool trios_validation_add_range_rule(struct ValidationContext *ctx,
                                     const char *field,
                                     double min_value,
                                     double max_value);

/**
 * Add an exact-value validation rule
 */
bool trios_validation_add_exact_rule(struct ValidationContext *ctx,
                                     const char *field,
                                     double expected,
                                     double tolerance);

/**
 * Add a sacred invariant validation rule
 */
bool trios_validation_add_sacred_rule(struct ValidationContext *ctx,
                                      const char *field,
                                      double expected,
                                      double tolerance);

/**
 * Validate a single numeric value against all rules in context
 */
enum ValidationCode trios_validation_check_value(struct ValidationContext *ctx,
                                                 const char *field,
                                                 double value);

/**
 * Validate the Trinity identity: φ² + 1/φ² = 3
 */
bool trios_validation_trinity_identity(double tolerance);

/**
 * Validate golden ratio value
 */
bool trios_validation_phi(double value, double tolerance);

/**
 * Validate Fibonacci relationship: F(n+2) = F(n+1) + F(n)
 */
bool trios_validation_fibonacci(long fn_prev, long fn_curr, long fn_next);

/**
 * Check toxicity score — returns true if the change is toxic
 */
bool trios_validation_is_toxic(const struct ValidationContext *ctx, double threshold);

/**
 * Compute conformance score [0.0, 1.0] for a context
 */
double trios_validation_conformance_score(const struct ValidationContext *ctx);
