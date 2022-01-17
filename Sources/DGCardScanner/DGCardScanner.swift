
import AVFoundation
import CoreImage
import UIKit
import Vision

public class DGCardScanner: UIViewController {
    public static var appearance = Appearance()
    
    // MARK: - Private Properties
    private let captureSession = AVCaptureSession()
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let preview = AVCaptureVideoPreviewLayer(session: self.captureSession)
        preview.videoGravity = .resizeAspect
        return preview
    }()

    private let device = AVCaptureDevice.default(for: .video)

    private var viewGuide: PartialTransparentView!

    private var creditCardNumber: String?
    private var creditCardName: String?
    private var creditCardDate: String?
    private var cardInformation: CardInformation?
    private var matchedCount = 0

    private let videoOutput = AVCaptureVideoDataOutput()
    
    private lazy var helperLabel: UILabel = {
        let view = UILabel()
        view.text = DGCardScanner.appearance.helperText
        view.textColor = .white
        return view
    }()

    // MARK: - Instance dependencies
    private let resultsHandler: (_ number: String, _ date: String, _ name: String) -> Void

    // MARK: - Initializers
    init(resultsHandler: @escaping (_ number: String, _ date: String, _ name: String) -> Void) {
        self.resultsHandler = resultsHandler
        super.init(nibName: nil, bundle: nil)
    }

    public class func getScanner(resultsHandler: @escaping (_ number: String, _ date: String, _ name: String) -> Void) -> UIViewController {
        DGCardScanner(resultsHandler: resultsHandler)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadView() {
        view = UIView()
    }

    deinit {
        stop()
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
        captureSession.startRunning()
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }

    // MARK: - Add Views
    private func setupCaptureSession() {
        addCameraInput()
        addPreviewLayer()
        addVideoOutput()
        addGuideView()
    }

    private func addCameraInput() {
        guard let device = device else { return }
        let cameraInput = try! AVCaptureDeviceInput(device: device)
        captureSession.addInput(cameraInput)
    }

    private func addPreviewLayer() {
        view.layer.addSublayer(previewLayer)
    }

    private func addVideoOutput() {
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as NSString: NSNumber(value: kCVPixelFormatType_32BGRA)] as [String: Any]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "my.image.handling.queue"))
        captureSession.addOutput(videoOutput)
        guard let connection = videoOutput.connection(with: AVMediaType.video),
            connection.isVideoOrientationSupported else {
            return
        }
        connection.videoOrientation = .portrait
    }

    private func addGuideView() {
        let widht = UIScreen.main.bounds.width - (UIScreen.main.bounds.width * 0.2)
        let height = widht - (widht * 0.45)
        let viewX = (UIScreen.main.bounds.width / 2) - (widht / 2)
        let viewY = (UIScreen.main.bounds.height / 2) - (height / 2) - 100

        viewGuide = PartialTransparentView(rectsArray: [CGRect(x: viewX, y: viewY, width: widht, height: height)])

        view.addSubview(viewGuide)
        viewGuide.translatesAutoresizingMaskIntoConstraints = false
        viewGuide.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0).isActive = true
        viewGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        viewGuide.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        viewGuide.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
        view.bringSubviewToFront(viewGuide)
        
        let bottomY = (UIScreen.main.bounds.height / 2) + (height / 2) - 100
        let labelHintBottomY = bottomY + 30
        
        view.addSubview(helperLabel)
        helperLabel.translatesAutoresizingMaskIntoConstraints = false
        helperLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        helperLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: labelHintBottomY).isActive = true
        
        
        view.backgroundColor = .black
    }


    // MARK: - Completed process
    @objc func scanCompleted(creditCardNumber: String, creditCardDate: String, creditCardName: String) {
        resultsHandler(creditCardNumber, creditCardDate, creditCardName)
        stop()
        DispatchQueue.main.async {
            self.dismiss(animated: true, completion: nil)
        }
        
    }

    private func stop() {
        captureSession.stopRunning()
    }

    // MARK: - Payment detection
    private func handleObservedPaymentCard(in frame: CVImageBuffer) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.extractPaymentCardData(frame: frame)
        }
    }

    private func extractPaymentCardData(frame: CVImageBuffer) {
        let ciImage = CIImage(cvImageBuffer: frame)
        let widht = UIScreen.main.bounds.width - (UIScreen.main.bounds.width * 0.2)
        let height = widht - (widht * 0.45)
        let viewX = (UIScreen.main.bounds.width / 2) - (widht / 2)
        let viewY = (UIScreen.main.bounds.height / 2) - (height / 2) - 100 + height

        let resizeFilter = CIFilter(name: "CILanczosScaleTransform")!

        // Desired output size
        let targetSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)

        // Compute scale and corrective aspect ratio
        let scale = targetSize.height / ciImage.extent.height
        let aspectRatio = targetSize.width / (ciImage.extent.width * scale)

        // Apply resizing
        resizeFilter.setValue(ciImage, forKey: kCIInputImageKey)
        resizeFilter.setValue(scale, forKey: kCIInputScaleKey)
        resizeFilter.setValue(aspectRatio, forKey: kCIInputAspectRatioKey)
        let outputImage = resizeFilter.outputImage

        let croppedImage = outputImage!.cropped(to: CGRect(x: viewX, y: viewY, width: widht, height: height))

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        let stillImageRequestHandler = VNImageRequestHandler(ciImage: croppedImage, options: [:])
        try? stillImageRequestHandler.perform([request])

        guard let texts = request.results, texts.count > 0 else {
            // no text detected
            return
        }

        let arrayLines = texts.flatMap({ $0.topCandidates(20).map({ $0.string }) })

        for line in arrayLines {
            let trimmed = line.replacingOccurrences(of: " ", with: "").lowercased()
            if trimmed.count >= 15 && trimmed.count <= 16 && trimmed.isOnlyNumbers {
                creditCardNumber = line
                continue
            }
            
            let last5Characters = String(trimmed.suffix(5))
            if last5Characters.isDate {
                creditCardDate = last5Characters
                continue
            }
            
            if trimmed.contains("card") && trimmed.isOnlyAlpha {
                if let cardName = parseCardName(line), cardName.isEmpty == false {
                    creditCardName = cardName
                    continue
                }
            }
            
            if let cardName = CARD.allCases.first(where: { trimmed.contains($0.rawValue.lowercased()) }).map({ $0.rawValue }) {
                creditCardName = cardName
            }
        }
        
        guard let creditCardName = self.creditCardName, let creditCardDate = self.creditCardDate, let creditCardNumber = self.creditCardNumber else { return }
        
        let cardInformation: CardInformation = .init(cardName: creditCardName, cardDate: creditCardDate, cardNumber: creditCardNumber)
        if self.cardInformation == cardInformation {
            self.matchedCount += 1
        } else {
            self.matchedCount = 0
        }
        
        self.cardInformation = cardInformation
        
        if self.matchedCount >= 4 {
            scanCompleted(creditCardNumber: creditCardNumber, creditCardDate: creditCardDate, creditCardName: creditCardName)
        }
    }
    
    private func parseCardName(_ cardName: String) -> String? {
        let cardName = cardName.uppercased()
        if let range = cardName.range(of: "CARD") {
            return String(cardName[..<range.lowerBound])
        }
        return nil
    }

    private func tapticFeedback() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension DGCardScanner: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            debugPrint("unable to get image from sample buffer")
            return
        }

        handleObservedPaymentCard(in: frame)
    }
}

// MARK: - Extensions
private extension String {
    var isOnlyAlpha: Bool {
        return !isEmpty && range(of: "[^a-zA-Z]", options: .regularExpression) == nil
    }

    var isOnlyNumbers: Bool {
        return !isEmpty && range(of: "[^0-9]", options: .regularExpression) == nil
    }

    // Date Pattern MM/YY or MM/YYYY
    var isDate: Bool {
        let arrayDate = components(separatedBy: "/")
        if arrayDate.count == 2 {
            if let month = Int(arrayDate[0]) {
                return month <= 12 && month >= 1
            }
        }
        return false
    }
}

// MARK: - Class PartialTransparentView
class PartialTransparentView: UIView {
    var rectsArray: [CGRect]?

    convenience init(rectsArray: [CGRect]) {
        self.init()

        self.rectsArray = rectsArray

        backgroundColor = UIColor.black.withAlphaComponent(0.6)
        isOpaque = false
    }

    override func draw(_ rect: CGRect) {
        backgroundColor?.setFill()
        UIRectFill(rect)

        guard let rectsArray = rectsArray else {
            return
        }

        for holeRect in rectsArray {
            let path = UIBezierPath(roundedRect: holeRect, cornerRadius: 10)

            let holeRectIntersection = rect.intersection(holeRect)

            UIRectFill(holeRectIntersection)

            UIColor.clear.setFill()
            UIGraphicsGetCurrentContext()?.setBlendMode(CGBlendMode.copy)
            path.fill()
        }
    }
}

extension DGCardScanner {
    public class Appearance {
        public var helperText = "카드를 가운데에 정렬시키세요."
    }
}

extension DGCardScanner {
    struct CardInformation: Equatable {
        let cardName: String
        let cardDate: String
        let cardNumber: String
    }
}

enum CARD: String, CaseIterable {
    case NH
    case Shinhan
    case KB
    case WOORI
    case KAKAOBANK
}
