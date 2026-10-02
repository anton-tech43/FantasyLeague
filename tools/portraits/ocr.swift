// Reads the text in images with the system's Vision OCR. One line per image:
// "<path>\t<all recognised text, space-joined>". Used by import.py to read each
// sticker's name label, which is what names the player (the zip's file names
// have been wrong before; the label is drawn on the same image as the man).
// Usage: swift ocr.swift a.png b.png ...
import Foundation
import Vision
import AppKit

for path in CommandLine.arguments.dropFirst() {
    guard let image = NSImage(contentsOfFile: path),
          let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("\(path)\t"); continue
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    try? VNImageRequestHandler(cgImage: cg).perform([request])
    let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
    print("\(path)\t\(text)")
}
