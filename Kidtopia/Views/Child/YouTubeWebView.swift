import SwiftUI
import WebKit

/// Plays a YouTube video through the official inline embed.
///
/// The embed's JavaScript player API reports state changes back to the app, so
/// the playlist can move on when a video ends and a removed or private video can
/// be skipped without the child ever seeing an error.
struct YouTubeWebView: UIViewRepresentable {
    let videoID: String

    /// Called when the video played to its end.
    let onFinished: () -> Void

    /// Called with a parent-facing description when the video cannot play.
    let onFailed: (String) -> Void

    let onStartedPlaying: () -> Void
    let onPaused: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onFinished: onFinished,
            onFailed: onFailed,
            onStartedPlaying: onStartedPlaying,
            onPaused: onPaused
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        // Nothing is persisted between sessions: no cookies, no local storage.
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: Coordinator.messageHandlerName)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        // The child never navigates the web view itself.
        webView.allowsBackForwardNavigationGestures = false
        webView.navigationDelegate = context.coordinator

        context.coordinator.load(videoID: videoID, into: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.load(videoID: videoID, into: webView)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: Coordinator.messageHandlerName
        )
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        static let messageHandlerName = "kidtopia"

        private let onFinished: () -> Void
        private let onFailed: (String) -> Void
        private let onStartedPlaying: () -> Void
        private let onPaused: () -> Void
        private var loadedVideoID: String?

        init(
            onFinished: @escaping () -> Void,
            onFailed: @escaping (String) -> Void,
            onStartedPlaying: @escaping () -> Void,
            onPaused: @escaping () -> Void
        ) {
            self.onFinished = onFinished
            self.onFailed = onFailed
            self.onStartedPlaying = onStartedPlaying
            self.onPaused = onPaused
        }

        func load(videoID: String, into webView: WKWebView) {
            guard loadedVideoID != videoID else { return }
            loadedVideoID = videoID
            webView.loadHTMLString(Self.playerHTML(videoID: videoID), baseURL: URL(string: "https://www.youtube.com"))
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let body = message.body as? [String: Any],
                  let event = body["event"] as? String else {
                return
            }

            switch event {
            case "ended":
                onFinished()
            case "playing":
                onStartedPlaying()
            case "paused":
                onPaused()
            case "error":
                let code = body["code"] as? Int ?? -1
                onFailed(Self.message(forErrorCode: code))
            default:
                break
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onFailed(error.localizedDescription)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            onFailed(error.localizedDescription)
        }

        /// The YouTube IFrame API error codes, translated into something a
        /// parent can act on.
        private static func message(forErrorCode code: Int) -> String {
            switch code {
            case 2:
                return String(
                    localized: "This YouTube link is not valid.",
                    comment: "YouTube embed error"
                )
            case 5:
                return String(
                    localized: "This video cannot be played on this device.",
                    comment: "YouTube embed error"
                )
            case 100:
                return String(
                    localized: "Video unavailable — it was removed or made private.",
                    comment: "YouTube embed error"
                )
            case 101, 150:
                return String(
                    localized: "The owner of this video does not allow it to be played outside YouTube.",
                    comment: "YouTube embed error"
                )
            default:
                return String(
                    localized: "This video could not be played.",
                    comment: "YouTube embed error"
                )
            }
        }

        private static func playerHTML(videoID: String) -> String {
            // The identifier is validated by `YouTubeLink` before it is stored,
            // so only the 11 unreserved characters can reach this template.
            let safeID = videoID.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
            return """
            <!DOCTYPE html>
            <html>
            <head>
            <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
            <style>
              html, body { margin: 0; padding: 0; background: transparent; height: 100%; overflow: hidden; }
              #player { width: 100%; height: 100%; }
            </style>
            </head>
            <body>
            <div id="player"></div>
            <script src="https://www.youtube.com/iframe_api"></script>
            <script>
              function post(payload) {
                window.webkit.messageHandlers.\(messageHandlerName).postMessage(payload);
              }
              var player;
              function onYouTubeIframeAPIReady() {
                player = new YT.Player('player', {
                  videoId: '\(safeID)',
                  playerVars: {
                    playsinline: 1,
                    autoplay: 1,
                    controls: 0,
                    disablekb: 1,
                    fs: 0,
                    rel: 0,
                    modestbranding: 1,
                    iv_load_policy: 3
                  },
                  events: {
                    onReady: function (event) { event.target.playVideo(); },
                    onStateChange: function (event) {
                      if (event.data === YT.PlayerState.ENDED) { post({ event: 'ended' }); }
                      else if (event.data === YT.PlayerState.PLAYING) { post({ event: 'playing' }); }
                      else if (event.data === YT.PlayerState.PAUSED) { post({ event: 'paused' }); }
                    },
                    onError: function (event) { post({ event: 'error', code: event.data }); }
                  }
                });
              }
              window.addEventListener('error', function () { post({ event: 'error', code: -1 }); });
            </script>
            </body>
            </html>
            """
        }
    }
}
