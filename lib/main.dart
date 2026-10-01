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
    return MaterialApp(
      title: 'Auralis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: Colors.cyan,
        scaffoldBackgroundColor: const Color(0xFF070B12),
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
  bool _running = false;
  String _status = 'Engine idle';

  Future<void> _toggleEngine() async {
    try {
      if (_running) {
        await _engine.stop();
        setState(() {
          _running = false;
          _status = 'Engine stopped';
        });
      } else {
        await _engine.start();
        setState(() {
          _running = true;
          _status = 'Audio engine running';
        });
      }
    } catch (error) {
      setState(() => _status = 'Engine error: $error');
    }
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auralis'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.graphic_eq, size: 88),
              const SizedBox(height: 24),
              Text(
                'Auralis Audio Engine',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Low-latency audio enhancement — foundation build',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Icon(
                        _running ? Icons.circle : Icons.circle_outlined,
                        color: _running ? Colors.greenAccent : Colors.white38,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_status)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _toggleEngine,
                icon: Icon(_running ? Icons.stop : Icons.play_arrow),
                label: Text(_running ? 'Stop Engine' : 'Start Engine'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
