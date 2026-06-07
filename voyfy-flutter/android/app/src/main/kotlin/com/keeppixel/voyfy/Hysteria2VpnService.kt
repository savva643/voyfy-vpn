package com.keeppixel.voyfy

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.LocalSocket
import android.net.LocalSocketAddress
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class Hysteria2VpnService : VpnService() {
    companion object {
        const val ACTION_CONNECT = "com.keeppixel.voyfy.CONNECT"
        const val ACTION_DISCONNECT = "com.keeppixel.voyfy.DISCONNECT"
        const val EXTRA_CONFIG = "config"
        const val NOTIFICATION_CHANNEL_ID = "voyfy_vpn_channel"
        const val NOTIFICATION_ID = 1
        const val TAG = "Hysteria2VpnService"
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var hysteria2Process: Process? = null
    private var tun2socksProcess: Process? = null
    private val executor: ExecutorService = Executors.newFixedThreadPool(2)

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                val config = intent.getStringExtra(EXTRA_CONFIG)
                if (config != null) {
                    startVpn(config)
                } else {
                    Log.e(TAG, "No config provided for VPN connection")
                    stopSelf()
                }
            }
            ACTION_DISCONNECT -> {
                stopVpn()
                stopSelf()
            }
            else -> {
                // If service is restarted by system, stop it
                stopVpn()
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun startVpn(config: String) {
        Log.i(TAG, "Starting Hysteria2 VPN...")

        // Start foreground service with notification
        startForeground(NOTIFICATION_ID, createNotification("VoyFy VPN", "Connecting..."))

        // Write config to file
        val filesDir = filesDir
        val configFile = File(filesDir, "hysteria2_config.yaml")
        try {
            FileOutputStream(configFile).use { it.write(config.toByteArray()) }
        } catch (e: IOException) {
            Log.e(TAG, "Failed to write config file", e)
            updateNotification("Failed to start VPN")
            return
        }

        // Find binaries (Flutter downloader saves them in app_flutter/bin/)
        val hysteria2Path = findHysteria2Binary()
        val tun2socksPath = findTun2socksBinary()

        if (hysteria2Path == null) {
            Log.e(TAG, "Hysteria2 binary not found in any known location")
            updateNotification("Hysteria2 binary not found")
            return
        }
        val hysteria2Binary = File(hysteria2Path)
        Log.i(TAG, "Using hysteria2 binary at: $hysteria2Path")
        
        if (tun2socksPath != null) {
            Log.i(TAG, "Using tun2socks binary at: $tun2socksPath")
        }

        // Binaries are packaged as .so in jniLibs and extracted to nativeLibraryDir by Android
        // nativeLibraryDir allows execution on all Android versions, no need to copy or chmod

        // Establish TUN interface
        val builder = Builder()
            .setSession("VoyfyVPN")
            .addAddress("172.19.0.1", 30)
            .addDnsServer("8.8.8.8")
            .addDnsServer("8.8.4.4")
            .addRoute("0.0.0.0", 0)
            .setMtu(1500)

        // Exclude our own app to prevent routing loops
        // Hysteria2's outbound traffic will bypass the VPN TUN
        try {
            builder.addDisallowedApplication(packageName)
        } catch (e: Exception) {
            Log.w(TAG, "Could not add disallowed application", e)
        }

        vpnInterface = builder.establish()
        if (vpnInterface == null) {
            Log.e(TAG, "Failed to establish VPN interface")
            updateNotification("Failed to establish VPN")
            return
        }

        Log.i(TAG, "VPN TUN interface established, fd=${vpnInterface!!.fd}")

        // Start Hysteria2 with SOCKS5 inbound
        startHysteria2(hysteria2Binary, configFile)

        // Start tun2socks if available
        if (tun2socksPath != null) {
            startTun2socks(File(tun2socksPath))
        } else {
            Log.w(TAG, "tun2socks binary not found, TUN bridging will not work")
            // Try alternative: use native bridge or just hysteria2 TUN mode
        }

        updateNotification("VoyFy VPN is connected")

        // Send status back to Flutter via broadcast or shared preference
        sendVpnStatus("connected")
    }

    private fun startHysteria2(binary: File, configFile: File) {
        executor.execute {
            try {
                val processBuilder = ProcessBuilder(
                    binary.absolutePath,
                    "-c", configFile.absolutePath
                )
                processBuilder.redirectErrorStream(true)
                processBuilder.directory(filesDir)
                
                // Set up environment
                val env = processBuilder.environment()
                env["PATH"] = filesDir.absolutePath + ":/system/bin:/vendor/bin"

                hysteria2Process = processBuilder.start()
                
                // Log output
                hysteria2Process!!.inputStream.bufferedReader().use { reader ->
                    var line: String?
                    while (reader.readLine().also { line = it } != null) {
                        Log.d(TAG, "[hysteria2] $line")
                    }
                }
                
                val exitCode = hysteria2Process!!.waitFor()
                Log.i(TAG, "Hysteria2 process exited with code $exitCode")
                
                // If process exits unexpectedly, stop VPN
                if (vpnInterface != null) {
                    sendVpnStatus("disconnected")
                    stopVpn()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Hysteria2 process error", e)
                sendVpnStatus("error")
            }
        }
    }

    private fun startTun2socks(binary: File) {
        executor.execute {
            try {
                val sockName = "tun2socks.sock"
                val sockPath = File(filesDir, sockName)
                sockPath.delete() // clean up old socket

                // badvpn-tun2socks arguments (shadowsocks-android fork supports --sock-path)
                val processBuilder = ProcessBuilder(
                    binary.absolutePath,
                    "--netif-ipaddr", "172.19.0.2",
                    "--netif-netmask", "255.255.255.252",
                    "--socks-server-addr", "127.0.0.1:1080",
                    "--tunmtu", "1500",
                    "--loglevel", "notice",
                    "--enable-udprelay",
                    "--sock-path", sockName
                )
                processBuilder.redirectErrorStream(true)
                processBuilder.directory(filesDir)

                tun2socksProcess = processBuilder.start()

                // Send TUN fd via Unix socket (shadowsocks-android tun2socks expects fd over socket)
                sendFd()

                tun2socksProcess!!.inputStream.bufferedReader().use { reader ->
                    var line: String?
                    while (reader.readLine().also { line = it } != null) {
                        Log.d(TAG, "[tun2socks] $line")
                    }
                }

                val exitCode = tun2socksProcess!!.waitFor()
                Log.i(TAG, "tun2socks process exited with code $exitCode")
            } catch (e: Exception) {
                Log.e(TAG, "tun2socks process error", e)
            }
        }
    }

    private fun sendFd() {
        val sockPath = File(filesDir, "tun2socks.sock").absolutePath
        var tries = 0
        while (tries < 10) {
            try {
                Thread.sleep(200)
                LocalSocket().use { localSocket ->
                    localSocket.connect(LocalSocketAddress(sockPath, LocalSocketAddress.Namespace.FILESYSTEM))
                    val fd = vpnInterface!!.fileDescriptor
                    localSocket.setFileDescriptorsForSend(arrayOf(fd))
                    localSocket.outputStream.write(42)
                    localSocket.outputStream.flush()
                }
                Log.i(TAG, "Sent TUN fd to tun2socks successfully")
                return
            } catch (e: Exception) {
                Log.d(TAG, "sendFd attempt $tries failed: ${e.message}")
                tries++
            }
        }
        Log.e(TAG, "Failed to send TUN fd to tun2socks after $tries attempts")
    }

    private fun stopVpn() {
        Log.i(TAG, "Stopping Hysteria2 VPN...")

        // Kill processes
        hysteria2Process?.let {
            try {
                it.destroy()
                if (!it.waitFor(3, java.util.concurrent.TimeUnit.SECONDS)) {
                    it.destroyForcibly()
                } else {
                    // Process exited normally
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error stopping hysteria2", e)
            }
        }
        hysteria2Process = null

        tun2socksProcess?.let {
            try {
                it.destroy()
                if (!it.waitFor(3, java.util.concurrent.TimeUnit.SECONDS)) {
                    it.destroyForcibly()
                } else {
                    // Process exited normally
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error stopping tun2socks", e)
            }
        }
        tun2socksProcess = null

        // Close TUN interface
        try {
            vpnInterface?.close()
        } catch (e: Exception) {
            Log.w(TAG, "Error closing VPN interface", e)
        }
        vpnInterface = null

        updateNotification("VoyFy VPN is disconnected")
        sendVpnStatus("disconnected")
    }

    override fun onDestroy() {
        stopVpn()
        executor.shutdown()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "VoyFy VPN",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "VoyFy VPN connection status"
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(title: String, text: String): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_view)  // Default icon
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun updateNotification(text: String) {
        val notification = createNotification("VoyFy VPN", text)
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun sendVpnStatus(status: String) {
        // Store status in shared preferences for Flutter to read
        getSharedPreferences("voyfy_vpn", Context.MODE_PRIVATE)
            .edit()
            .putString("vpn_status", status)
            .apply()
    }

    // Find hysteria2 binary - first check nativeLibraryDir (.so from jniLibs), then fallback to downloaded files
    private fun findHysteria2Binary(): String? {
        // Android extracts .so files from jniLibs to nativeLibraryDir, and this dir allows exec on all versions
        val nativeLibDir = File(applicationInfo.nativeLibraryDir)
        val nativeLib = File(nativeLibDir, "libhysteria2.so")
        if (nativeLib.exists()) {
            Log.i(TAG, "Found hysteria2 binary in nativeLibraryDir: ${nativeLib.absolutePath}")
            return nativeLib.absolutePath
        }

        // Fallback: Flutter downloader paths (for debug builds without jniLibs)
        val flutterDir = applicationContext.getDir("flutter", Context.MODE_PRIVATE)
        val binDir = File(flutterDir, "bin")
        
        val arch = when {
            Build.SUPPORTED_ABIS.any { it.contains("arm64") } -> "arm64"
            Build.SUPPORTED_ABIS.any { it.contains("armeabi") } -> "arm"
            Build.SUPPORTED_ABIS.any { it.contains("x86_64") } -> "amd64"
            else -> "arm64"
        }
        
        val possiblePaths = listOf(
            File(binDir, "hysteria2-android-$arch").absolutePath,
            File(binDir, "hysteria2").absolutePath,
            File(File(filesDir, "bin"), "hysteria2").absolutePath,
            File(File(filesDir, "bin"), "hysteria2-android-$arch").absolutePath,
            File(filesDir, "hysteria2").absolutePath,
            File(filesDir, "hysteria2-android-$arch").absolutePath,
        )
        
        for (path in possiblePaths) {
            if (File(path).exists()) {
                Log.i(TAG, "Found hysteria2 binary at: $path")
                return path
            }
        }
        
        binDir.listFiles()?.forEach { file ->
            if (file.name.startsWith("hysteria2") && file.isFile) {
                Log.i(TAG, "Found hysteria2 binary (search): ${file.absolutePath}")
                return file.absolutePath
            }
        }
        
        File(filesDir, "bin").listFiles()?.forEach { file ->
            if (file.name.startsWith("hysteria2") && file.isFile) {
                Log.i(TAG, "Found hysteria2 binary (files/bin): ${file.absolutePath}")
                return file.absolutePath
            }
        }
        
        Log.w(TAG, "hysteria2 binary not found. Searched nativeLibraryDir and: $possiblePaths")
        return null
    }

    // Find tun2socks binary - first check nativeLibraryDir (.so from jniLibs), then fallback to downloaded files
    private fun findTun2socksBinary(): String? {
        // Android extracts .so files from jniLibs to nativeLibraryDir, and this dir allows exec on all versions
        val nativeLibDir = File(applicationInfo.nativeLibraryDir)
        val nativeLib = File(nativeLibDir, "libtun2socks.so")
        if (nativeLib.exists()) {
            Log.i(TAG, "Found tun2socks binary in nativeLibraryDir: ${nativeLib.absolutePath}")
            return nativeLib.absolutePath
        }

        // Fallback: Flutter downloader paths (for debug builds without jniLibs)
        val flutterDir = applicationContext.getDir("flutter", Context.MODE_PRIVATE)
        val binDir = File(flutterDir, "bin")
        
        val arch = when {
            Build.SUPPORTED_ABIS.any { it.contains("arm64") } -> "arm64"
            Build.SUPPORTED_ABIS.any { it.contains("armeabi") } -> "arm"
            Build.SUPPORTED_ABIS.any { it.contains("x86_64") } -> "amd64"
            else -> "arm64"
        }
        
        val possiblePaths = listOf(
            File(binDir, "tun2socks").absolutePath,
            File(binDir, "tun2socks-android-$arch").absolutePath,
            File(File(filesDir, "bin"), "tun2socks").absolutePath,
            File(File(filesDir, "bin"), "tun2socks-android-$arch").absolutePath,
            File(filesDir, "tun2socks").absolutePath,
            File(filesDir, "tun2socks-android-$arch").absolutePath,
        )
        
        for (path in possiblePaths) {
            if (File(path).exists()) {
                Log.i(TAG, "Found tun2socks binary at: $path")
                return path
            }
        }
        
        binDir.listFiles()?.forEach { file ->
            if (file.name.startsWith("tun2socks") && file.isFile) {
                Log.i(TAG, "Found tun2socks binary (search): ${file.absolutePath}")
                return file.absolutePath
            }
        }
        
        File(filesDir, "bin").listFiles()?.forEach { file ->
            if (file.name.startsWith("tun2socks") && file.isFile) {
                Log.i(TAG, "Found tun2socks binary (files/bin): ${file.absolutePath}")
                return file.absolutePath
            }
        }
        
        Log.w(TAG, "tun2socks binary not found")
        return null
    }

}
