import 'package:flutter/services.dart';

class AudioEngine {
  static const MethodChannel _channel = MethodChannel('com.auralis.audio/engine');

  Future<void> start() async {
    await _channel.invokeMethod<void>('start');
  }

  Future<void> stop() async {
    await _channel.invokeMethod<void>('stop');
  }

  Future<bool> get isSupported async {
    return await _channel.invokeMethod<bool>('isSupported') ?? false;
  }

  void dispose() {}
}
