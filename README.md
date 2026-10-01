# Auralis

Auralis is an experimental Android audio project built with Flutter and native Android audio processing.

## Goal

Explore whether wired headphones can be improved through software:

- low-latency audio processing
- equalization, filters and dynamics
- noise-analysis experiments
- adaptive-filter research
- experimental software ANC, only after safe device-specific calibration

Software alone cannot guarantee hardware-ANC performance. A generic wired headset often has no microphone at the ear to measure residual sound, and phone audio-routing latency can make uncalibrated anti-noise ineffective or increase the noise. Do not invert live microphone audio without measuring the full acoustic path and using a suitable reference/error-microphone setup.

## Current prototype

The Android app currently provides a **measurement-only microphone capture stage**. It requests microphone permission, prefers a wired-headset microphone when Android exposes one, and reports input level, sample rate and an estimated capture-buffer duration. It intentionally does not play microphone audio or generate anti-noise. The buffer figure is not an end-to-end or round-trip latency measurement.

## Architecture

Flutter UI
-> MethodChannel
-> Android AudioRecord capture and input metrics
-> (future) calibrated PCM/DSP pipeline
-> (future) Android audio output
-> wired headphones

## Build

The repository is designed to build through GitHub Actions without Android Studio installed locally. The workflow bootstraps the generated Android project and builds a release APK artifact.

## Roadmap

- [x] Flutter project bootstrap and native control bridge
- [x] Android microphone capture and live input metrics
- [x] Prefer a wired-headset microphone when available
- [ ] Measure true input-to-output / acoustic round-trip latency
- [ ] Add bounded-gain playback and a hard limiter
- [ ] Parametric EQ and safe filters
- [ ] Noise analysis and reduction experiments
- [ ] Adaptive filtering with a suitable reference/error signal
- [ ] Experimental FxLMS ANC only on calibrated, supported routes
- [ ] Device-specific validation and tuning

## Safety

This prototype captures microphone input but does not cancel environmental sound. Active cancellation can amplify noise when phase, timing or acoustic-path estimates are wrong. Any future playback path must include conservative gain limits, a hard limiter, route checks, a fast stop control, and device-specific calibration before ANC is enabled.
