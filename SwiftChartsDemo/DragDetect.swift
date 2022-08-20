import SwiftUI

struct DragWatcher: ViewModifier {
    @GestureState private var dragLocation: CGPoint = .zero
    @State private var didEnter = false

    let onEnter: ((CGPoint) -> Void)?
    let onExit: ((CGPoint) -> Void)?

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .updating($dragLocation) { value, state, _ in
                        state = value.location
                    }
            )
            .background(GeometryReader { geo in
                dragObserver(geo)
            })
    }

    private func dragObserver(_ geo: GeometryProxy) -> some View {
        if geo.frame(in: .global).contains(dragLocation) {
            DispatchQueue.main.async {
                didEnter = true
                onEnter?(dragLocation)
            }
        } else if didEnter {
            DispatchQueue.main.async {
                didEnter = false
                onExit?(dragLocation)
            }
        }
        return Color.clear
    }
}

extension View {
    func onDrag(
        onEnter: ((CGPoint) -> Void)? = nil,
        onExit: ((CGPoint) -> Void)? = nil
    ) -> some View {
        self.modifier(DragWatcher(onEnter: onEnter, onExit: onExit))
    }
}
