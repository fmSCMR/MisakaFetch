package app.misakafetch

import android.app.Activity
import android.content.ContentResolver
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.DocumentsContract
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.concurrent.Executors

/** Only writes new, app-owned media; never reads the user's existing photos. */
class AndroidImageSaver(private val activity: Activity, messenger: BinaryMessenger) {
    private val resolver = activity.applicationContext.contentResolver
    private val channel = MethodChannel(messenger, "misakafetch/image_save")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pending: PendingSave? = null
    private var closed = false

    private data class PendingSave(
        val bytes: ByteArray, val mimeType: String, val filename: String,
        val result: MethodChannel.Result,
    )

    init { channel.setMethodCallHandler(::handle) }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "saveImage") { result.notImplemented(); return }
        if (closed || pending != null) {
            result.error("save_busy", "A save is already pending", null); return
        }
        val bytes = call.argument<ByteArray>("bytes")
        val mimeType = call.argument<String>("mimeType")
        val filename = call.argument<String>("filename")
        // Bound the bridge payload and never allow a path through DISPLAY_NAME.
        if (bytes == null || bytes.isEmpty() || bytes.size > 20 * 1024 * 1024 ||
            mimeType !in setOf("image/jpeg", "image/png", "image/webp", "image/gif") ||
            filename.isNullOrBlank() || filename.length > 220 ||
            filename.any { it == '/' || it == '\\' || it.code < 32 } ||
            filename == "." || filename == "..") {
            result.error("invalid_image", "Invalid image payload", null); return
        }
        val save = PendingSave(bytes, mimeType!!, filename, result)
        pending = save
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            runWrite(save) { saveToMediaStore(save) }
        } else {
            // API 24–28: system SAF picker grants write access only to the chosen document.
            try {
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = save.mimeType
                    putExtra(Intent.EXTRA_TITLE, save.filename)
                }
                activity.startActivityForResult(intent, DOCUMENT_REQUEST)
            } catch (error: Exception) {
                pending = null
                logFailure(error)
                result.error("save_failed", "Document picker unavailable", null)
            }
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != DOCUMENT_REQUEST) return false
        val save = pending ?: return true
        if (resultCode != Activity.RESULT_OK) {
            pending = null
            save.result.success(null)
            return true
        }
        val uri = data?.data
        if (uri == null || uri.scheme != ContentResolver.SCHEME_CONTENT) {
            pending = null
            save.result.error("save_failed", "Missing document URI", null)
            return true
        }
        runWrite(save) {
            try {
                writeBytes(uri, save.bytes)
            } catch (error: Exception) {
                // ACTION_CREATE_DOCUMENT creates a new document and never overwrites
                // an existing user file. Remove the incomplete new document if supported.
                try { DocumentsContract.deleteDocument(resolver, uri) }
                catch (cleanupError: Exception) { logFailure(cleanupError) }
                throw error
            }
            "系统选择的位置（${save.filename}）"
        }
        return true
    }

    private fun runWrite(save: PendingSave, write: () -> String) {
        worker.execute {
            try {
                val location = write()
                main.post {
                    if (!closed) {
                        pending = null
                        save.result.success(location)
                    }
                }
            } catch (error: Exception) {
                logFailure(error)
                main.post {
                    if (!closed) {
                        pending = null
                        save.result.error("save_failed", "Cannot save original image", null)
                    }
                }
            }
        }
    }

    @android.annotation.TargetApi(Build.VERSION_CODES.Q)
    private fun saveToMediaStore(save: PendingSave): String {
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, save.filename)
            put(MediaStore.Images.Media.MIME_TYPE, save.mimeType)
            put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/MisakaFetch")
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val uri = resolver.insert(
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY), values
        ) ?: throw IOException("MediaStore insert failed")
        try {
            writeBytes(uri, save.bytes)
            val published = ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }
            if (resolver.update(uri, published, null, null) != 1) {
                throw IOException("MediaStore publish failed")
            }
            // The provider may rename duplicate DISPLAY_NAMEs. Report the folder,
            // not a guessed filesystem path or an internal content:// URI.
            return "相册 / Pictures/MisakaFetch"
        } catch (error: Exception) {
            try { resolver.delete(uri, null, null) }
            catch (cleanupError: Exception) { logFailure(cleanupError) }
            throw error
        }
    }

    private fun writeBytes(uri: Uri, bytes: ByteArray) {
        val stream = resolver.openOutputStream(uri, "w")
            ?: throw IOException("Cannot open output stream")
        stream.use { it.write(bytes); it.flush() }
    }

    private fun logFailure(error: Exception) {
        // Avoid URI/input logs and keep technical failures out of release UI.
        if (activity.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE != 0) {
            Log.e("MisakaFetch", "Original image save failed", error)
        }
    }

    fun close() {
        closed = true
        channel.setMethodCallHandler(null)
        pending = null
        // Let an in-progress write finish and publish/clean up its MediaStore entry.
        worker.shutdown()
    }

    private companion object { const val DOCUMENT_REQUEST = 4207 }
}
