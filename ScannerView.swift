//
//  ScannerView.swift
//  GLTP-Conference-Administration-App
//
//  Created by 稲村 健太郎 on 2025/07/22.
//

// -----------------------------------------------------------------------------
//
// ScannerView.swift
// QRコードを読み取るカメラ画面です。（変更なし）
//
// -----------------------------------------------------------------------------
import SwiftUI
import AVFoundation
import UIKit

struct ScannerView: UIViewControllerRepresentable {
    
    @Binding var scannedCode: String?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(scannedCode: $scannedCode, presentationMode: presentationMode)
    }

    class Coordinator: NSObject, ScannerViewControllerDelegate {
        @Binding var scannedCode: String?
        var presentationMode: Binding<PresentationMode>

        init(scannedCode: Binding<String?>, presentationMode: Binding<PresentationMode>) {
            _scannedCode = scannedCode
            self.presentationMode = presentationMode
        }

        func didFind(barcode: String) {
            self.scannedCode = barcode
            self.presentationMode.wrappedValue.dismiss() // スキャナーを閉じる
        }

        func didFail(error: CameraError) {
            print("Scanning failed: \(error.localizedDescription)")
            self.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - UIKit part
protocol ScannerViewControllerDelegate: AnyObject {
    func didFind(barcode: String)
    func didFail(error: CameraError)
}

enum CameraError: Error {
    case invalidDeviceInput
    case invalidScannedValue
}

class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: ScannerViewControllerDelegate?
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCaptureSession()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if (captureSession?.isRunning == false) {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
        }
    }

    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            delegate?.didFail(error: .invalidDeviceInput)
            return
        }

        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            delegate?.didFail(error: .invalidDeviceInput)
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            // 読み取るコードの種類をQRコードに限定
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
                  let stringValue = readableObject.stringValue else { return }
            // 読み取り成功時にバイブレーション
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            delegate?.didFind(barcode: stringValue)
        }
    }
}
