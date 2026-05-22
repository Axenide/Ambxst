/**
 * fps_preload.c — Built-in FPS counter for Ambxst
 *
 * Intercepts Vulkan (vkQueuePresentKHR), EGL (eglSwapBuffers), and
 * GLX (glXSwapBuffers) to measure actual application frame rate.
 * Activated only when ambxst-fps=1 is set in the environment.
 *
 * Output: writes average FPS + PID to /dev/shm/ambxst_fps every N frames.
 *
 * Compile:
 *   gcc -shared -fPIC -O2 -o libambfps.so fps_preload.c -lm -ldl
 *
 * Install (part of Ambxst):
 *   cp libambfps.so ~/.local/lib/libambfps.so
 *
 * Usage:
 *   ambxst-fps ./game              # wrapper script
 *   LD_PRELOAD=libambfps.so ./game # direct (needs ambxst-fps=1 env)
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

#if defined(__GNUC__) && __GNUC__ >= 4
#define EXPORT __attribute__((visibility("default")))
#else
#define EXPORT
#endif

/* ── Activation guard ──────────────────────────────────────────── */
/* Only hook functions if ambxst-fps env var is set and non-zero.   */
static int _ambfps_enabled = 0;

static void _check_env(void) {
    const char *v = getenv("ambxst-fps");
    if (!v || !v[0] || strcmp(v, "0") == 0) {
        v = getenv("AMBXST_FPS");
    }
    if (v && v[0] && strcmp(v, "0") != 0) _ambfps_enabled = 1;
}

/* ── FPS tracking ──────────────────────────────────────────────── */
#define MAX_SAMPLES 32
static double fps_samples[MAX_SAMPLES];
static int sample_count = 0, sample_idx = 0;
static uint64_t last_present_ns = 0, frame_count = 0;

/* EMA smoothing coefficient (higher = smoother, slower response) */
#define EMA_ALPHA 0.08
static double fps_smoothed = 0.0;
static int smooth_init = 0;

static uint64_t get_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
}

static void write_fps(double fps) {
    FILE *f = fopen("/dev/shm/ambxst_fps", "w");
    if (f) {
        fprintf(f, "fps=%.1f\npid=%d\nframes=%lu\n"
                "source=ambxst-preload\n",
                fps, getpid(),
                (unsigned long)frame_count);
        fclose(f);
    }
}

static void record_present(void) {
    if (!_ambfps_enabled) return;

    uint64_t now = get_ns();
    if (last_present_ns > 0) {
        uint64_t dt = now - last_present_ns;
        /* Ignore frames delivered too fast (<0.5ms = >2000 fps, noise) */
        if (dt > 500000ULL) {
            double fps = 1000000000.0 / (double)dt;
            if (fps > 0.0 && fps < 2000.0) {
                /* Rolling window for initial average */
                fps_samples[sample_idx] = fps;
                sample_idx = (sample_idx + 1) % MAX_SAMPLES;
                if (sample_count < MAX_SAMPLES) sample_count++;

                /* Exponential moving average */
                if (!smooth_init) {
                    fps_smoothed = fps;
                    smooth_init = 1;
                } else {
                    fps_smoothed = fps_smoothed * (1.0 - EMA_ALPHA) + fps * EMA_ALPHA;
                }

                frame_count++;

                /* Write every 8 frames for responsive updates */
                if (frame_count % 8 == 0) {
                    int n = sample_count < MAX_SAMPLES ? sample_count : MAX_SAMPLES;
                    double sum = 0.0;
                    for (int i = 0; i < n; i++) sum += fps_samples[i];
                    double rolling_avg = sum / n;
                    /* Blend: 70% EMA (smooth trend) + 30% rolling (reactive) */
                    double blended = fps_smoothed * 0.7 + rolling_avg * 0.3;
                    write_fps(blended);
                }
            }
        }
    }
    last_present_ns = now;
}

/* ── Vulkan hook: intercept vkQueuePresentKHR ──────────────────── */

static int hooked_vkQueuePresentKHR(void *queue, void *pPresentInfo) {
    record_present();

    static int (*real)(void*, void*) = NULL;
    if (!real) {
        void *h = dlopen("libvulkan.so.1", RTLD_LAZY | RTLD_NOLOAD);
        if (h) real = dlsym(h, "vkQueuePresentKHR");
    }
    return real ? real(queue, pPresentInfo) : 0;
}

/* ── EGL hook: intercept eglSwapBuffers ────────────────────────── */

static int hooked_eglSwapBuffers(void *display, void *surface) {
    record_present();

    static int (*real)(void*, void*) = NULL;
    if (!real) {
        void *h = dlopen("libEGL.so.1", RTLD_LAZY | RTLD_NOLOAD);
        if (h) real = dlsym(h, "eglSwapBuffers");
    }
    return real ? real(display, surface) : 0;
}

/* ── GLX hook: intercept glXSwapBuffers (older OpenGL games) ───── */

static void hooked_glXSwapBuffers(void *display, uint64_t drawable) {
    record_present();

    static void (*real)(void*, uint64_t) = NULL;
    if (!real) {
        void *h = dlopen("libGL.so.1", RTLD_LAZY | RTLD_NOLOAD);
        if (h) real = dlsym(h, "glXSwapBuffers");
    }
    if (real) real(display, drawable);
}

/* ── vkGetDeviceProcAddr interception ──────────────────────────── */
/* When the game asks for vkQueuePresentKHR, give it our version.   */

EXPORT void *vkGetDeviceProcAddr(void *device, const char *pName) {
    if (_ambfps_enabled && pName && strcmp(pName, "vkQueuePresentKHR") == 0)
        return (void*)hooked_vkQueuePresentKHR;

    static void *(*real)(void*, const char*) = NULL;
    if (!real) {
        void *h = dlopen("libvulkan.so.1", RTLD_LAZY | RTLD_NOLOAD);
        if (h) real = dlsym(h, "vkGetDeviceProcAddr");
    }
    return real ? real(device, pName) : NULL;
}

/* vkGetInstanceProcAddr must be hooked to return our GDPA */
EXPORT void *vkGetInstanceProcAddr(void *instance, const char *pName) {
    if (pName) {
        if (strcmp(pName, "vkGetInstanceProcAddr") == 0)
            return (void*)vkGetInstanceProcAddr;
        if (strcmp(pName, "vkGetDeviceProcAddr") == 0)
            return (void*)vkGetDeviceProcAddr;
    }
    static void *(*real)(void*, const char*) = NULL;
    if (!real) {
        void *h = dlopen("libvulkan.so.1", RTLD_LAZY | RTLD_NOLOAD);
        if (h) real = dlsym(h, "vkGetInstanceProcAddr");
    }
    return real ? real(instance, pName) : NULL;
}

/* ── Exported swap functions ───────────────────────────────────── */

EXPORT int eglSwapBuffers(void *display, void *surface) {
    if (!_ambfps_enabled) {
        static int (*real)(void*, void*) = NULL;
        if (!real) {
            void *h = dlopen("libEGL.so.1", RTLD_LAZY | RTLD_NOLOAD);
            if (h) real = dlsym(h, "eglSwapBuffers");
        }
        return real ? real(display, surface) : 0;
    }
    return hooked_eglSwapBuffers(display, surface);
}

EXPORT void glXSwapBuffers(void *display, uint64_t drawable) {
    if (!_ambfps_enabled) {
        static void (*real)(void*, uint64_t) = NULL;
        if (!real) {
            void *h = dlopen("libGL.so.1", RTLD_LAZY | RTLD_NOLOAD);
            if (h) real = dlsym(h, "glXSwapBuffers");
        }
        if (real) real(display, drawable);
        return;
    }
    hooked_glXSwapBuffers(display, drawable);
}

/* ── Constructor ───────────────────────────────────────────────── */

static void __attribute__((constructor)) init(void) {
    _check_env();
    if (_ambfps_enabled) {
        /* Write initial zero to signal presence */
        FILE *f = fopen("/dev/shm/ambxst_fps", "w");
        if (f) {
            fprintf(f, "fps=0.0\npid=%d\nframes=0\nsource=ambxst-preload\n",
                    getpid());
            fclose(f);
        }
    }
}

static void __attribute__((destructor)) fini(void) {
    if (_ambfps_enabled) {
        remove("/dev/shm/ambxst_fps");
    }
}
