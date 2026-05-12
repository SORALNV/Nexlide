import PDFKit
import SwiftUI

struct PDFDocumentView: UIViewRepresentable {
    let document: PDFDocument
    let pageIndex: Int
    let interactionEnabled: Bool

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.backgroundColor = .black
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.autoScales = true
        pdfView.displaysPageBreaks = false
        pdfView.usePageViewController(false)
        pdfView.isUserInteractionEnabled = interactionEnabled
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document
        }

        if let page = document.page(at: pageIndex), pdfView.currentPage !== page {
            pdfView.go(to: page)
        }

        pdfView.autoScales = true
        pdfView.isUserInteractionEnabled = interactionEnabled
    }
}

struct PDFPagePreviewImage: View {
    let document: PDFDocument
    let pageIndex: Int
    let maxPixelDimension: CGFloat

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.black

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
        }
        .task(id: "\(ObjectIdentifier(document as AnyObject))-\(pageIndex)-\(Int(maxPixelDimension))") {
            image = renderPreview()
        }
    }

    private func renderPreview() -> UIImage? {
        guard let page = document.page(at: pageIndex) else { return nil }

        let bounds = page.bounds(for: .mediaBox)
        let dominantSide = max(bounds.width, bounds.height, 1)
        let scale = maxPixelDimension / dominantSide
        let size = CGSize(
            width: max(bounds.width * scale, 1),
            height: max(bounds.height * scale, 1)
        )

        return page.thumbnail(of: size, for: .mediaBox)
    }
}
