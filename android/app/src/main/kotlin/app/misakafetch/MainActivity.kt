package app.misakafetch

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.content.Intent

class MainActivity : FlutterActivity() {
    private var imageSaver: AndroidImageSaver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        imageSaver = AndroidImageSaver(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    @Deprecated("Used by the platform document picker")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (imageSaver?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        imageSaver?.close()
        imageSaver = null
        super.onDestroy()
    }
}
