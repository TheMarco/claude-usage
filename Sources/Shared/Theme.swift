import SwiftUI

/// Flat single-color palette. No gradients anywhere — what you see in
/// SwiftUI's `.foregroundStyle(Theme.claudeAngular)` evaluates to one color.
enum Theme {
    // Brand accents — Claude matches the clawd.png pixel color exactly.
    static let claude = Color(red: 216/255.0, green: 139/255.0, blue: 101/255.0)  // #D88B65
    static let codex  = Color(red:  77/255.0, green: 140/255.0, blue: 255/255.0)  // #4D8CFF

    // Backwards-compatible aliases used by existing call sites — all flat.
    static let claudeStart = claude
    static let claudeMid   = claude
    static let claudeEnd   = claude
    static let codexStart  = codex
    static let codexMid    = codex
    static let codexEnd    = codex

    static let claudeLinear = LinearGradient(colors: [claude],
                                             startPoint: .top, endPoint: .bottom)
    static let codexLinear  = LinearGradient(colors: [codex],
                                             startPoint: .top, endPoint: .bottom)

    static let claudeAngular = AngularGradient(
        gradient: Gradient(colors: [claude, claude]), center: .center
    )
    static let codexAngular = AngularGradient(
        gradient: Gradient(colors: [codex, codex]), center: .center
    )
    static let combinedAngular = AngularGradient(
        gradient: Gradient(colors: [claude, codex, claude]), center: .center
    )

    // Surface — flat dark, no gradient and no overlay highlight.
    static let surface = Color(red: 0.06, green: 0.06, blue: 0.08)
    static let backgroundGradient = LinearGradient(colors: [surface],
                                                   startPoint: .top, endPoint: .bottom)
    static let highlightOverlay = Color.clear

    static let trackColor = Color.white.opacity(0.07)
}
