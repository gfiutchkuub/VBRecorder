import AppKit

struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(pasteboard: NSPasteboard = .general) {
        items = pasteboard.pasteboardItems?.map { item in
            item.types.reduce(into: [:]) { result, type in
                result[type] = item.data(forType: type)
            }
        } ?? []
    }

    func restore(to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()

        let restoredItems = items.map { itemData in
            let item = NSPasteboardItem()

            for (type, data) in itemData {
                item.setData(data, forType: type)
            }

            return item
        }

        if !restoredItems.isEmpty {
            pasteboard.writeObjects(restoredItems)
        }
    }
}
