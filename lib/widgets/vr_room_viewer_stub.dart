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
    .info-popup {
      position: fixed; z-index: 40;
      bottom: 60px; transform: translateX(-50%);
      background: rgba(10,10,20,0.92); backdrop-filter: blur(20px);
      border: 1px solid rgba(230,0,126,0.5); border-radius: 16px;
      padding: 12px 14px; width: 44%; max-width: 280px; text-align: center;
      font-family: sans-serif; color: white; display: none;
      box-sizing: border-box;
    }
    #info-popup-l { left: 25%; }
    #info-popup-r { left: 75%; }
    .info-name { font-size: 12px; font-weight: bold; margin-bottom: 3px; word-break: keep-all; line-height: 1.35; }
    .info-code { font-size: 9px; color: rgba(255,255,255,0.5); }

    /* ── Alternative cards in VR popup ── */
    .info-alternatives::-webkit-scrollbar { display: none; }
    .alternative-card {
      flex: 0 0 54px;
      height: 48px;
      background: rgba(255, 255, 255, 0.08);
      border: 1px solid rgba(255, 255, 255, 0.15);
      border-radius: 8px;
      padding: 4px;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      box-sizing: border-box;
      font-size: 7px;
      line-height: 1.1;
    }
    .alternative-card.current {
      border-color: #e6007e;
      background: rgba(230, 0, 126, 0.2);
    }
    .alternative-card img {
      width: 100%;
      height: 20px;
      object-fit: contain;
      margin-bottom: 2px;
    }
    .alternative-card .alt-name {
      font-size: 6.5px;
      color: rgba(255,255,255,0.85);
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      width: 100%;
    }
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
    <strong>손가락 딱! 소리</strong>를 내면 위치가 전환되고,<br>
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

  <div id="hud-label">🥽 손가락 딱! 소리로 위치 전환 &nbsp;|&nbsp; 가전을 응시하면 정보 표시</div>
  <div id="info-popup-l" class="info-popup">
    <div class="info-name"></div>
    <div class="info-code"></div>
    <div class="info-alternatives" style="display: flex; gap: 8px; margin-top: 8px; overflow-x: auto; justify-content: center; padding: 2px 0;"></div>
  </div>
  <div id="info-popup-r" class="info-popup">
    <div class="info-name"></div>
    <div class="info-code"></div>
    <div class="info-alternatives" style="display: flex; gap: 8px; margin-top: 8px; overflow-x: auto; justify-content: center; padding: 2px 0;"></div>
  </div>
</div>

<script>
// ══════════════════════════════════════════════════════════════
// Data
// ══════════════════════════════════════════════════════════════
let elements = __ELEMENTS_JSON__;
const productsDb = __PRODUCTS_DATABASE_JSON__;

const areaSize = (elements.length > 0 && elements[0].areaSize) ? elements[0].areaSize : '84㎡ (25평)';
let roomSize = 600;
let glbName = 'apartment_25py.glb';
if (areaSize.includes('18평') || areaSize.includes('59㎡')) { roomSize = 450; glbName = 'apartment_18py.glb'; }
else if (areaSize.includes('34평') || areaSize.includes('112㎡')) { roomSize = 800; glbName = 'apartment_34py.glb'; }

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
  camera.position.set(roomSize * 0.05, 80, roomSize * 0.05);

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

function getPercentileBoundingBox(object, lowP = 0.008, highP = 0.992) {
  let xs = [], ys = [], zs = [];
  object.updateMatrixWorld(true);
  object.traverse(node => {
    if (node.isMesh && node.geometry) {
      const pos = node.geometry.attributes.position;
      if (pos) {
        const v = new THREE.Vector3();
        for (let i = 0; i < pos.count; i++) {
          v.fromBufferAttribute(pos, i);
          v.applyMatrix4(node.matrixWorld);
          xs.push(v.x);
          ys.push(v.y);
          zs.push(v.z);
        }
      }
    }
  });
  if (xs.length === 0) {
    return new THREE.Box3().setFromObject(object);
  }
  xs.sort((a,b)=>a-b);
  ys.sort((a,b)=>a-b);
  zs.sort((a,b)=>a-b);
  const val = (arr, p) => arr[Math.max(0, Math.min(arr.length-1, Math.floor(arr.length * p)))];
  return new THREE.Box3(
    new THREE.Vector3(val(xs, lowP), val(ys, lowP), val(zs, lowP)),
    new THREE.Vector3(val(xs, highP), val(ys, highP), val(zs, highP))
  );
}

function getCategoryFromName(name) {
  const lowercase = name.toLowerCase();
  if (lowercase.includes('냉장고') || lowercase.includes('refrigerator')) {
    return 'refrigerators';
  } else if (lowercase.includes('건조기') || lowercase.includes('dryer')) {
    return 'dryers';
  } else if (lowercase.includes('세탁기') || lowercase.includes('washer') || lowercase.includes('washing')) {
    return 'washers';
  } else if (lowercase.includes('에어컨') || lowercase.includes('air')) {
    return 'air-conditioners';
  }
  return 'refrigerators';
}

function getModelSrc(name) {
  const lowercase = name.toLowerCase();
  let path = '';
  if (lowercase.includes('냉장고') || lowercase.includes('refrigerator')) {
    path = 'assets/models/M876GBB231.glb';
  } else if (lowercase.includes('건조기') || lowercase.includes('dryer')) {
    path = 'assets/models/RH10WTW.glb';
  } else if (lowercase.includes('세탁기') || lowercase.includes('washer') || lowercase.includes('washing')) {
    path = 'assets/models/T17DX3A.glb';
  } else if (lowercase.includes('에어컨') || lowercase.includes('air')) {
    path = 'assets/models/SQ06GA1WAJ-AKOR.glb';
  } else {
    path = 'assets/models/M876GBB231.glb';
  }
  return '/assets/' + path;
}

function generateSimulatedApartment() {
  const aptGroup = new THREE.Group();
  aptGroup.name = "simulated_apartment";

  const sideMat = new THREE.MeshStandardMaterial({ color: 0xeae6df, roughness: 0.95 });
  const topMat = new THREE.MeshBasicMaterial({ color: 0x1a1a1a });
  const wallMaterials = [sideMat, sideMat, topMat, sideMat, sideMat, sideMat];
  
  const wallHeight = 120;
  const wallThickness = 12;

  function addWall(x, z, w, d) {
    const wall = new THREE.Mesh(new THREE.BoxGeometry(w, wallHeight, d), wallMaterials);
    wall.position.set(x, wallHeight / 2, z);
    aptGroup.add(wall);
  }

  function addWindow(x, z, w, d, rotationY = 0) {
    const baseH = 35;
    const windowGroup = new THREE.Group();
    windowGroup.position.set(x, 0, z);
    windowGroup.rotation.y = rotationY;

    const base = new THREE.Mesh(new THREE.BoxGeometry(w, baseH, d), wallMaterials);
    base.position.y = baseH / 2;
    windowGroup.add(base);

    const glassMat = new THREE.MeshStandardMaterial({
      color: 0x88ccff,
      transparent: true,
      opacity: 0.35,
      roughness: 0.1,
      metalness: 0.9
    });
    const glass = new THREE.Mesh(new THREE.BoxGeometry(w - 6, wallHeight - baseH, 2), glassMat);
    glass.position.y = baseH + (wallHeight - baseH) / 2;
    windowGroup.add(glass);

    const frameMat = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.4 });
    
    const frameTop = new THREE.Mesh(new THREE.BoxGeometry(w, 4, d + 2), frameMat);
    frameTop.position.y = wallHeight;
    windowGroup.add(frameTop);

    const frameLeft = new THREE.Mesh(new THREE.BoxGeometry(4, wallHeight - baseH, d + 2), frameMat);
    frameLeft.position.set(-w/2 + 2, baseH + (wallHeight - baseH)/2, 0);
    windowGroup.add(frameLeft);

    const frameRight = new THREE.Mesh(new THREE.BoxGeometry(4, wallHeight - baseH, d + 2), frameMat);
    frameRight.position.set(w/2 - 2, baseH + (wallHeight - baseH)/2, 0);
    windowGroup.add(frameRight);

    const frameMid = new THREE.Mesh(new THREE.BoxGeometry(3, wallHeight - baseH, d + 1), frameMat);
    frameMid.position.set(0, baseH + (wallHeight - baseH)/2, 0);
    windowGroup.add(frameMid);

    aptGroup.add(windowGroup);
  }

  const half = roomSize / 2;

  if (roomSize === 450) {
    addWall(0, -half, roomSize, wallThickness);
    addWall(-half, 0, wallThickness, roomSize);
    addWall(half, 0, wallThickness, roomSize);
    
    addWall(-150, half, 150, wallThickness);
    addWindow(0, half, 150, wallThickness);
    addWall(150, half, 150, wallThickness);

    addWall(-112.5, 37.5, 112.5, wallThickness);
    addWall(-56.25, 112.5, wallThickness, 150);

    addWall(-150, -37.5, 120, wallThickness);
    addWall(-90, -75, wallThickness, 75);

    const bathFloorGeo = new THREE.PlaneGeometry(120, 75);
    const bathFloorMat = new THREE.MeshStandardMaterial({ color: 0x7f8c8d, roughness: 0.8 });
    const bathFloor = new THREE.Mesh(bathFloorGeo, bathFloorMat);
    bathFloor.rotation.x = -Math.PI / 2;
    bathFloor.position.set(-150, 0.5, -75);
    aptGroup.add(bathFloor);

    const counterMat = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.5 });
    const counter = new THREE.Mesh(new THREE.BoxGeometry(35, 85, 120), counterMat);
    counter.position.set(190, 85/2, -120);
    aptGroup.add(counter);
  } 
  else if (roomSize === 800) {
    addWall(0, -434, 800, wallThickness);
    addWall(-400, 0, wallThickness, 868);
    addWall(400, 0, wallThickness, 868);
    addWall(0, 434, 800, wallThickness);

    addWall(210, 0, wallThickness, 868);

    addWall(-176, -74, wallThickness, 720);
    addWall(27, -287, wallThickness, 294);
    addWall(-95, -324, 610, wallThickness);
    addWall(-288, -86, 224, wallThickness);
    addWall(-288, 21, 224, wallThickness);
    addWall(118, -54, 183, wallThickness);
    addWall(-95, 286, 610, wallThickness);

    const bathFloorGeo = new THREE.PlaneGeometry(224, 107);
    const bathFloorMat = new THREE.MeshStandardMaterial({ color: 0x5a5f66, roughness: 0.8 });
    const bathFloor = new THREE.Mesh(bathFloorGeo, bathFloorMat);
    bathFloor.rotation.x = -Math.PI / 2;
    bathFloor.position.set(-288, 0.5, -32);
    aptGroup.add(bathFloor);

    const counterMat = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.5 });
    const counter = new THREE.Mesh(new THREE.BoxGeometry(100, 85, 40), counterMat);
    counter.position.set(-74, 85/2, -100);
    aptGroup.add(counter);
  } 
  else {
    addWall(0, -300, 600, wallThickness);
    addWall(-300, 0, wallThickness, 600);
    addWall(300, 0, wallThickness, 600);
    
    addWall(-200, 300, 200, wallThickness);
    addWindow(0, 300, 200, wallThickness);
    addWall(200, 300, 200, wallThickness);

    addWall(-75, 0, 450, wallThickness);
    addWall(0, -90, wallThickness, 420);

    addWall(-150, 60, wallThickness, 120);
    addWall(-225, 120, 150, wallThickness);

    addWall(-100, 210, wallThickness, 180);
    addWall(100, 210, wallThickness, 180);
    addWall(200, 150, wallThickness, 300);

    addWall(150, -50, wallThickness, 100);
    addWall(75, 0, 150, wallThickness);

    addWall(250, 120, 100, wallThickness);
    addWindow(200, -240, 200, wallThickness);

    const publicBathFloor = new THREE.Mesh(new THREE.PlaneGeometry(150, 100), new THREE.MeshStandardMaterial({ color: 0x5a5f66, roughness: 0.8 }));
    publicBathFloor.rotation.x = -Math.PI / 2;
    publicBathFloor.position.set(75, 0.5, -50);
    aptGroup.add(publicBathFloor);

    const masterBathFloor = new THREE.Mesh(new THREE.PlaneGeometry(150, 120), new THREE.MeshStandardMaterial({ color: 0x6c727a, roughness: 0.8 }));
    masterBathFloor.rotation.x = -Math.PI / 2;
    masterBathFloor.position.set(-225, 0.5, 60);
    aptGroup.add(masterBathFloor);

    const entranceFloor = new THREE.Mesh(new THREE.PlaneGeometry(80, 180), new THREE.MeshStandardMaterial({ color: 0xdcdde1, roughness: 0.6 }));
    entranceFloor.rotation.x = -Math.PI / 2;
    entranceFloor.position.set(260, 0.5, 210);
    aptGroup.add(entranceFloor);

    const kitFloor = new THREE.Mesh(new THREE.PlaneGeometry(100, 120), new THREE.MeshStandardMaterial({ color: 0xf5f6fa, roughness: 0.2, metalness: 0.1 }));
    kitFloor.rotation.x = -Math.PI / 2;
    kitFloor.position.set(250, 0.5, 60);
    aptGroup.add(kitFloor);

    const balconyFloor = new THREE.Mesh(new THREE.PlaneGeometry(200, 60), new THREE.MeshStandardMaterial({ color: 0xbfc7cc, roughness: 0.7 }));
    balconyFloor.rotation.x = -Math.PI / 2;
    balconyFloor.position.set(200, 0.5, -270);
    aptGroup.add(balconyFloor);

    const counterMat = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.5 });
    const topMat = new THREE.MeshStandardMaterial({ color: 0x2f3542, roughness: 0.2, metalness: 0.2 });
    
    const counter = new THREE.Mesh(new THREE.BoxGeometry(100, 85, 40), counterMat);
    counter.position.set(250, 85/2, 100);
    aptGroup.add(counter);

    const counterTop = new THREE.Mesh(new THREE.BoxGeometry(102, 4, 42), topMat);
    counterTop.position.set(250, 85 + 2, 100);
    aptGroup.add(counterTop);

    const counterSide = new THREE.Mesh(new THREE.BoxGeometry(40, 85, 100), counterMat);
    counterSide.position.set(280, 85/2, 50);
    aptGroup.add(counterSide);

    const counterSideTop = new THREE.Mesh(new THREE.BoxGeometry(42, 4, 102), topMat);
    counterSideTop.position.set(280, 85 + 2, 50);
    aptGroup.add(counterSideTop);

    const glassMat = new THREE.MeshStandardMaterial({ color: 0xa5d6a7, transparent: true, opacity: 0.35, roughness: 0.1 });
    const bathGlass = new THREE.Mesh(new THREE.BoxGeometry(2, 130, 45), glassMat);
    bathGlass.position.set(-150, 130/2, 60);
    aptGroup.add(bathGlass);
  }

  scene.add(aptGroup);
}

function loadRoom() {
  const loader = new THREE.GLTFLoader();
  const loadingEl = document.getElementById('loading');
  if (loadingEl) loadingEl.style.display = 'block';

  loader.load('/assets/assets/models/' + glbName, (gltf) => {
    const loadedApt = gltf.scene;
    loadedApt.name = 'apartment_glb';
    
    loadedApt.updateMatrixWorld(true);
    const box = getPercentileBoundingBox(loadedApt);
    const size = box.getSize(new THREE.Vector3());
    const maxDim = Math.max(size.x, size.z);
    
    if (maxDim > 0) {
      const targetScale = (roomSize * 0.95) / maxDim;
      loadedApt.scale.set(targetScale, targetScale, targetScale);
      loadedApt.updateMatrixWorld(true);
      
      const centeredBox = getPercentileBoundingBox(loadedApt);
      const center = centeredBox.getCenter(new THREE.Vector3());
      loadedApt.position.set(-center.x, -centeredBox.min.y, -center.z);
    }
    
    scene.add(loadedApt);
    loadAppliances();
  }, undefined, (err) => {
    console.warn("Could not load assets/models/" + glbName + ", generating high-fidelity simulated dollhouse fallback.");
    generateSimulatedApartment();
    loadAppliances();
  });
}

function loadAppliances() {
  const loader = new THREE.GLTFLoader();
  const lgEls = elements.filter(e => e.isLG);
  let loaded = 0;

  const loadingEl = document.getElementById('loading');

  if (lgEls.length === 0) {
    if (loadingEl) loadingEl.style.display = 'none';
    return;
  }

  lgEls.forEach(el => {
    let src = '';
    if (el.model3DUrl) {
      src = el.model3DUrl;
      if (!src.startsWith('assets/')) {
        src = 'assets/' + src;
      }
      if (!src.startsWith('assets/assets/')) {
        src = 'assets/' + src;
      }
      src = '/' + src;
    } else {
      src = getModelSrc(el.name);
    }

    loader.load(src, (gltf) => {
      const group = new THREE.Group();
      group.name = 'appliance_' + el.id;
      group.userData = el;

      const model = gltf.scene;
      model.updateMatrixWorld(true);

      const box = getPercentileBoundingBox(model);
      const size = box.getSize(new THREE.Vector3());

      const sizeX = size.x;
      const sizeY = size.y;
      const sizeZ = size.z;

      let scaleX = el.dx / sizeX;
      let scaleY = el.dy / sizeY;
      let scaleZ = el.dz / sizeZ;

      let rotateModel = 0;
      if (sizeZ > sizeX && el.dx > el.dz) {
        scaleX = el.dx / sizeZ;
        scaleZ = el.dz / sizeX;
        rotateModel = Math.PI / 2;
      }

      model.scale.set(scaleX, scaleY, scaleZ);
      model.rotation.y = rotateModel;
      model.updateMatrixWorld(true);

      const adjustedBox = getPercentileBoundingBox(model);
      const bottomY = adjustedBox.min.y;
      const center = adjustedBox.getCenter(new THREE.Vector3());

      model.position.set(-center.x, -bottomY, -center.z);
      group.add(model);

      group.position.x = el.x * (roomSize / 200.0);
      
      let targetY = el.y || 0;
      if (el.name.toLowerCase().includes('벽걸이') || el.name.toLowerCase().includes('wall')) {
        targetY = 180;
      }
      group.position.y = targetY;
      group.position.z = el.z * (roomSize / 200.0);

      const lowercaseName = el.name.toLowerCase();
      if (lowercaseName.includes('냉장고') || lowercaseName.includes('refrigerator')) {
        group.rotation.y = Math.PI;
      } else if (lowercaseName.includes('세탁기') || lowercaseName.includes('washer') ||
                 lowercaseName.includes('건조기') || lowercaseName.includes('dryer')) {
        if (el.x < 0) {
          group.rotation.y = Math.PI / 2;
        } else {
          group.rotation.y = -Math.PI / 2;
        }
      } else if (lowercaseName.includes('에어컨') || lowercaseName.includes('air')) {
        group.rotation.y = Math.PI;
      }

      scene.add(group);
      applianceMeshes.push(group);

      if (++loaded >= lgEls.length) {
        if (loadingEl) loadingEl.style.display = 'none';
        camera.position.set(roomSize * 0.05, 80, roomSize * 0.1);
      }
    }, undefined, (err) => {
      console.error('Error loading model in VR:', err);
      if (++loaded >= lgEls.length) {
        if (loadingEl) loadingEl.style.display = 'none';
      }
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

let alphaOffset = 0;
let isCalibrated = false;

const qOrient = new THREE.Quaternion();
const zee = new THREE.Vector3(0, 0, 1);

function updateCameraFromGyro() {
  if (deviceAlpha === 0 && deviceBeta === 90 && deviceGamma === 0) {
    return; // Wait for real sensor data
  }
  
  let currentAlpha = deviceAlpha;
  if (isCalibrated) {
    currentAlpha = deviceAlpha - alphaOffset;
  }
  
  euler.set(
    THREE.MathUtils.degToRad(deviceBeta),
    THREE.MathUtils.degToRad(currentAlpha),
    THREE.MathUtils.degToRad(-deviceGamma),
    'YXZ'
  );
  
  camera.quaternion.setFromEuler(euler);
  camera.quaternion.multiply(qScreen);
  
  let orientDeg = window.orientation;
  if (orientDeg === undefined && screen.orientation) {
    orientDeg = screen.orientation.angle;
  }
  const orient = orientDeg !== undefined ? THREE.MathUtils.degToRad(orientDeg) : THREE.MathUtils.degToRad(90);
  qOrient.setFromAxisAngle(zee, -orient);
  camera.quaternion.multiply(qOrient);
}

function calibrateGyro() {
  alphaOffset = deviceAlpha;
  isCalibrated = true;
  console.log("Gyro calibrated with yaw offset:", alphaOffset);
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

let activeFocusElement = null;
const infoPopupL = document.getElementById('info-popup-l');
const infoPopupR = document.getElementById('info-popup-r');
const infoNames  = document.querySelectorAll('.info-popup .info-name');
const infoCodes  = document.querySelectorAll('.info-popup .info-code');
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
  activeFocusElement = el;
  infoNames.forEach(node => node.textContent = el.name || '가전');
  infoCodes.forEach(node => node.textContent = el.code || '');

  // Render alternative appliances list
  const category = getCategoryFromName(el.name);
  const list = productsDb[category] || [];
  let altHtml = '';
  list.forEach(item => {
    const isCurrent = item.code === el.code;
    let imgSrc = item.front_image || '';
    if (imgSrc && !imgSrc.startsWith('assets/')) imgSrc = 'assets/' + imgSrc;
    if (imgSrc && !imgSrc.startsWith('assets/assets/')) imgSrc = 'assets/' + imgSrc;
    if (imgSrc && !imgSrc.startsWith('/')) imgSrc = '/' + imgSrc;

    altHtml += `
      <div class="alternative-card ${isCurrent ? 'current' : ''}">
        <img src="${imgSrc}" onerror="this.style.display='none';">
        <div class="alt-name">${item.name}</div>
      </div>
    `;
  });

  document.querySelectorAll('.info-popup .info-alternatives').forEach(container => {
    container.innerHTML = altHtml;
  });

  infoPopupL.style.display = 'block';
  infoPopupR.style.display = 'block';
  infoVisible = true;

  if (infoHideTimer) clearTimeout(infoHideTimer);
  infoHideTimer = setTimeout(() => {
    infoPopupL.style.display = 'none';
    infoPopupR.style.display = 'none';
    infoVisible = false;
    activeFocusElement = null;
  }, 6000);
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
// Movement: Finger snap audio recognition & Viewpoint cycling
// ══════════════════════════════════════════════════════════════
const viewpoints = [
  { x: 0, z: 0, label: "중앙" },
  { x: 0, z: -150, label: "거실 구역" },
  { x: 150, z: 80, label: "침실 구역" },
  { x: -150, z: -80, label: "부엌 구역" }
];
let currentViewpointIndex = 0;
let audioCtx = null;
let analyser = null;
let source = null;
let isAudioEnabled = false;
let lastPeakTime = 0;

async function initAudio() {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    analyser = audioCtx.createAnalyser();
    analyser.fftSize = 512;
    source = audioCtx.createMediaStreamSource(stream);
    source.connect(analyser);
    isAudioEnabled = true;
    console.log("Audio snap detection initialized");
    detectSnap();
  } catch (e) {
    console.warn("Microphone access denied or error:", e);
  }
}

function cycleViewpoint() {
  currentViewpointIndex = (currentViewpointIndex + 1) % viewpoints.length;
  const vp = viewpoints[currentViewpointIndex];
  
  const scaleFactor = roomSize / 600.0;
  const targetX = vp.x * scaleFactor;
  const targetZ = vp.z * scaleFactor;
  
  camera.position.x = targetX;
  camera.position.z = targetZ;
  camera.position.y = 80;
  
  showHUDNotification("위치 전환: " + vp.label);
}

function showHUDNotification(text) {
  const hud = document.getElementById('hud-label');
  if (hud) {
    hud.innerHTML = "🥽 " + text + " &nbsp;|&nbsp; 고개를 돌려 탐색";
    setTimeout(() => {
      hud.innerHTML = "🥽 손가락 딱! 소리로 위치 전환 &nbsp;|&nbsp; 가전을 응시하면 정보 표시";
    }, 2500);
  }
}

function detectSnap() {
  if (!isAudioEnabled) return;
  requestAnimationFrame(detectSnap);
  
  const bufferLength = analyser.fftSize;
  const data = new Float32Array(bufferLength);
  analyser.getFloatTimeDomainData(data);
  
  let peak = 0;
  let sum = 0;
  for (let i = 0; i < bufferLength; i++) {
    const val = Math.abs(data[i]);
    if (val > peak) peak = val;
    sum += val * val;
  }
  const rms = Math.sqrt(sum / bufferLength);
  
  const now = Date.now();
  const crestFactor = peak / (rms + 0.0001);
  
  if (peak > 0.35 && crestFactor > 4.0 && (now - lastPeakTime > 1000)) {
    lastPeakTime = now;
    if (!isCalibrated) {
      calibrateGyro();
      showHUDNotification("영점 조절(정면 설정) 완료! 🥽");
    } else {
      if (infoVisible && activeFocusElement) {
        cycleAlternativeAppliance();
      } else {
        cycleViewpoint();
      }
    }
  }
}

function cycleAlternativeAppliance() {
  if (!activeFocusElement) return;
  const el = activeFocusElement;
  const category = getCategoryFromName(el.name);
  const list = productsDb[category] || [];
  if (list.length === 0) return;
  
  const currentIndex = list.findIndex(item => item.code === el.code);
  const nextIndex = (currentIndex + 1) % list.length;
  const nextItem = list[nextIndex];
  
  if (nextItem.code === el.code) {
    showHUDNotification("대체 가전이 없습니다.");
    return;
  }
  
  swapApplianceInScene(
    el.id,
    nextItem.code,
    nextItem.name,
    nextItem.model_3d_url || '',
    nextItem.width_mm / 10,
    nextItem.height_mm / 10,
    nextItem.depth_mm / 10
  );
}

function swapApplianceInScene(id, code, name, model3DUrl, width, height, depth) {
  const wrapperName = 'appliance_' + id;
  const oldWrapper = scene.getObjectByName(wrapperName);
  if (!oldWrapper) {
    console.error('Old wrapper not found:', wrapperName);
    return;
  }
  
  const positionX = oldWrapper.position.x;
  const positionY = oldWrapper.position.y;
  const positionZ = oldWrapper.position.z;
  const rotationY = oldWrapper.rotation.y;
  
  scene.remove(oldWrapper);
  const idx = applianceMeshes.indexOf(oldWrapper);
  if (idx !== -1) {
    applianceMeshes.splice(idx, 1);
  }
  
  let src = model3DUrl;
  if (src) {
    if (!src.startsWith('assets/')) src = 'assets/' + src;
    if (!src.startsWith('assets/assets/')) src = 'assets/' + src;
    src = '/' + src;
  } else {
    src = getModelSrc(name);
  }
  
  const loader = new THREE.GLTFLoader();
  const loadingEl = document.getElementById('loading');
  if (loadingEl) {
    loadingEl.style.display = 'block';
    loadingEl.textContent = '가전 모델 교체 중...';
  }
  
  loader.load(src, (gltf) => {
    const group = new THREE.Group();
    group.name = wrapperName;
    
    const model = gltf.scene;
    model.updateMatrixWorld(true);
    
    const box = getPercentileBoundingBox(model);
    const size = box.getSize(new THREE.Vector3());
    
    let scaleX = width / size.x;
    let scaleY = height / size.y;
    let scaleZ = depth / size.z;
    
    let rotateModel = 0;
    if (size.z > size.x && width > depth) {
      scaleX = width / size.z;
      scaleZ = depth / size.x;
      rotateModel = Math.PI / 2;
    }
    
    model.scale.set(scaleX, scaleY, scaleZ);
    model.rotation.y = rotateModel;
    model.updateMatrixWorld(true);
    
    const adjustedBox = getPercentileBoundingBox(model);
    const bottomY = adjustedBox.min.y;
    const center = adjustedBox.getCenter(new THREE.Vector3());
    
    model.position.set(-center.x, -bottomY, -center.z);
    group.add(model);
    
    group.position.set(positionX, positionY, positionZ);
    group.rotation.y = rotationY;
    
    const newEl = {
      id: id,
      code: code,
      name: name,
      model3DUrl: model3DUrl,
      dx: width * 10,
      dy: height * 10,
      dz: depth * 10,
      isLG: true,
      x: activeFocusElement.x,
      y: activeFocusElement.y,
      z: activeFocusElement.z
    };
    group.userData = newEl;
    
    scene.add(group);
    applianceMeshes.push(group);
    
    const elIdx = elements.findIndex(item => item.id === id);
    if (elIdx !== -1) {
      elements[elIdx].code = code;
      elements[elIdx].name = name;
      elements[elIdx].model3DUrl = model3DUrl;
      elements[elIdx].dx = width * 10;
      elements[elIdx].dy = height * 10;
      elements[elIdx].dz = depth * 10;
    }
    
    showInfo(newEl);
    showHUDNotification("가전 교체 완료: " + name);
    
    if (loadingEl) loadingEl.style.display = 'none';
  }, undefined, (err) => {
    console.error('Error loading swap model in VR:', err);
    if (loadingEl) loadingEl.style.display = 'none';
  });
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

  isCalibrated = false;
  initThree();
  initAudio();
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
