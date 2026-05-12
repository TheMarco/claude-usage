import SwiftUI
import WebKit

/// Drops the user into the real claude.ai login page (WKWebView) and grabs
/// the `sessionKey` cookie out of the web view's cookie jar after the user
/// signs in. No paste required.
struct ClaudeAILoginSheet: View {
    @Binding var isPresented: Bool
    let onCapture: (String) -> Void

    @State private var statusText: String = "Loading claude.ai…"
    @State private var captured: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.tint)
                Text("Sign in to claude.ai")
                    .font(.headline)
                Spacer()
                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Button("Cancel") { isPresented = false }
                    .controlSize(.small)
            }
            .padding(12)
            .background(.regularMaterial)

            Divider()

            ClaudeAIWebView(
                statusText: $statusText,
                onCapture: { key in
                    guard !captured else { return }
                    captured = true
                    onCapture(key)
                    isPresented = false
                }
            )
            .frame(minWidth: 720, idealWidth: 760, minHeight: 720, idealHeight: 760)
        }
        .frame(minWidth: 720, minHeight: 760)
    }
}

private struct ClaudeAIWebView: NSViewRepresentable {
    @Binding var statusText: String
    let onCapture: (String) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Persistent cookie store so the user stays logged in across launches.
        config.websiteDataStore = .default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        view.customUserAgent =
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"

        // If the user is already signed in (cookie present from a previous session),
        // we can capture immediately without even showing the login flow.
        context.coordinator.checkExistingCookie(view: view) { found in
            if !found {
                view.load(URLRequest(url: URL(string: "https://claude.ai/login")!))
            }
        }
        context.coordinator.webView = view
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(statusText: $statusText, onCapture: onCapture)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKHTTPCookieStoreObserver {
        @Binding var statusText: String
        let onCapture: (String) -> Void
        weak var webView: WKWebView? {
            didSet {
                guard let store = webView?.configuration.websiteDataStore.httpCookieStore else { return }
                store.add(self)              // event-driven capture
                startPollTimer()             // belt-and-suspenders
            }
        }
        private var pollTimer: Timer?
        private var captured = false

        init(statusText: Binding<String>, onCapture: @escaping (String) -> Void) {
            self._statusText = statusText
            self.onCapture = onCapture
        }

        deinit {
            pollTimer?.invalidate()
            webView?.configuration.websiteDataStore.httpCookieStore.remove(self)
        }

        private func startPollTimer() {
            pollTimer?.invalidate()
            pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
                guard let self, let view = self.webView else { return }
                self.poll(webView: view)
            }
        }

        // MARK: WKHTTPCookieStoreObserver
        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            cookieStore.getAllCookies { [weak self] cookies in
                self?.handle(cookies: cookies)
            }
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            updateStatus(for: webView.url)
            poll(webView: webView)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            updateStatus(for: webView.url)
        }

        // MARK: WKUIDelegate (Google SSO popups)

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url, navigationAction.targetFrame == nil {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        // MARK: Helpers

        func checkExistingCookie(view: WKWebView, completion: @escaping (Bool) -> Void) {
            view.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                if Self.sessionKey(in: cookies) != nil {
                    self?.handle(cookies: cookies)
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }

        private func poll(webView: WKWebView) {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                self?.handle(cookies: cookies)
            }
        }

        private func handle(cookies: [HTTPCookie]) {
            guard !captured, let key = Self.sessionKey(in: cookies) else { return }
            captured = true
            pollTimer?.invalidate()
            statusText = "Captured sessionKey"
            DispatchQueue.main.async { self.onCapture(key) }
        }

        private func updateStatus(for url: URL?) {
            guard let url else { return }
            if url.path.contains("login") || url.path.contains("magic-link") {
                statusText = "Sign in below…"
            } else {
                statusText = url.host ?? ""
            }
        }

        private static func sessionKey(in cookies: [HTTPCookie]) -> String? {
            for c in cookies
            where c.name == "sessionKey"
                && c.domain.contains("claude.ai")
                && !c.value.isEmpty {
                return c.value
            }
            return nil
        }
    }
}
