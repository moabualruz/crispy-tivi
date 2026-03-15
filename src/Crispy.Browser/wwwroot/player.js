// CrispyTivi browser player bridge
// Controlled by HtmlVideoPlayerService.cs via JS interop.
// Supports native HTML5 video for HTTP progressive / HLS (via hls.js).

let videoEl = null;
let hlsInstance = null;
let dotNetRef = null;

function getOrCreateVideo() {
    if (!videoEl) {
        videoEl = document.createElement('video');
        videoEl.id = 'crispy-player';
        videoEl.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;background:#000;z-index:9000;display:none;';
        document.body.appendChild(videoEl);

        videoEl.addEventListener('playing', () => dotNetRef?.invokeMethodAsync('OnPlaying'));
        videoEl.addEventListener('waiting', () => dotNetRef?.invokeMethodAsync('OnBuffering'));
        videoEl.addEventListener('timeupdate', () => {
            if (dotNetRef) {
                dotNetRef.invokeMethodAsync('OnTimeUpdate', Math.floor(videoEl.currentTime * 1000));
            }
        });
        videoEl.addEventListener('error', () => {
            const msg = videoEl.error?.message ?? 'Unknown playback error';
            dotNetRef?.invokeMethodAsync('OnError', msg);
        });
    }
    return videoEl;
}

function destroyHls() {
    if (hlsInstance) {
        hlsInstance.destroy();
        hlsInstance = null;
    }
}

export function play(url, ref) {
    dotNetRef = ref;
    const video = getOrCreateVideo();

    destroyHls();
    video.style.display = 'block';

    const isHls = url.toLowerCase().includes('.m3u8') || url.toLowerCase().includes('/hls/');

    if (isHls && typeof Hls !== 'undefined' && Hls.isSupported()) {
        // Use hls.js for MSE-based HLS playback
        hlsInstance = new Hls({
            enableWorker: true,
            lowLatencyMode: true,
        });
        hlsInstance.loadSource(url);
        hlsInstance.attachMedia(video);
        hlsInstance.on(Hls.Events.MANIFEST_PARSED, () => video.play());
        hlsInstance.on(Hls.Events.ERROR, (event, data) => {
            if (data.fatal) {
                dotNetRef?.invokeMethodAsync('OnError', `HLS error: ${data.type} / ${data.details}`);
            }
        });
    } else if (isHls && video.canPlayType('application/vnd.apple.mpegurl')) {
        // Safari native HLS
        video.src = url;
        video.play();
    } else {
        // HTTP progressive / native browser-supported formats
        video.src = url;
        video.play();
    }
}

export function pause() {
    videoEl?.pause();
}

export function resume() {
    videoEl?.play();
}

export function stop() {
    destroyHls();
    if (videoEl) {
        videoEl.pause();
        videoEl.src = '';
        videoEl.style.display = 'none';
    }
    dotNetRef = null;
}

export function seek(positionMs) {
    if (videoEl) {
        videoEl.currentTime = positionMs / 1000;
    }
}

export function setRate(rate) {
    if (videoEl) {
        videoEl.playbackRate = rate;
    }
}

export function setVolume(volume) {
    if (videoEl) {
        videoEl.volume = Math.max(0, Math.min(1, volume));
    }
}

export function setMuted(muted) {
    if (videoEl) {
        videoEl.muted = muted;
    }
}

export function requestPip() {
    if (videoEl && document.pictureInPictureEnabled) {
        videoEl.requestPictureInPicture().catch(() => {});
    }
}
