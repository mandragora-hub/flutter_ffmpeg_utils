#pragma once

#ifndef COMMON_H
#define COMMON_H

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

// #if !defined(__wasm__)
typedef enum { LOG_LEVEL_DEBUG = 0, LOG_LEVEL_INFO = 1, LOG_LEVEL_WARN = 2, LOG_LEVEL_ERROR = 3 } LogLevel_t;
void platform_log(LogLevel_t logLevel, const char *fmt, ...);
// #endif

#endif // COMMON_H