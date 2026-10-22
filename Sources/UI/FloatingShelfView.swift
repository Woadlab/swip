import AppKit
import SwiftUI

public struct FloatingShelfView: View {
    @ObservedObject var shelf = FloatingShelfController.shared
    @SwipState private var isTargeted = false

    public init() {}

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(isTargeted ? Theme.accent : Color.white.opacity(0.18), lineWidth: isTargeted ? 2 : 1)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(Theme.accent)
                    Text("Floating Shelf")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    if !shelf.items.isEmpty {
                        Button(action: { shelf.clear() }) {
                            Text("Clear")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

                Divider()
                    .opacity(0.4)

                // Content
                if shelf.items.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "tray.and.arrow.down")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text("Drop files here")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("Stage files here, then drag them into any other application.")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(shelf.items, id: \.self) { url in
                                ShelfItemRow(url: url) {
                                    shelf.remove(url: url)
                                }
                            }
                        }
                        .padding(12)
                    }
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            shelf.add(urls: [url])
                        }
                    }
                }
            }
            return true
        }
    }
}

struct ShelfItemRow: View {
    let url: URL
    let onRemove: () -> Void
    @SwipState private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            Image(nsImage: icon)
                .resizable()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                let size = FileSizeFormatter.size(of: url)
                Text(FileSizeFormatter.string(size))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isHovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.white.opacity(isHovering ? 0.08 : 0.03), in: RoundedRectangle(cornerRadius: 10))
        .onHover { isHovering = $0 }
        .onDrag {
            NSItemProvider(object: url as NSURL)
        }
    }
}
