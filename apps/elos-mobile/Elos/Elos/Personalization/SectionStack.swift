import SwiftUI

/// The container every customizable screen is built from.
///
/// A screen hands it a closure that maps a `LayoutSection` to a view; the stack decides what appears,
/// in what order, and how wide. That inversion is the whole point — `TodayView` no longer contains a
/// hard-coded list of cards, so "put hydration above habits" is a stored preference instead of a diff.
///
/// It also owns edit mode: the same closure renders the real content, dimmed, under a control strip.
/// Editing the actual screen rather than an abstract list means you're arranging the thing you're
/// looking at.
struct SectionStack<Content: View>: View {
    let screen: CustomizableScreen
    /// Defaults to the screen's own rhythm, which itself scales with the density setting.
    var spacing: CGFloat? = nil
    /// Lets a screen say "this section has nothing to show right now". Kept out of the store because
    /// it's a fact about today's data, not a preference — and it changes minute to minute.
    var isAvailable: (LayoutSection) -> Bool = { _ in true }
    @ViewBuilder var content: (LayoutSection) -> Content

    @EnvironmentObject private var layout: LayoutStore
    @EnvironmentObject private var theme: ThemeStore

    private var isEditing: Bool { layout.editingScreen == screen }
    private var gap: CGFloat { spacing ?? Space.xl }

    private var placements: [PlacedSection] {
        layout.placedSections(for: screen).map {
            PlacedSection(section: $0.section, span: $0.span, isAvailable: isAvailable($0.section))
        }
    }

    /// Outside edit mode, a section with nothing to show is dropped entirely — leaving it in would
    /// render an empty view that still consumed a full stack gap, which is exactly the ragged
    /// spacing the old hand-written `if` chains avoided.
    private var rows: [SectionRow] {
        SectionRowPacker.pack(isEditing ? placements : placements.filter(\.isAvailable))
    }

    var body: some View {
        VStack(spacing: gap) {
            ForEach(rows) { row in
                switch row {
                case .single(let placed):
                    sectionView(placed)
                case .pair(let left, let right):
                    HStack(alignment: .top, spacing: gap) {
                        sectionView(left)
                        sectionView(right)
                    }
                    // Two cards in a row should agree on height rather than one floating short.
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            if isEditing {
                SectionTray(screen: screen)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(theme.animation(.elosStandard), value: layout.revision)
        .animation(theme.animation(.elosStandard), value: isEditing)
    }

    @ViewBuilder
    private func sectionView(_ placed: PlacedSection) -> some View {
        if isEditing {
            SectionEditWrapper(placed: placed) {
                content(placed.section)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        } else {
            content(placed.section)
                .frame(maxWidth: .infinity, alignment: .top)
                .contextMenu { SectionContextMenu(section: placed.section) }
        }
    }
}

// MARK: - Context menu
//
// The discovery route. Long-pressing something to rearrange it is the gesture iOS has taught people
// on the Home Screen for a decade, so it's the one worth borrowing — the Settings entry and the
// toolbar buttons exist for people who never try it.

private struct SectionContextMenu: View {
    let section: LayoutSection

    @EnvironmentObject private var layout: LayoutStore

    var body: some View {
        Group {
            if !section.isPinned {
                Button {
                    HapticManager.selection()
                    withAnimation(.elosStandard) { layout.nudge(section, by: -1) }
                } label: { Label("Move up", systemImage: "arrow.up") }
                .disabled(!layout.canNudge(section, by: -1))

                Button {
                    HapticManager.selection()
                    withAnimation(.elosStandard) { layout.nudge(section, by: 1) }
                } label: { Label("Move down", systemImage: "arrow.down") }
                .disabled(!layout.canNudge(section, by: 1))

                if section.canResize {
                    Button {
                        HapticManager.selection()
                        withAnimation(.elosStandard) { layout.toggleSpan(section) }
                    } label: {
                        let next: SectionSpan = layout.span(for: section) == .half ? .full : .half
                        Label(next.label, systemImage: next.icon)
                    }
                }
            }

            Divider()

            Button {
                HapticManager.impact(.light)
                withAnimation(.elosStandard) { layout.editingScreen = section.screen }
            } label: { Label("Rearrange \(section.screen.title)", systemImage: "square.grid.3x1.below.line.grid.1x2") }

            Button {
                layout.customizingScreen = section.screen
                layout.showingCustomizeSheet = true
            } label: { Label("Customize…", systemImage: "paintbrush") }

            if !section.isPinned {
                Divider()
                Button(role: .destructive) {
                    HapticManager.impact(.medium)
                    withAnimation(.elosStandard) { layout.setHidden(section, true) }
                } label: { Label("Hide \(section.title)", systemImage: "eye.slash") }
            }
        }
    }
}

// MARK: - Edit chrome

/// A section as it appears while rearranging: a control strip naming it, and the real content
/// underneath, dimmed and inert.
///
/// The content stays live rather than being replaced by a grey box, because half of arranging a
/// screen is judging how the cards look next to each other.
private struct SectionEditWrapper<Content: View>: View {
    let placed: PlacedSection
    @ViewBuilder let content: Content

    @EnvironmentObject private var layout: LayoutStore
    @EnvironmentObject private var theme: ThemeStore
    @State private var wiggle = false

    private var section: LayoutSection { placed.section }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            controlStrip

            if placed.isAvailable {
                content
                    .allowsHitTesting(false)
                    .opacity(0.55)
            } else {
                unavailablePlaceholder
            }
        }
        .padding(Space.s)
        .background(Color.tint.opacity(0.05), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(
                    Color.tint.opacity(section.isPinned ? 0.25 : 0.7),
                    style: StrokeStyle(lineWidth: 1.5, dash: section.isPinned ? [3, 4] : [])
                )
        }
        .rotationEffect(.degrees(wiggle ? 0.35 : -0.35))
        .onAppear {
            guard theme.config.animationsEnabled, !section.isPinned else { return }
            withAnimation(.easeInOut(duration: 0.16).repeatForever(autoreverses: true)) {
                wiggle = true
            }
        }
    }

    // Four 30pt buttons plus a title is a ~235pt *hard* minimum — nothing in it can compress. In a
    // half-width card that minimum propagates all the way up: the paired row demanded ~496pt, the
    // scroll view grew to fit it, and the whole app centred inside an over-wide root — the tab bar
    // ended up hanging off both edges of the screen. A half-width card gets a menu instead, whose
    // minimum is one button wide.
    @ViewBuilder
    private var controlStrip: some View {
        HStack(spacing: Space.s) {
            Image(systemName: section.icon)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(Color.tint)
                .frame(width: 18)

            Text(section.title)
                .font(.system(.footnote, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                // Yields width to the controls rather than the other way round.
                .layoutPriority(-1)

            Spacer(minLength: 0)

            if section.isPinned {
                Text("Always on")
                    .font(.elosMicro)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .layoutPriority(-1)
            } else if placed.span == .half {
                compactMenu
            } else {
                controlButton("chevron.up", label: "Move \(section.title) up",
                              enabled: layout.canNudge(section, by: -1)) {
                    layout.nudge(section, by: -1)
                }
                controlButton("chevron.down", label: "Move \(section.title) down",
                              enabled: layout.canNudge(section, by: 1)) {
                    layout.nudge(section, by: 1)
                }
                if section.canResize {
                    let span = layout.span(for: section)
                    controlButton(span == .half ? "rectangle.split.2x1" : "rectangle",
                                  label: "\(section.title) width: \(span.label)",
                                  enabled: true) {
                        layout.toggleSpan(section)
                    }
                }
                controlButton("eye.slash", label: "Hide \(section.title)", enabled: true, destructive: true) {
                    layout.setHidden(section, true)
                }
            }
        }
        // Fixed-size controls in one row can't reflow, so cap the ramp here the way the tab bar and
        // segmented control already do.
        .elosDenseLayout()
    }

    /// Everything the full strip offers, folded into one button.
    private var compactMenu: some View {
        Menu {
            Button {
                HapticManager.selection()
                withAnimation(.elosStandard) { layout.nudge(section, by: -1) }
            } label: { Label("Move up", systemImage: "arrow.up") }
            .disabled(!layout.canNudge(section, by: -1))

            Button {
                HapticManager.selection()
                withAnimation(.elosStandard) { layout.nudge(section, by: 1) }
            } label: { Label("Move down", systemImage: "arrow.down") }
            .disabled(!layout.canNudge(section, by: 1))

            if section.canResize {
                Button {
                    HapticManager.selection()
                    withAnimation(.elosStandard) { layout.toggleSpan(section) }
                } label: { Label(SectionSpan.full.label, systemImage: SectionSpan.full.icon) }
            }

            Divider()

            Button(role: .destructive) {
                HapticManager.impact(.medium)
                withAnimation(.elosStandard) { layout.setHidden(section, true) }
            } label: { Label("Hide", systemImage: "eye.slash") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(Color.tint)
                .frame(width: 30, height: 30)
                .background(Color(.tertiarySystemFill), in: Circle())
        }
        .accessibilityLabel("\(section.title) options")
    }

    private func controlButton(_ icon: String,
                               label: String,
                               enabled: Bool,
                               destructive: Bool = false,
                               action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.selection()
            withAnimation(.elosStandard) { action() }
        } label: {
            Image(systemName: icon)
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(enabled ? (destructive ? Color.bad : Color.tint) : Color.secondary.opacity(0.4))
                .frame(width: 30, height: 30)
                .background(Color(.tertiarySystemFill), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private var unavailablePlaceholder: some View {
        HStack(spacing: Space.s) {
            Image(systemName: "moon.zzz")
                .foregroundStyle(.secondary)
            Text("Nothing to show right now — it'll appear here when there is.")
                .font(.elosCaption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
    }
}

// MARK: - Add tray

/// The hidden sections, offered back. Sits at the bottom of the stack in edit mode so "where did my
/// card go" and "what else can I put here" have the same answer in the same place.
private struct SectionTray: View {
    let screen: CustomizableScreen

    @EnvironmentObject private var layout: LayoutStore

    private var hidden: [LayoutSection] { layout.hiddenSections(for: screen) }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(hidden.isEmpty ? "EVERYTHING IS ON THIS SCREEN"
                                : "ADD \(screen.itemNounPlural.uppercased())")
                .elosSectionLabel()

            if hidden.isEmpty {
                Text("Hide something and it'll wait here.")
                    .font(.elosCaption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(hidden) { section in
                    Button {
                        HapticManager.success()
                        withAnimation(.elosStandard) { layout.setHidden(section, false) }
                    } label: {
                        HStack(spacing: Space.m) {
                            Image(systemName: section.icon)
                                .font(.subheadline)
                                .foregroundStyle(Color.tint)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(section.title)
                                    .font(.system(.subheadline, weight: .medium))
                                    .foregroundStyle(.primary)
                                Text(section.blurb)
                                    .font(.elosCaption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.tint)
                        }
                        .padding(.vertical, Space.s)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add \(section.title)")

                    if section != hidden.last { Divider() }
                }
            }
        }
        .padding(Space.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .elosCard()
    }
}

// MARK: - Entry point

/// The button that puts a screen into edit mode. Placed in each screen's toolbar, and in Today's
/// header where there is no toolbar to put it in.
struct CustomizeScreenButton: View {
    let screen: CustomizableScreen
    var compact = false

    @EnvironmentObject private var layout: LayoutStore

    var body: some View {
        Menu {
            Button {
                HapticManager.impact(.light)
                withAnimation(.elosStandard) { layout.editingScreen = screen }
            } label: {
                Label("Rearrange \(screen.itemNounPlural)", systemImage: "arrow.up.arrow.down")
            }
            Button {
                layout.customizingScreen = screen
                layout.showingCustomizeSheet = true
            } label: {
                Label("Appearance & layout", systemImage: "paintbrush")
            }
            if layout.isCustomized(screen) {
                Divider()
                Button(role: .destructive) {
                    HapticManager.warning()
                    withAnimation(.elosStandard) { layout.reset(screen) }
                } label: {
                    Label("Reset \(screen.title)", systemImage: "arrow.uturn.backward")
                }
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(compact ? .system(.footnote, weight: .semibold) : .body)
                .foregroundStyle(Color.tint)
                .frame(minWidth: 30, minHeight: 30)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Customize \(screen.title)")
    }
}

// MARK: - Edit bar

/// Floating confirmation bar shown while any screen is being rearranged. Lives at the app root so it
/// stays put while the screen underneath scrolls.
struct LayoutEditBar: View {
    @EnvironmentObject private var layout: LayoutStore
    /// Lives outside the tab content, so it misses the rebuild a theme change triggers there —
    /// observing the store directly keeps its accent in step. Same reason as `ElosSegmentedControl`.
    @ObservedObject private var theme = ThemeStore.shared

    var body: some View {
        if let screen = layout.editingScreen {
            HStack(spacing: Space.m) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Arranging \(screen.title)")
                        .font(.system(.subheadline, weight: .semibold))
                    Text("Move, resize or hide — changes save as you go.")
                        .font(.elosMicro)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)

                if layout.isCustomized(screen) {
                    Button {
                        HapticManager.warning()
                        withAnimation(.elosStandard) { layout.reset(screen) }
                    } label: {
                        Text("Reset")
                            .font(.system(.footnote, weight: .semibold))
                            .foregroundStyle(Color.bad)
                            .padding(.horizontal, Space.m)
                            .padding(.vertical, Space.s)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    HapticManager.success()
                    withAnimation(.elosStandard) { layout.editingScreen = nil }
                } label: {
                    Text("Done")
                        .font(.system(.footnote, weight: .bold))
                        .foregroundStyle(Color.onTint)
                        .padding(.horizontal, Space.l)
                        .padding(.vertical, Space.s)
                        .background(Color.tint, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .elosDenseLayout()
            .padding(Space.m)
            .elosCard()
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
            .padding(.horizontal, Space.m)
        }
    }
}
