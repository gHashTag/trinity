// Web View — Web Content Display
import SwiftUI
@preconcurrency import WebKit

// MARK: - Web View

struct WebView: NSViewRepresentable {
    let url: URL?
    let html: String?
    @Binding var isLoading: Bool
    @Binding var title: String?
    let onNavigationFinished: (() -> Void)?

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        var didFinish = false

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            webView.evaluateJavaScript("document.title") { result, error in
                if let title = result as? String {
                    self.parent.title = title
                }
            }
            self.parent.onNavigationFinished?()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.targetFrame == nil {
                decisionHandler(.cancel)
                NSWorkspace.shared.open(navigationAction.request.url!)
            } else {
                decisionHandler(.allow)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        if let html = html {
            webView.loadHTMLString(html, baseURL: nil)
        } else if let url = url {
            let request = URLRequest(url: url)
            webView.load(request)
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Update logic if needed
    }
}

// MARK: - Simple Web View

struct SimpleWebView: View {
    let url: URL
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(V4Color.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError = error {
                VStack(spacing: ParietalSpacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(WernickeTypography.size32)
                        .foregroundStyle(V4Color.warning)

                    Text("Failed to load page")
                        .font(WernickeTypography.body14Medium)
                        .foregroundStyle(V4Color.textPrimary)

                    Text(loadError.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(V4Color.textSecondary)

                    Button {
                        isLoading = true
                        error = nil
                    } label: {
                        Text("Retry")
                            .font(WernickeTypography.size13)
                            .foregroundStyle(.white)
                            .padding(.horizontal, ParietalSpacing.lg)
                            .padding(.vertical, ParietalSpacing.xs + 2)
                            .background(V4Color.accent)
                            .cornerRadius(V1Theme.cornerSmall)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                WebView(
                    url: url,
                    html: nil,
                    isLoading: $isLoading,
                    title: .constant(nil),
                    onNavigationFinished: nil
                )
            }
        }
    }
}

// MARK: - HTML Content View

struct HTMLContentView: View {
    let html: String
    let baseURL: URL?
    @State private var isLoading = false

    var body: some View {
        WebView(
            url: nil,
            html: html,
            isLoading: $isLoading,
            title: .constant(nil),
            onNavigationFinished: nil
        )
    }
}

// MARK: - Markdown Web View

struct MarkdownWebView: View {
    let markdown: String
    @State private var html: String = ""

    var body: some View {
        HTMLContentView(html: renderMarkdown(markdown), baseURL: nil)
    }

    private func renderMarkdown(_ markdown: String) -> String {
        // Simple markdown to HTML conversion
        let html = markdown
            .replacingOccurrences(of: "\\n\\n", with: "</p><p>")
            .replacingOccurrences(of: "\\n", with: "<br>")
            .replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>")
            .replacingOccurrences(of: "\\*(.+?)\\*", with: "<em>$1</em>")
            .replacingOccurrences(of: "`(.+?)`", with: "<code>$1</code>")

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body { font-family: -apple-system, sans-serif; padding: 20px; line-height: 1.6; }
                code { background: #f4f4f4; padding: 2px 6px; border-radius: 4px; }
            </style>
        </head>
        <body><p>\(html)</p></body>
        </html>
        """
    }
}

// MARK: - Preview

struct WebView_Previews: PreviewProvider {
    static var previews: some View {
        SimpleWebView(url: URL(string: "https://example.com")!)
            .frame(width: ParietalSpacing.sheetWidth, height: ParietalSpacing.mediumModalFrame)

        MarkdownWebView(markdown: "# Hello\n\nThis is **bold** and *italic*.")
            .frame(width: ParietalSpacing.sheetWidth, height: ParietalSpacing.modalFrame)
    }
}
