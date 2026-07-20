package com.redsky.skygmovil

import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "redsky/ocr",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "recognizeText" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("invalid_args", "Missing image path.", null)
                        return@setMethodCallHandler
                    }

                    val recognizer =
                        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

                    try {
                        val image = InputImage.fromFilePath(this, Uri.fromFile(java.io.File(path)))
                        recognizer
                            .process(image)
                            .addOnSuccessListener { visionText ->
                                result.success(
                                    mapOf(
                                        "text" to visionText.text,
                                    ),
                                )
                                recognizer.close()
                            }.addOnFailureListener { error ->
                                result.error("ocr_failed", error.message, null)
                                recognizer.close()
                            }
                    } catch (error: Exception) {
                        recognizer.close()
                        result.error("ocr_failed", error.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
