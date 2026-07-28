package com.crewcomm.cmc

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import java.util.concurrent.Executors
import kotlin.math.max

class NativePcmPlayer(private val context: Context) {
    private val executor = Executors.newSingleThreadExecutor()
    private var audioTrack: AudioTrack? = null
    private var sampleRate = 16000

    fun initialize(requestedSampleRate: Int, channels: Int) {
        if (audioTrack != null && sampleRate == requestedSampleRate) {
            return
        }
        releaseTrack()
        sampleRate = requestedSampleRate
        val channelMask = if (channels == 2) {
            AudioFormat.CHANNEL_OUT_STEREO
        } else {
            AudioFormat.CHANNEL_OUT_MONO
        }
        val minimumBuffer = AudioTrack.getMinBufferSize(
            sampleRate,
            channelMask,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        val bufferSize = max(minimumBuffer * 4, sampleRate / 2)
        audioTrack = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(channelMask)
                    .build(),
            )
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setBufferSizeInBytes(bufferSize)
            .build()
            .also { it.play() }
        val audioManager = context.getSystemService(AudioManager::class.java)
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        @Suppress("DEPRECATION")
        run {
            audioManager.isSpeakerphoneOn = true
        }
    }

    fun write(pcm: ByteArray, volume: Float) {
        val copy = pcm.copyOf()
        executor.execute {
            val track = audioTrack ?: return@execute
            track.setVolume(volume.coerceIn(0f, 1f))
            track.write(copy, 0, copy.size, AudioTrack.WRITE_BLOCKING)
        }
    }

    fun stop() {
        executor.execute {
            audioTrack?.pause()
            audioTrack?.flush()
            audioTrack?.play()
        }
    }

    fun dispose() {
        executor.execute {
            releaseTrack()
            val audioManager = context.getSystemService(AudioManager::class.java)
            audioManager.mode = AudioManager.MODE_NORMAL
        }
        executor.shutdown()
    }

    private fun releaseTrack() {
        audioTrack?.run {
            try {
                stop()
            } catch (_: IllegalStateException) {
            }
            release()
        }
        audioTrack = null
    }
}
