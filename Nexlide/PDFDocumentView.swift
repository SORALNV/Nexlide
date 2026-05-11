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
