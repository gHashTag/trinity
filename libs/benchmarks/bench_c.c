/**
 * Benchmark for libtrinityvsa
 * 
 * Compile: gcc -O3 -mavx2 -I ../c/libtrinityvsa/include bench_c.c \
 *          -L ../c/libtrinityvsa -ltrinityvsa -lm -o bench_c
 */

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "trinity_vsa.h"

#define ITERATIONS 1000
#define WARMUP 100

static double get_time_us(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1e6 + ts.tv_nsec / 1e3;
}

static double benchmark(const char* name, void (*fn)(void*), void* ctx) {
    // Warmup
    for (int i = 0; i < WARMUP; i++) {
        fn(ctx);
    }
    
    // Benchmark
    double start = get_time_us();
    for (int i = 0; i < ITERATIONS; i++) {
        fn(ctx);
    }
    double end = get_time_us();
    
    double avg_us = (end - start) / ITERATIONS;
    printf("%-20s %8.2f µs\n", name, avg_us);
    return avg_us;
}

typedef struct {
    trit_vector_t* a;
    trit_vector_t* b;
    trit_vector_t* result;
    packed_trit_vec_t* pa;
    packed_trit_vec_t* pb;
} bench_ctx_t;

static void bench_bind(void* ctx) {
    bench_ctx_t* c = (bench_ctx_t*)ctx;
    trit_vector_t* r = trit_bind(c->a, c->b);
    trit_vector_free(r);
}

static void bench_similarity(void* ctx) {
    bench_ctx_t* c = (bench_ctx_t*)ctx;
    volatile double sim = trit_similarity(c->a, c->b);
    (void)sim;
}

static void bench_dot(void* ctx) {
    bench_ctx_t* c = (bench_ctx_t*)ctx;
    volatile int64_t dot = trit_dot(c->a, c->b);
    (void)dot;
}

static void bench_permute(void* ctx) {
    bench_ctx_t* c = (bench_ctx_t*)ctx;
    trit_vector_t* r = trit_permute(c->a, 1);
    trit_vector_free(r);
}

static void bench_packed_bind(void* ctx) {
    bench_ctx_t* c = (bench_ctx_t*)ctx;
    packed_trit_vec_t* r = packed_bind(c->pa, c->pb);
    packed_free(r);
}

static void bench_packed_dot(void* ctx) {
    bench_ctx_t* c = (bench_ctx_t*)ctx;
    volatile int64_t dot = packed_dot(c->pa, c->pb);
    (void)dot;
}

int main(void) {
    printf("=== Trinity VSA C Library Benchmark ===\n\n");
    printf("SIMD: AVX2=%s AVX-512=%s\n\n", 
           trinity_has_avx2() ? "yes" : "no",
           trinity_has_avx512() ? "yes" : "no");
    
    size_t dims[] = {1000, 10000, 100000};
    int num_dims = sizeof(dims) / sizeof(dims[0]);
    
    for (int d = 0; d < num_dims; d++) {
        size_t dim = dims[d];
        printf("--- Dimension: %zu ---\n", dim);
        
        bench_ctx_t ctx;
        ctx.a = trit_vector_random(dim, 42);
        ctx.b = trit_vector_random(dim, 123);
        ctx.pa = packed_from_trit_vector(ctx.a);
        ctx.pb = packed_from_trit_vector(ctx.b);
        
        benchmark("bind", bench_bind, &ctx);
        benchmark("similarity", bench_similarity, &ctx);
        benchmark("dot", bench_dot, &ctx);
        benchmark("permute", bench_permute, &ctx);
        benchmark("packed_bind", bench_packed_bind, &ctx);
        benchmark("packed_dot", bench_packed_dot, &ctx);
        
        trit_vector_free(ctx.a);
        trit_vector_free(ctx.b);
        packed_free(ctx.pa);
        packed_free(ctx.pb);
        
        printf("\n");
    }
    
    return 0;
}
