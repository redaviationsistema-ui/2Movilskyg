import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let didLaunch = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "redsky/ocr",
        binaryMessenger: controller.binaryMessenger
      )

      channel.setMethodCallHandler { [weak self] call, result in
        guard let self else { return }

        switch call.method {
        case "recognizeText":
          guard
            let arguments = call.arguments as? [String: Any],
            let imagePath = arguments["path"] as? String,
            imagePath.isEmpty == false
          else {
            result(
              FlutterError(
                code: "invalid_args",
                message: "Missing image path.",
                details: nil
              )
            )
            return
          }

          self.recognizeText(at: imagePath, result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return didLaunch
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func recognizeText(at imagePath: String, result: @escaping FlutterResult) {
    NSLog("[iOS OCR] recognizeText path=%@", imagePath)

    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: imagePath) else {
      NSLog("[iOS OCR] file not found: %@", imagePath)
      result(
        FlutterError(
          code: "file_not_found",
          message: "Image file does not exist.",
          details: imagePath
        )
      )
      return
    }

    guard let uiImage = UIImage(contentsOfFile: imagePath) else {
      NSLog("[iOS OCR] could not load UIImage from path: %@", imagePath)
      result(
        FlutterError(
          code: "ocr_failed",
          message: "Could not load image from path.",
          details: imagePath
        )
      )
      return
    }

    NSLog("[iOS OCR] loaded UIImage size=%fx%f orientation=%ld", uiImage.size.width, uiImage.size.height, uiImage.imageOrientation.rawValue)

    guard let cgImage = uiImage.cgImage else {
      NSLog("[iOS OCR] could not get cgImage from UIImage")
      result(
        FlutterError(
          code: "ocr_failed",
          message: "Could not convert UIImage to CGImage.",
          details: nil
        )
      )
      return
    }

    let request = VNRecognizeTextRequest { request, error in
      if let error = error {
        NSLog("[iOS OCR] Vision failed error=%@", error.localizedDescription)
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "ocr_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
        return
      }

      let observations = request.results as? [VNRecognizedTextObservation] ?? []
      let recognizedText = observations
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)

      NSLog(
        "[iOS OCR] Vision success path=%@ observations=%ld textLength=%ld",
        imagePath,
        observations.count,
        recognizedText.count
      )

      DispatchQueue.main.async {
        result(["text": recognizedText])
      }
    }

    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["es", "es-MX", "es-419", "en-US"]

    let orientation = CGImagePropertyOrientation(uiImage.imageOrientation)
    NSLog("[iOS OCR] using orientation=%ld", orientation.rawValue)

    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try handler.perform([request])
      } catch {
        NSLog("[iOS OCR] Handler failed error=%@", error.localizedDescription)
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "ocr_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }
  }
}

private extension CGImagePropertyOrientation {
  init(_ uiOrientation: UIImage.Orientation) {
    switch uiOrientation {
    case .up: self = .up
    case .down: self = .down
    case .left: self = .left
    case .right: self = .right
    case .upMirrored: self = .upMirrored
    case .downMirrored: self = .downMirrored
    case .leftMirrored: self = .leftMirrored
    case .rightMirrored: self = .rightMirrored
    @unknown default:
      self = .up
    }
  }
}
