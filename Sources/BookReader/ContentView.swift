import SwiftUI
import PDFKit
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0
    @State private var showTOCPopover = false
    @State private var showHighlightsPopover = false
    @State private var showTrimMarginsPopover = false
    @State private var pdfView: PDFView?
    /// When set, PDFReaderView will navigate to this page (0-based) and clear it.
    @State private var goToPageIndex: Int?
    @State private var isBottomSliderHovered = false
    @State private var leftArrowHovered = false
    @State private var rightArrowHovered = false
    @State private var isTopBarHovered = false
    @State private var highlightsRefreshID = 0
    
    var body: some View {
        Group {
            if appState.document != nil {
                mainReadingView
            } else {
                welcomeView
            }
        }
        .background(TitleBarDoubleClickMonitor())  // Listens for double-click in title bar (traffic lights) only; does not block content
        .sheet(isPresented: $appState.showOpenPanel) {
            OpenDocumentView { url in
                appState.loadDocument(from: url)
                appState.showOpenPanel = false
            } onCancel: {
                appState.showOpenPanel = false
            }
        }
    }
    
    private var welcomeView: some View {
        VStack(spacing: 24) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange.opacity(0.8), .pink.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Book Reader")
                .font(.system(size: 28, weight: .semibold))
            
            Text("Add PDFs to your library, then open to read")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            
            Button {
                appState.showOpenPanel = true
            } label: {
                Label("Add PDF", systemImage: "plus.circle.fill")
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            
            LibrarySectionView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { appState.refreshLibrary() }
        .onDrop(of: [.fileURL, .pdf], isTargeted: nil) { providers in
            _ = providers.first?.loadObject(ofClass: URL.self) { url, _ in
                if let url = url, url.pathExtension.lowercased() == "pdf" {
                    DispatchQueue.main.async { appState.loadDocument(from: url) }
                }
            }
            return true
        }
    }
    
    private var mainReadingView: some View {
        VStack(spacing: 0) {
            // Top toolbar - fixed above PDF so it never overlaps content
            topToolbar
            
            // PDF + overlays fill the rest
            ZStack(alignment: .topLeading) {
                PDFReaderView(
                    document: appState.document,
                    currentPage: $currentPage,
                    pdfViewRef: $pdfView,
                    initialPage: appState.initialPageToOpen,
                    goToPageIndex: $goToPageIndex,
                    onInitialPageApplied: { appState.clearInitialPage() },
                    onAnnotationAdded: { appState.saveDocument() }
                )
                
                // Side hover zones: previous/next arrows pop up when hovering over left/right edges
                HStack(spacing: 0) {
                    sideArrowZone(isLeft: true)
                    Spacer()
                    sideArrowZone(isLeft: false)
                }
                .allowsHitTesting(true)
                
                // Bottom strip: page indicator + slider (offset pushes it a bit lower toward window bottom)
                VStack(spacing: 0) {
                    Spacer()
                    bottomPageIndicator
                    bottomPageSliderStrip
                }
                .offset(y: 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(ScrollWheelBlockerRepresentable().allowsHitTesting(false))
        .overlay(ArrowKeyMonitorRepresentable(
            onPrevious: {
                goToPageIndex = max(0, currentPage - 2)
            },
            onNext: {
                let pageCount = appState.document?.pageCount ?? 1
                let lastLeft = pageCount >= 2 ? ((pageCount - 1) / 2) * 2 : 0
                goToPageIndex = min(currentPage + 2, lastLeft)
            }
        ).allowsHitTesting(false))
        .onChange(of: currentPage) { _, newPage in
            appState.saveCurrentPage(newPage)
        }
    }
    
    private var topToolbar: some View {
        HStack(spacing: 0) {
            // Back — left edge (fixed dark color so visible on white PDF in dark mode)
            Button {
                appState.saveCurrentPage(currentPage)
                appState.closeDocument()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.pdfOverlayPrimary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Book title — centered; fixed dark color so visible on white PDF in dark mode
            if let url = appState.documentURL {
                Text(url.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 11, weight: .regular))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(Color.pdfOverlayPrimary)
                    .frame(maxWidth: .infinity)
            } else {
                Color.clear.frame(maxWidth: .infinity)
            }
            
            // 3-dots menu — right edge (like Buy in Apple Books)
            Menu {
                Button {
                    showTOCPopover = true
                } label: {
                    Label("Table of Contents", systemImage: "list.bullet")
                }
                Button {
                    showHighlightsPopover = true
                } label: {
                    Label("Highlights & Notes", systemImage: "highlighter")
                }
                Button {
                    showTrimMarginsPopover = true
                } label: {
                    Label("Trim side margins…", systemImage: "crop")
                }
                Divider()
                Button {
                    appState.showOpenPanel = true
                } label: {
                    Label("Open Another PDF", systemImage: "folder")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13))
                    .foregroundColor(Color.pdfOverlaySecondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24, height: 24)
            .popover(isPresented: $showTOCPopover, arrowEdge: .bottom) {
                TableOfContentsView(
                    document: appState.document,
                    onSelectPage: { pageIndex in
                        showTOCPopover = false
                        DispatchQueue.main.async { goToPageIndex = pageIndex }
                    }
                )
            }
            .popover(isPresented: $showTrimMarginsPopover, arrowEdge: .bottom) {
                trimMarginsPopoverContent
            }
            .popover(isPresented: $showHighlightsPopover, arrowEdge: .bottom) {
                HighlightsNotesView(
                    document: appState.document,
                    refreshID: highlightsRefreshID,
                    onSelectPage: { pageIndex in
                        showHighlightsPopover = false
                        DispatchQueue.main.async { goToPageIndex = pageIndex }
                    },
                    onDelete: { items in
                        guard let doc = appState.document else { return }
                        for (pageIndex, annotation) in items {
                            doc.page(at: pageIndex)?.removeAnnotation(annotation)
                        }
                        appState.saveDocument()
                        highlightsRefreshID += 1
                    }
                )
                .frame(width: 320, height: 400)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(
            Color(nsColor: .windowBackgroundColor)
                .opacity(isTopBarHovered ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: isTopBarHovered)
        )
        .onHover { isTopBarHovered = $0 }
    }
    
    private var trimMarginsPopoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trim side margins")
                .font(.headline)
            Text("Crop the same amount from the left and right of each page to reduce white space. Your PDF file is not modified when saving.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("None")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: Binding(
                    get: { appState.sideCropFraction },
                    set: { appState.sideCropFraction = $0 }
                ), in: 0...0.5, step: 0.02)
                Text("Max")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text("\(Int(round(appState.sideCropFraction * 100)))% from each side")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(width: 260)
    }
    
    /// Left or right edge hover zone: shows previous/next arrow on hover, click navigates
    @ViewBuilder
    private func sideArrowZone(isLeft: Bool) -> some View {
        let hovered = isLeft ? leftArrowHovered : rightArrowHovered
        let pageCount = appState.document?.pageCount ?? 1
        let lastLeftPage = pageCount >= 2 ? ((pageCount - 1) / 2) * 2 : 0
        ZStack {
            // Hover zone only (full side) — no tap, just shows/hides the arrow
            Color.clear
                .frame(width: 80)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .onHover { over in
                    if isLeft { leftArrowHovered = over }
                    else { rightArrowHovered = over }
                }
            // Arrow icon — tap only on the icon triggers next/prev (fixed dark so visible on white PDF in dark mode)
            Image(systemName: isLeft ? "chevron.left" : "chevron.right")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(Color.pdfOverlaySecondary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.pdfOverlayTrack))
                .contentShape(Circle())
                .opacity(hovered ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: hovered)
                .allowsHitTesting(hovered)
                .onTapGesture(count: 1) {
                    if isLeft {
                        goToPageIndex = max(0, currentPage - 2)
                    } else {
                        goToPageIndex = min(currentPage + 2, lastLeftPage)
                    }
                    DispatchQueue.main.async {
                        pdfView?.window?.makeFirstResponder(pdfView)
                    }
                }
        }
        .frame(width: 80)
        .frame(maxHeight: .infinity)
        .padding(isLeft ? .leading : .trailing, 8)
    }
    
    private var bottomPageIndicator: some View {
        HStack {
            Spacer()
            if let doc = appState.document {
                let booksPageCount = (doc.pageCount + 1) / 2
                let currentBooksPage = (currentPage / 2) + 1
                Text("Page \(currentBooksPage) of \(booksPageCount)")
                    .font(.system(size: 12))
                    .foregroundColor(Color.pdfOverlaySecondary)
            }
            Spacer()
        }
        .padding(.bottom, 16)
    }
    
    /// Full-width horizontal page bar (Apple Books style): one tick per "books page" (spread)
    private var bottomPageSliderStrip: some View {
        let pageCount = appState.document?.pageCount ?? 1
        let booksPageCount = max(1, (pageCount + 1) / 2)
        let maxBooksPageIndex = booksPageCount - 1
        return AppleBooksStylePageBar(
            pageIndex: Binding(
                get: { currentPage / 2 },
                set: { goToPageIndex = min(max(0, $0) * 2, pageCount - 1) }
            ),
            maxPageIndex: maxBooksPageIndex,
            isVisible: isBottomSliderHovered
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .contentShape(Rectangle())
        .onHover { isBottomSliderHovered = $0 }
    }
}

// MARK: - Apple Books–style horizontal page bar (thin track + pill thumb)
// Uses fixed dark colors so the bar stays visible on white PDF in both light and dark mode.
private struct AppleBooksStylePageBar: View {
    @Binding var pageIndex: Int
    let maxPageIndex: Int
    let isVisible: Bool
    
    @State private var dragIndex: Int? = nil
    
    private let trackHeight: CGFloat = 4
    private let thumbHeight: CGFloat = 10
    private let thumbMinWidth: CGFloat = 24
    
    private var displayedIndex: Int {
        if let d = dragIndex { return d }
        return pageIndex
    }
    
    private var trackColor: Color { Color.pdfOverlayTrack }
    private var thumbColor: Color { Color.pdfOverlayThumb }
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(trackColor)
                    .frame(height: trackHeight)
                    .frame(maxWidth: .infinity)
                
                if maxPageIndex > 0 {
                    let fraction = CGFloat(displayedIndex) / CGFloat(maxPageIndex)
                    let thumbWidth = max(thumbMinWidth, w / CGFloat(maxPageIndex + 1))
                    let range = w - thumbWidth
                    let x = range * fraction
                    RoundedRectangle(cornerRadius: thumbHeight / 2)
                        .fill(thumbColor)
                        .frame(width: thumbWidth, height: thumbHeight)
                        .offset(x: x)
                }
            }
            .frame(height: thumbHeight)
            .frame(maxWidth: .infinity)
            .opacity(isVisible ? 1 : 0)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard maxPageIndex > 0, w > 0 else { return }
                        let fraction = value.location.x / w
                        let newIndex = min(max(0, Int(round(fraction * CGFloat(maxPageIndex)))), maxPageIndex)
                        dragIndex = newIndex
                    }
                    .onEnded { _ in
                        if let idx = dragIndex {
                            pageIndex = idx
                            dragIndex = nil
                        }
                    }
            )
            .onTapGesture { location in
                guard maxPageIndex > 0, w > 0 else { return }
                let fraction = location.x / w
                let newIndex = min(max(0, Int(round(fraction * CGFloat(maxPageIndex)))), maxPageIndex)
                pageIndex = newIndex
            }
        }
        .frame(height: 32)
    }
}

// MARK: - Arrow key monitor (so left/right always change page regardless of first responder)
private final class ArrowKeyMonitorCoordinator {
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
}

private final class ArrowKeyMonitorView: NSView {
    weak var coordinator: ArrowKeyMonitorCoordinator?
    private var monitor: Any?
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
        guard let win = window, let coord = coordinator else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak win, weak coord] ev in
            guard let w = win, ev.window === w else { return ev }
            switch ev.keyCode {
            case 123: coord?.onPrevious?(); return nil
            case 124: coord?.onNext?(); return nil
            default: return ev
            }
        }
    }
    
    deinit {
        if let m = monitor { NSEvent.removeMonitor(m) }
    }
}

private struct ArrowKeyMonitorRepresentable: NSViewRepresentable {
    var onPrevious: () -> Void
    var onNext: () -> Void
    
    func makeCoordinator() -> ArrowKeyMonitorCoordinator {
        let c = ArrowKeyMonitorCoordinator()
        c.onPrevious = onPrevious
        c.onNext = onNext
        return c
    }
    
    func makeNSView(context: Context) -> ArrowKeyMonitorView {
        let v = ArrowKeyMonitorView()
        v.coordinator = context.coordinator
        return v
    }
    
    func updateNSView(_ nsView: ArrowKeyMonitorView, context: Context) {
        context.coordinator.onPrevious = onPrevious
        context.coordinator.onNext = onNext
    }
}

// MARK: - Library Section (welcome screen)
private struct LibrarySectionView: View {
    @EnvironmentObject var appState: AppState
    @State private var urlToRemoveFromLibrary: URL?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Library")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            
            if appState.libraryDocuments.isEmpty {
                Text("No PDFs in library yet. Tap \"Add PDF\" or drop a file here.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(appState.libraryDocuments, id: \.path) { url in
                            HStack(spacing: 8) {
                                Button {
                                    appState.loadDocument(from: url)
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.orange)
                                        Text(url.deletingPathExtension().lastPathComponent)
                                            .font(.system(size: 13))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .foregroundColor(.primary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                Button {
                                    urlToRemoveFromLibrary = url
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
        .frame(maxWidth: 360)
        .padding(.top, 16)
        .confirmationDialog("Remove from Library?", isPresented: Binding(
            get: { urlToRemoveFromLibrary != nil },
            set: { if !$0 { urlToRemoveFromLibrary = nil } }
        )) {
            Button("Remove from Library", role: .destructive) {
                if let url = urlToRemoveFromLibrary {
                    appState.removeFromLibrary(url)
                    urlToRemoveFromLibrary = nil
                }
            }
            Button("Cancel", role: .cancel) {
                urlToRemoveFromLibrary = nil
            }
        } message: {
            if let url = urlToRemoveFromLibrary {
                Text("\"\(url.deletingPathExtension().lastPathComponent)\" will be removed from your library. The file will not be deleted from your computer.")
            } else {
                Text("The file will not be deleted from your computer.")
            }
        }
    }
}

// MARK: - Open Document View
struct OpenDocumentView: View {
    let onSelect: (URL) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Choose a PDF")
                .font(.headline)
            
            Button("Select PDF File") {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.allowedContentTypes = [.pdf]
                panel.title = "Choose a PDF"
                panel.message = "Select a PDF book or textbook to open"
                
                if panel.runModal() == .OK, let url = panel.url {
                    onSelect(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            
            Button("Cancel") {
                onCancel()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(40)
        .frame(width: 300)
    }
}

// MARK: - Fixed colors for overlay UI on PDF (visible on white in both light and dark mode)
private extension Color {
    static var pdfOverlayPrimary: Color { Color(white: 0.2) }
    static var pdfOverlaySecondary: Color { Color(white: 0.45) }
    static var pdfOverlayTrack: Color { Color(white: 0, opacity: 0.12) }
    static var pdfOverlayThumb: Color { Color(white: 0, opacity: 0.4) }
}
