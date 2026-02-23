import SwiftUI
import PDFKit

struct OutlineItem: Identifiable {
    let id = UUID()
    let label: String
    let pageIndex: Int
    let depth: Int
    let outline: PDFOutline
}

struct TableOfContentsView: View {
    let document: PDFDocument?
    let onSelectPage: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private var outlineItems: [OutlineItem] {
        guard let document = document,
              let outlineRoot = document.outlineRoot else {
            return []
        }
        return flattenOutline(outlineRoot, depth: 0)
    }
    
    private func flattenOutline(_ outline: PDFOutline, depth: Int) -> [OutlineItem] {
        var items: [OutlineItem] = []
        
        if let label = outline.label, let doc = document {
            let pageIndex = outline.destination?.page.flatMap { doc.index(for: $0) } ?? 0
            items.append(OutlineItem(label: label, pageIndex: pageIndex, depth: depth, outline: outline))
        }
        
        for child in outline.childrenArray {
            items.append(contentsOf: flattenOutline(child, depth: depth + 1))
        }
        
        return items
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Contents")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
            
            if outlineItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("No table of contents")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("This PDF doesn't have outline information")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(outlineItems) { item in
                            Button {
                                onSelectPage(item.pageIndex)
                                dismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Text(item.label)
                                        .font(.system(size: 12))
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, CGFloat(item.depth) * 12)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(width: 260)
    }
}

// MARK: - PDF Outline Extension
extension PDFOutline {
    var childrenArray: [PDFOutline] {
        guard numberOfChildren >= 1 else { return [] }
        return (0..<numberOfChildren).compactMap { child(at: $0) }
    }
}
