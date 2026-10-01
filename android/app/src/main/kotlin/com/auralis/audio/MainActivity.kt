package com.auralis.audio

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.AudioManager
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.auralis.audio/engine"
        private const val REQUEST_RECORD_AUDIO = 7142
    }

    private val captureEngine by lazy { MicrophoneCaptureEngine(this) }
    private var pendingStartResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> startWithPermission(result)
                    "stop" -> {
                        pendingStartResult?.error("CANCELLED", "Audio start was cancelled", null)
                        pendingStartResult = null
                        captureEngine.stop()
                        result.success(null)
                    }
                    "getMetrics" -> result.success(captureEngine.metrics())
                    "isSupported" -> result.success(captureEngine.isSupported())
                    else -> result.notImplemented()
                }
            }
    }

    private fun startWithPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        ) {
            startCapture(result)
            return
        }
        if (pendingStartResult != null) {
            result.error("PERMISSION_PENDING", "Microphone permission request is already pending", null)
            return
        }
        pendingStartResult = result
        requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), REQUEST_RECORD_AUDIO)
    }

    private fun startCapture(result: MethodChannel.Result) {
        try {
            captureEngine.start()
            result.success(null)
        } catch (error: Exception) {
            result.error("AUDIO_START_FAILED", error.message ?: "Unable to start microphone capture", null)
        }
    }

    @Deprecated("Android permission callback required for the native MethodChannel flow")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_RECORD_AUDIO) return

        val result = pendingStartResult
        pendingStartResult = null
        if (result == null) return
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            startCapture(result)
        } else {
            result.error("MICROPHONE_PERMISSION_DENIED", "Microphone permission is required for the capture test", null)
        }
    }

    override fun onDestroy() {
        pendingStartResult?.error("ACTIVITY_DESTROYED", "Activity closed before audio capture started", null)
        pendingStartResult = null
        captureEngine.stop()
        super.onDestroy()
    }
}

/** A measurement-only input stage. It intentionally has no audio output or phase inversion. */
private class MicrophoneCaptureEngine(private val context: Context) {
    companion object {
        private const val SAMPLE_RATE_HZ = 48_000
        private const val BYTES_PER_SAMPLE = 2
        private const val MIN_DBFS = -120.0
    }

    @Volatile private var recording = false
    @Volatile private var rmsDbfs = MIN_DBFS
    @Volatile private var peakDbfs = MIN_DBFS
    @Volatile private var headsetMicSelected = false
    @Volatile private var captureBufferMs = 0.0

    private var audioRecord: AudioRecord? = null
    private var captureThread: Thread? = null
    private var actualSampleRateHz = SAMPLE_RATE_HZ

    @Synchronized
    fun isSupported(): Boolean {
        return AudioRecord.getMinBufferSize(
            SAMPLE_RATE_HZ,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        ) > 0
    }

    @Synchronized
    fun start() {
        if (recording) return
        val minBufferBytes = AudioRecord.getMinBufferSize(
            SAMPLE_RATE_HZ,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minBufferBytes <= 0) {
            throw IllegalStateException("This device does not support 48 kHz mono microphone capture")
        }

        val bufferBytes = max(minBufferBytes, SAMPLE_RATE_HZ / 10 * BYTES_PER_SAMPLE)
        val bufferFrames = bufferBytes / BYTES_PER_SAMPLE
        val recorder = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE_HZ,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferBytes,
        )
        if (recorder.state != AudioRecord.STATE_INITIALIZED) {
            recorder.release()
            throw IllegalStateException("Android could not initialize the microphone recorder")
        }

        headsetMicSelected = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val manager = applicationAudioManager()
            val headsetInput = manager?.getDevices(AudioManager.GET_DEVICES_INPUTS)
                ?.firstOrNull { device ->
                    device.type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                        (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                            device.type == AudioDeviceInfo.TYPE_USB_HEADSET)
                }
            if (headsetInput != null) {
                headsetMicSelected = recorder.setPreferredDevice(headsetInput)
            }
        }

        try {
            recorder.startRecording()
        } catch (error: Exception) {
            recorder.release()
            throw error
        }
        if (recorder.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
            recorder.release()
            throw IllegalStateException("Android did not enter microphone recording state")
        }

        audioRecord = recorder
        actualSampleRateHz = SAMPLE_RATE_HZ
        captureBufferMs = bufferFrames * 1000.0 / actualSampleRateHz
        rmsDbfs = MIN_DBFS
        peakDbfs = MIN_DBFS
        recording = true
        captureThread = Thread({ captureLoop(recorder, bufferFrames) }, "Auralis-MicCapture").apply {
            priority = Thread.MAX_PRIORITY
            start()
        }
    }

    private fun applicationAudioManager(): AudioManager? {
        return try {
            context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        } catch (_: Exception) {
            null
        }
    }

    private fun captureLoop(recorder: AudioRecord, bufferFrames: Int) {
        val samples = ShortArray(bufferFrames)
        while (recording) {
            val count = recorder.read(samples, 0, samples.size)
            if (count <= 0) {
                if (recording) {
                    rmsDbfs = MIN_DBFS
                    peakDbfs = MIN_DBFS
                    try {
                        Thread.sleep(10)
                    } catch (_: InterruptedException) {
                        Thread.currentThread().interrupt()
                        return
                    }
                }
                continue
            }

            var squareSum = 0.0
            var peak = 0
            for (index in 0 until count) {
                val sample = samples[index].toInt()
                val magnitude = if (sample == Short.MIN_VALUE.toInt()) 32768 else kotlin.math.abs(sample)
                squareSum += sample.toDouble() * sample.toDouble()
                if (magnitude > peak) peak = magnitude
            }
            val rms = sqrt(squareSum / count)
            rmsDbfs = if (rms <= 0.0) MIN_DBFS else max(MIN_DBFS, 20.0 * log10(rms / 32768.0))
            peakDbfs = if (peak <= 0) MIN_DBFS else max(MIN_DBFS, 20.0 * log10(peak / 32768.0))
        }
    }

    fun metrics(): Map<String, Any> {
        return mapOf(
            "capturing" to recording,
            "sampleRate" to actualSampleRateHz,
            "rmsDbfs" to rmsDbfs,
            "peakDbfs" to peakDbfs,
            "bufferMs" to captureBufferMs,
            "wiredHeadsetMic" to headsetMicSelected,
        )
    }

    @Synchronized
    fun stop() {
        if (!recording && audioRecord == null) return
        recording = false
        val recorder = audioRecord
        try {
            if (recorder?.recordingState == AudioRecord.RECORDSTATE_RECORDING) recorder.stop()
        } catch (_: IllegalStateException) {
            // The capture thread may already have been stopped by Android.
        }
        try {
            captureThread?.join(500)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        recorder?.release()
        audioRecord = null
        captureThread = null
        rmsDbfs = MIN_DBFS
        peakDbfs = MIN_DBFS
        headsetMicSelected = false
        captureBufferMs = 0.0
    }
}
