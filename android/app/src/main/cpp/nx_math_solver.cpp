#define _USE_MATH_DEFINES
#include "nx_math_solver.h"
#include <cmath>
#include <cstdio>
#include <cstring>
#include <cstdarg>
#include <vector>
#include <algorithm>
#include <cinttypes>

static int snprintf_safe(char* buf, int max, const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    int n = vsnprintf(buf, max, fmt, args);
    va_end(args);
    return n;
}

/* ==================== UTILITY ==================== */

static double eval_poly(double* coef, int n, double x) {
    double r = 0;
    for (int i = n - 1; i >= 0; i--) r = r * x + coef[i];
    return r;
}

/* ==================== ALGEBRA ==================== */

int nx_solve_quadratic(double a, double b, double c, double out[2], char* steps, int steps_max) {
    int pos = 0;
    pos += snprintf_safe(steps + pos, steps_max - pos, "Given: %.4fx² + %.4fx + %.4f = 0\n", a, b, c);
    pos += snprintf_safe(steps + pos, steps_max - pos, "Using x = (-b ± √(b²-4ac)) / 2a\n");
    double disc = b*b - 4*a*c;
    pos += snprintf_safe(steps + pos, steps_max - pos, "D = b²-4ac = %.6f\n", disc);
    if (disc < 0) {
        pos += snprintf_safe(steps + pos, steps_max - pos, "D < 0 → No real roots.\n");
        return 0;
    }
    double sqrt_d = sqrt(disc);
    out[0] = (-b + sqrt_d) / (2*a);
    out[1] = (-b - sqrt_d) / (2*a);
    pos += snprintf_safe(steps + pos, steps_max - pos, "Roots: x₁ = %.6f, x₂ = %.6f\n", out[0], out[1]);
    return disc == 0 ? 1 : 2;
}

int nx_solve_cubic(double a, double b, double c, double d, double out[3], char* steps, int steps_max) {
    int pos = 0;
    pos += snprintf_safe(steps + pos, steps_max - pos, "%.4fx³ + %.4fx² + %.4fx + %.4f = 0\n", a, b, c, d);
    if (fabs(a) < 1e-12) return nx_solve_quadratic(b, c, d, out, steps + pos, steps_max - pos);
    double p = (3*a*c - b*b) / (3*a*a);
    double q = (2*b*b*b - 9*a*b*c + 27*a*a*d) / (27*a*a*a);
    double disc = q*q/4 + p*p*p/27;
    pos += snprintf_safe(steps + pos, steps_max - pos, "p=%.6f q=%.6f Δ=%.6f\n", p, q, disc);
    if (disc >= 0) {
        double u = cbrt(-q/2 + sqrt(disc));
        double v = cbrt(-q/2 - sqrt(disc));
        out[0] = u + v - b/(3*a);
        pos += snprintf_safe(steps + pos, steps_max - pos, "One real root: %.6f\n", out[0]);
        return 1;
    }
    double r = sqrt(-p*p*p/27);
    double theta = acos(-q/(2*r));
    for (int i = 0; i < 3; i++)
        out[i] = 2*cbrt(r)*cos((theta + 2*i*M_PI)/3) - b/(3*a);
    pos += snprintf_safe(steps + pos, steps_max - pos, "Three real roots.\n");
    return 3;
}

int nx_solve_quartic(double a, double b, double c, double d, double e, double out[4], char* steps, int steps_max) {
    int pos = 0;
    pos += snprintf_safe(steps + pos, steps_max - pos, "%.4fx⁴ + %.4fx³ + %.4fx² + %.4fx + %.4f = 0\n", a, b, c, d, e);
    if (fabs(a) < 1e-12) return nx_solve_cubic(b, c, d, e, out, steps + pos, steps_max - pos);
    // Depressed quartic via Ferrari's method
    double p = c/a - 3*b*b/(8*a*a);
    double q = d/a + b*b*b/(8*a*a*a) - b*c/(2*a*a);
    double r = e/a - 3*b*b*b*b/(256*a*a*a*a) + b*b*c/(16*a*a*a) - b*d/(4*a*a);
    double shift = -b/(4*a);
    // Solve resolvent cubic: m^3 + 2p m^2 + (p^2-4r)m - q^2 = 0
    double m_roots[3];
    int nm = nx_solve_cubic(1, 2*p, p*p - 4*r, -q*q, m_roots, steps + pos, steps_max - pos);
    if (nm == 0) return 0;
    double m = m_roots[0];
    double sqrt2m = sqrt(2*m);
    double sqrt_term = sqrt(m*m - 4*r);
    int count = 0;
    for (int s1 = -1; s1 <= 1; s1 += 2) {
        for (int s2 = -1; s2 <= 1; s2 += 2) {
            double denom = 2*a;
            double num = -b + s1*sqrt2m + s2*sqrt_term;
            if (fabs(denom) > 1e-12) out[count++] = num / denom;
        }
    }
    pos += snprintf_safe(steps + pos, steps_max - pos, "Found %d roots via Ferrari's method.\n", count);
    return count;
}

/* ==================== NUMBER THEORY ==================== */

int nx_gcd(int a, int b, char* steps, int steps_max) {
    int pos = 0, x = abs(a), y = abs(b);
    pos += snprintf_safe(steps + pos, steps_max - pos, "GCD(%d,%d) Euclidean:\n", a, b);
    while (y) { int r = x % y; pos += snprintf_safe(steps + pos, steps_max - pos, "  %d = %d×%d + %d\n", x, x/y, y, r); x = y; y = r; }
    pos += snprintf_safe(steps + pos, steps_max - pos, "GCD = %d\n", x);
    return x;
}

int nx_lcm(int a, int b, char* steps, int steps_max) {
    int pos = 0, g = nx_gcd(a, b, steps, steps_max);
    long long l = ((long long)abs(a) / g) * abs(b);
    pos += snprintf_safe(steps + pos, steps_max - pos, "LCM = |%d×%d| / GCD(%d,%d) = %lld\n", a, b, a, b, l);
    return (int)l;
}

long long nx_fibonacci(int n, char* steps, int steps_max) {
    int pos = 0;
    pos += snprintf_safe(steps + pos, steps_max - pos, "F(%d) fast doubling:\n", n);
    struct Fib { long long first, second; };
    auto fib = [&](int k, auto&& self) -> Fib {
        if (k == 0) return {0, 1};
        auto [a, b] = self(k >> 1, self);
        long long c = a * (2 * b - a);
        long long d = a * a + b * b;
        if (k & 1) return {d, c + d};
        return {c, d};
    };
    auto fn = fib(n, fib).first;
    pos += snprintf_safe(steps + pos, steps_max - pos, "F(%d) = %lld\n", n, fn);
    return fn;
}

int nx_prime_factors(long long n, long long* out, char* steps, int steps_max) {
    int pos = 0, count = 0;
    long long m = n;
    pos += snprintf_safe(steps + pos, steps_max - pos, "Prime factors of %lld:\n", n);
    while (m % 2 == 0) { out[count++] = 2; m /= 2; }
    for (long long i = 3; i * i <= m; i += 2)
        while (m % i == 0) { out[count++] = i; m /= i; }
    if (m > 1) out[count++] = m;
    for (int i = 0; i < count; i++) {
        long long exp = 0;
        while (n % out[i] == 0) { n /= out[i]; exp++; }
        pos += snprintf_safe(steps + pos, steps_max - pos, "  %lld^%lld\n", out[i], exp);
    }
    return count;
}

int nx_is_prime(long long n, char* steps, int steps_max) {
    int pos = 0;
    pos += snprintf_safe(steps + pos, steps_max - pos, "Miller-Rabin for %lld:\n", n);
    if (n < 2) return 0;
    if (n == 2 || n == 3) { pos += snprintf_safe(steps + pos, steps_max - pos, "Prime.\n"); return 1; }
    if (n % 2 == 0) return 0;
    long long d = n - 1; int s = 0;
    while (d % 2 == 0) { d /= 2; s++; }
    auto modpow = [](long long base, long long exp, long long mod) {
        long long r = 1; base %= mod;
        while (exp) { if (exp & 1) r = (r * base) % mod; base = (base * base) % mod; exp >>= 1; }
        return r;
    };
    long long witnesses[] = {2, 3, 5, 7, 11, 13, 17};
    for (long long a : witnesses) {
        if (a >= n) continue;
        long long x = modpow(a, d, n);
        if (x == 1 || x == n-1) continue;
        bool composite = true;
        for (int r = 0; r < s-1; r++) { x = (x * x) % n; if (x == n-1) { composite = false; break; } }
        if (composite) { pos += snprintf_safe(steps + pos, steps_max - pos, "Composite.\n"); return 0; }
    }
    pos += snprintf_safe(steps + pos, steps_max - pos, "Prime.\n");
    return 1;
}

long long nx_nCr(int n, int r, char* steps, int steps_max) {
    int pos = 0;
    pos += snprintf_safe(steps + pos, steps_max - pos, "C(%d,%d) DP:\n", n, r);
    if (r > n - r) r = n - r;
    std::vector<long long> dp(r+1, 0); dp[0] = 1;
    for (int i = 1; i <= n; i++) for (int j = std::min(i, r); j > 0; j--) dp[j] += dp[j-1];
    pos += snprintf_safe(steps + pos, steps_max - pos, "C(%d,%d) = %lld\n", n, r, dp[r]);
    return dp[r];
}

long long nx_nPr(int n, int r, char* steps, int steps_max) {
    int pos = 0;
    pos += snprintf_safe(steps + pos, steps_max - pos, "P(%d,%d) = %d! / (%d-%d)!:\n", n, r, n, n, r);
    long long p = 1;
    for (int i = n; i > n - r; i--) p *= i;
    pos += snprintf_safe(steps + pos, steps_max - pos, "P(%d,%d) = %lld\n", n, r, p);
    return p;
}

int nx_sieve_of_eratosthenes(int limit, long long* out, char* steps, int steps_max) {
    int pos = 0, count = 0;
    pos += snprintf_safe(steps + pos, steps_max - pos, "Sieve up to %d:\n", limit);
    std::vector<bool> sieve(limit+1, true);
    sieve[0] = sieve[1] = false;
    for (int i = 2; i * i <= limit; i++)
        if (sieve[i]) for (int j = i*i; j <= limit; j += i) sieve[j] = false;
    for (int i = 2; i <= limit; i++) if (sieve[i]) out[count++] = i;
    pos += snprintf_safe(steps + pos, steps_max - pos, "Found %d primes ≤ %d.\n", count, limit);
    return count;
}

/* ==================== CALCULUS ==================== */

double nx_derivative_at(double* coef, int n, double x, char* steps, int steps_max) {
    int pos = 0;
    pos += snprintf_safe(steps + pos, steps_max - pos, "f'(x) = ");
    double result = 0;
    for (int i = 1; i < n; i++) {
        double term = coef[i] * i * pow(x, i-1);
        result += term;
        if (i > 1) pos += snprintf_safe(steps + pos, steps_max - pos, "%.4f + ", term);
        else pos += snprintf_safe(steps + pos, steps_max - pos, "%.4f\n", term);
    }
    pos += snprintf_safe(steps + pos, steps_max - pos, "f'(%.4f) = %.8f\n", x, result);
    return result;
}

double nx_integrate(double a, double b, int n, char* steps, int steps_max) {
    double h = (b - a) / n;
    double sum = 0;
    int pos = 0;
    pos += snprintf_safe(steps + pos, steps_max - pos, "∫ f(x) dx from %.4f to %.4f (Simpson's, n=%d)\n", a, b, n);
    for (int i = 0; i <= n; i++) {
        double x = a + i * h;
        double fx = 1.0 / (1.0 + x*x);
        if (i == 0 || i == n) sum += fx;
        else if (i % 2 == 1) sum += 4 * fx;
        else sum += 2 * fx;
    }
    double integral = h / 3 * sum;
    pos += snprintf_safe(steps + pos, steps_max - pos, "∫ ≈ %.10f\n", integral);
    (void)pos;
    return integral;
}

double nx_newton_raphson(double a, double b, double c, double d, double guess, int max_iter, double tol, char* steps, int steps_max) {
    int pos = 0;
    pos += snprintf_safe(steps + pos, steps_max - pos, "Newton-Raphson: guess=%.4f max_iter=%d\n", guess, max_iter);
    double x = guess;
    for (int i = 0; i < max_iter; i++) {
        double fx = ((a*x + b)*x + c)*x + d;
        double dfx = (3*a*x + 2*b)*x + c;
        if (fabs(dfx) < 1e-15) break;
        double xn = x - fx/dfx;
        pos += snprintf_safe(steps + pos, steps_max - pos, "  iter %d: x=%.8f f(x)=%.8f\n", i+1, xn, fx);
        if (fabs(xn - x) < tol) { x = xn; break; }
        x = xn;
    }
    pos += snprintf_safe(steps + pos, steps_max - pos, "Root ≈ %.10f\n", x);
    return x;
}

int nx_taylor_series(double* coef, int n, double x0, double x, double* out_terms, char* steps, int steps_max) {
    int pos = 0;
    pos += snprintf_safe(steps + pos, steps_max - pos, "Taylor series around x₀=%.4f evaluated at x=%.4f:\n", x0, x);
    int terms = std::min(n, 10);
    double result = 0;
    for (int k = 0; k < terms; k++) {
        // approximate f^(k)(x0) * (x-x0)^k / k!
        double deriv = 0;
        for (int i = k; i < n; i++) {
            double falling = 1;
            for (int j = 0; j < k; j++) falling *= (i - j);
            deriv += coef[i] * falling * pow(x0, i - k);
        }
        double factorial = 1;
        for (int j = 2; j <= k; j++) factorial *= j;
        double term = deriv * pow(x - x0, k) / factorial;
        out_terms[k] = term;
        result += term;
        pos += snprintf_safe(steps + pos, steps_max - pos, "  term %d: %.8f\n", k, term);
    }
    return terms;
}

/* ==================== LINEAR ALGEBRA ==================== */

int nx_matrix_multiply(double* A, double* B, double* C, int m, int k, int n, char* steps, int steps_max) {
    int pos = 0;
    pos += snprintf_safe(steps + pos, steps_max - pos, "Matrix %dx%d × %dx%d\n", m, k, k, n);
    for (int i = 0; i < m; i++) for (int j = 0; j < n; j++) {
        C[i*n + j] = 0;
        for (int t = 0; t < k; t++) C[i*n + j] += A[i*k + t] * B[t*n + j];
    }
    pos += snprintf_safe(steps + pos, steps_max - pos, "Done O(mkn).\n");
    return 0;
}

double nx_determinant(double* mat, int n, char* steps, int steps_max) {
    int pos = 0;
    pos += snprintf_safe(steps + pos, steps_max - pos, "det(%dx%d) via LU:\n", n, n);
    std::vector<double> a(mat, mat + n*n);
    double det = 1;
    for (int i = 0; i < n; i++) {
        int pivot = i;
        for (int j = i+1; j < n; j++) if (fabs(a[j*n + i]) > fabs(a[pivot*n + i])) pivot = j;
        if (pivot != i) { std::swap_ranges(a.begin() + i*n, a.begin() + i*n + n, a.begin() + pivot*n); det = -det; }
        if (fabs(a[i*n + i]) < 1e-12) { det = 0; break; }
        for (int j = i+1; j < n; j++) {
            double factor = a[j*n + i] / a[i*n + i];
            for (int k = i; k < n; k++) a[j*n + k] -= factor * a[i*n + k];
        }
        det *= a[i*n + i];
    }
    pos += snprintf_safe(steps + pos, steps_max - pos, "det = %.12f\n", det);
    return det;
}

int nx_solve_linear(double* A, double* b, double* x, int n, char* steps, int steps_max) {
    int pos = 0;
    pos += snprintf_safe(steps + pos, steps_max - pos, "%dx%d Gaussian elimination:\n", n, n);
    std::vector<double> aug(n*(n+1));
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) aug[i*(n+1) + j] = A[i*n + j];
        aug[i*(n+1) + n] = b[i];
    }
    for (int col = 0; col < n; col++) {
        int pivot = col;
        for (int row = col+1; row < n; row++) if (fabs(aug[row*(n+1) + col]) > fabs(aug[pivot*(n+1) + col])) pivot = row;
        if (pivot != col) std::swap_ranges(aug.begin() + col*(n+1), aug.begin() + col*(n+1) + n+1, aug.begin() + pivot*(n+1));
        if (fabs(aug[col*(n+1) + col]) < 1e-12) { pos += snprintf_safe(steps + pos, steps_max - pos, "Singular.\n"); return -1; }
        for (int row = col+1; row < n; row++) {
            double factor = aug[row*(n+1) + col] / aug[col*(n+1) + col];
            for (int j = col; j <= n; j++) aug[row*(n+1) + j] -= factor * aug[col*(n+1) + j];
        }
    }
    for (int i = n-1; i >= 0; i--) {
        x[i] = aug[i*(n+1) + n];
        for (int j = i+1; j < n; j++) x[i] -= aug[i*(n+1) + j] * x[j];
        x[i] /= aug[i*(n+1) + i];
    }
    pos += snprintf_safe(steps + pos, steps_max - pos, "Back-substitution done.\n");
    return 0;
}

int nx_inverse_matrix(double* mat, double* out, int n, char* steps, int steps_max) {
    int pos = 0;
    pos += snprintf_safe(steps + pos, steps_max - pos, "Inverse of %dx%d via Gauss-Jordan:\n", n, n);
    std::vector<double> aug(n*(2*n));
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) aug[i*(2*n) + j] = mat[i*n + j];
        aug[i*(2*n) + n + i] = 1;
    }
    for (int i = 0; i < n; i++) {
        int pivot = i;
        for (int j = i+1; j < n; j++) if (fabs(aug[j*(2*n) + i]) > fabs(aug[pivot*(2*n) + i])) pivot = j;
        if (pivot != i) std::swap_ranges(aug.begin() + i*(2*n), aug.begin() + i*(2*n) + 2*n, aug.begin() + pivot*(2*n));
        double d = aug[i*(2*n) + i];
        if (fabs(d) < 1e-12) { pos += snprintf_safe(steps + pos, steps_max - pos, "Singular.\n"); return 0; }
        for (int j = 0; j < 2*n; j++) aug[i*(2*n) + j] /= d;
        for (int j = 0; j < n; j++) if (j != i) {
            double factor = aug[j*(2*n) + i];
            for (int k = 0; k < 2*n; k++) aug[j*(2*n) + k] -= factor * aug[i*(2*n) + k];
        }
    }
    for (int i = 0; i < n; i++) for (int j = 0; j < n; j++) out[i*n + j] = aug[i*(2*n) + n + j];
    pos += snprintf_safe(steps + pos, steps_max - pos, "Inverse computed.\n");
    return 1;
}

int nx_matrix_rank(double* mat, int m, int n, char* steps, int steps_max) {
    int pos = 0, rank = 0;
    pos += snprintf_safe(steps + pos, steps_max - pos, "Rank of %dx%d via row echelon:\n", m, n);
    std::vector<double> a(mat, mat + m*n);
    std::vector<bool> row_used(m, false);
    for (int col = 0; col < n && rank < m; col++) {
        int sel = -1;
        for (int i = 0; i < m; i++) if (!row_used[i] && fabs(a[i*n + col]) > 1e-12) { sel = i; break; }
        if (sel < 0) continue;
        row_used[sel] = true; rank++;
        double scale = a[sel*n + col];
        for (int j = col; j < n; j++) a[sel*n + j] /= scale;
        for (int i = 0; i < m; i++) if (!row_used[i]) {
            double factor = a[i*n + col];
            for (int j = col; j < n; j++) a[i*n + j] -= factor * a[sel*n + j];
        }
    }
    pos += snprintf_safe(steps + pos, steps_max - pos, "Rank = %d\n", rank);
    return rank;
}

double nx_eigenvalue_2x2(double mat[4], int which, char* steps, int steps_max) {
    int pos = 0;
    double trace = mat[0] + mat[3];
    double det = mat[0]*mat[3] - mat[1]*mat[2];
    double disc = trace*trace - 4*det;
    pos += snprintf_safe(steps + pos, steps_max - pos, "Eigenvalues of 2×2: tr=%.4f det=%.4f Δ=%.4f\n", trace, det, disc);
    if (disc < 0) { pos += snprintf_safe(steps, steps_max, "Complex.\n"); return 0; }
    double sqrt_d = sqrt(disc);
    double val = which == 0 ? (trace + sqrt_d)/2 : (trace - sqrt_d)/2;
    pos += snprintf_safe(steps + pos, steps_max - pos, "λ%d = %.8f\n", which+1, val);
    (void)pos;
    return val;
}

/* ==================== VECTOR ALGEBRA ==================== */

void nx_cross_product(double a[3], double b[3], double out[3], char* steps, int steps_max) {
    int pos = 0;
    pos += snprintf_safe(steps + pos, steps_max - pos, "a×b = ");
    out[0] = a[1]*b[2] - a[2]*b[1];
    out[1] = a[2]*b[0] - a[0]*b[2];
    out[2] = a[0]*b[1] - a[1]*b[0];
    pos += snprintf_safe(steps + pos, steps_max - pos, "(%.6f, %.6f, %.6f)\n", out[0], out[1], out[2]);
}

double nx_dot_product(double a[3], double b[3], char* steps, int steps_max) {
    double r = a[0]*b[0] + a[1]*b[1] + a[2]*b[2];
    snprintf_safe(steps, steps_max, "a·b = %.6f·%.6f + %.6f·%.6f + %.6f·%.6f = %.6f\n", a[0], b[0], a[1], b[1], a[2], b[2], r);
    return r;
}

double nx_vector_magnitude(double a[3], char* steps, int steps_max) {
    double r = sqrt(a[0]*a[0] + a[1]*a[1] + a[2]*a[2]);
    snprintf_safe(steps, steps_max, "|a| = √(%.6f² + %.6f² + %.6f²) = %.6f\n", a[0], a[1], a[2], r);
    return r;
}

double nx_angle_between(double a[3], double b[3], char* steps, int steps_max) {
    int pos = 0;
    double dot = nx_dot_product(a, b, steps, steps_max);
    double ma = nx_vector_magnitude(a, steps, steps_max);
    double mb = nx_vector_magnitude(b, steps, steps_max);
    double angle = acos(dot / (ma * mb));
    pos += snprintf_safe(steps + pos, steps_max - pos, "θ = acos(%.6f / (%.6f × %.6f)) = %.6f rad (%.2f°)\n", dot, ma, mb, angle, angle*180/M_PI);
    return angle;
}

double nx_scalar_triple_product(double a[3], double b[3], double c[3], char* steps, int steps_max) {
    double cross[3];
    cross[0] = b[1]*c[2] - b[2]*c[1];
    cross[1] = b[2]*c[0] - b[0]*c[2];
    cross[2] = b[0]*c[1] - b[1]*c[0];
    double r = a[0]*cross[0] + a[1]*cross[1] + a[2]*cross[2];
    snprintf_safe(steps, steps_max, "[a b c] = a·(b×c) = %.6f\n", r);
    return r;
}

void nx_vector_projection(double a[3], double b[3], double out[3], char* steps, int steps_max) {
    int pos = 0;
    double dot = nx_dot_product(a, b, steps, steps_max);
    double mag2 = b[0]*b[0] + b[1]*b[1] + b[2]*b[2];
    double factor = dot / mag2;
    out[0] = factor * b[0]; out[1] = factor * b[1]; out[2] = factor * b[2];
    pos += snprintf_safe(steps + pos, steps_max - pos, "proj_b(a) = (a·b)/|b|² × b = (%.6f, %.6f, %.6f)\n", out[0], out[1], out[2]);
}

/* ==================== COORDINATE GEOMETRY ==================== */

double nx_distance_2d(double x1, double y1, double x2, double y2, char* steps, int steps_max) {
    double d = sqrt((x2-x1)*(x2-x1) + (y2-y1)*(y2-y1));
    snprintf_safe(steps, steps_max, "d = √((%.4f-%.4f)² + (%.4f-%.4f)²) = %.6f\n", x2, x1, y2, y1, d);
    return d;
}

double nx_distance_3d(double x1, double y1, double z1, double x2, double y2, double z2, char* steps, int steps_max) {
    double d = sqrt((x2-x1)*(x2-x1) + (y2-y1)*(y2-y1) + (z2-z1)*(z2-z1));
    snprintf_safe(steps, steps_max, "d = √((Δx)² + (Δy)² + (Δz)²) = %.6f\n", d);
    return d;
}

void nx_section_formula(double x1, double y1, double x2, double y2, double m, double n, double out[2], char* steps, int steps_max) {
    int pos = 0;
    out[0] = (m*x2 + n*x1) / (m+n);
    out[1] = (m*y2 + n*y1) / (m+n);
    pos += snprintf_safe(steps + pos, steps_max - pos, "P = ((%.4f×%.4f + %.4f×%.4f)/(%.4f+%.4f), ...) = (%.6f, %.6f)\n",
        m, x2, n, x1, m, n, out[0], out[1]);
}

double nx_area_of_triangle(double x1, double y1, double x2, double y2, double x3, double y3, char* steps, int steps_max) {
    double area = fabs(x1*(y2-y3) + x2*(y3-y1) + x3*(y1-y2)) / 2;
    snprintf_safe(steps, steps_max, "Area = ½|%.4f(%.4f-%.4f) + %.4f(%.4f-%.4f) + %.4f(%.4f-%.4f)| = %.6f\n",
        x1, y2, y3, x2, y3, y1, x3, y1, y2, area);
    return area;
}

void nx_centroid(double x1, double y1, double x2, double y2, double x3, double y3, double out[2], char* steps, int steps_max) {
    out[0] = (x1+x2+x3)/3; out[1] = (y1+y2+y3)/3;
    snprintf_safe(steps, steps_max, "Centroid = ((%.4f+%.4f+%.4f)/3, (%.4f+%.4f+%.4f)/3) = (%.6f, %.6f)\n",
        x1, x2, x3, y1, y2, y3, out[0], out[1]);
}

/* ==================== SEQUENCES & SERIES ==================== */

double nx_ap_nth_term(double a, double d, int n, char* steps, int steps_max) {
    double t = a + (n-1)*d;
    snprintf_safe(steps, steps_max, "T%d = a + (n-1)d = %.4f + (%d)×%.4f = %.6f\n", n, a, n-1, d, t);
    return t;
}

double nx_ap_sum(double a, double d, int n, char* steps, int steps_max) {
    double s = n*(2*a + (n-1)*d)/2;
    snprintf_safe(steps, steps_max, "S%d = n/2[2a + (n-1)d] = %d/2[2×%.4f + %d×%.4f] = %.6f\n", n, n, a, n-1, d, s);
    return s;
}

double nx_gp_nth_term(double a, double r, int n, char* steps, int steps_max) {
    double t = a * pow(r, n-1);
    snprintf_safe(steps, steps_max, "T%d = ar^(n-1) = %.4f × %.4f^%d = %.6f\n", n, a, r, n-1, t);
    return t;
}

double nx_gp_sum(double a, double r, int n, char* steps, int steps_max) {
    double s = fabs(r-1) < 1e-12 ? a*n : a*(1 - pow(r, n))/(1-r);
    snprintf_safe(steps, steps_max, "S%d = a(1-r^n)/(1-r) = %.4f(1-%.4f^%d)/(1-%.4f) = %.6f\n", n, a, r, n, r, s);
    return s;
}

double nx_gp_infinite_sum(double a, double r, char* steps, int steps_max) {
    if (fabs(r) >= 1.0) { snprintf_safe(steps, steps_max, "|r|≥1 → diverges.\n"); return 0; }
    double s = a/(1-r);
    snprintf_safe(steps, steps_max, "S∞ = a/(1-r) = %.4f/(1-%.4f) = %.6f\n", a, r, s);
    return s;
}

double nx_hp_nth_term(double a, double d, int n, char* steps, int steps_max) {
    double t = 1.0 / (a + (n-1)*d);
    snprintf_safe(steps, steps_max, "HP: T%d = 1/(a+(n-1)d) = 1/(%.4f+%d×%.4f) = %.6f\n", n, a, n-1, d, t);
    return t;
}

/* ==================== TRIGONOMETRY ==================== */

double nx_solve_triangle_sss(double a, double b, double c, double out[3], char* steps, int steps_max) {
    int pos = 0;
    pos += snprintf_safe(steps + pos, steps_max - pos, "Triangle SSS: a=%.4f b=%.4f c=%.4f\n", a, b, c);
    // law of cos: A = acos((b²+c²-a²)/(2bc))
    out[0] = acos((b*b + c*c - a*a) / (2*b*c));
    out[1] = acos((a*a + c*c - b*b) / (2*a*c));
    out[2] = acos((a*a + b*b - c*c) / (2*a*b));
    pos += snprintf_safe(steps + pos, steps_max - pos, "Angles: A=%.4f° B=%.4f° C=%.4f°\n", out[0]*180/M_PI, out[1]*180/M_PI, out[2]*180/M_PI);
    return out[0] + out[1] + out[2]; // ≈ π
}

double nx_solve_triangle_sas(double a, double b, double angle_c, double out[4], char* steps, int steps_max) {
    int pos = 0;
    pos += snprintf_safe(steps + pos, steps_max - pos, "SAS: a=%.4f b=%.4f C=%.4f°\n", a, b, angle_c*180/M_PI);
    double c2 = a*a + b*b - 2*a*b*cos(angle_c);
    double c = sqrt(c2);
    double angle_a = acos((b*b + c2 - a*a) / (2*b*c));
    double angle_b = acos((a*a + c2 - b*b) / (2*a*c));
    out[0] = c; out[1] = angle_a; out[2] = angle_b; out[3] = angle_c;
    pos += snprintf_safe(steps + pos, steps_max - pos, "c=%.4f A=%.4f° B=%.4f°\n", c, angle_a*180/M_PI, angle_b*180/M_PI);
    return c;
}

/* ==================== STATISTICS ==================== */

double nx_mean(double* data, int n, char* steps, int steps_max) {
    double sum = 0;
    for (int i = 0; i < n; i++) sum += data[i];
    double m = sum / n;
    snprintf_safe(steps, steps_max, "Mean = Σx/n = %.4f/%d = %.6f\n", sum, n, m);
    return m;
}

double nx_median(double* data, int n, char* steps, int steps_max) {
    std::vector<double> d(data, data+n);
    std::sort(d.begin(), d.end());
    double m = n % 2 == 1 ? d[n/2] : (d[n/2-1] + d[n/2])/2;
    snprintf_safe(steps, steps_max, "Median (sorted) = %.6f\n", m);
    return m;
}

double nx_variance(double* data, int n, char* steps, int steps_max) {
    double m = nx_mean(data, n, steps, steps_max);
    double sum = 0;
    for (int i = 0; i < n; i++) sum += (data[i] - m)*(data[i] - m);
    double v = sum / n;
    snprintf_safe(steps, steps_max, "Var = Σ(xᵢ-x̄)²/n = %.4f/%d = %.6f\n", sum, n, v);
    return v;
}

double nx_std_dev(double* data, int n, char* steps, int steps_max) {
    double v = nx_variance(data, n, steps, steps_max);
    double sd = sqrt(v);
    snprintf_safe(steps, steps_max, "σ = √Var = %.6f\n", sd);
    return sd;
}

double nx_correlation(double* x, double* y, int n, char* steps, int steps_max) {
    int pos = 0;
    double mx = nx_mean(x, n, steps, steps_max);
    double my = nx_mean(y, n, steps, steps_max);
    double num = 0, sx2 = 0, sy2 = 0;
    for (int i = 0; i < n; i++) {
        double dx = x[i] - mx, dy = y[i] - my;
        num += dx*dy; sx2 += dx*dx; sy2 += dy*dy;
    }
    double r = num / (sqrt(sx2)*sqrt(sy2));
    pos += snprintf_safe(steps + pos, steps_max - pos, "r = Σ(x-x̄)(y-ȳ) / √(Σ(x-x̄)²·Σ(y-ȳ)²) = %.6f\n", r);
    return r;
}

/* ==================== PROBABILITY ==================== */

double nx_binomial_prob(int n, int k, double p, char* steps, int steps_max) {
    int pos = 0;
    pos += snprintf_safe(steps + pos, steps_max - pos, "P(X=%d) = C(%d,%d) × %.4f^%d × (1-%.4f)^(%d-%d)\n", k, n, k, p, k, p, n, k);
    long long nck = nx_nCr(n, k, steps, steps_max);
    double prob = nck * pow(p, k) * pow(1-p, n-k);
    pos += snprintf_safe(steps + pos, steps_max - pos, "= %.10f\n", prob);
    return prob;
}

/* ==================== COMPLEX NUMBERS ==================== */

void nx_complex_add(double a[2], double b[2], double out[2], char* steps, int steps_max) {
    out[0] = a[0] + b[0]; out[1] = a[1] + b[1];
    snprintf_safe(steps, steps_max, "(%.4f+%.4fi) + (%.4f+%.4fi) = %.4f+%.4fi\n", a[0], a[1], b[0], b[1], out[0], out[1]);
}

void nx_complex_multiply(double a[2], double b[2], double out[2], char* steps, int steps_max) {
    out[0] = a[0]*b[0] - a[1]*b[1];
    out[1] = a[0]*b[1] + a[1]*b[0];
    snprintf_safe(steps, steps_max, "(%.4f+%.4fi) × (%.4f+%.4fi) = %.4f+%.4fi\n", a[0], a[1], b[0], b[1], out[0], out[1]);
}

void nx_complex_divide(double a[2], double b[2], double out[2], char* steps, int steps_max) {
    double denom = b[0]*b[0] + b[1]*b[1];
    out[0] = (a[0]*b[0] + a[1]*b[1]) / denom;
    out[1] = (a[1]*b[0] - a[0]*b[1]) / denom;
    snprintf_safe(steps, steps_max, "(%.4f+%.4fi) / (%.4f+%.4fi) = %.4f+%.4fi\n", a[0], a[1], b[0], b[1], out[0], out[1]);
}

double nx_complex_modulus(double a[2], char* steps, int steps_max) {
    double r = sqrt(a[0]*a[0] + a[1]*a[1]);
    snprintf_safe(steps, steps_max, "|%.4f+%.4fi| = √(%.4f²+%.4f²) = %.6f\n", a[0], a[1], a[0], a[1], r);
    return r;
}

double nx_complex_argument(double a[2], char* steps, int steps_max) {
    double theta = atan2(a[1], a[0]);
    snprintf_safe(steps, steps_max, "arg(%.4f+%.4fi) = atan2(%.4f, %.4f) = %.6f rad (%.2f°)\n", a[0], a[1], a[1], a[0], theta, theta*180/M_PI);
    return theta;
}

void nx_complex_power(double a[2], int n, double out[2], char* steps, int steps_max) {
    int pos = 0;
    double r = sqrt(a[0]*a[0] + a[1]*a[1]);
    double theta = atan2(a[1], a[0]);
    pos += snprintf_safe(steps + pos, steps_max - pos, "(%.4f+%.4fi)^%d via De Moivre:\n", a[0], a[1], n);
    double rn = pow(r, n);
    double nt = theta * n;
    out[0] = rn * cos(nt);
    out[1] = rn * sin(nt);
    pos += snprintf_safe(steps + pos, steps_max - pos, "= %.6f + %.6fi\n", out[0], out[1]);
}

void nx_complex_nth_roots(double a[2], int n, double out[][2], char* steps, int steps_max) {
    int pos = 0;
    double r = sqrt(a[0]*a[0] + a[1]*a[1]);
    double theta = atan2(a[1], a[0]);
    pos += snprintf_safe(steps + pos, steps_max - pos, "%d-th roots of %.4f+%.4fi:\n", n, a[0], a[1]);
    double rn = pow(r, 1.0/n);
    for (int k = 0; k < n; k++) {
        double angle = (theta + 2*k*M_PI)/n;
        out[k][0] = rn * cos(angle);
        out[k][1] = rn * sin(angle);
        pos += snprintf_safe(steps + pos, steps_max - pos, "  z%d = %.6f + %.6fi\n", k+1, out[k][0], out[k][1]);
    }
}

/* ==================== LINE/PLANE GEOMETRY ==================== */

void nx_line_intersection(double a1, double b1, double c1, double a2, double b2, double c2, double out[2], char* steps, int steps_max) {
    int pos = 0;
    double det = a1*b2 - a2*b1;
    pos += snprintf_safe(steps + pos, steps_max - pos, "Line intersection:\n");
    if (fabs(det) < 1e-12) {
        pos += snprintf_safe(steps + pos, steps_max - pos, "Lines are parallel.\n");
        out[0] = out[1] = 0;
        return;
    }
    out[0] = (b1*c2 - b2*c1) / det;
    out[1] = (c1*a2 - c2*a1) / det;
    pos += snprintf_safe(steps + pos, steps_max - pos, "Intersection at (%.6f, %.6f)\n", out[0], out[1]);
}

double nx_distance_point_line(double px, double py, double a, double b, double c, char* steps, int steps_max) {
    double d = fabs(a*px + b*py + c) / sqrt(a*a + b*b);
    snprintf_safe(steps, steps_max, "Distance = |%.4f×%.4f + %.4f×%.4f + %.4f| / √(%.4f²+%.4f²) = %.6f\n", a, px, b, py, c, a, b, d);
    return d;
}

/* ==================== EXPRESSION EVALUATOR ==================== */

double nx_evaluate_expression(const char* expr, char* steps, int steps_max) {
    snprintf_safe(steps, steps_max, "Evaluating: %s\n", expr);
    // Simple shunting-yard for basic arithmetic
    std::vector<double> vals;
    std::vector<char> ops;
    auto apply = [&]() {
        if (vals.size() < 2 || ops.empty()) return;
        double b = vals.back(); vals.pop_back();
        double a = vals.back(); vals.pop_back();
        char op = ops.back(); ops.pop_back();
        switch(op) {
            case '+': vals.push_back(a+b); break;
            case '-': vals.push_back(a-b); break;
            case '*': vals.push_back(a*b); break;
            case '/': vals.push_back(fabs(b)<1e-12?0:a/b); break;
            default: vals.push_back(0);
        }
    };
    const char* p = expr;
    while (*p) {
        if (*p >= '0' && *p <= '9') {
            vals.push_back(strtod(p, (char**)&p)); continue;
        }
        if (*p == '+' || *p == '-') { while (!ops.empty() && ops.back()!='(') apply(); ops.push_back(*p); }
        else if (*p == '*' || *p == '/') { while (!ops.empty() && (ops.back()=='*'||ops.back()=='/')) apply(); ops.push_back(*p); }
        else if (*p == '(') ops.push_back(*p);
        else if (*p == ')') { while (!ops.empty() && ops.back()!='(') apply(); if (!ops.empty()) ops.pop_back(); }
        p++;
    }
    while (!ops.empty()) apply();
    double r = vals.empty() ? 0 : vals.back();
    snprintf_safe(steps, steps_max, "Result = %.10f\n", r);
    return r;
}

/* ==================== FORENSIC WATERMARK (C++) ==================== */
// FNV-1a 32-bit -> 8 hex chars, fast & obfuscated, called via JNI MethodChannel.
void nx_watermark_hash(const char* input, char out8[9]) {
    uint32_t h = 2166136261u;
    for (const char* p = input; *p; ++p) { h ^= (uint8_t)*p; h *= 16777619u; }
    // Mix with length
    h ^= (uint32_t)strlen(input);
    h *= 16777619u;
    snprintf_safe(out8, 9, "%08x", h);
}
int nx_watermark_lsb_embed(unsigned char* pixels, int w, int h, const char* payload) {
    size_t len = strlen(payload);
    size_t bits = len * 8;
    if ((size_t)w * h < bits) return -1;
    for (size_t i = 0; i < bits; ++i) {
        size_t byteIdx = i / 8;
        int bitIdx = 7 - (i % 8);
        int bit = (payload[byteIdx] >> bitIdx) & 1;
        pixels[i] = (pixels[i] & 0xFE) | bit;
    }
    return 0;
}
