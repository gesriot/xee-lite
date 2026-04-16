import AppKit
import Foundation

enum PrintScalingMode: String, CaseIterable, Identifiable {
    case fit
    case fill

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .fit:
            return "Fit Entire Image"
        case .fill:
            return "Fill Entire Page"
        }
    }

    var detail: String {
        switch self {
        case .fit:
            return "Preserves the full image inside the printable page area."
        case .fill:
            return "Fills the printable page area and may crop the image edges."
        }
    }
}

enum ImagePrinter {
    @MainActor
    static func printImage(
        _ image: NSImage,
        title: String,
        window: NSWindow?,
        scalingMode: PrintScalingMode
    ) {
        let printInfo = NSPrintInfo.shared.copy() as? NSPrintInfo ?? NSPrintInfo.shared
        printInfo.horizontalPagination = .automatic
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = true

        let printableView = PrintableImageView(
            image: image,
            printInfo: printInfo,
            scalingMode: scalingMode
        )

        let operation = NSPrintOperation(view: printableView, printInfo: printInfo)
        operation.jobTitle = title
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true

        if let window {
            operation.runModal(
                for: window,
                delegate: nil as AnyObject?,
                didRun: nil,
                contextInfo: nil
            )
        } else {
            _ = operation.run()
        }
    }
}

private final class PrintableImageView: NSView {
    let image: NSImage
    let scalingMode: PrintScalingMode
    let printInfo: NSPrintInfo

    init(image: NSImage, printInfo: NSPrintInfo, scalingMode: PrintScalingMode) {
        self.image = image
        self.printInfo = printInfo
        self.scalingMode = scalingMode

        let paperSize = printInfo.paperSize
        super.init(frame: NSRect(origin: .zero, size: paperSize))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool {
        true
    }

    override func knowsPageRange(_ range: NSRangePointer) -> Bool {
        range.pointee = NSRange(location: 1, length: 1)
        return true
    }

    override func rectForPage(_ page: Int) -> NSRect {
        bounds
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        bounds.fill()

        let printableRect = printInfo.imageablePageBounds
        let destinationRect = resolvedDestinationRect(in: printableRect)

        if scalingMode == .fill {
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: printableRect).addClip()
            image.draw(in: destinationRect)
            NSGraphicsContext.restoreGraphicsState()
        } else {
            image.draw(in: destinationRect)
        }
    }

    private func resolvedDestinationRect(in printableRect: CGRect) -> CGRect {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else {
            return printableRect
        }

        let widthRatio = printableRect.width / imageSize.width
        let heightRatio = printableRect.height / imageSize.height
        let scale = scalingMode == .fill ? max(widthRatio, heightRatio) : min(widthRatio, heightRatio)

        let scaledSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )

        return CGRect(
            x: printableRect.midX - scaledSize.width / 2,
            y: printableRect.midY - scaledSize.height / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
    }
}
