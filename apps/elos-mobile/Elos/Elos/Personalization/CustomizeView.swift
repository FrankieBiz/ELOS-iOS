import SwiftUI
import UIKit

/// The personalization editor.
///
/// Always presented from the app root, never nested inside another sheet. That's not stylistic: a
/// theme change re-identifies the tab content underneath (see `ContentView`), which would tear down
/// any sheet hosted in there — so Settings closes itself and hands off to this rather than pushing it.
struct CustomizeView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case appearance = "Appearance"
        case layout     = "Layout"
        case tabs       = "Tabs"
        var id: String { rawValue }
    }

    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var layout: LayoutStore
    @Environment(\.dismiss) private var dismiss

    @State private var tab: Tab = .appearance
    @State private var screen: CustomizableScreen = .today
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ElosSegmentedControl(tabs: Tab.allCases, label: \.rawValue, selection: $tab)
                    .padding(.horizontal, Space.gutter)
                    .padding(.vertical, Space.m)

                ScrollView {
                    VStack(alignment: .leading, spacing: Space.xl) {
                        switch tab {
                        case .appearance: appearanceTab
                        case .layout:     layoutTab
                        case .tabs:       tabsTab
                        }
                    }
                    .padding(.horizontal, Space.gutter)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
            .elosPageBackground()
            .navigationTitle("Make it yours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Menu {
                        Button(role: .destructive) { showResetConfirm = true } label: {
                            Label("Reset everything", systemImage: "arrow.uturn.backward")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More options")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .confirmationDialog("Reset everything?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Reset appearance and layout", role: .destructive) {
                    HapticManager.warning()
                    theme.reset()
                    layout.resetEverything()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Puts every screen, colour and shape back the way the app ships. Your data isn't touched.")
            }
        }
        .onAppear {
            if let requested = layout.customizingScreen {
                screen = requested
                tab = .layout
                layout.customizingScreen = nil
            }
        }
    }

    // MARK: - Appearance

    private var appearanceTab: some View {
        Group {
            ThemePreviewCard()

            group("Presets", "A starting point you can then take apart.") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.m) {
                        ForEach(ThemePreset.all) { preset in
                            presetChip(preset)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }

            group("Accent", "Used by every button, ring, chart and highlight in the app.") {
                accentPicker
            }

            group("Appearance", nil) {
                ElosSegmentedControl(tabs: AppearanceMode.allCases, label: \.label,
                                     selection: binding(\.appearance))
            }

            group("Background", nil) {
                ElosSegmentedControl(tabs: BackgroundStyle.allCases, label: \.label,
                                     selection: binding(\.background))
            }

            group("Spacing", "How tightly everything is packed.") {
                ElosSegmentedControl(tabs: Density.allCases, label: \.label,
                                     selection: binding(\.density))
            }

            group("Corners", nil) {
                ElosSegmentedControl(tabs: CornerStyle.allCases, label: \.label,
                                     selection: binding(\.corners))
            }

            group("Cards", theme.config.cardStyle.blurb) {
                ElosSegmentedControl(tabs: CardStyle.allCases, label: \.label,
                                     selection: binding(\.cardStyle))
            }

            group("Typeface", nil) {
                ElosSegmentedControl(tabs: FontDesignChoice.allCases, label: \.label,
                                     selection: binding(\.fontDesign))
            }

            group("Text size", "Applied on top of the size set in iOS Settings, not instead of it.") {
                ElosSegmentedControl(tabs: TextScale.allCases, label: \.label,
                                     selection: binding(\.textScale))
            }

            group("Details", nil) {
                VStack(spacing: 0) {
                    switchRow("Accent section headers", "textformat.size.smaller",
                              isOn: binding(\.accentSectionLabels))
                    Divider()
                    switchRow("Animations", "wand.and.sparkles", isOn: binding(\.animationsEnabled))
                    Divider()
                    switchRow("Haptics", "hand.tap", isOn: binding(\.hapticsEnabled))
                    Divider()
                    switchRow("Icon-only tab bar", "rectangle.bottomthird.inset.filled",
                              isOn: binding(\.compactTabBar))
                }
                .padding(.horizontal, Space.card)
                .elosCard()
            }
        }
    }

    private func presetChip(_ preset: ThemePreset) -> some View {
        let isCurrent = theme.config == preset.config
        return Button {
            HapticManager.impact(.light)
            withAnimation(.elosStandard) { theme.update { $0 = preset.config } }
        } label: {
            VStack(alignment: .leading, spacing: Space.s) {
                // Three swatches: accent, card, page — enough to read the preset at a glance without
                // pretending to be a screenshot.
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(preset.config.accentID == AccentPalette.customID
                              ? Color(hex: preset.config.customAccentHex)
                              : (AccentPalette.option(id: preset.config.accentID)?.color ?? .gray))
                        .frame(width: 26, height: 14)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(width: 14, height: 14)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                        .frame(width: 14, height: 14)
                }
                Text(preset.name)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(preset.blurb)
                    .font(.elosMicro)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(width: 132, alignment: .leading)
            .padding(Space.m)
            .elosCard()
            .overlay {
                if isCurrent {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(Color.tint, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preset.name) preset")
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }

    private var accentPicker: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: Space.m)], spacing: Space.m) {
                ForEach(AccentPalette.all) { option in
                    swatch(color: option.color,
                           selected: theme.config.accentID == option.id,
                           label: option.name) {
                        theme.update { $0.accentID = option.id }
                    }
                }
                swatch(color: Color(hex: theme.config.customAccentHex),
                       selected: theme.config.accentID == AccentPalette.customID,
                       label: "Custom",
                       showsPipette: true) {
                    theme.update { $0.accentID = AccentPalette.customID }
                }
            }

            if theme.config.accentID == AccentPalette.customID {
                ColorPicker("Pick any colour",
                            selection: Binding(
                                get: { Color(hex: theme.config.customAccentHex) },
                                set: { picked in
                                    theme.update { config in config.customAccentHex = picked.hexString }
                                }
                            ),
                            supportsOpacity: false)
                    .font(.elosBody)
                    .padding(Space.card)
                    .elosCard()

                // Worth saying out loud: white text on a pale custom colour is the one way to make
                // the app unreadable from this screen, and `Color.onTint` already flips to black to
                // stop that — but a very light accent still washes out against the page.
                Label("Very light colours stay legible but lose contrast against the page.",
                      systemImage: "info.circle")
                    .font(.elosMicro)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func swatch(color: Color,
                        selected: Bool,
                        label: String,
                        showsPipette: Bool = false,
                        action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.selection()
            withAnimation(.elosQuick) { action() }
        } label: {
            ZStack {
                Circle().fill(color)
                if showsPipette {
                    Image(systemName: "eyedropper")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(Color.legibleForeground(on: color))
                }
                if selected {
                    Circle().strokeBorder(Color.primary.opacity(0.9), lineWidth: 2)
                    Circle().strokeBorder(Color(.systemBackground), lineWidth: 3.5).padding(2)
                }
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Layout

    private var layoutTab: some View {
        Group {
            group("Screen", nil) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.s) {
                        ForEach(CustomizableScreen.allCases) { candidate in
                            Button {
                                HapticManager.selection()
                                withAnimation(.elosQuick) { screen = candidate }
                            } label: {
                                Label(candidate.title, systemImage: candidate.icon)
                                    .font(.system(.footnote, weight: .semibold))
                                    .foregroundStyle(screen == candidate ? Color.onTint : Color.primary)
                                    .padding(.horizontal, Space.l)
                                    .padding(.vertical, Space.s)
                                    .background(screen == candidate ? AnyShapeStyle(Color.tint)
                                                                    : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                                                in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(screen == candidate ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }

            Button {
                HapticManager.impact(.medium)
                layout.editingScreen = screen
                dismiss()
            } label: {
                Label("Rearrange on the screen itself", systemImage: "hand.draw")
            }
            .elosSecondaryButton()

            group("\(screen.title) \(screen.itemNounPlural)",
                  "Drag a row, or use the arrows. The eye hides something without deleting anything.") {
                VStack(spacing: 0) {
                    let sections = layout.orderedSections(for: screen)
                    ForEach(Array(sections.enumerated()), id: \.element) { index, section in
                        SectionEditorRow(section: section)
                        if index < sections.count - 1 { Divider() }
                    }
                }
                .padding(.horizontal, Space.card)
                .elosCard()
            }

            if layout.isCustomized(screen) {
                Button(role: .destructive) {
                    HapticManager.warning()
                    withAnimation(.elosStandard) { layout.reset(screen) }
                } label: {
                    Label("Reset \(screen.title)", systemImage: "arrow.uturn.backward")
                }
                .elosSecondaryButton()
            }
        }
    }

    // MARK: - Tabs

    private var tabsTab: some View {
        Group {
            group("Tab bar", "Reorder the bar, hide what you don't use, and pick where the app opens.") {
                VStack(spacing: 0) {
                    let tabs = layout.orderedTabs
                    ForEach(Array(tabs.enumerated()), id: \.element) { index, appTab in
                        TabEditorRow(tab: appTab)
                        if index < tabs.count - 1 { Divider() }
                    }
                }
                .padding(.horizontal, Space.card)
                .elosCard()
            }

            group("Opens on", "The tab you land on when you launch the app.") {
                VStack(spacing: 0) {
                    ForEach(layout.visibleTabs) { appTab in
                        Button {
                            HapticManager.selection()
                            layout.setLaunchTab(appTab)
                        } label: {
                            HStack(spacing: Space.m) {
                                Image(systemName: appTab.icon)
                                    .frame(width: 24)
                                    .foregroundStyle(Color.tint)
                                Text(appTab.label)
                                    .font(.elosBody)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if layout.config.tabs.launchTab == appTab {
                                    Image(systemName: "checkmark")
                                        .font(.system(.footnote, weight: .bold))
                                        .foregroundStyle(Color.tint)
                                }
                            }
                            .padding(.vertical, Space.m)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if appTab != layout.visibleTabs.last { Divider() }
                    }
                }
                .padding(.horizontal, Space.card)
                .elosCard()
            }

            if layout.config.tabs != TabLayout() {
                Button(role: .destructive) {
                    HapticManager.warning()
                    withAnimation(.elosStandard) { layout.resetTabs() }
                } label: {
                    Label("Reset tab bar", systemImage: "arrow.uturn.backward")
                }
                .elosSecondaryButton()
            }
        }
    }

    // MARK: - Building blocks

    @ViewBuilder
    private func group<Content: View>(_ title: String,
                                      _ footnote: String?,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(title).elosSectionLabel()
            content()
            if let footnote {
                Text(footnote)
                    .font(.elosMicro)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func switchRow(_ title: String, _ icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: icon)
                .font(.elosBody)
        }
        .tint(Color.tint)
        .padding(.vertical, Space.m)
    }

    /// Two-way binding into a single `ThemeConfig` field, routed through `ThemeStore.update` so
    /// persistence and the revision bump happen in one place.
    private func binding<Value>(_ keyPath: WritableKeyPath<ThemeConfig, Value>) -> Binding<Value> {
        Binding(
            get: { theme.config[keyPath: keyPath] },
            set: { newValue in theme.update { $0[keyPath: keyPath] = newValue } }
        )
    }
}

// MARK: - Section row

private struct SectionEditorRow: View {
    let section: LayoutSection

    @EnvironmentObject private var layout: LayoutStore
    @State private var isDropTarget = false

    private var isHidden: Bool { layout.isHidden(section) }

    var body: some View {
        HStack(spacing: Space.m) {
            Image(systemName: section.icon)
                .font(.subheadline)
                .foregroundStyle(isHidden ? Color.secondary : Color.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(isHidden ? .secondary : .primary)
                Text(section.isPinned ? "Always shown" : section.blurb)
                    .font(.elosMicro)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !section.isPinned {
                if section.canResize && !isHidden {
                    iconButton(layout.span(for: section).icon,
                               label: "\(section.title) width: \(layout.span(for: section).label)") {
                        layout.toggleSpan(section)
                    }
                }
                iconButton(isHidden ? "eye.slash" : "eye",
                           label: isHidden ? "Show \(section.title)" : "Hide \(section.title)",
                           tinted: !isHidden) {
                    layout.toggleHidden(section)
                }
                VStack(spacing: 2) {
                    arrow("chevron.up", delta: -1)
                    arrow("chevron.down", delta: 1)
                }
                Image(systemName: "line.3.horizontal")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, Space.m)
        .contentShape(Rectangle())
        .opacity(isHidden ? 0.55 : 1)
        .background(alignment: .top) {
            if isDropTarget {
                Rectangle().fill(Color.tint).frame(height: 2)
            }
        }
        // Transferred as a raw string rather than a bespoke `Transferable` + declared UTType: the
        // payload is validated back into the enum on drop, and a stray text drop from elsewhere is
        // simply rejected. One less thing in the Info.plist for no loss of behaviour.
        .draggable(section.rawValue) {
            Label(section.title, systemImage: section.icon)
                .padding(Space.s)
                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
        }
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first,
                  let dropped = LayoutSection(rawValue: raw),
                  dropped.screen == section.screen else { return false }
            HapticManager.impact(.light)
            withAnimation(.elosStandard) { layout.move(dropped, before: section) }
            return true
        } isTargeted: { targeted in
            withAnimation(.elosQuick) { isDropTarget = targeted }
        }
    }

    private func arrow(_ icon: String, delta: Int) -> some View {
        let enabled = layout.canNudge(section, by: delta) && !isHidden
        return Button {
            HapticManager.selection()
            withAnimation(.elosStandard) { layout.nudge(section, by: delta) }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(enabled ? Color.tint : Color.secondary.opacity(0.35))
                .frame(width: 26, height: 15)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(delta < 0 ? "Move \(section.title) up" : "Move \(section.title) down")
    }

    private func iconButton(_ icon: String,
                            label: String,
                            tinted: Bool = true,
                            action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.selection()
            withAnimation(.elosStandard) { action() }
        } label: {
            Image(systemName: icon)
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(tinted ? Color.tint : Color.secondary)
                .frame(width: 32, height: 32)
                .background(Color(.tertiarySystemFill), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Tab row

private struct TabEditorRow: View {
    let tab: AppTab

    @EnvironmentObject private var layout: LayoutStore

    private var isHidden: Bool { layout.isTabHidden(tab) }

    var body: some View {
        HStack(spacing: Space.m) {
            Image(systemName: tab.icon)
                .font(.subheadline)
                .foregroundStyle(isHidden ? Color.secondary : Color.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(tab.label)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(isHidden ? .secondary : .primary)
                if tab == layout.config.tabs.launchTab {
                    Text("Opens here")
                        .font(.elosMicro)
                        .foregroundStyle(Color.tint)
                } else if isHidden {
                    Text("Hidden")
                        .font(.elosMicro)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                HapticManager.selection()
                withAnimation(.elosStandard) { layout.setTabHidden(tab, !isHidden) }
            } label: {
                Image(systemName: isHidden ? "eye.slash" : "eye")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(canToggle ? (isHidden ? Color.secondary : Color.tint)
                                               : Color.secondary.opacity(0.35))
                    .frame(width: 32, height: 32)
                    .background(Color(.tertiarySystemFill), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canToggle)
            .accessibilityLabel(isHidden ? "Show \(tab.label) tab" : "Hide \(tab.label) tab")

            VStack(spacing: 2) {
                moveArrow("chevron.up", delta: -1)
                moveArrow("chevron.down", delta: 1)
            }
        }
        .padding(.vertical, Space.m)
        .opacity(isHidden ? 0.55 : 1)
    }

    private var canToggle: Bool { isHidden || layout.canHideTab(tab) }

    private func moveArrow(_ icon: String, delta: Int) -> some View {
        let order = layout.orderedTabs
        let index = order.firstIndex(of: tab) ?? 0
        let destination = index + delta
        let enabled = destination >= 0 && destination < order.count

        return Button {
            HapticManager.selection()
            // `move(fromOffsets:toOffset:)` inserts *before* the destination, so moving down has to
            // aim one past the neighbour to actually swap with it.
            withAnimation(.elosStandard) {
                layout.moveTabs(fromOffsets: IndexSet(integer: index),
                                toOffset: delta > 0 ? destination + 1 : destination)
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(enabled ? Color.tint : Color.secondary.opacity(0.35))
                .frame(width: 26, height: 15)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(delta < 0 ? "Move \(tab.label) earlier" : "Move \(tab.label) later")
    }
}

// MARK: - Preview card

/// A miniature of the app's own vocabulary — section header, card, figure, progress bar, chip,
/// primary button — so every control on this screen has something to visibly act on without
/// dismissing the sheet.
private struct ThemePreviewCard: View {
    @EnvironmentObject private var theme: ThemeStore

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Preview").elosSectionLabel()

            VStack(alignment: .leading, spacing: Space.m) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This week")
                            .font(.elosHeadline)
                        Text("4 of 5 sessions")
                            .font(.elosCaption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("82")
                        .font(.elosNumeric(.title))
                        .foregroundStyle(Color.tint)
                }

                ProgressBar(value: 0.8, color: .tint)

                HStack(spacing: Space.s) {
                    ChipView(label: "Push", foreground: .tint, background: .tintSoft)
                    ChipView(label: "On track", foreground: .good, background: .good.opacity(0.15))
                    Spacer()
                }

                Text("Start workout")
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(Color.onTint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.tint)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            }
            .padding(Space.card)
            .elosCard()
        }
        .animation(theme.animation(.elosStandard), value: theme.revision)
        .accessibilityHidden(true)
    }
}

// MARK: - Hex round-trip

extension Color {
    /// `Color(hex:)` in reverse, so a colour chosen in `ColorPicker` can be stored as a string.
    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return "D6592E" }
        let clamp: (CGFloat) -> Int = { Int((min(max($0, 0), 1) * 255).rounded()) }
        return String(format: "%02X%02X%02X", clamp(r), clamp(g), clamp(b))
    }
}
