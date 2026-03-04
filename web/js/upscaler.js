/**
 * CrispyTivi Video Upscaler
 *
 * WebGL 2 bicubic (Catmull-Rom) upscaling for the web
 * platform. Called from Dart via js_interop through
 * web_upscale_bridge_web.dart.
 *
 * Architecture:
 *   HTML <video> (media_kit web backend / HLS.js)
 *     | texImage2D (per-frame upload)
 *   WebGL 2 fragment shader (bicubic + unsharp mask)
 *     | upscaled framebuffer
 *   <canvas> overlay (display at screen resolution)
 *
 * Quality presets control sharpening amount:
 *   performance → 0.0 (pure bicubic)
 *   balanced    → 0.3 (mild enhancement)
 *   maximum     → 0.6 (notable enhancement)
 *
 * See .ai/docs/project-specs/video_upscaling_spec.md section 3.3.
 */
(function () {
  'use strict';

  // ── Configuration ────────────────────────────
  var SHARPEN = {
    performance: 0.0,
    balanced: 0.3,
    maximum: 0.6,
  };
  var MAX_RETRIES = 20;
  var RETRY_MS = 500;

  // ── State ────────────────────────────────────
  var _method = null;
  var _canvas = null;
  var _video = null;
  var _quality = null;
  var _running = false;
  var _resizeObs = null;

  // WebGL 2
  var _gl = null;
  var _program = null;
  var _vao = null;
  var _videoTex = null;
  var _locs = {};

  // ── Video Element Lookup ─────────────────────
  // Shadow-DOM-aware lookup matching the pattern in
  // WebHlsVideo._findVideoJs.
  function findVideo() {
    // 1. Direct lookup — any video with content.
    var videos = document.querySelectorAll('video');
    for (var i = 0; i < videos.length; i++) {
      if (videos[i].src || videos[i]._hls) return videos[i];
    }
    if (videos.length > 0) return videos[0];
    // 2. Shadow DOM (Flutter platform views).
    var hosts = document.querySelectorAll(
      'flt-platform-view',
    );
    for (var j = 0; j < hosts.length; j++) {
      var sr = hosts[j].shadowRoot;
      if (sr) {
        var v = sr.querySelector('video');
        if (v) return v;
      }
    }
    return null;
  }

  // ── Canvas Management ────────────────────────
  function createCanvas(video) {
    var container = video.parentElement;
    if (!container) return null;

    var c = document.createElement('canvas');
    c.style.position = 'absolute';
    c.style.top = '0';
    c.style.left = '0';
    c.style.width = '100%';
    c.style.height = '100%';
    c.style.pointerEvents = 'none';
    c.style.zIndex = '1';
    c.setAttribute('data-crispy-upscaler', 'true');

    sizeCanvas(c, container);
    container.appendChild(c);

    // Resize canvas when container changes size.
    if (typeof ResizeObserver !== 'undefined') {
      _resizeObs = new ResizeObserver(function () {
        sizeCanvas(c, container);
      });
      _resizeObs.observe(container);
    }

    return c;
  }

  function sizeCanvas(c, container) {
    var rect = container.getBoundingClientRect();
    var dpr = window.devicePixelRatio || 1;
    var w = Math.round(rect.width * dpr);
    var h = Math.round(rect.height * dpr);
    if (c.width !== w) c.width = w;
    if (c.height !== h) c.height = h;
  }

  // ── WebGL 2 Shaders ─────────────────────────

  var VERT_SRC = `#version 300 es
in vec2 aPos;
out vec2 vUV;
void main() {
  gl_Position = vec4(aPos, 0.0, 1.0);
  vUV = aPos * 0.5 + 0.5;
}`;

  var FRAG_SRC = `#version 300 es
precision highp float;

uniform sampler2D uVideo;
uniform vec2 uVideoSize;
uniform vec2 uOutputSize;
uniform float uSharpen;

in vec2 vUV;
out vec4 fragColor;

// Catmull-Rom spline weight (a = -0.5).
float cr(float x) {
  float ax = abs(x);
  if (ax >= 2.0) return 0.0;
  if (ax >= 1.0)
    return -0.5*ax*ax*ax + 2.5*ax*ax
           - 4.0*ax + 2.0;
  return 1.5*ax*ax*ax - 2.5*ax*ax + 1.0;
}

vec4 bicubic(vec2 uv) {
  vec2 px = uv * uVideoSize - 0.5;
  vec2 f = fract(px);
  vec2 o = floor(px);
  vec4 c = vec4(0.0);
  float tw = 0.0;
  for (int y = -1; y <= 2; y++) {
    float wy = cr(float(y) - f.y);
    for (int x = -1; x <= 2; x++) {
      float w = cr(float(x) - f.x) * wy;
      vec2 tc = (o + vec2(float(x), float(y))
                 + 0.5) / uVideoSize;
      tc = clamp(tc, 0.0, 1.0);
      c += texture(uVideo, tc) * w;
      tw += w;
    }
  }
  return c / tw;
}

void main() {
  // Aspect-ratio-correct UV mapping.
  float vA = uVideoSize.x / uVideoSize.y;
  float oA = uOutputSize.x / uOutputSize.y;
  vec2 vuv;
  if (vA > oA) {
    // Letterbox (bars top/bottom).
    float h = oA / vA;
    float off = (1.0 - h) * 0.5;
    if (vUV.y < off || vUV.y > 1.0 - off) {
      fragColor = vec4(0, 0, 0, 1);
      return;
    }
    vuv = vec2(vUV.x, (vUV.y - off) / h);
  } else {
    // Pillarbox (bars left/right).
    float w = vA / oA;
    float off = (1.0 - w) * 0.5;
    if (vUV.x < off || vUV.x > 1.0 - off) {
      fragColor = vec4(0, 0, 0, 1);
      return;
    }
    vuv = vec2((vUV.x - off) / w, vUV.y);
  }

  vec4 sharp = bicubic(vuv);

  // Unsharp mask: amplify detail that bicubic adds
  // over hardware bilinear.
  if (uSharpen > 0.0) {
    vec4 bl = texture(uVideo, vuv);
    sharp = clamp(sharp + (sharp - bl) * uSharpen,
                  0.0, 1.0);
  }

  fragColor = vec4(sharp.rgb, 1.0);
}`;

  // ── WebGL 2 Setup ───────────────────────────

  function compileShader(gl, type, src) {
    var s = gl.createShader(type);
    gl.shaderSource(s, src);
    gl.compileShader(s);
    if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
      console.error(
        '[CrispyUpscaler] shader:',
        gl.getShaderInfoLog(s),
      );
      gl.deleteShader(s);
      return null;
    }
    return s;
  }

  function linkProgram(gl, vs, fs) {
    var p = gl.createProgram();
    gl.attachShader(p, vs);
    gl.attachShader(p, fs);
    gl.linkProgram(p);
    if (!gl.getProgramParameter(p, gl.LINK_STATUS)) {
      console.error(
        '[CrispyUpscaler] link:',
        gl.getProgramInfoLog(p),
      );
      gl.deleteProgram(p);
      return null;
    }
    return p;
  }

  function initWebGL(video, quality) {
    _canvas = createCanvas(video);
    if (!_canvas) return false;

    _gl = _canvas.getContext('webgl2', {
      alpha: false,
      antialias: false,
      premultipliedAlpha: false,
      preserveDrawingBuffer: false,
    });
    if (!_gl) {
      _canvas.remove();
      _canvas = null;
      return false;
    }

    var gl = _gl;

    // Compile shaders.
    var vs = compileShader(gl, gl.VERTEX_SHADER, VERT_SRC);
    var fs = compileShader(
      gl,
      gl.FRAGMENT_SHADER,
      FRAG_SRC,
    );
    if (!vs || !fs) {
      cleanup();
      return false;
    }
    _program = linkProgram(gl, vs, fs);
    gl.deleteShader(vs);
    gl.deleteShader(fs);
    if (!_program) {
      cleanup();
      return false;
    }

    // Uniform locations.
    _locs.uVideo = gl.getUniformLocation(
      _program,
      'uVideo',
    );
    _locs.uVideoSize = gl.getUniformLocation(
      _program,
      'uVideoSize',
    );
    _locs.uOutputSize = gl.getUniformLocation(
      _program,
      'uOutputSize',
    );
    _locs.uSharpen = gl.getUniformLocation(
      _program,
      'uSharpen',
    );

    // Fullscreen quad VAO.
    _vao = gl.createVertexArray();
    gl.bindVertexArray(_vao);
    var buf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    // prettier-ignore
    gl.bufferData(
      gl.ARRAY_BUFFER,
      new Float32Array([
        -1, -1, 1, -1, -1, 1, 1, 1,
      ]),
      gl.STATIC_DRAW,
    );
    var aPos = gl.getAttribLocation(_program, 'aPos');
    gl.enableVertexAttribArray(aPos);
    gl.vertexAttribPointer(aPos, 2, gl.FLOAT, false, 0, 0);
    gl.bindVertexArray(null);

    // Video texture.
    _videoTex = gl.createTexture();
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, _videoTex);
    gl.texParameteri(
      gl.TEXTURE_2D,
      gl.TEXTURE_WRAP_S,
      gl.CLAMP_TO_EDGE,
    );
    gl.texParameteri(
      gl.TEXTURE_2D,
      gl.TEXTURE_WRAP_T,
      gl.CLAMP_TO_EDGE,
    );
    gl.texParameteri(
      gl.TEXTURE_2D,
      gl.TEXTURE_MIN_FILTER,
      gl.LINEAR,
    );
    gl.texParameteri(
      gl.TEXTURE_2D,
      gl.TEXTURE_MAG_FILTER,
      gl.LINEAR,
    );
    // Flip Y so UV (0,0) = bottom-left = bottom of
    // video (matching WebGL clip space).
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);

    _video = video;
    _quality = quality;
    _method = 'WebGL Bicubic';

    console.log(
      '[CrispyUpscaler] WebGL 2 initialized',
      {
        video:
          video.videoWidth + 'x' + video.videoHeight,
        canvas: _canvas.width + 'x' + _canvas.height,
        quality: quality,
      },
    );
    return true;
  }

  // ── Render Loop ──────────────────────────────

  function renderFrame() {
    if (!_running || !_gl || !_video) return;

    var gl = _gl;
    var video = _video;

    // Skip if video has no data yet.
    if (video.readyState < 2 || video.videoWidth === 0) {
      scheduleNext();
      return;
    }

    // Update canvas size if needed.
    if (_canvas && _video.parentElement) {
      var container = _video.parentElement;
      var rect = container.getBoundingClientRect();
      var dpr = window.devicePixelRatio || 1;
      var w = Math.round(rect.width * dpr);
      var h = Math.round(rect.height * dpr);
      if (_canvas.width !== w || _canvas.height !== h) {
        _canvas.width = w;
        _canvas.height = h;
      }
    }

    // Upload video frame to texture.
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, _videoTex);
    try {
      gl.texImage2D(
        gl.TEXTURE_2D,
        0,
        gl.RGBA,
        gl.RGBA,
        gl.UNSIGNED_BYTE,
        video,
      );
    } catch (e) {
      // Cross-origin or DRM-protected video.
      scheduleNext();
      return;
    }

    // Draw.
    gl.viewport(0, 0, _canvas.width, _canvas.height);
    gl.useProgram(_program);
    gl.uniform1i(_locs.uVideo, 0);
    gl.uniform2f(
      _locs.uVideoSize,
      video.videoWidth,
      video.videoHeight,
    );
    gl.uniform2f(
      _locs.uOutputSize,
      _canvas.width,
      _canvas.height,
    );
    gl.uniform1f(
      _locs.uSharpen,
      SHARPEN[_quality] || 0.0,
    );

    gl.bindVertexArray(_vao);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
    gl.bindVertexArray(null);

    scheduleNext();
  }

  function scheduleNext() {
    if (!_running) return;
    if (
      _video &&
      typeof _video.requestVideoFrameCallback ===
        'function'
    ) {
      _video.requestVideoFrameCallback(renderFrame);
    } else {
      requestAnimationFrame(renderFrame);
    }
  }

  // ── Cleanup ──────────────────────────────────

  function cleanup() {
    _running = false;

    if (_resizeObs) {
      _resizeObs.disconnect();
      _resizeObs = null;
    }

    if (_gl) {
      if (_program) _gl.deleteProgram(_program);
      if (_vao) _gl.deleteVertexArray(_vao);
      if (_videoTex) _gl.deleteTexture(_videoTex);
      var ext = _gl.getExtension('WEBGL_lose_context');
      if (ext) ext.loseContext();
    }

    if (_canvas) {
      _canvas.remove();
    }

    _gl = null;
    _program = null;
    _vao = null;
    _videoTex = null;
    _locs = {};
    _canvas = null;
    _video = null;
    _method = null;
    _quality = null;
  }

  // ── Public API ───────────────────────────────

  window.crispyUpscaler = {
    /**
     * Apply upscaling to the video element.
     * @param {number} scaleFactor — reserved (JS
     *   calculates actual scale from video/display)
     * @param {string} quality — 'performance' |
     *   'balanced' | 'maximum'
     */
    applyUpscaling: function (scaleFactor, quality) {
      // Idempotent: if already running with same
      // quality, do nothing.
      if (_running && _quality === quality) return;

      // If running with different quality, restart.
      if (_running) cleanup();

      var video = findVideo();
      if (!video) {
        // Video not in DOM yet — retry.
        var retries = 0;
        var self = this;
        var timer = setInterval(function () {
          retries++;
          video = findVideo();
          if (video) {
            clearInterval(timer);
            self._start(video, quality);
          } else if (retries >= MAX_RETRIES) {
            clearInterval(timer);
            console.warn(
              '[CrispyUpscaler] video not found '
              + 'after ' + MAX_RETRIES + ' retries',
            );
          }
        }, RETRY_MS);
        return;
      }

      this._start(video, quality);
    },

    _start: function (video, quality) {
      // Wait for video metadata if needed.
      if (video.videoWidth === 0) {
        var self = this;
        video.addEventListener(
          'loadedmetadata',
          function () {
            self._init(video, quality);
          },
          { once: true },
        );
        return;
      }
      this._init(video, quality);
    },

    _init: function (video, quality) {
      // Check if upscaling is needed.
      var container = video.parentElement;
      if (!container) return;
      var rect = container.getBoundingClientRect();
      var dpr = window.devicePixelRatio || 1;
      var outW = rect.width * dpr;
      var outH = rect.height * dpr;
      var vW = video.videoWidth;
      var vH = video.videoHeight;

      var scaleX = outW / vW;
      var scaleY = outH / vH;
      var scale = Math.min(scaleX, scaleY);

      if (scale <= 1.05) {
        console.log(
          '[CrispyUpscaler] no upscaling needed '
          + '(scale=' + scale.toFixed(2) + ')',
        );
        return;
      }

      console.log(
        '[CrispyUpscaler] scale factor: '
        + scale.toFixed(2) + 'x ('
        + vW + 'x' + vH
        + ' → ' + Math.round(outW) + 'x'
        + Math.round(outH) + ')',
      );

      // Try WebGL 2.
      var testCanvas = document.createElement('canvas');
      var testGl = testCanvas.getContext('webgl2');
      if (testGl) {
        // Clean up test context.
        var ext = testGl.getExtension(
          'WEBGL_lose_context',
        );
        if (ext) ext.loseContext();

        if (initWebGL(video, quality)) {
          _running = true;
          scheduleNext();
          return;
        }
      }

      // No GPU acceleration available.
      console.log(
        '[CrispyUpscaler] no WebGL 2 — '
        + 'unprocessed playback',
      );
      _method = null;
    },

    /**
     * Remove upscaling and show raw video.
     */
    removeUpscaling: function () {
      cleanup();
    },

    /**
     * Dispose all resources.
     */
    dispose: function () {
      cleanup();
    },

    /**
     * Returns the active upscaling method name.
     * @returns {string|null}
     */
    getActiveMethod: function () {
      return _method;
    },
  };
})();
