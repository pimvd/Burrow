import SwiftUI
import WebKit

/// Plays a YouTube video through the official inline embed.
///
/// The embed's JavaScript player API reports state changes back to the app, so
/// the playlist can move on when a video ends and a removed or private video can
/// be skipped without the child ever seeing an error.
///
/// The page the embed lives on is served from Burrow's own domain rather than
/// built here as a string. YouTube identifies an embedder through the HTTP
/// `Referer` header, and only a page loaded from a real origin sends one; a
/// string loaded into a web view does not, which is what the old `localhost`
/// base URL was working around. If the hosted page cannot be reached the app
/// falls back to that older behaviour, so a parent whose network — or whose
/// developer's hosting — is having a bad day still gets a video.
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

        /// The video that should be playing.
        private var requestedVideoID: String?
        /// The video the current page was navigated with, and `nil` until the
        /// first navigation. The two differ while the page is still loading.
        private var pageVideoID: String?
        /// Set once the page reports its player is built and can take commands.
        private var isPlayerReady = false
        /// The hosted page is only given up on once per player.
        private var didFallBack = false

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

        /// Points the player at a video.
        ///
        /// Only the first item costs a page load. Every item after it is handed
        /// to the page that is already open, so a playlist does not re-fetch the
        /// shell — or re-run the IFrame API — between songs.
        func load(videoID: String, into webView: WKWebView) {
            guard requestedVideoID != videoID else { return }
            requestedVideoID = videoID
            // Whatever was pushed into the previous video no longer describes
            // this one, which starts playing on its own.
            appliedIsPlaying = nil

            if pageVideoID == nil {
                navigate(to: videoID, in: webView)
            } else if isPlayerReady {
                switchVideo(to: videoID, in: webView)
            }
            // Otherwise the page is still loading; `ready` flushes the request.
        }

        /// Loads the hosted page, or the built-in copy when there is no usable
        /// address for the identifier.
        private func navigate(to videoID: String, in webView: WKWebView) {
            pageVideoID = videoID
            isPlayerReady = false

            guard let url = YouTubeLink.playerURL(videoID: videoID) else {
                loadFallbackPage(videoID: videoID, in: webView)
                return
            }
            webView.load(URLRequest(url: url))
        }

        private func switchVideo(to videoID: String, in webView: WKWebView) {
            pageVideoID = videoID
            let escaped = videoID.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
            webView.evaluateJavaScript("if (window.burrowLoad) { window.burrowLoad('\(escaped)'); }")
        }

        /// The pre-hosting behaviour, kept as a fallback. It identifies itself
        /// to YouTube less well, so it is second choice rather than the default.
        private func loadFallbackPage(videoID: String, in webView: WKWebView) {
            didFallBack = true
            pageVideoID = videoID
            isPlayerReady = false
            // The page must claim an origin of its own. Loading it as
            // youtube.com made the embed look like it was framed by YouTube
            // itself, which the player rejects with a 15x error for every
            // video. `localhost` is a legitimate secure origin.
            webView.loadHTMLString(
                Self.fallbackPlayerHTML(videoID: videoID),
                baseURL: URL(string: Self.fallbackOrigin)
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
            case "ready":
                isPlayerReady = true
                // The parent may have moved on while the page was loading.
                if let requestedVideoID, requestedVideoID != pageVideoID, let webView = message.webView {
                    switchVideo(to: requestedVideoID, in: webView)
                }
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

        /// Keeps the top frame on the player page.
        ///
        /// The embed's own frames are subframes and are left alone. Anything
        /// that would replace the page itself — or open a window — is refused,
        /// so no redirect can put the child somewhere else.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let targetFrame = navigationAction.targetFrame else {
                // No target frame means a request to open a new window, which
                // the child has no use for — unless it is the player page
                // itself, which some loads report this way.
                decisionHandler(Self.isPlayerPage(navigationAction.request.url) ? .allow : .cancel)
                return
            }
            guard targetFrame.isMainFrame else {
                decisionHandler(.allow)
                return
            }
            decisionHandler(Self.isPlayerPage(navigationAction.request.url) ? .allow : .cancel)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleNavigationFailure(error, in: webView)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            handleNavigationFailure(error, in: webView)
        }

        /// The hosted page being unreachable is not the child's problem: the
        /// built-in copy is tried once before anything is reported upward.
        private func handleNavigationFailure(_ error: Error, in webView: WKWebView) {
            if !didFallBack, let videoID = requestedVideoID {
                loadFallbackPage(videoID: videoID, in: webView)
                return
            }
            onFailed(error.localizedDescription)
        }

        /// The two pages the top frame may ever be: the hosted one, and the
        /// built-in copy under its own origin. `dismantleUIView` blanks the view
        /// on the way out, which has no URL at all.
        private static func isPlayerPage(_ url: URL?) -> Bool {
            guard let url else { return true }
            if url.absoluteString == "about:blank" { return true }
            if let hosted = URL(string: YouTubeLink.playerPageURL),
               url.host == hosted.host, url.path == hosted.path {
                return true
            }
            return url.host == URL(string: fallbackOrigin)?.host
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

        /// The origin the built-in fallback page is served under. Must not be a
        /// YouTube domain, or the embed is treated as framed by YouTube itself.
        private static let fallbackOrigin = "https://localhost"

        /// Privacy-enhanced host: no cookies are set until the child actually
        /// plays something.
        private static let playerHost = "https://www.youtube-nocookie.com"

        /// A copy of `website/player.html`, used only when the hosted page
        /// cannot be reached. Keep the two in step.
        private static func fallbackPlayerHTML(videoID: String) -> String {
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
              var captionSweep;

              function safeID(raw) {
                return String(raw || '').replace(/[^A-Za-z0-9_-]/g, '').slice(0, 11);
              }

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
              function startCaptionSweep() {
                if (captionSweep) { return; }
                var ticks = 0;
                captionSweep = setInterval(function () {
                  hideCaptions();
                  ticks += 1;
                  if (ticks >= 10) { clearInterval(captionSweep); captionSweep = null; }
                }, 700);
              }

              window.burrowLoad = function (rawID) {
                var id = safeID(rawID);
                if (!player || !id) { return; }
                if (captionSweep) { clearInterval(captionSweep); captionSweep = null; }
                player.loadVideoById(id);
              };

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
                    iv_load_policy: 3,
                    cc_load_policy: 0,
                    origin: '\(fallbackOrigin)'
                  },
                  events: {
                    onReady: function (event) {
                      post({ event: 'ready' });
                      event.target.playVideo();
                    },
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
