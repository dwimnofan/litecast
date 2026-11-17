import SwiftUI

struct NotchRootView: View {
    let state: NotchState
    let nowPlaying: NowPlayingService
    let battery: BatteryMonitor
    let shelf: ShelfStore
    let preferences: PreferencesStore
    let openLauncher: @MainActor () -> Void
    let openSettings: @MainActor () -> Void

    // Springs retarget from the current value and velocity, so rapid hover in/out never snaps.
    private let spring = Animation.spring(response: 0.38, dampingFraction: 0.82)

    var body: some View {
        let size = state.isExpanded ? NotchLayout.expandedSize : state.collapsedSize
        ZStack(alignment: .top) {
            UnevenRoundedRectangle(bottomLeadingRadius: state.isExpanded ? 24 : 8,
                                   bottomTrailingRadius: state.isExpanded ? 24 : 8)
                .fill(.black)
                .frame(width: size.width, height: size.height)
            if state.isExpanded {
                content
                    .frame(width: NotchLayout.expandedSize.width, height: NotchLayout.expandedSize.height, alignment: .top)
                    .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(spring, value: state.isExpanded)
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
    }

    private var content: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 16) {
                if preferences.notchShowMedia {
                    NowPlayingWidget(service: nowPlaying)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 8) {
                    if preferences.notchShowBattery, let status = battery.status {
                        BatteryWidget(status: status)
                    }
                    HStack(spacing: 6) {
                        QuickActionButton(title: "Launcher", symbol: "magnifyingglass") { openLauncher() }
                        QuickActionButton(title: "Settings", symbol: "gearshape") { openSettings() }
                    }
                }
            }
            if preferences.notchShowShelf {
                ShelfWidget(store: shelf)
            }
        }
        // The top of an expanded notch on a notched Mac is physically occluded by the camera housing.
        .padding(.top, state.hasNotch ? state.collapsedSize.height + 4 : 12)
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
    }
}

struct QuickActionButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}
