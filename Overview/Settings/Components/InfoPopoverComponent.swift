import SwiftUI

struct InfoPopover: View {
    let content: InfoPopoverContent
    @Binding var isPresented: Bool
    var showWarning: Bool = false  // For cases where we want to dynamically show warning state

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Group {
                if showWarning {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .modifier(WiggleModifier())
                        .transition(.scale)
                } else {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .transition(.scale)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.1), value: showWarning)
        .popover(isPresented: $isPresented) {
            VStack(alignment: .leading, spacing: 8) {
                Text(content.title)
                    .font(.headline)
                Text(content.message)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(width: 300)
        }
    }
}

struct InfoPopoverContent {
    let title: String
    let message: String
    let isWarning: Bool

    static let frameRate = InfoPopoverContent(
        title: "Frame Rate",
        message:
            "Higher frame rates provide smoother previews but use more system resources. Values above 10 FPS may impact system performance significantly. For most use cases, 5-10 FPS provides a good balance.",
        isWarning: true
    )

    static let autoHiding = InfoPopoverContent(
        title: "Automatic Hiding",
        message:
            "Configure when previews should automatically hide themselves. Hide inactive app previews will hide all preview windows except for those of the active application. Hide active window previews will hide the preview window for the active window",
        isWarning: false
    )

    static let windowAppearance = InfoPopoverContent(
        title: "Window Appearance",
        message:
            "Adjust visual properties of preview windows. Opacity controls window transparency. Lower values let you see through the preview. Shadows add depth but may impact performance. Default dimensions apply to new windows when created. ",
        isWarning: false
    )

    static let windowBehavior = InfoPopoverContent(
        title: "Window Behavior",
        message:
            "Control how preview windows interact with macOS. Show in Mission Control makes windows visible in the overview. Create on launch opens a window when Overview starts, if no windows were restored on launch. Close with preview source removes the preview window when the window being captured is closed. ",
        isWarning: false
    )

    static let windowFocus = InfoPopoverContent(
        title: "Window Focus Indication",
        message:
            "Show a border around preview windows when their source window is focused, with customization for the border color and width.",
        isWarning: false
    )

    static let sourceTitle = InfoPopoverContent(
        title: "Source Title Overlay",
        message:
            "Display the title of source windows on previews. Adjust font size and background opacity to balance readability with unobtrusiveness.",
        isWarning: false
    )

    static let sourceFilter = InfoPopoverContent(
        title: "Source App Filter",
        message:
            "Filter which applications appear in the window picker. Blocklist mode hides specified apps. Allowlist mode only shows specified apps. Use app names exactly as they appear in the window picker.",
        isWarning: false
    )

    static let hotkeyActivation = InfoPopoverContent(
        title: "Source Window Activation",
        message:
            "Configure keyboard shortcuts to quickly switch to specific windows. Each hotkey must include at least one modifier key (⌘/⌥/⌃/⇧) plus another character. Window titles must match exactly for hotkeys to work.",
        isWarning: false
    )
}

struct WiggleModifier: ViewModifier {
    @State private var angle: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.1)) {
                    angle = 10
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        angle = -10
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        angle = 10
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        angle = -10
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        angle = 10
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        angle = 0
                    }
                }
            }
    }
}
