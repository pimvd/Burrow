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

    /// Drives the embed. The IFrame player can only be paused by calling into
    /// its JavaScript API, so the transport state has to be pushed in here.
    let isPlaying: Bool

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
        context.coordinator.apply(isPlaying: isPlaying, to: webView)
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
        static let messageHandlerName = "burrow"

        private let onFinished: () -> Void
        private let onFailed: (String) -> Void
        private let onStartedPlaying: () -> Void
        private let onPaused: () -> Void
        private var loadedVideoID: String?

        /// The transport state last pushed into the embed, so a command is only
        /// sent when it actually changes. The player also reports its own state
        /// back, and without this every report would bounce a command back at it.
        private var appliedIsPlaying: Bool?

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

        /// Pushes the transport state into the embed's JavaScript player.
        func apply(isPlaying: Bool, to webView: WKWebView) {
            guard appliedIsPlaying != isPlaying else { return }
            appliedIsPlaying = isPlaying
            // `player` only exists once the IFrame API has finished loading; a
            // command that arrives before then is dropped rather than throwing.
            let call = isPlaying ? "playVideo" : "pauseVideo"
            webView.evaluateJavaScript(
                "if (window.player && window.player.\(call)) { window.player.\(call)(); }"
            )
        }

        func load(videoID: String, into webView: WKWebView) {
            guard loadedVideoID != videoID else { return }
            loadedVideoID = videoID
            // A fresh page autoplays, so whatever was pushed into the previous
            // one no longer describes this player.
            appliedIsPlaying = nil
            // The page must claim an origin of its own. Loading it as
            // youtube.com made the embed look like it was framed by YouTube
            // itself, which the player rejects with a 15x error for every
            // video. `localhost` is a legitimate secure origin.
            webView.loadHTMLString(
                Self.playerHTML(videoID: videoID),
                baseURL: URL(string: Self.playerOrigin)
            )
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

        /// The origin the player page is served under. Must not be a YouTube
        /// domain, or the embed is treated as framed by YouTube itself.
        private static let playerOrigin = "https://localhost"

        /// Privacy-enhanced host: no cookies are set until the child actually
        /// plays something.
        private static let playerHost = "https://www.youtube-nocookie.com"

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

              // Clearing the caption track is the only thing that actually
              // removes subtitles. `cc_load_policy` does not suppress
              // auto-generated ones, and `unloadModule` leaves them running.
              function hideCaptions() {
                if (!player) { return; }
                try { player.setOption('captions', 'track', {}); } catch (e) {}
                try { player.setOption('cc', 'track', {}); } catch (e) {}
              }

              // The captions module only loads a second or two after playback
              // starts, so one call at that moment is too early to catch it.
              var captionSweep;
              function startCaptionSweep() {
                if (captionSweep) { return; }
                var ticks = 0;
                captionSweep = setInterval(function () {
                  hideCaptions();
                  ticks += 1;
                  if (ticks >= 10) { clearInterval(captionSweep); captionSweep = null; }
                }, 700);
              }

              function onYouTubeIframeAPIReady() {
                player = new YT.Player('player', {
                  host: '\(playerHost)',
                  videoId: '\(safeID)',
                  playerVars: {
                    playsinline: 1,
                    autoplay: 1,
                    controls: 0,
                    disablekb: 1,
                    fs: 0,
                    rel: 0,
                    modestbranding: 1,
                    iv_load_policy: 3,
                    cc_load_policy: 0,
                    origin: '\(playerOrigin)'
                  },
                  events: {
                    onReady: function (event) { event.target.playVideo(); },
                    onStateChange: function (event) {
                      hideCaptions();
                      if (event.data === YT.PlayerState.ENDED) { post({ event: 'ended' }); }
                      else if (event.data === YT.PlayerState.PLAYING) {
                        startCaptionSweep();
                        post({ event: 'playing' });
                      }
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
