import 'dart:async';

import 'package:flutter/material.dart';

import 'audio_engine.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AuralisApp());
}

class AuralisApp extends StatelessWidget {
  const AuralisApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF081018);
    return MaterialApp(
      title: 'Auralis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF64E6C2),
          brightness: Brightness.dark,
          surface: const Color(0xFF111D27),
        ),
        scaffoldBackgroundColor: background,
      ),
      home: const AuralisHome(),
    );
  }
}

class AuralisHome extends StatefulWidget {
  const AuralisHome({super.key});

  @override
  State<AuralisHome> createState() => _AuralisHomeState();
}

class _AuralisHomeState extends State<AuralisHome> {
  final AudioEngine _engine = AudioEngine();
  Timer? _metricsTimer;
  bool _running = false;
  bool _busy = false;
  String _status = 'Ready to measure';
  Map<String, dynamic> _metrics = const {};

  Future<void> _toggleEngine() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_running) {
        _metricsTimer?.cancel();
        await _engine.stop();
        if (!mounted) return;
        setState(() {
          _running = false;
          _metrics = const {};
          _status = 'Capture stopped';
        });
      } else {
        await _engine.start();
        if (!mounted) return;
        setState(() {
          _running = true;
          _status = 'Microphone capture active';
        });
        _metricsTimer = Timer.periodic(
          const Duration(milliseconds: 300),
          (_) => _refreshMetrics(),
        );
        await _refreshMetrics();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'Could not start audio capture: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshMetrics() async {
    if (!_running) return;
    try {
      final metrics = await _engine.getMetrics();
      if (mounted) setState(() => _metrics = metrics);
    } catch (_) {
      // A temporary metrics read should not stop an otherwise active capture.
    }
  }

  @override
  void dispose() {
    _metricsTimer?.cancel();
    if (_running) {
      unawaited(_engine.stop().catchError((Object _) {}));
    }
    _engine.dispose();
    super.dispose();
  }

  String _metricText(String key, {String fallback = '—'}) {
    final value = _metrics[key];
    if (value == null) return fallback;
    if (value is num) return value.toStringAsFixed(1);
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final inputLevel = double.tryParse(_metricText('rmsDbfs')) ?? -120;
    final level = ((inputLevel + 60) / 60).clamp(0.0, 1.0).toDouble();
    final headsetMic = _metrics['wiredHeadsetMic'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auralis'),
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Text(
                'ANDROID AUDIO LAB',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      color: Colors.white54,
                    ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(
              'Hear less noise.',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'A research prototype for wired-headphone noise control.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                  ),
            ),
            const SizedBox(height: 22),
            Card(
              color: const Color(0xFF17242E),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.science_outlined, color: Color(0xFF64E6C2)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Prototype mode — no ANC yet',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'This build measures microphone input only. It does not yet generate anti-noise, so it will not cancel the sounds reaching your ears.',
                            style: TextStyle(color: Colors.white70, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _running ? Icons.graphic_eq : Icons.equalizer,
                          color: _running ? const Color(0xFF64E6C2) : Colors.white54,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _status,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (_busy)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Input level'),
                        Text('${_metricText('rmsDbfs')} dBFS'),
                      ],
                    ),
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: _running ? level : 0,
                        backgroundColor: Colors.white12,
                        color: const Color(0xFF64E6C2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _MetricRow(
                      label: 'Microphone route',
                      value: _running
                          ? (headsetMic ? 'Wired headset mic' : 'Phone / default mic')
                          : 'Not measured',
                    ),
                    const SizedBox(height: 10),
                    _MetricRow(
                      label: 'Capture buffer estimate',
                      value: _running ? '${_metricText('bufferMs')} ms' : '—',
                    ),
                    const SizedBox(height: 10),
                    _MetricRow(
                      label: 'Sample rate',
                      value: _running ? '${_metricText('sampleRate')} Hz' : '—',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _toggleEngine,
              icon: Icon(_running ? Icons.stop_rounded : Icons.mic_rounded),
              label: Text(_running ? 'Stop microphone test' : 'Start microphone test'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 17),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'For the next ANC milestone, test with the headset mic close to the ear and measure the complete input-to-output delay. Do not invert live audio before calibration.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                    height: 1.45,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
