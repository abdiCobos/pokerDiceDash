package io.github.abdicobos.pokerdicedash

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // LAN games: keep the process alive in the background (see KeepAliveService).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "io.github.abdicobos.pokerdicedash/keep_alive")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "start" -> {
                            askNotificationPermission()
                            val intent = Intent(this, KeepAliveService::class.java)
                                .putExtra(KeepAliveService.EXTRA_TEXT, call.argument<String>("text"))
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(true)
                        }
                        "stop" -> {
                            stopService(Intent(this, KeepAliveService::class.java))
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    // Never break the game over this: it only keeps it alive in the background.
                    result.error("KEEP_ALIVE", e.message, null)
                }
            }
    }

    /** Android 13+: without it the service still runs, only its notification is hidden. */
    private fun askNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4747)
        }
    }
}
