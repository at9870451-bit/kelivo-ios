// KelivoBridge — Flutter ↔ Rust 通信（C FFI dlsym JSON 总线）
// Rust 侧：native/kelivo_core（kelivo_call / kelivo_free）
import 'dart:convert';
import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';

import 'package:flutter/services.dart' show MethodChannel;

/// 新版 Flutter SDK：lookupFunction<T extends Function, R extends Function>
/// 直接传函数签名（内部自动包装 NativeFunction）。
typedef _CallFn = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _FreeFn = void Function(Pointer<Utf8>);

class KelivoBridge {
  KelivoBridge._();

  static final DynamicLibrary _lib = _load();

  static DynamicLibrary _load() {
    if (Platform.isIOS) {
      // iOS：静态库通过 -force_load/-lkelivo_core 链入主二进制
      return DynamicLibrary.process();
    }
    return DynamicLibrary.open('libkelivo_core.so');
  }

  static final _call = _lib.lookupFunction<_CallFn, _CallFn>('kelivo_call');
  static final _free = _lib.lookupFunction<_FreeFn, _FreeFn>('kelivo_free');

  /// 同步调用 Rust：{"method","params"} → {"ok","data"} 信封
  static Map<String, dynamic> call(String method, Map<String, dynamic> params) {
    final payload = jsonEncode({'method': method, 'params': params});
    final inPtr = _toUtf8(payload);
    final outPtr = _call(inPtr);
    _free(inPtr);
    final text = outPtr.cast<Utf8>().toDartString();
    _free(outPtr);
    final decoded = jsonDecode(text);
    if (decoded is Map && decoded['ok'] == true) {
      return Map<String, dynamic>.from(decoded['data'] as Map? ?? {});
    }
    final err = decoded is Map ? (decoded['error'] ?? {}) : {};
    throw Exception(err is Map ? (err['message'] ?? 'KelivoCore 错误') : err.toString());
  }

  static Pointer<Utf8> _toUtf8(String s) {
    final bytes = utf8.encode(s);
    final ptr = calloc<Uint8>(bytes.length + 1);
    for (var i = 0; i < bytes.length; i++) {
      ptr[i] = bytes[i];
    }
    ptr[bytes.length] = 0;
    return ptr.cast<Utf8>();
  }
}
