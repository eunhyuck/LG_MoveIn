import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VRRoomViewer - Gyroscope-based stereoscopic VR (Google Cardboard style)
//   • DeviceOrientationEvent → head tracking (no touch needed)
//   • Side-by-side stereo rendering for VR headset
//   • Gaze-dwell selection & walk-forward
// ─────────────────────────────────────────────────────────────────────────────

class VRRoomViewer extends StatefulWidget {
  final List<Map<String, dynamic>> elements;
  final Map<String, List<dynamic>>? productsDatabase;

  const VRRoomViewer({
    super.key,
    required this.elements,
    this.productsDatabase,
  });

  @override
  State<VRRoomViewer> createState() => _VRRoomViewerState();
}

class _VRRoomViewerState extends State<VRRoomViewer> {
  HttpServer? _server;
  WebViewController? _controller;
  bool _isLoading = true;
  String? _serverUrl;

  @override
  void initState() {
    super.initState();
    _startLocalServer();
  }

  Future<void> _startLocalServer() async {
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = _server!.port;
      _serverUrl = 'http://127.0.0.1:$port/';

      _server!.listen((HttpRequest request) async {
        final path = request.uri.path;
        try {
          if (path == '/') {
            request.response
              ..headers.contentType = ContentType.html
              ..write(_getHtmlTemplate())
              ..close();
          } else if (path.startsWith('/assets/')) {
            String assetPath = path.substring(1);
            if (assetPath.startsWith('assets/assets/')) {
              assetPath = assetPath.substring(7);
            }
            try {
              final byteData = await rootBundle.load(assetPath);
              final bytes = byteData.buffer.asUint8List();
              if (path.endsWith('.glb')) {
                request.response.headers.contentType =
                    ContentType('application', 'octet-stream');
              } else if (path.endsWith('.js')) {
                request.response.headers.contentType =
                    ContentType('application', 'javascript');
              } else if (path.endsWith('.png')) {
                request.response.headers.contentType =
                    ContentType('image', 'png');
              } else if (path.endsWith('.jpg') || path.endsWith('.jpeg')) {
                request.response.headers.contentType =
                    ContentType('image', 'jpeg');
              }
              request.response.add(bytes);
            } catch (_) {
              request.response.statusCode = HttpStatus.notFound;
            }
            await request.response.close();
          } else {
            request.response
              ..statusCode = HttpStatus.notFound
              ..close();
          }
        } catch (_) {
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..close();
        }
      });

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setOnConsoleMessage((m) => debugPrint('VR: ${m.message}'))
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
        ))
        ..loadRequest(Uri.parse(_serverUrl!));

      setState(() => _controller = controller);
    } catch (e) {
      debugPrint('VR server error: $e');
    }
  }

  @override
  void dispose() {
    _server?.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFE6007E)));
    }
    return Stack(children: [
      WebViewWidget(controller: _controller!),
      if (_isLoading)
        const Center(
            child: CircularProgressIndicator(color: Color(0xFFE6007E))),
    ]);
  }

  String _getHtmlTemplate() {
    final elementsJson = jsonEncode(widget.elements);
    final dbJson = jsonEncode(widget.productsDatabase ?? {});
    return _rawVRHtml
        .replaceAll('__ELEMENTS_JSON__', elementsJson)
        .replaceAll('__PRODUCTS_DATABASE_JSON__', dbJson);
  }

  static const String _rawVRHtml = r'''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body, html { width: 100%; height: 100%; overflow: hidden; background: #000; touch-action: none; }
    canvas { display: block; }

    /* ── Start screen ── */
    #start-screen {
      position: fixed; inset: 0; z-index: 100;
      background: linear-gradient(135deg, #0a0a1a 0%, #1a0a20 100%);
      display: flex; flex-direction: column;
      align-items: center; justify-content: center; gap: 20px;
      font-family: -apple-system, sans-serif; color: white;
    }
    #start-icon { font-size: 64px; }
    #start-title { font-size: 22px; font-weight: bold; letter-spacing: 0.5px; }
    #start-desc {
      font-size: 12px; color: rgba(255,255,255,0.55); text-align: center;
      max-width: 260px; line-height: 1.7;
    }
    #start-btn {
      background: linear-gradient(135deg, #e6007e, #b0005e);
      border: none; border-radius: 50px; padding: 14px 40px;
      color: white; font-size: 15px; font-weight: bold;
      cursor: pointer; box-shadow: 0 4px 20px rgba(230,0,126,0.45);
      letter-spacing: 0.3px;
    }
    #start-note {
      font-size: 10px; color: rgba(255,255,255,0.3);
      text-align: center; max-width: 240px; line-height: 1.6;
    }

    /* ── VR canvas container ── */
    #vr-wrap { display: none; position: fixed; inset: 0; }

    /* ── Center divider ── */
    #divider {
      position: fixed; top: 0; left: 50%; width: 3px; height: 100%;
      background: #000; z-index: 10; transform: translateX(-50%);
    }

    /* ── Gaze reticle (center of each eye) ── */
    .reticle {
      position: fixed; top: 50%;
      transform: translateY(-50%);
      width: 22px; height: 22px;
      pointer-events: none; z-index: 20;
    }
    #reticle-l { left: calc(25% - 11px); }
    #reticle-r { left: calc(75% - 11px); }
    .reticle-ring {
      position: absolute; inset: 0; border-radius: 50%;
      border: 2px solid rgba(255,255,255,0.7);
    }
    .reticle-dot {
      position: absolute; top: 50%; left: 50%;
      transform: translate(-50%,-50%);
      width: 4px; height: 4px; border-radius: 50%;
      background: rgba(255,255,255,0.9);
    }
    .reticle-progress {
      position: absolute; inset: -4px; border-radius: 50%;
      border: 3px solid transparent;
      border-top-color: #e6007e;
      transform: rotate(-90deg);
      transition: none;
    }
    .reticle-progress.filling { animation: fillGaze 1.8s linear forwards; }
    @keyframes fillGaze {
      from { transform: rotate(-90deg); border-color: transparent; border-top-color: #e6007e; }
      25%  { border-top-color: #e6007e; border-right-color: #e6007e; }
      50%  { border-top-color: #e6007e; border-right-color: #e6007e; border-bottom-color: #e6007e; }
      75%  { border-color: #e6007e; }
      to   { border-color: #e6007e; transform: rotate(270deg); }
    }

    /* ── Loading ── */
    #loading {
      position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%);
      font-family: sans-serif; font-size: 13px; color: #e6007e; font-weight: bold;
      background: rgba(0,0,0,0.85); padding: 12px 24px; border-radius: 20px;
      border: 1px solid rgba(230,0,126,0.4); z-index: 50; display: none;
    }

    /* ── HUD label ── */
    #hud-label {
      position: fixed; bottom: 16px; left: 50%; transform: translateX(-50%);
      background: rgba(0,0,0,0.55); backdrop-filter: blur(8px);
      color: rgba(255,255,255,0.6); font-family: sans-serif; font-size: 10px;
      padding: 4px 16px; border-radius: 20px; z-index: 30; white-space: nowrap;
    }

    /* ── Info popup (centered in each half) ── */
    #info-popup {
      position: fixed; z-index: 40;
      left: 50%; bottom: 60px; transform: translateX(-50%);
      background: rgba(10,10,20,0.92); backdrop-filter: blur(20px);
      border: 1px solid rgba(230,0,126,0.5); border-radius: 16px;
      padding: 12px 18px; min-width: 200px; text-align: center;
      font-family: sans-serif; color: white; display: none;
    }
    #info-name { font-size: 13px; font-weight: bold; margin-bottom: 3px; }
    #info-code { font-size: 10px; color: rgba(255,255,255,0.5); }
  </style>

  <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/GLTFLoader.js"></script>
</head>
<body>

<!-- ── Start screen ── -->
<div id="start-screen">
  <div id="start-icon">🥽</div>
  <div id="start-title">VR 탐색 모드</div>
  <div id="start-desc">
    스마트폰을 VR 헤드셋에 넣고<br>
    고개를 돌려 공간을 탐색하세요.<br><br>
    <strong>가전을 2초간 응시</strong>하면 정보가 표시됩니다.
  </div>
  <button id="start-btn" onclick="startVR()">▶ VR 시작하기</button>
  <div id="start-note">
    * 자이로스코프 권한이 필요합니다 (iOS 13+)<br>
    * 화면 잠금을 해제한 상태로 사용하세요
  </div>
</div>

<!-- ── VR rendering area ── -->
<div id="vr-wrap">
  <div id="loading">🥽 VR 공간 로딩 중...</div>
  <div id="divider"></div>

  <!-- Left eye reticle -->
  <div class="reticle" id="reticle-l">
    <div class="reticle-ring"></div>
    <div class="reticle-dot"></div>
    <div class="reticle-progress" id="prog-l"></div>
  </div>
  <!-- Right eye reticle -->
  <div class="reticle" id="reticle-r">
    <div class="reticle-ring"></div>
    <div class="reticle-dot"></div>
    <div class="reticle-progress" id="prog-r"></div>
  </div>

  <div id="hud-label">🥽 고개를 돌려 탐색 &nbsp;|&nbsp; 가전을 응시하면 정보 표시</div>
  <div id="info-popup">
    <div id="info-name"></div>
    <div id="info-code"></div>
  </div>
</div>

<script>
// ══════════════════════════════════════════════════════════════
// Data
// ══════════════════════════════════════════════════════════════
let elements = __ELEMENTS_JSON__;
const productsDb = __PRODUCTS_DATABASE_JSON__;

const areaSize = (elements.length > 0 && elements[0].areaSize) ? elements[0].areaSize : '84㎡ (25평)';
let roomSize = 900;
let glbName = 'apartment_25py.glb';
if (areaSize.includes('18평') || areaSize.includes('59㎡')) { roomSize = 675; glbName = 'apartment_18py.glb'; }
else if (areaSize.includes('34평') || areaSize.includes('112㎡')) { roomSize = 1275; glbName = 'apartment_34py.glb'; }

// ══════════════════════════════════════════════════════════════
// Three.js setup
// ══════════════════════════════════════════════════════════════
let scene, camera, renderer;
let applianceMeshes = [];

function initThree() {
  scene = new THREE.Scene();
  scene.background = new THREE.Color(0x0d0d1a);
  scene.fog = new THREE.Fog(0x0d0d1a, roomSize * 2.5, roomSize * 7);

  const W = window.innerWidth;
  const H = window.innerHeight;

  // Single perspective camera; we render twice (left eye / right eye)
  camera = new THREE.PerspectiveCamera(90, (W * 0.5) / H, 1, roomSize * 8);
  camera.position.set(roomSize * 0.05, 160, roomSize * 0.05);

  renderer = new THREE.WebGLRenderer({ antialias: false });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));
  renderer.setSize(W, H);
  renderer.setScissorTest(true);
  renderer.shadowMap.enabled = false; // off for perf in VR
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.1;
  document.getElementById('vr-wrap').appendChild(renderer.domElement);
  renderer.domElement.style.position = 'fixed';
  renderer.domElement.style.inset = '0';

  // Lights
  scene.add(new THREE.AmbientLight(0xffffff, 0.7));
  const sun = new THREE.DirectionalLight(0xfff5e0, 1.3);
  sun.position.set(200, 400, 200);
  scene.add(sun);
  const fill = new THREE.DirectionalLight(0xd0e0ff, 0.35);
  fill.position.set(-200, 200, -200);
  scene.add(fill);

  loadRoom();
}

function loadRoom() {
  const loader = new THREE.GLTFLoader();
  document.getElementById('loading').style.display = 'block';

  loader.load('/assets/assets/models/' + glbName, (gltf) => {
    scene.add(gltf.scene);
    loadAppliances();
  }, undefined, () => { loadAppliances(); });
}

function loadAppliances() {
  const loader = new THREE.GLTFLoader();
  const lgEls = elements.filter(e => e.isLG && e.model3DUrl && e.model3DUrl.trim() !== '');
  let loaded = 0;

  if (lgEls.length === 0) {
    document.getElementById('loading').style.display = 'none';
    return;
  }

  lgEls.forEach(el => {
    const url = '/assets/' + el.model3DUrl.replace(/^\//, '').replace(/^assets\//, 'assets/');
    loader.load(url, (gltf) => {
      const group = new THREE.Group();
      group.name = 'appliance_' + el.id;
      group.userData = el;

      const model = gltf.scene;
      const box = new THREE.Box3().setFromObject(model);
      const sz  = new THREE.Vector3();
      box.getSize(sz);
      const scale = (el.dz || 90) / (sz.y || 1);
      model.scale.setScalar(scale);
      group.add(model);

      group.position.set((el.x - 0.5) * roomSize, 0, (el.y - 0.5) * roomSize);
      scene.add(group);
      applianceMeshes.push(group);

      if (++loaded >= lgEls.length) {
        document.getElementById('loading').style.display = 'none';
        camera.position.set(roomSize * 0.05, 160, roomSize * 0.1);
      }
    }, undefined, () => {
      if (++loaded >= lgEls.length) document.getElementById('loading').style.display = 'none';
    });
  });
}

// ══════════════════════════════════════════════════════════════
// Gyroscope / DeviceOrientation → camera quaternion
// ══════════════════════════════════════════════════════════════
const euler = new THREE.Euler();
const q0 = new THREE.Quaternion();
const qScreen = new THREE.Quaternion(-Math.sqrt(0.5), 0, 0, Math.sqrt(0.5));

let deviceAlpha = 0, deviceBeta = 90, deviceGamma = 0;

window.addEventListener('deviceorientation', (e) => {
  deviceAlpha = e.alpha || 0;
  deviceBeta  = e.beta  || 90;
  deviceGamma = e.gamma || 0;
});

function updateCameraFromGyro() {
  // ZXY Euler order for landscape phone in VR headset
  euler.set(
    THREE.MathUtils.degToRad(deviceBeta),
    THREE.MathUtils.degToRad(deviceAlpha),
    THREE.MathUtils.degToRad(-deviceGamma),
    'YXZ'
  );
  camera.quaternion.setFromEuler(euler);
  camera.quaternion.multiply(qScreen);
}

// ══════════════════════════════════════════════════════════════
// Stereo rendering (side-by-side, slight IPD offset)
// ══════════════════════════════════════════════════════════════
const ipd = 3.2; // inter-pupillary offset in scene units (tiny)

function renderStereo() {
  const W = window.innerWidth;
  const H = window.innerHeight;
  const halfW = Math.floor(W / 2);

  // Left eye
  renderer.setViewport(0, 0, halfW, H);
  renderer.setScissor(0, 0, halfW, H);
  camera.position.x -= ipd / 2;
  renderer.render(scene, camera);

  // Right eye
  renderer.setViewport(halfW, 0, halfW, H);
  renderer.setScissor(halfW, 0, halfW, H);
  camera.position.x += ipd;
  renderer.render(scene, camera);
  camera.position.x -= ipd / 2; // restore
}

// ══════════════════════════════════════════════════════════════
// Gaze-based selection & auto-walk
// ══════════════════════════════════════════════════════════════
const raycaster = new THREE.Raycaster();
const centerNDC = new THREE.Vector2(0, 0);
let gazeTarget = null;
let gazeTimer = 0;
let gazeDuration = 0;
const GAZE_DWELL = 1800; // ms to trigger
const WALK_SPEED = 2.5;  // units per frame toward gaze point
let walkToward = false;

const infoPopup = document.getElementById('info-popup');
const infoName  = document.getElementById('info-name');
const infoCode  = document.getElementById('info-code');
const progL     = document.getElementById('prog-l');
const progR     = document.getElementById('prog-r');

let infoVisible = false;
let infoHideTimer = null;

function doGazeRaycast() {
  if (!scene || applianceMeshes.length === 0) return null;
  raycaster.setFromCamera(centerNDC, camera);
  const hits = raycaster.intersectObjects(applianceMeshes, true);
  if (hits.length > 0) {
    let obj = hits[0].object;
    while (obj && obj.parent && obj !== scene) {
      if (obj.name && obj.name.startsWith('appliance_')) break;
      obj = obj.parent;
    }
    if (obj && obj.userData && obj.userData.name) return obj;
  }
  return null;
}

function showInfo(el) {
  infoName.textContent = el.name || '가전';
  infoCode.textContent = el.code || '';
  infoPopup.style.display = 'block';
  infoVisible = true;
  if (infoHideTimer) clearTimeout(infoHideTimer);
  infoHideTimer = setTimeout(() => {
    infoPopup.style.display = 'none';
    infoVisible = false;
  }, 4000);
}

function startGazeAnim() {
  progL.classList.add('filling');
  progR.classList.add('filling');
}
function stopGazeAnim() {
  progL.classList.remove('filling');
  progR.classList.remove('filling');
  // force reflow
  void progL.offsetWidth;
  void progR.offsetWidth;
}

// ══════════════════════════════════════════════════════════════
// Movement: slowly walk toward whatever you're looking at
// (head tilt forward > 15° triggers walk)
// ══════════════════════════════════════════════════════════════
const halfRoom = roomSize * 0.44;

function applyAutoWalk() {
  // Walk forward if beta (pitch) < 75° (tilting head down to "walk")
  if (deviceBeta < 75) {
    const fwd = new THREE.Vector3(0, 0, -1).applyQuaternion(camera.quaternion);
    fwd.y = 0;
    if (fwd.length() > 0.01) {
      fwd.normalize().multiplyScalar(WALK_SPEED);
      camera.position.add(fwd);
      camera.position.x = Math.max(-halfRoom, Math.min(halfRoom, camera.position.x));
      camera.position.z = Math.max(-halfRoom, Math.min(halfRoom, camera.position.z));
      camera.position.y = 160;
    }
  }
}

// ══════════════════════════════════════════════════════════════
// Main animation loop
// ══════════════════════════════════════════════════════════════
let lastTime = 0;

function animate(now) {
  requestAnimationFrame(animate);
  const dt = now - lastTime;
  lastTime = now;

  updateCameraFromGyro();
  applyAutoWalk();

  // Gaze dwell logic
  const hit = doGazeRaycast();
  if (hit) {
    if (hit !== gazeTarget) {
      gazeTarget = hit;
      gazeTimer = now;
      gazeDuration = 0;
      stopGazeAnim();
      startGazeAnim();
    } else {
      gazeDuration = now - gazeTimer;
      if (gazeDuration >= GAZE_DWELL) {
        showInfo(hit.userData);
        gazeTarget = null;
        stopGazeAnim();
      }
    }
  } else {
    if (gazeTarget) { gazeTarget = null; stopGazeAnim(); }
  }

  renderStereo();
}

// ══════════════════════════════════════════════════════════════
// Start
// ══════════════════════════════════════════════════════════════
async function startVR() {
  // Request DeviceOrientation permission (iOS 13+)
  if (typeof DeviceOrientationEvent !== 'undefined' &&
      typeof DeviceOrientationEvent.requestPermission === 'function') {
    try {
      const perm = await DeviceOrientationEvent.requestPermission();
      if (perm !== 'granted') {
        alert('자이로스코프 권한이 필요합니다. 설정에서 허용해주세요.');
        return;
      }
    } catch(e) {
      console.warn('DeviceOrientation permission error:', e);
    }
  }

  document.getElementById('start-screen').style.display = 'none';
  document.getElementById('vr-wrap').style.display = 'block';

  initThree();
  requestAnimationFrame(animate);
}

window.addEventListener('resize', () => {
  if (!renderer) return;
  const W = window.innerWidth, H = window.innerHeight;
  camera.aspect = (W * 0.5) / H;
  camera.updateProjectionMatrix();
  renderer.setSize(W, H);
});
</script>
</body>
</html>
''';
}
