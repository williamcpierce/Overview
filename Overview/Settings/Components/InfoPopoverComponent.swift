import SwiftUI

struct InfoPopover: View {
    let content: InfoPopoverContent
    @Binding var isPresented: Bool
    var showWarning: Bool = false

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
            VStack(alignment: .leading, spacing: 12) {
                Text(content.title)
                    .font(.headline)
                
                ForEach(content.sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.title)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(section.text)
                            .font(.body)
                    }
                }
            }
            .padding()
            .frame(width: 320)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct InfoPopoverContent {
    struct Section {
        let title: String
        let text: String
    }
    
    let title: String
    let sections: [Section]
    let isWarning: Bool
    
    static let frameRate = InfoPopoverContent(
        title: "Preview Frame Rate",
        sections: [
            Section(
                title: "Performance Impact",
                text: "Increasing preview frame rates can increase CPU usage proportionally.\nValues above 10 FPS may impact system performance significantly.\n\nNote that preview frame rate is automatically throttled for windows without any content changes. This may mean that with a high FPS setting, performance can be fine for some applicaitons, but degrade significantly in games or while scrolling."
            ),
            Section(
                title: "Recommended Settings",
                text: "• 1 FPS: Best for low performance impact\n• 5/10 FPS: Balanced settings for most uses\n• 30+ FPS: Smoother animation but higher system load"
            )
        ],
        isWarning: true
    )
    
    static let autoHiding = InfoPopoverContent(
        title: "Automatic Preview Hiding",
        sections: [
            Section(
                title: "Hide Inactive App Previews",
                text: "When enabled, all preview windows will automatically hide except those belonging to the currently active application.\nThis is useful if you only use Overview with multiple instances of the same application (i.e. EVE Online) and would like previews hidden while using other applications."
            ),
            Section(
                title: "Hide Active Window Preview",
                text: "Automatically hides the preview window when its source window becomes active.\nIn conjunction with this setting, two previews can be placed on top of one another, and used to switch back and forth between two applications while only ever seeing the preview of the inactive one."
            )
        ],
        isWarning: false
    )
    
    static let windowAppearance = InfoPopoverContent(
        title: "Window Appearance",
        sections: [
            Section(
                title: "Opacity",
                text: "Controls preview window transparency"
            ),
            Section(
                title: "Shadows",
                text: "Adds shadows to preview windows"
            ),
            Section(
                title: "Default Dimensions",
                text: "Sets initial dimensions for new windows. Windows can be resized while in Edit Mode."
            )
        ],
        isWarning: false
    )
    
    static let windowBehavior = InfoPopoverContent(
        title: "Window Behavior",
        sections: [
            Section(
                title: "Show in Mission Control",
                text: "Show previews in Mission Control"
            ),
            Section(
                title: "Create Window on Launch",
                text: "Opens a window at startup if none were restored from a previous session"
            ),
            Section(
                title: "Close With Preview Source",
                text: "Closes preview window when source window closes"
            )
        ],
        isWarning: false
    )
    
    static let windowFocus = InfoPopoverContent(
        title: "Window Focus Overlay",
        sections: [
            Section(
                title: "Overview",
                text: "Displays a customizable border around preview windows when their source window is active"
            ),
            Section(
                title: "Border Width",
                text: "Adjust the border width"
            ),
            Section(
                title: "Border Color",
                text: "Adjust the border color"
            )
        ],
        isWarning: false
    )
    
    static let sourceTitle = InfoPopoverContent(
        title: "Source Title Overlay",
        sections: [
            Section(
                title: "Overview",
                text: "Shows the title of the source window on the preview"
            ),
            Section(
                title: "Font Size",
                text: "Adjust for readability"
            ),
            Section(
                title: "Opacity",
                text: "Control title backdrop visibility. Higher opacity values improve text legibility but obstruct preview content."
            )
        ],
        isWarning: false
    )
    
    static let hotkeyActivation = InfoPopoverContent(
        title: "Source Window Activation Hotkeys",
        sections: [
            Section(
                title: "Hotkey Requirements",
                text: "Each hotkey must include:\n• At least one modifier key (⌘/⌥/⌃/⇧)\n• One additional character"
            ),
            Section(
                title: "Window Matching",
                text: "Hotkeys are matched to windows by their exact title. If multiple windows share the same title, behavior may be unpredictable."
            )
        ],
        isWarning: false
    )
    
    static let sourceFilter = InfoPopoverContent(
        title: "Source App Filter",
        sections: [
            Section(
                title: "Overview",
                text: "Filter which applications appear in the window picker."
            ),
            Section(
                title: "Filter Mode",
                text: "• Blocklist: Hide specific applications\n• Allowlist: Show only specified applications"
            ),
            Section(
                title: "Usage Tips",
                text: "Enter application names exactly as they appear in the window picker. Blocklist mode is useful for hiding system utilities, while allowlist mode helps focus on specific applications you want to monitor."
            )
        ],
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
