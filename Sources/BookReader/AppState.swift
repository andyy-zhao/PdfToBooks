import SwiftUI
@preconcurrency import PDFKit

private let sideCropFractionKey = "BookReader.sideCropFraction"
private let defaultSideCropFraction: Double = 0
/// Serial queue so only one save runs at a time; avoids overlapping writes and races with main-thread edits.
private let saveQueue = DispatchQueue(label: "BookReader.save", qos: .userInitiated)

/// Wrapper so we can pass the document into a @Sendable closure; saves are serialized so doc isn’t mutated during write.
private final class PDFDocumentSendableRef: @unchecked Sendable {
    let document: PDFDocument
    init(_ document: PDFDocument) { self.document = document }
}

@MainActor
class AppState: ObservableObject {
    @Published var document: PDFDocument?
    @Published var documentURL: URL?
    @Published var showOpenPanel = false
    @Published var showTableOfContents = false
    @Published var recentDocuments: [URL] = []
    @Published var libraryDocuments: [URL] = []
    @Published var initialPageToOpen: Int?
    @Published var sideCropFraction: Double = (UserDefaults.standard.object(forKey: sideCropFractionKey) as? Double) ?? defaultSideCropFraction {
        didSet {
            UserDefaults.standard.set(sideCropFraction, forKey: sideCropFractionKey)
            applyPageCropToCurrentDocument()
        }
    }
    
    init() {
        refreshRecentDocuments()
        refreshLibrary()
    }
    
    func refreshRecentDocuments() {
        recentDocuments = ReadingHistory.shared.recentDocuments
    }
    
    func refreshLibrary() {
        libraryDocuments = ReadingHistory.shared.libraryDocuments
    }
    
    func addToLibrary(_ url: URL) {
        ReadingHistory.shared.addToLibrary(url)
        refreshLibrary()
    }
    
    func removeFromLibrary(_ url: URL) {
        ReadingHistory.shared.removeFromLibrary(url)
        refreshLibrary()
    }
    
    func loadDocument(from url: URL) {
        if let doc = PDFDocument(url: url) {
            document = doc
            documentURL = url
            applyPageCropToCurrentDocument()
            ReadingHistory.shared.addRecentDocument(url)
            ReadingHistory.shared.addToLibrary(url)
            refreshRecentDocuments()
            refreshLibrary()
            initialPageToOpen = ReadingHistory.shared.getLastPage(for: url)
        }
    }
    
    func clearInitialPage() {
        initialPageToOpen = nil
    }
    
    func applyPageCropToCurrentDocument() {
        guard let doc = document else { return }
        applyPageCrop(document: doc, fraction: sideCropFraction)
    }
    
    func applyPageCrop(document doc: PDFDocument, fraction: Double) {
        let f = max(0, min(0.5, fraction))
        guard f > 0 else {
            resetPageCrop(document: doc)
            return
        }
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let media = page.bounds(for: .mediaBox)
            let dx = media.width * f
            let crop = media.insetBy(dx: dx, dy: 0)
            page.setBounds(crop, for: .cropBox)
        }
    }
    
    func resetPageCrop(document doc: PDFDocument) {
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let media = page.bounds(for: .mediaBox)
            page.setBounds(media, for: .cropBox)
        }
    }
    
    func closeDocument() {
        document = nil
        documentURL = nil
    }
    
    func saveDocument() {
        guard let doc = document, let url = documentURL else { return }
        let fraction = sideCropFraction
        resetPageCrop(document: doc)
        let ref = PDFDocumentSendableRef(doc)
        // Serial background queue: UI stays responsive; one save at a time so doc isn’t modified during write.
        // PDFDocument is not Sendable; we avoid races by not mutating doc on main until after this block’s main.async.
        saveQueue.async { [weak self] in
            ref.document.write(to: url)
            DispatchQueue.main.async { [weak self] in
                self?.applyPageCrop(document: ref.document, fraction: fraction)
            }
        }
    }
    
    func saveCurrentPage(_ page: Int) {
        guard let url = documentURL else { return }
        ReadingHistory.shared.setLastPage(page, for: url)
    }
}
