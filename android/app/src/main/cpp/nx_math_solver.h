#ifndef NX_MATH_SOLVER_H
#define NX_MATH_SOLVER_H

#ifdef __cplusplus
extern "C" {
#endif

/* === Algebra === */
int nx_solve_quadratic(double a, double b, double c, double out[2], char* steps, int steps_max);
int nx_solve_cubic(double a, double b, double c, double d, double out[3], char* steps, int steps_max);
int nx_solve_quartic(double a, double b, double c, double d, double e, double out[4], char* steps, int steps_max);

/* === Number Theory === */
int nx_gcd(int a, int b, char* steps, int steps_max);
int nx_lcm(int a, int b, char* steps, int steps_max);
long long nx_fibonacci(int n, char* steps, int steps_max);
int nx_prime_factors(long long n, long long* out, char* steps, int steps_max);
int nx_is_prime(long long n, char* steps, int steps_max);
long long nx_nCr(int n, int r, char* steps, int steps_max);
long long nx_nPr(int n, int r, char* steps, int steps_max);
int nx_sieve_of_eratosthenes(int limit, long long* out, char* steps, int steps_max);

/* === Calculus === */
double nx_derivative_at(double* coef, int n, double x, char* steps, int steps_max);
double nx_integrate(double a, double b, int n, char* steps, int steps_max);
double nx_newton_raphson(double a, double b, double c, double d, double guess, int max_iter, double tol, char* steps, int steps_max);
int nx_taylor_series(double* coef, int n, double x0, double x, double* out_terms, char* steps, int steps_max);

/* === Linear Algebra / Matrices === */
int nx_matrix_multiply(double* A, double* B, double* C, int m, int k, int n, char* steps, int steps_max);
double nx_determinant(double* mat, int n, char* steps, int steps_max);
int nx_solve_linear(double* A, double* b, double* x, int n, char* steps, int steps_max);
int nx_inverse_matrix(double* mat, double* out, int n, char* steps, int steps_max);
int nx_matrix_rank(double* mat, int m, int n, char* steps, int steps_max);
double nx_eigenvalue_2x2(double mat[4], int which, char* steps, int steps_max);

/* === Vector Algebra (3D) === */
void nx_cross_product(double a[3], double b[3], double out[3], char* steps, int steps_max);
double nx_dot_product(double a[3], double b[3], char* steps, int steps_max);
double nx_vector_magnitude(double a[3], char* steps, int steps_max);
double nx_angle_between(double a[3], double b[3], char* steps, int steps_max);
double nx_scalar_triple_product(double a[3], double b[3], double c[3], char* steps, int steps_max);
void nx_vector_projection(double a[3], double b[3], double out[3], char* steps, int steps_max);

/* === Coordinate Geometry === */
double nx_distance_2d(double x1, double y1, double x2, double y2, char* steps, int steps_max);
double nx_distance_3d(double x1, double y1, double z1, double x2, double y2, double z2, char* steps, int steps_max);
void nx_section_formula(double x1, double y1, double x2, double y2, double m, double n, double out[2], char* steps, int steps_max);
double nx_area_of_triangle(double x1, double y1, double x2, double y2, double x3, double y3, char* steps, int steps_max);
void nx_centroid(double x1, double y1, double x2, double y2, double x3, double y3, double out[2], char* steps, int steps_max);

/* === Sequences & Series === */
double nx_ap_nth_term(double a, double d, int n, char* steps, int steps_max);
double nx_ap_sum(double a, double d, int n, char* steps, int steps_max);
double nx_gp_nth_term(double a, double r, int n, char* steps, int steps_max);
double nx_gp_sum(double a, double r, int n, char* steps, int steps_max);
double nx_gp_infinite_sum(double a, double r, char* steps, int steps_max);
double nx_hp_nth_term(double a, double d, int n, char* steps, int steps_max);

/* === Trigonometry === */
double nx_solve_triangle_sss(double a, double b, double c, double out[3], char* steps, int steps_max);
double nx_solve_triangle_sas(double a, double b, double angle_c, double out[4], char* steps, int steps_max);

/* === Statistics === */
double nx_mean(double* data, int n, char* steps, int steps_max);
double nx_median(double* data, int n, char* steps, int steps_max);
double nx_std_dev(double* data, int n, char* steps, int steps_max);
double nx_variance(double* data, int n, char* steps, int steps_max);
double nx_correlation(double* x, double* y, int n, char* steps, int steps_max);

/* === Probability === */
double nx_binomial_prob(int n, int k, double p, char* steps, int steps_max);

/* === Complex Numbers (as 2D double[2] = real, imag) === */
void nx_complex_add(double a[2], double b[2], double out[2], char* steps, int steps_max);
void nx_complex_multiply(double a[2], double b[2], double out[2], char* steps, int steps_max);
void nx_complex_divide(double a[2], double b[2], double out[2], char* steps, int steps_max);
double nx_complex_modulus(double a[2], char* steps, int steps_max);
double nx_complex_argument(double a[2], char* steps, int steps_max);
void nx_complex_power(double a[2], int n, double out[2], char* steps, int steps_max);
void nx_complex_nth_roots(double a[2], int n, double out[][2], char* steps, int steps_max);

/* === Line/Plane Geometry === */
void nx_line_intersection(double a1, double b1, double c1, double a2, double b2, double c2, double out[2], char* steps, int steps_max);
double nx_distance_point_line(double px, double py, double a, double b, double c, char* steps, int steps_max);

/* === Forensic Watermark (C++ - fast, obfuscated) === */
void nx_watermark_hash(const char* input, char out8[9]);
int nx_watermark_lsb_embed(unsigned char* pixels, int w, int h, const char* payload);

/* === Utility: Evaluation of string expression via Shunting-Yard (basic) === */
double nx_evaluate_expression(const char* expr, char* steps, int steps_max);

#ifdef __cplusplus
}
#endif

#endif
