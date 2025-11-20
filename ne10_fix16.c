#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include "NE10_init.h"
#include "NE10_dsp.h"

#define MAX_SIZE 65536 // 2^16 (65K точек)

int main(int argc, char *argv[])
{
    ne10_fft_cpx_int16_t *in, *out;
    ne10_fft_cfg_int16_t cfg;
    struct timespec start, end;

    if (argc < 2) {
        fprintf(stderr, "Использование: %s <iterations>\n", argv[0]);
        return 1;
    }

    int iterations = atoi(argv[1]);
    if (iterations <= 0) {
        fprintf(stderr, "Ошибка: iterations должно быть > 0\n");
        return 1;
    }

    if (ne10_init() != NE10_OK) {
        fprintf(stderr, "Ошибка: не удалось инициализировать Ne10\n");
        return 1;
    }

    for (int N = 16; N <= MAX_SIZE; N *= 2) {
        in = (ne10_fft_cpx_int16_t*) malloc(N * sizeof(ne10_fft_cpx_int16_t));
        out = (ne10_fft_cpx_int16_t*) malloc(N * sizeof(ne10_fft_cpx_int16_t));

        if (!in || !out) {
            fprintf(stderr, "Ошибка выделения памяти для N=%d\n", N);
            return 1;
        }

        // Инициализация данных: заполнить нулями или значениями
        for (int i = 0; i < N; i++) {
            in[i].r = 0; // Можно заполнить для теста
            in[i].i = 0;
        }

        cfg = ne10_fft_alloc_c2c_int16(N);
        if (!cfg) {
            fprintf(stderr, "Ошибка создания FFT cfg для N=%d\n", N);
            free(in);
            free(out);
            return 1;
        }

        clock_gettime(CLOCK_MONOTONIC, &start);
        for (int i = 0; i < iterations; i++) {
            ne10_fft_c2c_1d_int16_neon(out, in, cfg, 0, N);
        }
        clock_gettime(CLOCK_MONOTONIC, &end);

        double t_ns = (end.tv_sec - start.tv_sec) * 1e9 +
                      (end.tv_nsec - start.tv_nsec);
        double t_us = t_ns / (iterations * 1e3); // мкс на операцию
        printf("N=%8d: %8.2f µs/FFT (iters=%d)\n", N, t_us, iterations);

        ne10_fft_destroy_c2c_int16(cfg);
        free(in);
        free(out);
    }

    return 0;
}

