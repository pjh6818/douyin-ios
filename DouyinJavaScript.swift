enum DouyinJavaScript {

    /// Injected once at document end — background monitoring for button enablement.
    /// Tracks the currently visible video via IntersectionObserver and reports URL changes.
    static let videoInterceptScript = """
    (function() {
        if (window.__douyinInterceptInstalled) return;
        window.__douyinInterceptInstalled = true;

        var lastSentURL = '';
        window.__douyinCurrentVisibleVideoSrc = null;

        function post(type, value) {
            try { window.webkit.messageHandlers.douyin.postMessage({type: type, value: value}); } catch(e) {}
        }

        function isRealVideoURL(url) {
            if (!url || url.length < 30) return false;
            if (url.startsWith('blob:')) return false;
            return url.includes('douyinvod') || url.includes('video_id=') ||
                   url.includes('tos-cn-ve') || url.includes('bytecdn') ||
                   url.includes('zjcdn.com') || url.includes('/video/tos/');
        }

        function getVideoSrc(v) {
            var src = v.src || '';
            if (!src && v.querySelector('source')) {
                src = v.querySelector('source').src || '';
            }
            return src;
        }

        function sendURL(src, source) {
            if (isRealVideoURL(src) && src !== lastSentURL) {
                lastSentURL = src;
                post(source, src);
                return true;
            }
            return false;
        }

        function extractFromVideos() {
            var videos = document.querySelectorAll('video');
            for (var i = 0; i < videos.length; i++) {
                var src = getVideoSrc(videos[i]);
                if (sendURL(src, 'videoSrc')) return true;
            }
            return false;
        }

        // --- IntersectionObserver: track which video is currently visible ---
        var visibleVideos = new Set();
        var videoIntersectionObserver = new IntersectionObserver(function(entries) {
            entries.forEach(function(entry) {
                if (entry.isIntersecting) {
                    visibleVideos.add(entry.target);
                } else {
                    visibleVideos.delete(entry.target);
                }
            });
            // Update the current visible video src
            updateVisibleVideoSrc();
        }, { threshold: 0.5 });

        function updateVisibleVideoSrc() {
            var best = null;
            visibleVideos.forEach(function(v) {
                var src = getVideoSrc(v);
                // Prefer playing video, then any with a real URL
                if (!v.paused && isRealVideoURL(src)) {
                    best = src;
                } else if (!best && isRealVideoURL(src)) {
                    best = src;
                }
            });
            if (best) {
                window.__douyinCurrentVisibleVideoSrc = best;
                // Also notify Swift so the button stays enabled
                sendURL(best, 'visibleVideo');
            }
        }

        function observeVideo(video) {
            videoIntersectionObserver.observe(video);
        }

        function hookVideoEvents(video) {
            if (video.__douyinEvtHooked) return;
            video.__douyinEvtHooked = true;
            observeVideo(video);
            video.addEventListener('play', function() {
                setTimeout(function() { extractFromVideos(); updateVisibleVideoSrc(); }, 200);
            });
            video.addEventListener('loadeddata', function() {
                setTimeout(function() { extractFromVideos(); updateVisibleVideoSrc(); }, 200);
            });
        }

        function findPlayAddr(obj, depth) {
            if (!obj || depth > 8) return null;
            if (typeof obj !== 'object') return null;
            if (obj.play_addr && obj.play_addr.url_list && obj.play_addr.url_list.length > 0) {
                return obj.play_addr.url_list[0];
            }
            if (Array.isArray(obj)) {
                for (var i = 0; i < Math.min(obj.length, 20); i++) {
                    var r = findPlayAddr(obj[i], depth + 1);
                    if (r) return r;
                }
            } else {
                for (var key in obj) {
                    if (!obj.hasOwnProperty(key)) continue;
                    var r = findPlayAddr(obj[key], depth + 1);
                    if (r) return r;
                }
            }
            return null;
        }

        function extractFromSSR() {
            try {
                if (window._ROUTER_DATA) {
                    var url = findPlayAddr(window._ROUTER_DATA, 0);
                    if (sendURL(url, 'ssrData')) return true;
                }
            } catch(e) {}
            try {
                var el = document.getElementById('RENDER_DATA');
                if (el) {
                    var data = JSON.parse(decodeURIComponent(el.textContent));
                    var url = findPlayAddr(data, 0);
                    if (sendURL(url, 'ssrData')) return true;
                }
            } catch(e) {}
            return false;
        }

        function extractURLsFromText(text) {
            try {
                var obj = JSON.parse(text);
                var url = findPlayAddr(obj, 0);
                if (url) sendURL(url, 'apiIntercept');
            } catch(e) {}
        }

        var origFetch = window.fetch;
        window.fetch = function() {
            var url = arguments[0];
            if (typeof url === 'string') {
                return origFetch.apply(this, arguments).then(function(response) {
                    var clone = response.clone();
                    clone.text().then(function(text) {
                        if (text.includes('play_addr')) {
                            extractURLsFromText(text);
                        }
                    }).catch(function(){});
                    return response;
                });
            }
            return origFetch.apply(this, arguments);
        };

        var origXHROpen = XMLHttpRequest.prototype.open;
        var origXHRSend = XMLHttpRequest.prototype.send;
        XMLHttpRequest.prototype.open = function(method, url) {
            this.__douyinURL = url;
            return origXHROpen.apply(this, arguments);
        };
        XMLHttpRequest.prototype.send = function() {
            var xhr = this;
            xhr.addEventListener('load', function() {
                try {
                    var text = xhr.responseText;
                    if (text && text.includes('play_addr')) {
                        extractURLsFromText(text);
                    }
                } catch(e) {}
            });
            return origXHRSend.apply(this, arguments);
        };

        document.querySelectorAll('video').forEach(hookVideoEvents);

        var videoObserver = new MutationObserver(function(mutations) {
            for (var i = 0; i < mutations.length; i++) {
                var mut = mutations[i];
                for (var j = 0; j < mut.addedNodes.length; j++) {
                    var node = mut.addedNodes[j];
                    if (node.nodeName === 'VIDEO') {
                        hookVideoEvents(node);
                        setTimeout(extractFromVideos, 300);
                    } else if (node.querySelectorAll) {
                        node.querySelectorAll('video').forEach(hookVideoEvents);
                        if (node.querySelectorAll('video').length > 0) {
                            setTimeout(extractFromVideos, 300);
                        }
                    }
                    if (mut.type === 'attributes' && mut.target.nodeName === 'VIDEO') {
                        setTimeout(extractFromVideos, 200);
                    }
                }
            }
        });
        videoObserver.observe(document.documentElement, {
            childList: true, subtree: true, attributes: true, attributeFilter: ['src']
        });

        var lastURL = location.href;
        setInterval(function() {
            if (location.href !== lastURL) {
                lastURL = location.href;
                post('urlChanged', lastURL);
                setTimeout(function() {
                    document.querySelectorAll('video').forEach(hookVideoEvents);
                    extractFromVideos() || extractFromSSR();
                }, 800);
            }
        }, 300);

        setTimeout(function() {
            extractFromVideos() || extractFromSSR();
        }, 1500);
    })();
    """

    /// Called on-demand when the user taps Play.
    /// Returns the src of the currently visible/playing video element.
    static let getCurrentVideoScript = """
    (function() {
        function isRealVideoURL(url) {
            if (!url || url.length < 30) return false;
            if (url.startsWith('blob:')) return false;
            return url.includes('douyinvod') || url.includes('video_id=') ||
                   url.includes('tos-cn-ve') || url.includes('bytecdn') ||
                   url.includes('zjcdn.com') || url.includes('/video/tos/');
        }
        function getVideoSrc(v) {
            var src = v.src || '';
            if (!src && v.querySelector('source')) {
                src = v.querySelector('source').src || '';
            }
            return src;
        }

        // 1) Prefer the cached visible-video src from IntersectionObserver
        if (window.__douyinCurrentVisibleVideoSrc &&
            isRealVideoURL(window.__douyinCurrentVisibleVideoSrc)) {
            return window.__douyinCurrentVisibleVideoSrc;
        }

        // 2) Find a currently-playing video with a real URL
        var videos = document.querySelectorAll('video');
        for (var i = 0; i < videos.length; i++) {
            var v = videos[i];
            if (!v.paused) {
                var src = getVideoSrc(v);
                if (isRealVideoURL(src)) return src;
            }
        }

        // 3) Find any video in the viewport with a real URL
        var viewportHeight = window.innerHeight || document.documentElement.clientHeight;
        for (var i = 0; i < videos.length; i++) {
            var rect = videos[i].getBoundingClientRect();
            var visible = rect.top < viewportHeight && rect.bottom > 0 &&
                          rect.height > 0 && rect.width > 0;
            if (visible) {
                var src = getVideoSrc(videos[i]);
                if (isRealVideoURL(src)) return src;
            }
        }

        // 4) Fallback — any video with a real URL
        for (var i = 0; i < videos.length; i++) {
            var src = getVideoSrc(videos[i]);
            if (isRealVideoURL(src)) return src;
        }

        return null;
    })();
    """
}
