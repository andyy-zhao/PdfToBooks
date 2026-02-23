import SwiftUI
import PDFKit
import AppKit

// Container that holds PDFView and a floating "Highlight" tooltip above text selection
final class PDFReaderContainerView: NSView {
    let pdfView = BookReaderPDFView()
    let highlightTooltip = NSView()
    let highlightButton = NSButton()
    weak var coordinator: PDFKitReaderRepresentable.Coordinator?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        highlightTooltip.wantsLayer = true
        highlightTooltip.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        highlightTooltip.layer?.cornerRadius = 6
        highlightTooltip.layer?.shadowOpacity = 0.2
        highlightTooltip.layer?.shadowRadius = 4
        highlightTooltip.layer?.shadowOffset = CGSize(width: 0, height: -1)
        highlightTooltip.isHidden = true
        
        highlightButton.title = "Highlight"
        highlightButton.bezelStyle = .rounded
        highlightButton.target = nil
        highlightButton.action = #selector(PDFKitReaderRepresentable.Coordinator.highlightFromTooltip(_:))
        highlightButton.translatesAutoresizingMaskIntoConstraints = false
        highlightTooltip.addSubview(highlightButton)
        
        NSLayoutConstraint.activate([
            highlightButton.topAnchor.constraint(equalTo: highlightTooltip.topAnchor, constant: 6),
            highlightButton.bottomAnchor.constraint(equalTo: highlightTooltip.bottomAnchor, constant: -6),
            highlightButton.leadingAnchor.constraint(equalTo: highlightTooltip.leadingAnchor, constant: 10),
            highlightButton.trailingAnchor.constraint(equalTo: highlightTooltip.trailingAnchor, constant: -10)
        ])
        
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        highlightTooltip.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pdfView)
        addSubview(highlightTooltip)
        
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(pdfView)
        super.mouseDown(with: event)
    }
    
    func showHighlightTooltip(at rect: CGRect) {
        let padding: CGFloat = 4
        let tooltipHeight: CGFloat = 36
        highlightTooltip.frame = CGRect(
            x: rect.midX - 50,
            y: rect.maxY + padding,
            width: 100,
            height: tooltipHeight
        )
        // Clamp to visible bounds
        var f = highlightTooltip.frame
        if f.minX < 0 { f.origin.x = 0 }
        if f.maxX > bounds.maxX { f.origin.x = bounds.maxX - f.width }
        if f.maxY > bounds.maxY { f.origin.y = bounds.maxY - f.height - padding }
        if f.minY < 0 { f.origin.y = rect.minY - f.height - padding }
        highlightTooltip.frame = f
        highlightTooltip.isHidden = false
    }
    
    func hideHighlightTooltip() {
        highlightTooltip.isHidden = true
    }
}

// Installs an NSEvent local monitor to block all scroll wheel events in the window (so PDFView's internal scroll view never receives them)
final class ScrollWheelBlockerView: NSView {
    private var monitor: Any?
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let _ = monitor { NSEvent.removeMonitor(monitor!) }
        monitor = nil
        guard let win = window else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak win] ev in
            guard let w = win, ev.window === w else { return ev }
            // Block only vertical scroll (mouse wheel); allow horizontal (two-finger swipe for next/prev page)
            if ev.scrollingDeltaY != 0 { return nil }
            return ev
        }
    }
    
    deinit {
        if let m = monitor { NSEvent.removeMonitor(m) }
    }
}

struct ScrollWheelBlockerRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> ScrollWheelBlockerView {
        ScrollWheelBlockerView()
    }
    func updateNSView(_ nsView: ScrollWheelBlockerView, context: Context) {}
}

// Custom PDFView that handles arrow key navigation, blocks vertical scrolling, and minimizes gap between pages
final class BookReaderPDFView: PDFView {
    override var acceptsFirstResponder: Bool { true }
    
    override func layout() {
        super.layout()
        reducePageGapInSubviews()
    }
    
    /// PDFKit clamps pageBreakMargins to ≥0, so we tweak internal subviews to reduce the gap
    private func reducePageGapInSubviews() {
        func recurse(_ view: NSView) {
            if let stack = view as? NSStackView {
                stack.spacing = 0
            }
            if let scroll = view as? NSScrollView {
                scroll.contentView.contentInsets = NSEdgeInsets(top: 0, left: -24, bottom: 0, right: -24)
            }
            for sub in view.subviews {
                recurse(sub)
            }
        }
        recurse(self)
    }
    
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123: // Left arrow - previous spread
            goToPreviousPage(nil)
        case 124: // Right arrow - next spread
            goToNextPage(nil)
        case 125, 126: // Down, Up - disabled (no vertical navigation)
            return
        default:
            super.keyDown(with: event)
        }
    }
    
    // Block only vertical scroll (mouse wheel); allow horizontal (two-finger swipe) for next/prev page
    override func scrollWheel(with event: NSEvent) {
        if event.scrollingDeltaY != 0 {
            return  // Ignore vertical
        }
        super.scrollWheel(with: event)  // Allow horizontal swipe
    }
}

struct PDFReaderView: View {
    let document: PDFDocument?
    @Binding var currentPage: Int
    @Binding var pdfViewRef: PDFView?
    var initialPage: Int?
    @Binding var goToPageIndex: Int?
    var onInitialPageApplied: (() -> Void)?
    var onAnnotationAdded: (() -> Void)?
    
    var body: some View {
        PDFKitReaderRepresentable(
            document: document,
            currentPage: $currentPage,
            pdfViewRef: $pdfViewRef,
            initialPage: initialPage,
            goToPageIndex: $goToPageIndex,
            onInitialPageApplied: onInitialPageApplied,
            onAnnotationAdded: onAnnotationAdded
        )
    }
}

struct PDFKitReaderRepresentable: NSViewRepresentable {
    let document: PDFDocument?
    @Binding var currentPage: Int
    @Binding var pdfViewRef: PDFView?
    var initialPage: Int?
    @Binding var goToPageIndex: Int?
    var onInitialPageApplied: (() -> Void)?
    var onAnnotationAdded: (() -> Void)?
    
    func makeNSView(context: Context) -> PDFReaderContainerView {
        let container = PDFReaderContainerView()
        let pdfView = container.pdfView
        
        pdfView.document = document
        pdfView.displayMode = .twoUp
        pdfView.displayDirection = .horizontal
        pdfView.autoScales = true
        pdfView.backgroundColor = .windowBackgroundColor
        pdfView.interpolationQuality = .high
        pdfView.pageBreakMargins = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        pdfView.pageShadowsEnabled = false
        
        context.coordinator.containerView = container
        context.coordinator.pdfView = pdfView
        context.coordinator.onAnnotationAdded = onAnnotationAdded
        context.coordinator.onInitialPageApplied = onInitialPageApplied
        context.coordinator.onPageChanged = { page in
            currentPage = page
        }
        container.coordinator = context.coordinator
        container.highlightButton.target = context.coordinator
        pdfViewRef = pdfView
        
        pdfView.delegate = context.coordinator
        DispatchQueue.main.async {
            container.window?.makeFirstResponder(pdfView)
        }
        pdfView.menu = context.coordinator.createContextMenu()
        
        if let pageIndex = initialPage, let page = document?.page(at: pageIndex) {
            pdfView.go(to: page)
            currentPage = pageIndex
            DispatchQueue.main.async { onInitialPageApplied?() }
        }
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionChanged(_:)),
            name: .PDFViewSelectionChanged,
            object: pdfView
        )
        
        return container
    }
    
    func updateNSView(_ container: PDFReaderContainerView, context: Context) {
        let pdfView = container.pdfView
        if pdfView.document !== document {
            pdfView.document = document
            if let pageIndex = initialPage, let page = document?.page(at: pageIndex) {
                pdfView.go(to: page)
                DispatchQueue.main.async { onInitialPageApplied?() }
            }
        }
        // Navigate when Highlights & Notes (or TOC) requests a page
        if let pageIndex = goToPageIndex,
           let page = document?.page(at: pageIndex) {
            pdfView.go(to: page)
            currentPage = pageIndex
            goToPageIndex = nil
        }
        pdfViewRef = pdfView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PDFViewDelegate {
        var parent: PDFKitReaderRepresentable
        weak var pdfView: PDFView?
        weak var containerView: PDFReaderContainerView?
        var onPageChanged: ((Int) -> Void)?
        var onAnnotationAdded: (() -> Void)?
        var onInitialPageApplied: (() -> Void)?
        
        init(_ parent: PDFKitReaderRepresentable) {
            self.parent = parent
        }
        
        @objc func selectionChanged(_ notification: Notification) {
            guard let view = pdfView, let container = containerView else { return }
            guard let selection = view.currentSelection, !selection.selectionsByLine().isEmpty else {
                container.hideHighlightTooltip()
                return
            }
            let selections = selection.selectionsByLine()
            guard let first = selections.first, let page = first.pages.first else { return }
            let pageBounds = first.bounds(for: page)
            let viewRect = view.convert(pageBounds, from: page)
            let containerRect = container.convert(viewRect, from: view)
            DispatchQueue.main.async {
                container.showHighlightTooltip(at: containerRect)
            }
        }
        
        @objc func highlightFromTooltip(_ sender: Any?) {
            highlightSelectedText(sender)
            containerView?.hideHighlightTooltip()
            pdfView?.setCurrentSelection(nil, animate: false)
        }
        
        @objc func pageChanged(_ notification: Notification) {
            guard let view = pdfView,
                  let page = view.currentPage,
                  let doc = view.document else { return }
            let pageIndex = doc.index(for: page)
            let leftPageIndex = (pageIndex / 2) * 2
            DispatchQueue.main.async { [weak self] in
                self?.onPageChanged?(leftPageIndex)
            }
        }
        
        func pdfViewParentViewController() -> NSViewController? { nil }
        
        func createContextMenu() -> NSMenu {
            let menu = NSMenu()
            
            let highlightItem = NSMenuItem(
                title: "Highlight",
                action: #selector(highlightSelectedText(_:)),
                keyEquivalent: ""
            )
            highlightItem.target = self
            menu.addItem(highlightItem)
            
            let removeHighlightItem = NSMenuItem(
                title: "Remove Highlight",
                action: #selector(removeHighlightFromSelection(_:)),
                keyEquivalent: ""
            )
            removeHighlightItem.target = self
            menu.addItem(removeHighlightItem)
            
            let noteItem = NSMenuItem(
                title: "Add Note",
                action: #selector(addNoteToSelection(_:)),
                keyEquivalent: ""
            )
            noteItem.target = self
            menu.addItem(noteItem)
            
            return menu
        }
        
        @objc func removeHighlightFromSelection(_ sender: Any?) {
            guard let pdfView = pdfView,
                  let selection = pdfView.currentSelection else { return }
            
            let selections = selection.selectionsByLine()
            for sel in selections {
                for page in sel.pages {
                    let bounds = sel.bounds(for: page)
                    let toRemove = page.annotations.filter { ann in
                        ann.type == "Highlight" && ann.bounds.intersects(bounds)
                    }
                    for ann in toRemove {
                        page.removeAnnotation(ann)
                    }
                }
            }
            DispatchQueue.main.async { [weak self] in
                self?.onAnnotationAdded?()
            }
        }
        
        @objc func highlightSelectedText(_ sender: Any?) {
            guard let pdfView = pdfView,
                  let selection = pdfView.currentSelection else { return }
            
            let selectedText = selection.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let selections = selection.selectionsByLine()
            // Group bounds by page so one highlight spanning multiple lines = one annotation per page
            var boundsByPage: [PDFPage: CGRect] = [:]
            for sel in selections {
                for page in sel.pages {
                    let rect = sel.bounds(for: page)
                    if let existing = boundsByPage[page] {
                        boundsByPage[page] = existing.union(rect)
                    } else {
                        boundsByPage[page] = rect
                    }
                }
            }
            for (page, unionRect) in boundsByPage {
                let highlight = PDFAnnotation(bounds: unionRect, forType: .highlight, withProperties: nil)
                highlight.color = NSColor.yellow.withAlphaComponent(0.4)
                highlight.contents = selectedText.isEmpty ? nil : selectedText
                page.addAnnotation(highlight)
            }
            DispatchQueue.main.async { [weak self] in
                self?.onAnnotationAdded?()
            }
        }
        
        @objc func addNoteToSelection(_ sender: Any?) {
            guard let pdfView = pdfView,
                  let selection = pdfView.currentSelection else { return }
            
            let selections = selection.selectionsByLine()
            for sel in selections {
                for page in sel.pages {
                    let bounds = sel.bounds(for: page)
                    let note = PDFAnnotation(bounds: bounds, forType: .text, withProperties: nil)
                    note.color = NSColor.yellow
                    note.contents = "Note"
                    page.addAnnotation(note)
                }
            }
            DispatchQueue.main.async { [weak self] in
                self?.onAnnotationAdded?()
            }
        }
    }
}

