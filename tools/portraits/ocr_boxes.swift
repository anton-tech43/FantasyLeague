// Every recognised text line in an image with its box, for sticker SHEETS:
// "<x>\t<y>\t<w>\t<h>\t<text>" in pixels, origin top-left. import_sheet.py
// finds each player's name label this way and cuts the player out above it.
// Usage: swift ocr_boxes.swift sheet.png
import Foundation
import Vision
import AppKit

guard CommandLine.arguments.count > 1,
      let image = NSImage(contentsOfFile: CommandLine.arguments[1]),
      let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { exit(1) }
let W = Double(cg.width), H = Double(cg.height)
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = false
try VNImageRequestHandler(cgImage: cg).perform([request])
for o in request.results ?? [] {
    guard let t = o.topCandidates(1).first?.string else { continue }
    let b = o.boundingBox  // normalised, origin bottom-left
    print(String(format: "%.0f\t%.0f\t%.0f\t%.0f\t", b.minX * W, (1 - b.maxY) * H, b.width * W, b.height * H) + t)
}
