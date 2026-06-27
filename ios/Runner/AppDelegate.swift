import Flutter
import ImageIO
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var ocrChannel: FlutterMethodChannel?
  private var registeredMessengerID: ObjectIdentifier?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    NSLog("[iOS OCR] AppDelegate iniciado")
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      NSLog("[iOS OCR] rootViewController disponible durante didFinishLaunchingWithOptions")
      registerOcrChannel(
        with: controller.binaryMessenger,
        source: "didFinishLaunchingWithOptions.rootViewController"
      )
    } else {
      NSLog("[iOS OCR] rootViewController es NIL durante didFinishLaunchingWithOptions")
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    registerOcrChannel(
      with: engineBridge.applicationRegistrar.messenger(),
      source: "didInitializeImplicitFlutterEngine"
    )
  }

  private func registerOcrChannel(with binaryMessenger: FlutterBinaryMessenger, source: String) {
    let messengerID = ObjectIdentifier(binaryMessenger as AnyObject)
    if registeredMessengerID == messengerID {
      NSLog("[iOS OCR] MethodChannel redsky/ocr ya registrado source=%@", source)
      return
    }

    let channel = FlutterMethodChannel(name: "redsky/ocr", binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { [unowned self] call, result in
      NSLog("[iOS OCR] Metodo recibido: %@", call.method)

      switch call.method {
      case "recognizeText":
        guard
          let arguments = call.arguments as? [String: Any],
          let imagePath = arguments["path"] as? String
        else {
          NSLog("[iOS OCR] invalid arguments: %@", String(describing: call.arguments))
          result(
            FlutterError(
              code: "invalid_args",
              message: "Missing image path.",
              details: nil
            )
          )
          return
        }

        recognizeText(at: imagePath, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    ocrChannel = channel
    registeredMessengerID = messengerID
    NSLog("[iOS OCR] MethodChannel redsky/ocr registered successfully source=%@", source)
  }

  private func recognizeText(at rawPath: String, result: @escaping FlutterResult) {
    NSLog("[iOS OCR] recognizeText rawPath=%@", rawPath)

    guard let imageURL = resolvedImageURL(from: rawPath) else {
      NSLog("[iOS OCR] invalid path after normalization rawPath=%@", rawPath)
      result(
        FlutterError(
          code: "invalid_args",
          message: "Missing image path.",
          details: nil
        )
      )
      return
    }

    let imagePath = imageURL.path
    NSLog("[iOS OCR] normalizedPath=%@", imagePath)

    guard FileManager.default.fileExists(atPath: imagePath) else {
      NSLog("[iOS OCR] file not found path=%@", imagePath)
      result(
        FlutterError(
          code: "ocr_failed",
          message: "Image file does not exist.",
          details: imagePath
        )
      )
      return
    }

    guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
      NSLog("[iOS OCR] could not create CGImageSource path=%@", imagePath)
      result(
        FlutterError(
          code: "ocr_failed",
          message: "Could not load image from path.",
          details: imagePath
        )
      )
      return
    }

    guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
      NSLog("[iOS OCR] could not create CGImage from source path=%@", imagePath)
      result(
        FlutterError(
          code: "ocr_failed",
          message: "Could not load image from path.",
          details: imagePath
        )
      )
      return
    }

    let imageProperties =
      CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
    let metadataOrientation =
      imageProperties?[kCGImagePropertyOrientation] as? UInt32
    let orientation =
      metadataOrientation.flatMap(CGImagePropertyOrientation.init(rawValue:)) ?? .up

    NSLog(
      "[iOS OCR] loaded image pixels=%ldx%ld orientation=%ld",
      cgImage.width,
      cgImage.height,
      orientation.rawValue
    )

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

      let observations = (request.results as? [VNRecognizedTextObservation] ?? [])
        .sorted(by: Self.readingOrderSort)
      let recognizedText = observations
        .compactMap { observation in
          observation.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { $0.isEmpty == false }
        .joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      let preview = String(recognizedText.prefix(500))

      NSLog(
        "[iOS OCR] Vision success path=%@ observations=%ld textLength=%ld",
        imagePath,
        observations.count,
        recognizedText.count
      )
      NSLog("[iOS OCR] Vision text preview=%@", preview)

      DispatchQueue.main.async {
        result(["text": recognizedText])
      }
    }

    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    request.recognitionLanguages = ["es-MX", "es", "en-US"]
    if #available(iOS 16.0, *) {
      request.automaticallyDetectsLanguage = true
    }

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

  private func resolvedImageURL(from rawPath: String) -> URL? {
    let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false else { return nil }

    let decoded = trimmed.removingPercentEncoding ?? trimmed
    let candidateURL: URL

    if decoded.hasPrefix("file://"), let fileURL = URL(string: decoded), fileURL.isFileURL {
      candidateURL = fileURL
    } else {
      candidateURL = URL(fileURLWithPath: (decoded as NSString).expandingTildeInPath)
    }

    return candidateURL.standardizedFileURL
  }

  private static func readingOrderSort(
    lhs: VNRecognizedTextObservation,
    rhs: VNRecognizedTextObservation
  ) -> Bool {
    let leftMidY = lhs.boundingBox.midY
    let rightMidY = rhs.boundingBox.midY
    let rowTolerance: CGFloat = 0.025

    if abs(leftMidY - rightMidY) > rowTolerance {
      return leftMidY > rightMidY
    }

    if abs(lhs.boundingBox.minX - rhs.boundingBox.minX) > 0.001 {
      return lhs.boundingBox.minX < rhs.boundingBox.minX
    }

    return lhs.boundingBox.width > rhs.boundingBox.width
  }
}
