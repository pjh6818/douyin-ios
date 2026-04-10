enum DouyinJavaScript {

    // MARK: - atDocumentStart: fetch/XHR 인터셉트

    static let networkInterceptScript = """
    (function() {
        if (window.__douyinNetworkHooked) return;
        window.__douyinNetworkHooked = true;

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

        function findAllVideoInfo(obj, depth, parentDesc) {
            var results = [];
            if (!obj || depth > 8) return results;
            if (typeof obj !== 'object') return results;
            // 현재 레벨의 desc를 우선 사용
            var desc = obj.desc || parentDesc || '';
            if (obj.play_addr && obj.play_addr.url_list && obj.play_addr.url_list.length > 0) {
                var url = obj.play_addr.url_list[0];
                if (isRealVideoURL(url)) {
                    results.push({ url: url, desc: desc });
                }
                return results;
            }
            if (Array.isArray(obj)) {
                for (var i = 0; i < Math.min(obj.length, 50); i++) {
                    results = results.concat(findAllVideoInfo(obj[i], depth + 1, desc));
                }
            } else {
                for (var key in obj) {
                    if (!obj.hasOwnProperty(key)) continue;
                    results = results.concat(findAllVideoInfo(obj[key], depth + 1, desc));
                }
            }
            return results;
        }

        if (!window.__douyinFeedState) {
            window.__douyinFeedState = { cursor: null, hasMore: true, refreshIndex: 2 };
        }

        function extractURLsFromText(text) {
            try {
                var obj = JSON.parse(text);
                var items = findAllVideoInfo(obj, 0);
                if (items.length > 0) {
                    post('videoInfoList', JSON.stringify(items));
                }
            } catch(e) {}
        }

        // fetch 인터셉트 (string URL + Request 객체 모두 처리)
        var origFetch = window.fetch;
        window.fetch = function() {
            var input = arguments[0];
            var url = typeof input === 'string' ? input :
                      (input && input.url ? input.url : '');
            return origFetch.apply(this, arguments).then(function(response) {
                if (url) {
                    var clone = response.clone();
                    clone.text().then(function(text) {
                        if (text.includes('play_addr')) {
                            extractURLsFromText(text);
                        }
                    }).catch(function(){});
                }
                return response;
            });
        };

        // XHR 인터셉트
        var origXHROpen = XMLHttpRequest.prototype.open;
        var origXHRSend = XMLHttpRequest.prototype.send;
        XMLHttpRequest.prototype.open = function(method, url) {
            this.__douyinURL = url;
            return origXHROpen.apply(this, arguments);
        };
        XMLHttpRequest.prototype.send = function() {
            var xhr = this;
            xhr.addEventListener('readystatechange', function() {
                if (xhr.readyState !== 4) return;
                try {
                    var text;
                    if (xhr.responseType === '' || xhr.responseType === 'text') {
                        text = xhr.responseText;
                    } else if (xhr.responseType === 'json') {
                        text = JSON.stringify(xhr.response);
                    }
                    if (text && text.includes('play_addr')) {
                        extractURLsFromText(text);
                    }
                } catch(e) {}
            });
            return origXHRSend.apply(this, arguments);
        };
    })();
    """

    // MARK: - atDocumentEnd: DOM 감시, SSR 추출, video 이벤트

    static let videoInterceptScript = """
    (function() {
        if (window.__douyinDOMInstalled) return;
        window.__douyinDOMInstalled = true;

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

        // --- IntersectionObserver ---
        var visibleVideos = new Set();
        var videoIntersectionObserver = new IntersectionObserver(function(entries) {
            entries.forEach(function(entry) {
                if (entry.isIntersecting) {
                    visibleVideos.add(entry.target);
                } else {
                    visibleVideos.delete(entry.target);
                }
            });
            updateVisibleVideoSrc();
        }, { threshold: 0.5 });

        function findVideoDesc(videoEl) {
            // video 요소에서 위로 올라가며 제목 텍스트 탐색
            var el = videoEl;
            for (var i = 0; i < 8 && el; i++) {
                el = el.parentElement;
                if (!el) break;
                // Douyin 모바일: 영상 설명이 근처 텍스트 노드에 있음
                var candidates = el.querySelectorAll('[class*="desc"], [class*="title"], [class*="text"], [class*="caption"]');
                for (var j = 0; j < candidates.length; j++) {
                    var t = (candidates[j].textContent || '').trim();
                    if (t.length > 2 && t.length < 300) return t;
                }
            }
            return '';
        }

        function updateVisibleVideoSrc() {
            var bestVideo = null;
            var best = null;
            visibleVideos.forEach(function(v) {
                var src = getVideoSrc(v);
                if (!v.paused && isRealVideoURL(src)) {
                    best = src; bestVideo = v;
                } else if (!best && isRealVideoURL(src)) {
                    best = src; bestVideo = v;
                }
            });
            if (best) {
                window.__douyinCurrentVisibleVideoSrc = best;
                var desc = bestVideo ? findVideoDesc(bestVideo) : '';
                post('visibleVideo', JSON.stringify({ url: best, desc: desc }));
            }
        }

        function hookVideoEvents(video) {
            if (video.__douyinEvtHooked) return;
            video.__douyinEvtHooked = true;
            videoIntersectionObserver.observe(video);
            video.addEventListener('play', function() {
                setTimeout(updateVisibleVideoSrc, 200);
            });
            video.addEventListener('loadeddata', function() {
                setTimeout(updateVisibleVideoSrc, 200);
            });
        }

        // DOM 감시
        document.querySelectorAll('video').forEach(hookVideoEvents);

        var videoObserver = new MutationObserver(function(mutations) {
            for (var i = 0; i < mutations.length; i++) {
                var mut = mutations[i];
                for (var j = 0; j < mut.addedNodes.length; j++) {
                    var node = mut.addedNodes[j];
                    if (node.nodeName === 'VIDEO') {
                        hookVideoEvents(node);
                    } else if (node.querySelectorAll) {
                        node.querySelectorAll('video').forEach(hookVideoEvents);
                    }
                    if (mut.type === 'attributes' && mut.target.nodeName === 'VIDEO') {
                        setTimeout(updateVisibleVideoSrc, 200);
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
                    updateVisibleVideoSrc();
                }, 800);
            }
        }, 300);

        setTimeout(updateVisibleVideoSrc, 1500);
    })();
    """

    // MARK: - 프리페치: tab/feed API 직접 호출

    static let scrollToLoadMoreScript = """
    (function() {
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
        function findAllVideoInfo(o, depth, parentDesc) {
            var results = [];
            if (!o || depth > 8 || typeof o !== 'object') return results;
            var desc = o.desc || parentDesc || '';
            if (o.play_addr && o.play_addr.url_list && o.play_addr.url_list.length > 0) {
                var u = o.play_addr.url_list[0];
                if (isRealVideoURL(u)) results.push({ url: u, desc: desc });
                return results;
            }
            if (Array.isArray(o)) {
                for (var i = 0; i < Math.min(o.length, 50); i++)
                    results = results.concat(findAllVideoInfo(o[i], depth + 1, desc));
            } else {
                for (var k in o) {
                    if (o.hasOwnProperty(k))
                        results = results.concat(findAllVideoInfo(o[k], depth + 1, desc));
                }
            }
            return results;
        }

        var state = window.__douyinFeedState || {};
        var refreshIndex = state.refreshIndex || 2;
        state.refreshIndex = refreshIndex + 1;
        window.__douyinFeedState = state;

        // tab/feed API 직접 호출 (URL 패턴은 로그에서 확보)
        var params = new URLSearchParams({
            device_platform: 'webapp',
            aid: '6383',
            channel: 'channel_pc_web',
            count: '10',
            refresh_index: String(refreshIndex),
            video_type_select: '1',
            filterGids: '',
            tag_id: '',
            share_aweme_id: '',
            live_insert_type: ''
        });
        if (state.cursor) {
            params.set('cursor', state.cursor);
            params.set('max_cursor', state.cursor);
        }
        var url = 'https://www.douyin.com/aweme/v1/web/tab/feed/?' + params.toString();

        fetch(url, { credentials: 'include' }).then(function(r) {
            if (!r.ok) {
                post('prefetchStatus', 'fetchError_' + r.status);
                return null;
            }
            return r.text();
        }).then(function(text) {
            if (!text) return;
            try {
                var obj = JSON.parse(text);
                if (obj.cursor !== undefined) state.cursor = obj.cursor;
                if (obj.max_cursor !== undefined) state.cursor = obj.max_cursor;
                if (obj.has_more !== undefined) state.hasMore = !!obj.has_more;

                var items = findAllVideoInfo(obj, 0);
                if (items.length > 0) {
                    post('videoInfoList', JSON.stringify(items));
                    post('prefetchStatus', 'fetched_' + items.length);
                } else {
                    post('prefetchStatus', 'noVideosInResponse');
                }
            } catch(e) {
                post('prefetchStatus', 'parseError');
            }
        }).catch(function(e) {
            post('prefetchStatus', 'fetchException');
        });
    })();
    """

    /// Play 버튼 탭 시 현재 보이는 영상 URL 반환
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
            if (!src && v.querySelector('source')) { src = v.querySelector('source').src || ''; }
            return src;
        }
        if (window.__douyinCurrentVisibleVideoSrc && isRealVideoURL(window.__douyinCurrentVisibleVideoSrc)) {
            return window.__douyinCurrentVisibleVideoSrc;
        }
        var videos = document.querySelectorAll('video');
        for (var i = 0; i < videos.length; i++) {
            if (!videos[i].paused) {
                var src = getVideoSrc(videos[i]);
                if (isRealVideoURL(src)) return src;
            }
        }
        var vh = window.innerHeight || document.documentElement.clientHeight;
        for (var i = 0; i < videos.length; i++) {
            var rect = videos[i].getBoundingClientRect();
            if (rect.top < vh && rect.bottom > 0 && rect.height > 0) {
                var src = getVideoSrc(videos[i]);
                if (isRealVideoURL(src)) return src;
            }
        }
        for (var i = 0; i < videos.length; i++) {
            var src = getVideoSrc(videos[i]);
            if (isRealVideoURL(src)) return src;
        }
        return null;
    })();
    """

}
