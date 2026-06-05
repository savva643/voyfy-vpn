package com.keeppixel.voyfy

import android.net.TrafficStats
import android.os.Bundle
import android.os.Process
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val ANDROID_CHANNEL = "com.voyfy.vpn/android"
    private val ANDROID_DATA_CHANNEL = "com.voyfy.vpn/android_data"
    
    private var androidChannel: MethodChannel? = null
    private var androidDataChannel: MethodChannel? = null
    
    // Store baseline values when VPN starts
    private var baselineRx: Long = 0
    private var baselineTx: Long = 0
    private var isVpnActive: Boolean = false
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        
        // Main Android channel
        androidChannel = MethodChannel(messenger, ANDROID_CHANNEL)
        androidChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getDataUsage" -> {
                    // Return data usage stats for VPN traffic
                    val stats = getVpnDataUsage()
                    result.success(stats)
                }
                "resetBaseline" -> {
                    // Reset baseline for new VPN session
                    resetDataBaseline()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        
        // Data usage channel (for Dart to receive updates)
        androidDataChannel = MethodChannel(messenger, ANDROID_DATA_CHANNEL)
    }
    
    private fun getVpnDataUsage(): Map<String, Long> {
        // Get current UID traffic stats
        val uid = Process.myUid()
        val currentRx = TrafficStats.getUidRxBytes(uid)
        val currentTx = TrafficStats.getUidTxBytes(uid)
        
        // If VPN is active, calculate relative to baseline
        return if (isVpnActive && currentRx > 0 && currentTx > 0) {
            mapOf(
                "bytesReceived" to (currentRx - baselineRx).coerceAtLeast(0),
                "bytesSent" to (currentTx - baselineTx).coerceAtLeast(0)
            )
        } else {
            // Return raw values if VPN not active
            mapOf(
                "bytesReceived" to currentRx,
                "bytesSent" to currentTx
            )
        }
    }
    
    private fun resetDataBaseline() {
        val uid = Process.myUid()
        baselineRx = TrafficStats.getUidRxBytes(uid)
        baselineTx = TrafficStats.getUidTxBytes(uid)
        isVpnActive = true
    }
    
    override fun onDestroy() {
        androidChannel?.setMethodCallHandler(null)
        androidDataChannel?.setMethodCallHandler(null)
        super.onDestroy()
    }
}
