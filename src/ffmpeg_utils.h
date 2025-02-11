#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "common.h"

#if _WIN32
#include <windows.h>
#else
#include <pthread.h>
#include <unistd.h>
#endif

FFI_PLUGIN_EXPORT int log_dump_format(const char *filename);

FFI_PLUGIN_EXPORT void show_codecs();

// Muxer: merge video and audio into one file. Return -1 if error occurred, 0
// otherwise.
FFI_PLUGIN_EXPORT int muxer(const char *video_filename,
                            const char *audio_filename,
                            const char *output_filename);

// A very short-lived native function.
//
// For very short-lived functions, it is fine to call them on the main isolate.
// They will block the Dart execution while running the native function, so
// only do this for native functions which are guaranteed to be short-lived.
FFI_PLUGIN_EXPORT int sum(int a, int b);

// A longer lived native function, which occupies the thread calling it.
//
// Do not call these kind of native functions in the main isolate. They will
// block Dart execution. This will cause dropped frames in Flutter applications.
// Instead, call these native functions on a separate isolate.
FFI_PLUGIN_EXPORT int sum_long_running(int a, int b);
