package pl.escaperoom.escape_room

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Two tiny platform channels:
 *  - `pl.escaperoom/incoming`: text opened/shared from other apps (.md/.json/plain)
 *    is handed to Dart once via `takeText`.
 *  - `pl.escaperoom/share`: Android share sheet for text or a cached file
 *    (`shareText`, `shareFile`).
 *  - `pl.escaperoom/update`: in-app update – launch the package installer on a
 *    downloaded APK (`installApk`) or open a web page (`openUrl`).
 */
class MainActivity : FlutterActivity() {
    private var pendingText: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingText = extractText(intent)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INCOMING_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeText" -> {
                        val t = pendingText
                        pendingText = null
                        result.success(t)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "shareText" -> {
                            shareText(call.argument("text") ?: "", call.argument("subject"))
                            result.success(null)
                        }
                        "shareFile" -> {
                            shareFile(
                                call.argument("path") ?: "",
                                call.argument("mimeType") ?: "text/plain",
                                call.argument("subject"),
                            )
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("share_failed", e.message, null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "installApk" -> {
                            installApk(call.argument("path") ?: "")
                            result.success(true)
                        }
                        "openUrl" -> {
                            val url: String = call.argument("url") ?: ""
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("update_failed", e.message, null)
                }
            }
    }

    /** Hands a downloaded APK (inside cacheDir/updates) to the system installer. */
    private fun installApk(path: String) {
        val file = File(path)
        require(file.exists()) { "Plik nie istnieje: $path" }
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
        val install = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(install)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractText(intent)?.let { pendingText = it }
    }

    private fun shareText(text: String, subject: String?) {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
            if (subject != null) putExtra(Intent.EXTRA_SUBJECT, subject)
        }
        startActivity(Intent.createChooser(send, subject))
    }

    private fun shareFile(path: String, mimeType: String, subject: String?) {
        val file = File(path)
        require(file.exists()) { "Plik nie istnieje: $path" }
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            if (subject != null) putExtra(Intent.EXTRA_SUBJECT, subject)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(send, subject))
    }

    private fun extractText(intent: Intent?): String? {
        if (intent == null) return null
        return when (intent.action) {
            Intent.ACTION_SEND -> {
                intent.getStringExtra(Intent.EXTRA_TEXT)
                    ?: readUri(streamUri(intent))
            }
            Intent.ACTION_VIEW -> readUri(intent.data)
            else -> null
        }
    }

    @Suppress("DEPRECATION")
    private fun streamUri(intent: Intent): Uri? =
        if (android.os.Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }

    private fun readUri(uri: Uri?): String? {
        if (uri == null) return null
        return try {
            contentResolver.openInputStream(uri)?.use { stream ->
                val bytes = stream.readBytes()
                if (bytes.size > MAX_BYTES) null else String(bytes, Charsets.UTF_8)
            }
        } catch (_: Exception) {
            null
        }
    }

    companion object {
        private const val INCOMING_CHANNEL = "pl.escaperoom/incoming"
        private const val SHARE_CHANNEL = "pl.escaperoom/share"
        private const val UPDATE_CHANNEL = "pl.escaperoom/update"
        private const val MAX_BYTES = 2 * 1024 * 1024
    }
}
