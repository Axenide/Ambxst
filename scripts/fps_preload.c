/**
 * fps_preload.c — Built-in FPS counter for NothingLess
 * Funciona como capa Vulkan+VK_LAYER con encadenamiento correcto.
 * También hooks OpenGL/EGL via LD_PRELOAD.
 *
 * Compile: gcc -shared -fPIC -O2 -o libambfps.so fps_preload.c -lm -ldl
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>
#include <unistd.h>
#include <stdint.h>
#include <dlfcn.h>

#define EXPORT __attribute__((visibility("default")))

static int enabled = 0;
static void check_env(void) {
    const char *v = getenv("nothingless-fps");
    if (!v || strcmp(v, "0") == 0) v = getenv("NOTHINGLESS_FPS");
    if (!v || strcmp(v, "0") == 0) v = getenv("ENABLE_VK_LAYER_nothingless_fps");
    if (v && v[0] && strcmp(v, "0") != 0) enabled = 1;
}

/* ── FPS tracking ──────────────────────────────────────────────── */
#define MAX_SAMPLES 32
static double fps_samples[MAX_SAMPLES];
static int sample_count = 0, sample_idx = 0;
static uint64_t last_present_ns = 0, frame_count = 0;
static double fps_smoothed = 0.0;
static int smooth_init = 0;

static uint64_t get_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
}

static void write_fps(double fps) {
    FILE *f = fopen("/dev/shm/nothingless_fps", "we");
    if (f) {
        fprintf(f, "fps=%.1f\npid=%d\nframes=%lu\nsource=nothingless-preload\n",
                fps, getpid(), (unsigned long)frame_count);
        fclose(f);
    }
}

static void record_present(void) {
    if (!enabled) return;
    uint64_t now = get_ns();
    if (last_present_ns > 0) {
        uint64_t dt = now - last_present_ns;
        if (dt > 500000ULL) {
            double fps = 1000000000.0 / (double)dt;
            if (fps > 0.0 && fps < 2000.0) {
                fps_samples[sample_idx] = fps;
                sample_idx = (sample_idx + 1) % MAX_SAMPLES;
                if (sample_count < MAX_SAMPLES) sample_count++;
                if (!smooth_init) { fps_smoothed = fps; smooth_init = 1; }
                else { fps_smoothed = fps_smoothed * (1.0 - 0.08) + fps * 0.08; }
                frame_count++;
                if (frame_count % 8 == 0) {
                    int n = sample_count < MAX_SAMPLES ? sample_count : MAX_SAMPLES;
                    double sum = 0.0;
                    for (int i = 0; i < n; i++) sum += fps_samples[i];
                    double blended = fps_smoothed * 0.7 + (sum / n) * 0.3;
                    write_fps(blended);
                }
            }
        }
    }
    last_present_ns = now;
}

/* ── Vulkan layer: intercept vkQueuePresentKHR ─────────────────── */
/* These functions are called by the Vulkan loader AS a layer */

/* Store pointers to the NEXT layer's functions */
static void *next_gipa = NULL;
static void *next_gdpa = NULL;
static void *next_qpresent = NULL;

/* Forward decls */
EXPORT void *vkGetDeviceProcAddr(void *device, const char *pName);
EXPORT int vkQueuePresentKHR(void *queue, void *pPresentInfo);

EXPORT void *vkGetInstanceProcAddr(void *instance, const char *pName) {
    if (!enabled) goto fallback;
    if (!pName) goto fallback;
    if (strcmp(pName, "vkGetInstanceProcAddr") == 0) return (void*)vkGetInstanceProcAddr;
    if (strcmp(pName, "vkGetDeviceProcAddr") == 0) return (void*)vkGetDeviceProcAddr;
    if (strcmp(pName, "vkQueuePresentKHR") == 0) return (void*)vkQueuePresentKHR;
fallback:
    if (!next_gipa) {
        void *h = dlopen("libvulkan.so.1", RTLD_LAZY | RTLD_NOLOAD);
        if (!h) h = dlopen("libvulkan.so", RTLD_LAZY | RTLD_NOLOAD);
        if (h) next_gipa = dlsym(h, "vkGetInstanceProcAddr");
    }
    if (next_gipa) {
        typedef void *(*PFN)(void*, const char*);
        return ((PFN)next_gipa)(instance, pName);
    }
    return NULL;
}

EXPORT void *vkGetDeviceProcAddr(void *device, const char *pName) {
    if (enabled && pName) {
        if (strcmp(pName, "vkQueuePresentKHR") == 0) return (void*)vkQueuePresentKHR;
    }
    if (!next_gdpa) {
        void *h = dlopen("libvulkan.so.1", RTLD_LAZY | RTLD_NOLOAD);
        if (!h) h = dlopen("libvulkan.so", RTLD_LAZY | RTLD_NOLOAD);
        if (h) next_gdpa = dlsym(h, "vkGetDeviceProcAddr");
    }
    if (next_gdpa) {
        typedef void *(*PFN)(void*, const char*);
        return ((PFN)next_gdpa)(device, pName);
    }
    return NULL;
}

EXPORT int vkQueuePresentKHR(void *queue, void *pPresentInfo) {
    record_present();
    if (!next_qpresent) {
        /* Get the next layer's vkQueuePresentKHR via the chain */
        if (next_gdpa) {
            typedef void *(*PFN)(void*, const char*);
            next_qpresent = ((PFN)next_gdpa)(NULL, "vkQueuePresentKHR");
        }
        if (!next_qpresent) {
            void *h = dlopen("libvulkan.so.1", RTLD_LAZY | RTLD_NOLOAD);
            if (!h) h = dlopen("libvulkan.so", RTLD_LAZY | RTLD_NOLOAD);
            if (h) next_qpresent = dlsym(h, "vkQueuePresentKHR");
        }
    }
    if (next_qpresent) {
        typedef int (*PFN)(void*, void*);
        return ((PFN)next_qpresent)(queue, pPresentInfo);
    }
    return 0;
}

/* ── OpenGL hooks (LD_PRELOAD only) ────────────────────────────── */
static void *resolve(const char *lib, const char *sym) {
    void *h = dlopen(lib, RTLD_LAZY | RTLD_NOLOAD);
    if (!h) h = dlopen(lib, RTLD_LAZY);
    if (!h) return NULL;
    void *p = dlsym(h, sym);
    dlclose(h);
    return p;
}

EXPORT int eglSwapBuffers(void *display, void *surface) {
    record_present();
    static int (*real)(void*, void*) = NULL;
    if (!real) real = resolve("libEGL.so.1", "eglSwapBuffers");
    if (!real) real = resolve("libEGL.so", "eglSwapBuffers");
    return real ? real(display, surface) : 0;
}

EXPORT void glXSwapBuffers(void *display, uint64_t drawable) {
    record_present();
    static void (*real)(void*, uint64_t) = NULL;
    if (!real) real = resolve("libGL.so.1", "glXSwapBuffers");
    if (!real) real = resolve("libGL.so", "glXSwapBuffers");
    if (real) real(display, drawable);
}

/* ── Constructor ───────────────────────────────────────────────── */
static void __attribute__((constructor)) init(void) {
    check_env();
    if (enabled) {
        write_fps(0.0);
    }
}

static void __attribute__((destructor)) fini(void) {
    if (enabled) remove("/dev/shm/nothingless_fps");
}
