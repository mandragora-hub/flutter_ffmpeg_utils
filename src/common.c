#include "common.h"

#include <stdarg.h>
#include <stdio.h>

#ifdef __ANDROID__
#include <android/log.h>

#define ANDROID_LOG_TAG "FFmpegUtils"
#endif

void platform_log(const LogLevel_t logLevel, const char *fmt, ...) {
  va_list args;
  va_start(args, fmt);

  switch (logLevel) {
    case LOG_LEVEL_DEBUG:
#ifdef __ANDROID__
      __android_log_vprint(ANDROID_LOG_DEBUG, ANDROID_LOG_TAG, fmt, args);
#else
      vprintf(fmt, args);
#endif
      break;
    case LOG_LEVEL_ERROR:
#ifdef __ANDROID__
      __android_log_vprint(ANDROID_LOG_ERROR, ANDROID_LOG_TAG, fmt, args);
#else
      vfprintf(stderr, fmt, args);
#endif
      break;
  }
  va_end(args);
}
