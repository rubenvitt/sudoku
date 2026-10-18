import PencilKit
import Vision

struct RecognizedDigit: Sendable {
    let digit: Int
    let confidence: Float
}

protocol DigitRecognizer: Sendable {
    func recognize(_ drawing: PKDrawing) async -> RecognizedDigit?
}

/// Vision text recognition on the strokes of one cell, rendered black on a white square.
struct VisionDigitRecognizer: DigitRecognizer {
    @concurrent
    func recognize(_ drawing: PKDrawing) async -> RecognizedDigit? {
        guard let image = Self.render(drawing) else { return nil }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try? VNImageRequestHandler(cgImage: image).perform([request]) // a failed request is just "not recognized"
        guard let candidate = request.results?.first?.topCandidates(1).first,
              let digit = mapRecognized(candidate.string) else { return nil }
        return RecognizedDigit(digit: digit, confidence: candidate.confidence)
    }

    /// Scales the ink to fit a `side`-pixel square with a 20 % margin, independent of the on-screen ink colour and theme.
    static func render(_ drawing: PKDrawing, side: CGFloat = 128) -> CGImage? {
        let bounds = drawing.bounds
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let black = PKDrawing(strokes: drawing.strokes.map { stroke in
            var stroke = stroke
            stroke.ink = PKInk(.pen, color: .black)
            return stroke
        })
        let scale = side * 0.6 / max(bounds.width, bounds.height)
        var ink = UIImage()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            ink = black.image(from: bounds, scale: scale)
        }
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            ink.draw(in: CGRect(origin: CGPoint(x: (side - size.width) / 2, y: (side - size.height) / 2), size: size))
        }.cgImage
    }
}

/// Maps Vision's text for one handwritten character to a digit 1…9, folding common look-alikes.
func mapRecognized(_ text: String) -> Int? {
    let characters = text.filter { !$0.isWhitespace && !".,".contains($0) }
    guard characters.count == 1, let character = characters.first else { return nil }
    switch character {
    case "l", "I", "|", "!": return 1
    case "S", "s": return 5
    case "Z", "z": return 2
    case "g", "q": return 9
    case "B": return 8
    default:
        guard let digit = character.wholeNumberValue, (1...9).contains(digit) else { return nil }
        return digit
    }
}
