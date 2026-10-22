import SwiftUI

/// A drop-in property wrapper that provides the exact semantics of `@State`
/// while bypassing compiler macro requirements in macOS toolchains.
@propertyWrapper
public struct SwipState<Value>: DynamicProperty {
    @StateObject private var storage: Storage

    private final class Storage: ObservableObject {
        @Published var value: Value
        init(_ value: Value) { self.value = value }
    }

    public init(wrappedValue: Value) {
        _storage = StateObject(wrappedValue: Storage(wrappedValue))
    }

    public init(initialValue: Value) {
        _storage = StateObject(wrappedValue: Storage(initialValue))
    }

    public var wrappedValue: Value {
        get { storage.value }
        nonmutating set { storage.value = newValue }
    }

    public var projectedValue: Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { self.wrappedValue = $0 }
        )
    }
}
