package com.keeppixel.voyfy

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.TrafficStats
import android.net.VpnService
import android.os.Bundle
import android.os.Process
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val ANDROID_CHANNEL = "com.voyfy.vpn/android"
    private val ANDROID_DATA_CHANNEL = "com.voyfy.vpn/android_data"
    
    private var androidChannel: MethodChannel? = null
    private var androidDataChannel: MethodChannel? = null
    private var pendingVpnResult: MethodChannel.Result? = null
    private var pendingVpnConfig: String? = null
    
    // Store baseline values when VPN starts
    private var baselineRx: Long = 0
    private var baselineTx: Long = 0
    private var isVpnActive: Boolean = false
    
    companion object {
        const val VPN_REQUEST_CODE = 1001
        const val TAG = "MainActivity"
    }
    
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
                "startVpn" -> {
                    val config = call.argument<String>("config")
                    if (config != null) {
                        startVpnService(config, result)
                    } else {
                        result.error("NO_CONFIG", "No VPN config provided", null)
                    }
                }
                "stopVpn" -> {
                    stopVpnService(result)
                }
                "getVpnStatus" -> {
                    val status = getSharedPreferences("voyfy_vpn", Context.MODE_PRIVATE)
                        .getString("vpn_status", "disconnected")
                    result.success(status)
                }
                else -> result.notImplemented()
            }
        }
        
        // Data usage channel (for Dart to receive updates)
        androidDataChannel = MethodChannel(messenger, ANDROID_DATA_CHANNEL)
    }
    
    private fun startVpnService(config: String, result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            // VPN permission not granted yet, request it
            pendingVpnResult = result
            pendingVpnConfig = config
            startActivityForResult(intent, VPN_REQUEST_CODE)
        } else {
            // Permission already granted, start directly
            launchVpnService(config)
            result.success(true)
        }
    }
    
    private fun stopVpnService(result: MethodChannel.Result) {
        val intent = Intent(this, Hysteria2VpnService::class.java).apply {
            action = Hysteria2VpnService.ACTION_DISCONNECT
        }
        startService(intent)
        isVpnActive = false
        result.success(true)
    }
    
    private fun launchVpnService(config: String) {
        val intent = Intent(this, Hysteria2VpnService::class.java).apply {
            action = Hysteria2VpnService.ACTION_CONNECT
            putExtra(Hysteria2VpnService.EXTRA_CONFIG, config)
        }
        startService(intent)
        isVpnActive = true
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            val result = pendingVpnResult
            val config = pendingVpnConfig
            pendingVpnResult = null
            pendingVpnConfig = null
            if (resultCode == Activity.RESULT_OK) {
                // Permission granted, start VPN with stored config
                if (config != null) {
                    launchVpnService(config)
                    result?.success(true)
                } else {
                    result?.error("NO_CONFIG", "No VPN config available after permission grant", null)
                }
            } else {
                result?.error("VPN_PERMISSION_DENIED", "User denied VPN permission", null)
            }
        }
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
