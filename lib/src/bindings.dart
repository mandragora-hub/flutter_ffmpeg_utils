import 'dart:ffi';
import 'dart:io';

import '../ffmpeg_utils_bindings_generated.dart';

const String _libName = 'ffmpeg_utils';

/// The dynamic library in which the symbols for [FFmpegUtilsBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final FFmpegUtilsBindings bindings = FFmpegUtilsBindings(_dylib);
