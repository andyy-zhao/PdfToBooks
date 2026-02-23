import Foundation

/// Persists recently opened PDFs and last-read page per document
final class ReadingHistory {
    static let shared = ReadingHistory()
    
    private let recentKey = "BookReader.recentDocuments"
    private let lastPageKey = "BookReader.lastPage"
    private let libraryKey = "BookReader.library"
    private let maxRecentCount = 10
    
    private init() {}
    
    // MARK: - Library (user-added PDFs)
    
    var libraryDocuments: [URL] {
        get {
            guard let data = UserDefaults.standard.data(forKey: libraryKey),
                  let urls = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return urls.compactMap { URL(string: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
        }
        set {
            let strings = newValue.map { $0.absoluteString }
            if let data = try? JSONEncoder().encode(strings) {
                UserDefaults.standard.set(data, forKey: libraryKey)
            }
        }
    }
    
    func addToLibrary(_ url: URL) {
        var lib = libraryDocuments
        lib.removeAll { $0.path == url.path }
        lib.insert(url, at: 0)
        libraryDocuments = lib
    }
    
    func removeFromLibrary(_ url: URL) {
        var lib = libraryDocuments
        lib.removeAll { $0.path == url.path }
        libraryDocuments = lib
    }
    
    // MARK: - Recent Documents
    
    var recentDocuments: [URL] {
        get {
            guard let data = UserDefaults.standard.data(forKey: recentKey),
                  let urls = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return urls.compactMap { URL(string: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
        }
        set {
            let strings = newValue.prefix(maxRecentCount).map { $0.absoluteString }
            if let data = try? JSONEncoder().encode(strings) {
                UserDefaults.standard.set(data, forKey: recentKey)
            }
        }
    }
    
    func addRecentDocument(_ url: URL) {
        var recent = recentDocuments
        recent.removeAll { $0 == url }
        recent.insert(url, at: 0)
        recentDocuments = Array(recent)
    }
    
    // MARK: - Last Page
    
    private var lastPageStore: [String: Int] {
        get {
            guard let data = UserDefaults.standard.data(forKey: lastPageKey),
                  let dict = try? JSONDecoder().decode([String: Int].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: lastPageKey)
            }
        }
    }
    
    func getLastPage(for url: URL) -> Int? {
        let key = url.path
        let page = lastPageStore[key]
        return page
    }
    
    func setLastPage(_ page: Int, for url: URL) {
        var store = lastPageStore
        store[url.path] = page
        lastPageStore = store
    }
}
