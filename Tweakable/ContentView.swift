//

import SwiftUI

struct PreferenceValue: Equatable {
    var initialValue: any TweakableType
    var edit: (String, Binding<any TweakableType>) -> AnyView
    var compare: (any TweakableType, any TweakableType) -> Bool
    init<T: TweakableType & Equatable>(initialValue: T) {
        self.initialValue = initialValue
        self.compare = { l, r in
            guard let l1 = l as? T, let r1 = r as? T else { return false }
            return l1 == r1
        }
        self.edit = { label, binding in
            let b: Binding<T> = Binding(get: { binding.wrappedValue as! T }, set: { binding.wrappedValue = $0 })
            return AnyView(T.edit(label: label, binding: b))
        }
    }

    static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.compare(lhs.initialValue, rhs.initialValue) // todo we can't compare closures
    }
}

struct TweakablePreference: PreferenceKey {
    static var defaultValue: [String:PreferenceValue] = [:]
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct TweakableValuesKey: EnvironmentKey {
    static var defaultValue: [String:any TweakableType] = [:]
}

extension EnvironmentValues {
    var tweakables: TweakableValuesKey.Value {
        get { self[TweakableValuesKey.self] }
        set { self[TweakableValuesKey.self] = newValue }
    }
}

protocol TweakableType {
    associatedtype V: View
    static func edit(label: String, binding: Binding<Self>) -> V
}

extension Double: TweakableType {
    static func edit(label: String, binding: Binding<Self>) -> some View {
        Slider(value: binding, in: 0...300) { Text(label) }
    }
}

extension Color: TweakableType {
    static func edit(label: String, binding: Binding<Self>) -> some View {
        ColorPicker(label, selection: binding)
    }
}

extension View {
    func tweakable<Value: TweakableType & Equatable, Output: View>(_ label: String, initialValue: Value, @ViewBuilder content: @escaping (AnyView, Value) -> Output) -> some View {
        modifier(Tweakable(label: label, initialValue: initialValue, run: content))
    }
}

struct Tweakable<Value: TweakableType & Equatable, Output: View>: ViewModifier {
    var label: String
    var initialValue: Value
    @ViewBuilder var run: (AnyView, Value) -> Output
    @Environment(\.tweakables) var tweakables

    func body(content: Content) -> some View {
        run(AnyView(content), (tweakables[label] as? Value) ?? initialValue)
            .transformPreference(TweakablePreference.self) { value in
                value[label] = .init(initialValue: initialValue)
            }
    }
}

struct TweakableGUI: ViewModifier {
    @State private var values: [String: PreferenceValue] = [:]
//    @State private var values: [String: PreferenceValue] = [:]

    func body(content: Content) -> some View {
        content
            .environment(\.tweakables, values.mapValues { $0.initialValue })
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                Form {
                    ForEach(values.keys.sorted(), id: \.self) { key in
                        let b: Binding<PreferenceValue> = 
                        Binding($values[key])!
                        values[key]!.edit(key, b.initialValue)
                    }
                }
                .frame(maxHeight: 200)
            }
            .onPreferenceChange(TweakablePreference.self, perform: { value in
                values = value
            })
    }
}

struct ContentView: View {
    var body: some View {
        Text("Hello, world!")
            .tweakable("padding", initialValue: 10) {
                $0.padding($1)
            }
            .tweakable("offset", initialValue: 10) {
                $0.offset(x: $1)
            }
            .tweakable("foreground color", initialValue: Color.white) {
                $0.foregroundStyle($1)
            }
            .tweakable("padding", initialValue: Color.blue) {
                $0.background($1)
            }
//            .background(Color.blue)
            .modifier(TweakableGUI())
    }
}

#Preview {
    ContentView()
}
