import SwiftUI
import PDFKit

struct AnnotationItem: Identifiable {
    let id = UUID()
    let annotation: PDFAnnotation
    let pageIndex: Int
    let text: String
    let type: AnnotationType
    
    enum AnnotationType {
        case highlight
        case note
    }
}

/// One logical highlight (single or spanning multiple pages) = one row
struct HighlightGroup: Identifiable {
    let id = UUID()
    let text: String
    let firstPageIndex: Int
    let lastPageIndex: Int
    let annotations: [(pageIndex: Int, annotation: PDFAnnotation)]
    
    /// Books page (1-based): 2 PDF pages = 1 books page
    var pageLabel: String {
        let firstBooksPage = (firstPageIndex / 2) + 1
        let lastBooksPage = (lastPageIndex / 2) + 1
        if firstPageIndex == lastPageIndex {
            return "Page \(firstBooksPage)"
        }
        return "Pages \(firstBooksPage)–\(lastBooksPage)"
    }
}

struct HighlightsNotesView: View {
    let document: PDFDocument?
    var refreshID: Int = 0
    var onSelectPage: ((Int) -> Void)?
    var onDelete: (([(pageIndex: Int, annotation: PDFAnnotation)]) -> Void)?
    
    @State private var showDeleteConfirm = false
    @State private var itemsToDelete: [(pageIndex: Int, annotation: PDFAnnotation)]?
    
    private var highlightGroups: [HighlightGroup] {
        guard let document = document else { return [] }
        var list: [(pageIndex: Int, annotation: PDFAnnotation, text: String)] = []
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            for annotation in page.annotations where annotation.type == "Highlight" {
                let text: String
                if let sel = page.selection(for: annotation.bounds),
                   let str = sel.string, !str.isEmpty {
                    text = str.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    text = annotation.contents ?? "Highlighted text"
                }
                list.append((pageIndex, annotation, text))
            }
        }
        list.sort { $0.pageIndex < $1.pageIndex }
        var groups: [HighlightGroup] = []
        var i = 0
        while i < list.count {
            let text = list[i].text
            var anns: [(Int, PDFAnnotation)] = [(list[i].pageIndex, list[i].annotation)]
            i += 1
            while i < list.count && list[i].pageIndex == anns.last!.0 + 1 && list[i].text == text {
                anns.append((list[i].pageIndex, list[i].annotation))
                i += 1
            }
            groups.append(HighlightGroup(
                text: text,
                firstPageIndex: anns[0].0,
                lastPageIndex: anns.last!.0,
                annotations: anns
            ))
        }
        return groups
    }
    
    private var noteItems: [AnnotationItem] {
        guard let document = document else { return [] }
        var items: [AnnotationItem] = []
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            for annotation in page.annotations where annotation.type == "Text" {
                items.append(AnnotationItem(
                    annotation: annotation,
                    pageIndex: pageIndex,
                    text: annotation.contents ?? "Note",
                    type: .note
                ))
            }
        }
        return items
    }
    
    private var isEmpty: Bool {
        highlightGroups.isEmpty && noteItems.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Highlights & Notes")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
            
            if isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "highlighter")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("No highlights or notes yet")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("Select text and use the Highlight tooltip or right-click")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(highlightGroups) { group in
                            row(
                                text: group.text,
                                pageLabel: group.pageLabel,
                                isHighlight: true,
                                onTap: { onSelectPage?(group.firstPageIndex) },
                                onDeleteRequest: {
                                    itemsToDelete = group.annotations
                                    showDeleteConfirm = true
                                }
                            )
                        }
                        ForEach(noteItems) { item in
                            row(
                                text: item.text,
                                pageLabel: "Page \((item.pageIndex / 2) + 1)",
                                isHighlight: false,
                                onTap: { onSelectPage?(item.pageIndex) },
                                onDeleteRequest: {
                                    itemsToDelete = [(item.pageIndex, item.annotation)]
                                    showDeleteConfirm = true
                                }
                            )
                        }
                    }
                    .padding(12)
                }
                .id(refreshID)
            }
        }
        .alert("Remove this?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {
                itemsToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let items = itemsToDelete {
                    onDelete?(items)
                    itemsToDelete = nil
                }
            }
        } message: {
            Text("This cannot be undone.")
        }
    }
    
    private func row(
        text: String,
        pageLabel: String,
        isHighlight: Bool,
        onTap: @escaping () -> Void,
        onDeleteRequest: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isHighlight ? "highlighter" : "note.text")
                    .font(.system(size: 14))
                    .foregroundColor(isHighlight ? .yellow : .orange)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(text)
                        .font(.system(size: 12))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    Text(pageLabel)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(8)
            .contentShape(Rectangle())
            .onTapGesture(count: 1) {
                onTap()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Button {
                onDeleteRequest()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}
