import 'package:flutter/services.dart';

class AudioEngine {
  static const MethodChannel _channel = MethodChannel('com.auralis.audio/engine');

  Future<void> start() async {
    await _channel.invokeMethod<void>('start');
  }

  Future<void> stop() async {
    await _channel.invokeMethod<void>('stop');
  }

  Future<Map<String, dynamic>> getMetrics() async {
    final metrics = await _channel.invokeMapMethod<String, dynamic>('getMetrics');
    return metrics ?? const {};
  }

  void dispose() {
    // The screen stops capture explicitly; native Android also stops on teardown.
  }
}
