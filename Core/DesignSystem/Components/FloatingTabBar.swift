// MARK: - FloatingTabBar.swift
// YTPlayer — Core/DesignSystem/Components/FloatingTabBar.swift
// Swift 5.7, iOS 16.0
//
// Capsule-shaped YouTube-style Floating Bottom Navigation Bar (#1C1C1E @ 95% opacity,
// #48484A single persistent sliding selection capsule via matchedGeometryEffect + Spring,
// pure white 24pt icons without text labels, light haptics, and VoiceOver accessibility).

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Bottom Navigation Tab Definition

enum YTBottomTab: Int, CaseIterable, Identifiable {
    case home = 0
    case search = 1
    case library = 2
    case settings = 3

    var id: Int { rawValue }

    var accessibilityTitle: String {
        switch self {
        case .home:
            return "Trang chủ"
        case .search:
            return "Tìm kiếm"
        case .library:
            return "Thư viện"
        case .settings:
            return "Cài đặt"
        }
    }
}

// MARK: - FloatingTabBar View

struct FloatingTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var selectionNamespace

    #if canImport(UIKit)
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)
    #endif

    var body: some View {
        HStack(spacing: 0) {
            ForEach(YTBottomTab.allCases) { tab in
                let isSelected = (selectedTab == tab.rawValue)

                Button {
                    handleTabTap(tab)
                } label: {
                    tabIcon(for: tab)
                        .frame(width: 24, height: 24)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(FloatingTabItemButtonStyle())
                .matchedGeometryEffect(
                    id: tab.rawValue,
                    in: selectionNamespace,
                    properties: .frame,
                    isSource: true
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(tab.accessibilityTitle)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
            }
        }
        .background(
            Capsule(style: .continuous)
                .fill(Color.ytFloatingBarSelection)
                .matchedGeometryEffect(
                    id: selectedTab,
                    in: selectionNamespace,
                    properties: .frame,
                    isSource: false
                )
                .animation(
                    .spring(response: 0.32, dampingFraction: 0.79, blendDuration: 0.08),
                    value: selectedTab
                )
        )
        .padding(5)
        .frame(height: 56)
        .background(
            Capsule(style: .continuous)
                .fill(Color.ytFloatingBarBackground.opacity(0.95))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.ytFloatingBarBorder, lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.32), radius: 10, x: 0, y: 4)
        .onAppear {
            #if canImport(UIKit)
            hapticGenerator.prepare()
            #endif
        }
    }

    private func handleTabTap(_ tab: YTBottomTab) {
        guard selectedTab != tab.rawValue else { return }
        #if canImport(UIKit)
        hapticGenerator.impactOccurred(intensity: 0.75)
        hapticGenerator.prepare()
        #endif
        selectedTab = tab.rawValue
    }

    @ViewBuilder
    private func tabIcon(for tab: YTBottomTab) -> some View {
        switch tab {
        case .home:
            Image(systemName: "house.fill")
                .font(.system(size: 20, weight: .semibold))
        case .search:
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .medium))
        case .library:
            LibraryPlaylistPlayIcon()
                .frame(width: 24, height: 24)
        case .settings:
            Image(systemName: "gearshape")
                .font(.system(size: 20, weight: .medium))
        }
    }
}

// MARK: - Custom Vector Icon: Three Horizontal Bars + Play Triangle (Reference Match)

struct LibraryPlaylistPlayIcon: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let scaleX = w / 24.0
            let scaleY = h / 24.0
            let barHeight = 2.25 * scaleY

            ZStack(alignment: .topLeading) {
                // Top horizontal bar
                Capsule(style: .continuous)
                    .frame(width: 17.5 * scaleX, height: barHeight)
                    .offset(x: 2.2 * scaleX, y: 5.0 * scaleY)

                // Middle horizontal bar
                Capsule(style: .continuous)
                    .frame(width: 17.5 * scaleX, height: barHeight)
                    .offset(x: 2.2 * scaleX, y: 10.4 * scaleY)

                // Bottom shorter horizontal bar
                Capsule(style: .continuous)
                    .frame(width: 10.5 * scaleX, height: barHeight)
                    .offset(x: 2.2 * scaleX, y: 15.8 * scaleY)

                // Bottom-right Play triangle
                LibraryPlayTriangleShape()
                    .fill(Color.white)
                    .overlay(
                        LibraryPlayTriangleShape()
                            .stroke(
                                Color.white,
                                style: StrokeStyle(
                                    lineWidth: 1.0 * min(scaleX, scaleY),
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )
                    )
                    .frame(width: w, height: h)
            }
        }
    }
}

private struct LibraryPlayTriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 24.0
        let sy = rect.height / 24.0
        var path = Path()
        path.move(to: CGPoint(x: 15.4 * sx, y: 13.5 * sy))
        path.addLine(to: CGPoint(x: 21.4 * sx, y: 17.0 * sy))
        path.addLine(to: CGPoint(x: 15.4 * sx, y: 20.5 * sy))
        path.closeSubpath()
        return path
    }
}

// MARK: - Subtle Press Style (No Opacity Flicker)

private struct FloatingTabItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct FloatingTabBar_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Spacer()
                FloatingTabBar(selectedTab: .constant(0))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .preferredColorScheme(.dark)
    }
}
