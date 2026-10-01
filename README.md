# Auralis

Auralis is an experimental Android audio engine built with Flutter and native Android audio processing.

## Goal

Make inexpensive wired headphones sound substantially better through software:

- low-latency audio processing
- equalization and filters
- dynamics processing
- noise reduction experiments
- adaptive DSP
- experimental software ANC research

Auralis does not claim that software alone can reproduce hardware ANC. The project will measure latency and device behavior before attempting adaptive cancellation.

## Architecture

Flutter UI
-> MethodChannel
-> Android audio engine
-> PCM/DSP pipeline
-> Android audio output
-> wired headphones

The first milestone is deliberately small: establish a buildable Android app and a native engine control bridge. Real-time PCM processing will be added incrementally.

## Build

The repository is designed to build through GitHub Actions, so development can be performed without Android Studio on the local device.

See .github/workflows/android.yml.

## Roadmap

- [x] Project bootstrap
- [x] Flutter/native engine bridge
- [ ] Native AudioRecord/AudioTrack pipeline
- [ ] Round-trip latency measurement
- [ ] Parametric EQ
- [ ] Filters and dynamics
- [ ] Noise analysis/reduction
- [ ] Adaptive filtering
- [ ] Experimental FxLMS ANC
- [ ] Device-specific tuning

## Safety

Audio processing can produce unexpectedly high output levels or unstable feedback. Auralis should always include conservative gain limits and a hard limiter before experimental cancellation features are enabled.
