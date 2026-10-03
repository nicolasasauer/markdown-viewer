package com.nicolas.markdown_viewer

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.FileOutputStream
import java.util.concurrent.Executors

/**
 * Bridges Android file handling to Flutter:
 *  - VIEW / EDIT / SEND intents (opening .md files from other apps)
 *  - Storage Access Framework pickers for "Open" and "Save as"
 *  - writing back to the opened content:// or file:// URI
 *  - opening links from the preview in another app (browser, mail, ...)
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private val io = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var pendingOpen: MethodChannel.Result? = null
    private var pendingCreate: MethodChannel.Result? = null
    private var pendingCreateContent: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialFile" -> readIntentAsync(intent) { result.success(it) }
                    "openDocument" -> openDocument(result)
                    "createDocument" -> createDocument(
                        call.argument<String>("name") ?: "Untitled.md",
                        call.argument<String>("content") ?: "",
                        result,
                    )
                    "saveFile" -> {
                        val uri = call.argument<String>("uri")
                        val content = call.argument<String>("content")
                        if (uri == null || content == null) {
                            result.error("bad_args", "uri and content are required", null)
                        } else {
                            io.execute {
                                try {
                                    writeUri(Uri.parse(uri), content)
                                    mainHandler.post { result.success(null) }
                                } catch (e: Exception) {
                                    mainHandler.post { result.error("save_failed", e.message ?: e.toString(), null) }
                                }
                            }
                        }
                    }
                    "openUrl" -> {
                        val url = call.argument<String>("url")
                        if (url == null) {
                            result.error("bad_args", "url is required", null)
                        } else {
                            try {
                                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                                result.success(true)
                            } catch (e: ActivityNotFoundException) {
                                result.success(false)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        readIntentAsync(intent) { file ->
            if (file != null) channel?.invokeMethod("onFileOpened", file)
        }
    }

    // ---- Intents ------------------------------------------------------------

    private fun readIntentAsync(intent: Intent?, callback: (Map<String, Any?>?) -> Unit) {
        io.execute {
            val file = try {
                readIntent(intent)
            } catch (e: Exception) {
                mapOf("error" to (e.message ?: e.toString()))
            }
            mainHandler.post { callback(file) }
        }
    }

    private fun readIntent(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_VIEW, Intent.ACTION_EDIT -> intent.data
            Intent.ACTION_SEND -> {
                val stream = streamExtra(intent)
                if (stream == null) {
                    val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return null
                    return mapOf("name" to "Shared text.md", "content" to text, "uri" to null)
                }
                stream
            }
            else -> null
        }
        return uri?.let { readUri(it) }
    }

    @Suppress("DEPRECATION")
    private fun streamExtra(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
        }

    // ---- Storage Access Framework -------------------------------------------

    private fun openDocument(result: MethodChannel.Result) {
        if (pendingOpen != null) {
            result.error("busy", "A file picker is already open", null)
            return
        }
        pendingOpen = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        startActivityForResult(intent, REQUEST_OPEN)
    }

    private fun createDocument(name: String, content: String, result: MethodChannel.Result) {
        if (pendingCreate != null) {
            result.error("busy", "A file picker is already open", null)
            return
        }
        pendingCreate = result
        pendingCreateContent = content
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "text/markdown"
            putExtra(Intent.EXTRA_TITLE, name)
        }
        startActivityForResult(intent, REQUEST_CREATE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        when (requestCode) {
            REQUEST_OPEN -> {
                val result = pendingOpen ?: return
                pendingOpen = null
                if (uri == null) {
                    result.success(null)
                    return
                }
                takePersistablePermission(uri, data!!.flags)
                io.execute {
                    val file = try {
                        readUri(uri)
                    } catch (e: Exception) {
                        mapOf("error" to (e.message ?: e.toString()))
                    }
                    mainHandler.post { result.success(file) }
                }
            }
            REQUEST_CREATE -> {
                val result = pendingCreate ?: return
                val content = pendingCreateContent ?: ""
                pendingCreate = null
                pendingCreateContent = null
                if (uri == null) {
                    result.success(null)
                    return
                }
                takePersistablePermission(uri, data!!.flags)
                io.execute {
                    try {
                        writeUri(uri, content)
                        val info = mapOf("name" to displayName(uri), "uri" to uri.toString())
                        mainHandler.post { result.success(info) }
                    } catch (e: Exception) {
                        mainHandler.post { result.error("save_failed", e.message ?: e.toString(), null) }
                    }
                }
            }
        }
    }

    private fun takePersistablePermission(uri: Uri, flags: Int) {
        val modeFlags = flags and
            (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        try {
            contentResolver.takePersistableUriPermission(uri, modeFlags)
        } catch (ignored: Exception) {
            // Not every provider offers persistable grants; the temporary grant still works.
        }
    }

    // ---- File I/O -----------------------------------------------------------

    private fun readUri(uri: Uri): Map<String, Any?> {
        val stream = contentResolver.openInputStream(uri)
            ?: throw IllegalStateException("Cannot open $uri")
        val text = stream.use { it.bufferedReader(Charsets.UTF_8).readText() }
        return mapOf(
            "name" to displayName(uri),
            "content" to text.removePrefix("﻿"),
            "uri" to uri.toString(),
        )
    }

    private fun writeUri(uri: Uri, content: String) {
        val out = if (uri.scheme == "file") {
            FileOutputStream(uri.path ?: throw IllegalArgumentException("Invalid file URI"))
        } else {
            contentResolver.openOutputStream(uri, "wt")
                ?: throw IllegalStateException("No output stream")
        }
        out.use { it.write(content.toByteArray(Charsets.UTF_8)) }
    }

    private fun displayName(uri: Uri): String {
        if (uri.scheme == "content") {
            try {
                contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                    ?.use { cursor ->
                        if (cursor.moveToFirst()) {
                            cursor.getString(0)?.let { return it }
                        }
                    }
            } catch (ignored: Exception) {
                // Fall through to the path-based name.
            }
        }
        return uri.lastPathSegment?.substringAfterLast('/') ?: "Document.md"
    }

    companion object {
        private const val CHANNEL = "markdown_viewer/file"
        private const val REQUEST_OPEN = 4101
        private const val REQUEST_CREATE = 4102
    }
}
