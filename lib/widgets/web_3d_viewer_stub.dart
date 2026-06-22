import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'web_3d_viewer.dart';

class Web3DViewerStub extends Web3DViewer {
  const Web3DViewerStub({
    super.key,
    super.modelUrl,
    super.frontImage,
    super.elements,
    super.productsDatabase,
    super.onApplianceSwapped,
    super.mood,
  });

  @override
  Widget build(BuildContext context) {
    if (elements != null) {
      return ThreeDWebviewRoomViewer(
        elements: elements!,
        productsDatabase: productsDatabase,
        onApplianceSwapped: onApplianceSwapped,
        mood: mood,
      );
    }
    if (modelUrl != null && modelUrl!.isNotEmpty) {
      return ModelViewer(
        src: modelUrl!,
        alt: 'LG 가전 3D 모델',
        ar: false,
        autoRotate: true,
        cameraControls: true,
        backgroundColor: const Color(0xFFF8F9FC),
      );
    }
    if (frontImage != null && frontImage!.isNotEmpty) {
      return Center(child: Image.asset(frontImage!, fit: BoxFit.contain));
    }
    return const Center(
      child: Text('3D 모델을 불러올 수 없습니다.',
          style: TextStyle(color: Color(0xFF8A877F), fontSize: 13)),
    );
  }
}

Web3DViewer getWeb3DViewer({
  String? modelUrl,
  String? frontImage,
  List<Map<String, dynamic>>? elements,
  Map<String, List<dynamic>>? productsDatabase,
  String? mood,
  void Function(
    String id,
    String code,
    String name,
    String? model3DUrl,
    double dx,
    double dy,
    double dz,
  )? onApplianceSwapped,
}) {
  return Web3DViewerStub(
    modelUrl: modelUrl,
    frontImage: frontImage,
    elements: elements,
    productsDatabase: productsDatabase,
    onApplianceSwapped: onApplianceSwapped,
    mood: mood,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ThreeDWebviewRoomViewer - Hosts WebGL Three.js inside Mobile Webview
// ─────────────────────────────────────────────────────────────────────────────

class ThreeDWebviewRoomViewer extends StatefulWidget {
  final List<Map<String, dynamic>> elements;
  final Map<String, List<dynamic>>? productsDatabase;
  final String? mood;
  final void Function(
    String id,
    String code,
    String name,
    String? model3DUrl,
    double dx,
    double dy,
    double dz,
  )? onApplianceSwapped;

  const ThreeDWebviewRoomViewer({
    super.key,
    required this.elements,
    this.productsDatabase,
    this.onApplianceSwapped,
    this.mood,
  });

  @override
  State<ThreeDWebviewRoomViewer> createState() => _ThreeDWebviewRoomViewerState();
}

class _ThreeDWebviewRoomViewerState extends State<ThreeDWebviewRoomViewer> {
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
      print('Local Three.js server running at: $_serverUrl');

      _server!.listen((HttpRequest request) async {
        final path = request.uri.path;
        
        try {
          if (path == '/') {
            final htmlTemplate = _getHtmlTemplate();
            request.response
              ..headers.contentType = ContentType.html
              ..write(htmlTemplate)
              ..close();
          } else if (path.startsWith('/assets/')) {
            String assetPath = path.substring(1); // remove leading slash
            if (assetPath.startsWith('assets/assets/')) {
              assetPath = assetPath.substring(7);
            }
            try {
              final byteData = await rootBundle.load(assetPath);
              final bytes = byteData.buffer.asUint8List();
              
              // Set Content-Type
              if (path.endsWith('.glb')) {
                request.response.headers.contentType = ContentType('application', 'octet-stream');
              } else if (path.endsWith('.js')) {
                request.response.headers.contentType = ContentType('application', 'javascript');
              } else if (path.endsWith('.png')) {
                request.response.headers.contentType = ContentType('image', 'png');
              } else if (path.endsWith('.jpg') || path.endsWith('.jpeg')) {
                request.response.headers.contentType = ContentType('image', 'jpeg');
              }
              
              request.response.add(bytes);
            } catch (e) {
              print('Failed to serve asset: $assetPath, error: $e');
              request.response.statusCode = HttpStatus.notFound;
            }
            await request.response.close();
          } else {
            request.response
              ..statusCode = HttpStatus.notFound
              ..close();
          }
        } catch (e) {
          print('Error serving local asset request: $e');
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..close();
        }
      });

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFFF8F9FC))
        ..setOnConsoleMessage((JavaScriptConsoleMessage message) {
          debugPrint('WebView Console: ${message.message} (level: ${message.level.name})');
        })
        ..addJavaScriptChannel(
          'ApplianceChannel',
          onMessageReceived: (JavaScriptMessage message) {
            try {
              final data = json.decode(message.message) as Map<String, dynamic>;
              if (data['action'] == 'swap' && widget.onApplianceSwapped != null) {
                widget.onApplianceSwapped!(
                  data['id'] as String,
                  data['code'] as String,
                  data['name'] as String,
                  data['model3DUrl'] as String?,
                  (data['dx'] as num).toDouble(),
                  (data['dy'] as num).toDouble(),
                  (data['dz'] as num).toDouble(),
                );
              }
            } catch (e) {
              print('Error decoding ApplianceChannel message: $e');
            }
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (url) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(_serverUrl!));

      setState(() {
        _controller = controller;
      });
    } catch (e) {
      print('Failed to start local loopback server: $e');
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
        child: CircularProgressIndicator(color: Color(0xFFE6007E)),
      );
    }
    return Stack(
      children: [
        WebViewWidget(controller: _controller!),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFFE6007E)),
          ),
      ],
    );
  }

  String _getHtmlTemplate() {
    final elementsJson = jsonEncode(widget.elements);
    final dbJson = jsonEncode(widget.productsDatabase ?? {});
    final moodVal = widget.mood ?? '우드톤';
    return _rawHtml
        .replaceAll('__ELEMENTS_JSON__', elementsJson)
        .replaceAll('__PRODUCTS_DATABASE_JSON__', dbJson)
        .replaceAll('__MOOD_VALUE__', moodVal);
  }

  static const String _rawHtml = r'''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    body, html {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: radial-gradient(circle, #ffffff 0%, #eef1f6 100%);
    }
    #canvas3d {
      width: 100%;
      height: 100%;
    }
    #loading {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      font-family: sans-serif;
      font-size: 13px;
      color: #e6007e;
      font-weight: bold;
      pointer-events: none;
      background: rgba(255,255,255,0.9);
      padding: 10px 20px;
      border-radius: 20px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.1);
      transition: opacity 0.3s;
      z-index: 2000;
    }

    /* UI Buttons & Control Panel */
    #controls-panel {
      position: absolute;
      top: 24px;
      right: 24px;
      z-index: 1000;
      display: flex;
      gap: 12px;
    }
    .control-btn {
      background: rgba(255, 255, 255, 0.85);
      backdrop-filter: blur(8px);
      border: 1.5px solid #e2e4e8;
      padding: 12px 20px;
      border-radius: 24px;
      font-family: sans-serif;
      font-size: 13px;
      font-weight: bold;
      color: #555555;
      cursor: pointer;
      box-shadow: 0 4px 10px rgba(0,0,0,0.08);
      transition: all 0.2s ease;
    }
    .control-btn:hover {
      background: #ffffff;
      border-color: #e6007e;
      color: #e6007e;
    }
    .control-btn.active {
      background: #e6007e;
      border-color: #e6007e;
      color: white;
    }
    
    /* FPS Info Modal Overlay */
    #fps-instructions {
      display: none;
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background: rgba(0,0,0,0.45);
      z-index: 999;
      justify-content: center;
      align-items: center;
      cursor: pointer;
      flex-direction: column;
      font-family: sans-serif;
      color: white;
    }
    .instructions-card {
      background: rgba(20, 20, 20, 0.9);
      backdrop-filter: blur(12px);
      padding: 24px 32px;
      border-radius: 16px;
      text-align: center;
      border: 1px solid rgba(255,255,255,0.15);
      box-shadow: 0 10px 30px rgba(0,0,0,0.3);
      max-width: 320px;
    }

    /* Scrollbar Styling for Premium List */
    #alternatives-container::-webkit-scrollbar {
      height: 4px;
    }
    #alternatives-container::-webkit-scrollbar-track {
      background: rgba(255, 255, 255, 0.05);
      border-radius: 2px;
    }
    #alternatives-container::-webkit-scrollbar-thumb {
      background: rgba(255, 255, 255, 0.2);
      border-radius: 2px;
    }
    #alternatives-container::-webkit-scrollbar-thumb:hover {
      background: rgba(255, 255, 255, 0.4);
    }

    /* Premium UI Feedbacks */
    .swap-card {
      transition: transform 0.2s cubic-bezier(0.25, 1, 0.5, 1), background-color 0.2s ease, border-color 0.2s ease, box-shadow 0.2s ease;
      cursor: pointer;
    }
    .swap-card:active {
      transform: scale(0.96);
      background: rgba(255, 255, 255, 0.12) !important;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3) !important;
    }
    .swap-card.current:active {
      background: rgba(230, 0, 126, 0.2) !important;
    }

    .close-btn {
      transition: background-color 0.2s, transform 0.1s;
    }
    .close-btn:active {
      transform: scale(0.9);
      background: rgba(255, 255, 255, 0.3) !important;
    }

    .swap-action-btn {
      transition: background-color 0.2s, transform 0.1s, border-color 0.2s;
    }
    .swap-action-btn:not(:disabled):active {
      transform: scale(0.96);
      background: #b30062 !important;
    }
  </style>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/GLTFLoader.js"></script>
</head>
<body>
  <div id="loading">LG 3D 가전 배치 공간 로딩 중...</div>

  <!-- Alternative Appliances Swap Panel -->
  <div id="swapPanel" style="
    position: absolute;
    bottom: -370px;
    left: 0;
    width: 100%;
    height: 310px;
    background: rgba(20, 20, 20, 0.88);
    backdrop-filter: blur(24px);
    -webkit-backdrop-filter: blur(24px);
    border-top: 1px solid rgba(255, 255, 255, 0.18);
    border-radius: 28px 28px 0px 0px;
    z-index: 1005;
    transition: bottom 0.35s cubic-bezier(0.16, 1, 0.3, 1);
    font-family: sans-serif;
    color: white;
    padding: 16px 16px 8px 16px;
    box-sizing: border-box;
    box-shadow: 0 -12px 40px rgba(0, 0, 0, 0.5);
    display: flex;
    flex-direction: column;
  ">
    <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 10px;">
      <div style="flex: 1; min-width: 0;">
        <div style="display: flex; align-items: center; gap: 6px; margin-bottom: 4px;">
          <div id="swap-category-badge" style="font-size: 10px; font-weight: bold; background: #e6007e; color: white; padding: 2px 8px; border-radius: 10px; text-transform: uppercase;">Category</div>
          <div id="swap-code" style="font-size: 11px; color: #b0b5c0;">Model Code</div>
        </div>
        <div id="swap-title" style="font-size: 14px; font-weight: bold; line-height: 1.3; overflow: hidden; text-overflow: ellipsis; display: -webkit-box; -webkit-line-clamp: 1; -webkit-box-orient: vertical; color: #ffffff;">Appliance Name</div>
      </div>
      <button class="close-btn" onclick="event.stopPropagation(); hideSwapPanel(); clearSelectionWithoutHidingPanel();" style="background: rgba(255,255,255,0.12); border: none; border-radius: 50%; width: 32px; height: 32px; color: white; font-weight: bold; font-size: 14px; cursor: pointer; display: flex; align-items: center; justify-content: center; outline: none; margin-left: 10px; flex-shrink: 0;">✕</button>
    </div>
    
    <div style="font-size: 11px; font-weight: bold; margin-bottom: 8px; color: #e6007e; display: flex; align-items: center; gap: 4px;">
      <span>✦</span> 가전 교체 제안 리스트
    </div>
    <div id="alternatives-container" style="flex: 1; overflow-x: auto; display: flex; gap: 12px; padding-bottom: 4px; align-items: stretch;">
      <!-- Populated dynamically -->
    </div>
  </div>

  <div id="canvas3d"></div>


  <script>
    const container = document.getElementById('canvas3d');
    const loadingEl = document.getElementById('loading');

    // Parse layout areaSize from elements
    let elements = __ELEMENTS_JSON__;
    const productsDb = __PRODUCTS_DATABASE_JSON__;

    // Raycasting & Selection variables
    const raycaster = new THREE.Raycaster();
    const mouse = new THREE.Vector2();
    let selectedGroup = null;
    let boxHelper = null;

    const areaSize = (elements.length > 0 && elements[0].areaSize) ? elements[0].areaSize : '84㎡ (25평)';
    const selectedMood = '__MOOD_VALUE__';
    
    let roomSize = 600;
    let glbName = 'apartment_25py.glb';
    if (areaSize.includes('18평') || areaSize.includes('59㎡')) {
      roomSize = 450;
      glbName = 'apartment_18py.glb';
    } else if (areaSize.includes('34평') || areaSize.includes('112㎡') || areaSize.includes('114㎡')) {
      roomSize = 800;
      if (selectedMood === '미드센추리') {
        glbName = 'apartment_34py_midcentury.glb';
      } else if (selectedMood === '미니멀') {
        glbName = 'apartment_34py_minimal.glb';
      } else if (selectedMood === 'Cozy') {
        glbName = 'apartment_34py_cozy.glb';
      } else {
        glbName = 'apartment_34py.glb';
      }
    }
    roomSize = roomSize * 1.5;

    const scene = new THREE.Scene();
    
    const camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 1, roomSize * 20);
    camera.position.set(roomSize * 0.8, roomSize * 1.13, roomSize * 0.8);

    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    renderer.setPixelRatio(window.devicePixelRatio);
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.0;
    container.appendChild(renderer.domElement);

    // Default Controls (Orbit)
    const controls = new THREE.OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    controls.dampingFactor = 0.05;
    controls.maxPolarAngle = Math.PI / 2 - 0.02; 
    controls.minDistance = 50;
    controls.maxDistance = roomSize * 8;

    // Procedural Textures Generation (CORS & Path Safe)
    function createWoodFloorTexture() {
      const canvas = document.createElement('canvas');
      canvas.width = 512;
      canvas.height = 512;
      const ctx = canvas.getContext('2d');
      ctx.fillStyle = '#dfcbaf';
      ctx.fillRect(0, 0, 512, 512);

      // Oak Planks
      const plankHeight = 32;
      const plankWidth = 128;
      ctx.strokeStyle = '#bfa586';
      ctx.lineWidth = 1.5;

      for (let y = 0; y <= 512; y += plankHeight) {
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(512, y);
        ctx.stroke();

        const offset = (y / plankHeight) % 2 * 64;
        for (let x = -64; x <= 576; x += plankWidth) {
          ctx.beginPath();
          ctx.moveTo(x + offset, y);
          ctx.lineTo(x + offset, y + plankHeight);
          ctx.stroke();
        }
      }

      // Plank color variations
      for (let y = 0; y < 512; y += plankHeight) {
        const offset = (y / plankHeight) % 2 * 64;
        for (let x = -64; x <= 576; x += plankWidth) {
          if (Math.random() > 0.6) {
            ctx.fillStyle = 'rgba(0, 0, 0, 0.03)';
            ctx.fillRect(x + offset, y, plankWidth, plankHeight);
          } else if (Math.random() > 0.8) {
            ctx.fillStyle = 'rgba(255, 255, 255, 0.04)';
            ctx.fillRect(x + offset, y, plankWidth, plankHeight);
          }
        }
      }

      // Subtle wood grains
      for (let i = 0; i < 4000; i++) {
        const rx = Math.random() * 512;
        const ry = Math.random() * 512;
        ctx.fillStyle = Math.random() > 0.5 ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.05)';
        ctx.fillRect(rx, ry, 3 + Math.random() * 10, 1);
      }

      const texture = new THREE.CanvasTexture(canvas);
      texture.wrapS = THREE.RepeatWrapping;
      texture.wrapT = THREE.RepeatWrapping;
      texture.repeat.set(4, 4);
      return texture;
    }

    function createRugTexture() {
      const canvas = document.createElement('canvas');
      canvas.width = 128;
      canvas.height = 128;
      const ctx = canvas.getContext('2d');
      ctx.fillStyle = '#e2dfd9';
      ctx.fillRect(0, 0, 128, 128);

      ctx.strokeStyle = '#ccc8be';
      ctx.lineWidth = 1;
      for (let i = 0; i < 128; i += 4) {
        ctx.beginPath();
        ctx.moveTo(i, 0);
        ctx.lineTo(i, 128);
        ctx.stroke();

        ctx.beginPath();
        ctx.moveTo(0, i);
        ctx.lineTo(128, i);
        ctx.stroke();
      }

      const texture = new THREE.CanvasTexture(canvas);
      texture.wrapS = THREE.RepeatWrapping;
      texture.wrapT = THREE.RepeatWrapping;
      texture.repeat.set(2, 2);
      return texture;
    }

    // Lights
    const ambientLight = new THREE.AmbientLight(0xfffaf0, 0.45);
    scene.add(ambientLight);

    // Warm Sun Light streaming through window
    const sunLight = new THREE.DirectionalLight(0xfff5e6, 0.95);
    sunLight.position.set(150, 280, -350);
    sunLight.castShadow = true;
    sunLight.shadow.mapSize.width = 2048;
    sunLight.shadow.mapSize.height = 2048;
    sunLight.shadow.bias = -0.0005;
    sunLight.shadow.radius = 4;
    scene.add(sunLight);

    // Ceiling spot light for living room center
    const ceilingSpot = new THREE.SpotLight(0xffffff, 0.6, 600, Math.PI / 4, 0.5, 1);
    ceilingSpot.position.set(0, 230, 80);
    ceilingSpot.castShadow = true;
    scene.add(ceilingSpot);

    // Floor (Oak wood texture)
    const floorGeo = new THREE.BoxGeometry(roomSize, 1, roomSize);
    const floorMat = new THREE.MeshStandardMaterial({ 
      map: createWoodFloorTexture(), 
      roughness: 0.4,
      metalness: 0.05
    });
    const floor = new THREE.Mesh(floorGeo, floorMat);
    floor.position.y = -0.5;
    floor.receiveShadow = true;
    scene.add(floor);

    // (Sofa and Rug removed as requested to avoid layout clutter)
    const metalLegMat = new THREE.MeshStandardMaterial({ color: 0x1e293b, metalness: 0.85, roughness: 0.2 });


    // TV Stand
    const standGroup = new THREE.Group();
    const walnutMat = new THREE.MeshStandardMaterial({ color: 0x543e2f, roughness: 0.65 });
    
    const cabinet = new THREE.Mesh(new THREE.BoxGeometry(160, 26, 45), walnutMat);
    cabinet.position.y = 13;
    cabinet.castShadow = true;
    cabinet.receiveShadow = true;
    standGroup.add(cabinet);

    for (let lx of [-70, 70]) {
      for (let lz of [-18, 18]) {
        const leg = new THREE.Mesh(new THREE.CylinderGeometry(1.5, 1.5, 6), metalLegMat);
        leg.position.set(lx, 3, lz);
        leg.castShadow = true;
        standGroup.add(leg);
      }
    }
    standGroup.position.set(0, 0, -250 * 1.5);
    scene.add(standGroup);

    // Houseplant
    const plantGroup = new THREE.Group();
    const pot = new THREE.Mesh(new THREE.CylinderGeometry(15, 11, 26), new THREE.MeshStandardMaterial({ color: 0xfafafa, roughness: 0.4 }));
    pot.position.y = 13;
    pot.castShadow = true;
    plantGroup.add(pot);

    const leafMat = new THREE.MeshStandardMaterial({ color: 0x1d4d38, roughness: 0.8 });
    for (let i = 0; i < 6; i++) {
      const leaf = new THREE.Mesh(new THREE.SphereGeometry(14, 8, 8), leafMat);
      leaf.scale.set(1, 2.0, 0.4);
      leaf.rotation.x = Math.random() * 0.4 + 0.2;
      leaf.rotation.y = (i * Math.PI / 3.0);
      leaf.position.set(Math.sin(i) * 6, 26 + i * 3, Math.cos(i) * 6);
      leaf.castShadow = true;
      plantGroup.add(leaf);
    }
    plantGroup.position.set(130 * 1.5, 0, -240 * 1.5);
    scene.add(plantGroup);

    // Grid helper
    const gridHelper = new THREE.GridHelper(roomSize, roomSize / 20, 0x8a877f, 0xe2e4e8);
    gridHelper.position.y = 0.05;
    scene.add(gridHelper);

    // Apartment dollhouse generator
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
        wall.castShadow = true;
        wall.receiveShadow = true;
        aptGroup.add(wall);
      }

      function addWindow(x, z, w, d, rotationY = 0) {
        const baseH = 35;
        const windowGroup = new THREE.Group();
        windowGroup.position.set(x, 0, z);
        windowGroup.rotation.y = rotationY;

        const base = new THREE.Mesh(new THREE.BoxGeometry(w, baseH, d), wallMaterials);
        base.position.y = baseH / 2;
        base.castShadow = true;
        base.receiveShadow = true;
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
        publicBathFloor.receiveShadow = true;
        aptGroup.add(publicBathFloor);

        const masterBathFloor = new THREE.Mesh(new THREE.PlaneGeometry(150, 120), new THREE.MeshStandardMaterial({ color: 0x6c727a, roughness: 0.8 }));
        masterBathFloor.rotation.x = -Math.PI / 2;
        masterBathFloor.position.set(-225, 0.5, 60);
        masterBathFloor.receiveShadow = true;
        aptGroup.add(masterBathFloor);

        const entranceFloor = new THREE.Mesh(new THREE.PlaneGeometry(80, 180), new THREE.MeshStandardMaterial({ color: 0xdcdde1, roughness: 0.6 }));
        entranceFloor.rotation.x = -Math.PI / 2;
        entranceFloor.position.set(260, 0.5, 210);
        entranceFloor.receiveShadow = true;
        aptGroup.add(entranceFloor);

        const kitFloor = new THREE.Mesh(new THREE.PlaneGeometry(100, 120), new THREE.MeshStandardMaterial({ color: 0xf5f6fa, roughness: 0.2, metalness: 0.1 }));
        kitFloor.rotation.x = -Math.PI / 2;
        kitFloor.position.set(250, 0.5, 60);
        kitFloor.receiveShadow = true;
        aptGroup.add(kitFloor);

        const balconyFloor = new THREE.Mesh(new THREE.PlaneGeometry(200, 60), new THREE.MeshStandardMaterial({ color: 0xbfc7cc, roughness: 0.7 }));
        balconyFloor.rotation.x = -Math.PI / 2;
        balconyFloor.position.set(200, 0.5, -270);
        balconyFloor.receiveShadow = true;
        aptGroup.add(balconyFloor);

        const counterMat = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.5 });
        const topMat = new THREE.MeshStandardMaterial({ color: 0x2f3542, roughness: 0.2, metalness: 0.2 });
        
        const counter = new THREE.Mesh(new THREE.BoxGeometry(100, 85, 40), counterMat);
        counter.position.set(250, 85/2, 100);
        counter.castShadow = true;
        counter.receiveShadow = true;
        aptGroup.add(counter);

        const counterTop = new THREE.Mesh(new THREE.BoxGeometry(102, 4, 42), topMat);
        counterTop.position.set(250, 85 + 2, 100);
        counterTop.castShadow = true;
        aptGroup.add(counterTop);

        const counterSide = new THREE.Mesh(new THREE.BoxGeometry(40, 85, 100), counterMat);
        counterSide.position.set(280, 85/2, 50);
        counterSide.castShadow = true;
        aptGroup.add(counterSide);

        const counterSideTop = new THREE.Mesh(new THREE.BoxGeometry(42, 4, 102), topMat);
        counterSideTop.position.set(280, 85 + 2, 50);
        counterSideTop.castShadow = true;
        aptGroup.add(counterSideTop);

        const glassMat = new THREE.MeshStandardMaterial({ color: 0xa5d6a7, transparent: true, opacity: 0.35, roughness: 0.1 });
        const bathGlass = new THREE.Mesh(new THREE.BoxGeometry(2, 130, 45), glassMat);
        bathGlass.position.set(-150, 130/2, 60);
        aptGroup.add(bathGlass);
      }

      scene.add(aptGroup);
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

    const loader = new THREE.GLTFLoader();

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
      return 'assets/' + path;
    }

    function loadAppliances() {
      const elements = __ELEMENTS_JSON__;
      let loadedCount = 0;
      const totalToLoad = elements.filter(el => el.isLG).length;

      if (totalToLoad === 0) {
        loadingEl.style.opacity = 0;
      }

      elements.forEach(el => {
        if (!el.isLG) return;

        let src = '';
        if (el.model3DUrl) {
          src = el.model3DUrl;
          if (!src.startsWith('assets/')) {
            src = 'assets/' + src;
          }
          if (!src.startsWith('assets/assets/')) {
            src = 'assets/' + src;
          }
        } else {
          src = getModelSrc(el.name);
        }
        loader.load(src, (gltf) => {
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

          const wrapper = new THREE.Group();
          wrapper.name = 'appliance_' + el.id;
          
          model.position.set(-center.x, -bottomY, -center.z);
          wrapper.add(model);

          wrapper.position.x = el.x * (roomSize / 200.0);
          
          let targetY = el.y;
          if (el.name.toLowerCase().includes('벽걸이') || el.name.toLowerCase().includes('wall')) {
            targetY = 180;
          }
          
          wrapper.position.y = targetY;
          wrapper.position.z = el.z * (roomSize / 200.0);

          const lowercaseName = el.name.toLowerCase();
          if (lowercaseName.includes('냉장고') || lowercaseName.includes('refrigerator')) {
            wrapper.rotation.y = Math.PI;
          } else if (lowercaseName.includes('세탁기') || lowercaseName.includes('washer') ||
                     lowercaseName.includes('건조기') || lowercaseName.includes('dryer')) {
            if (el.x < 0) {
              wrapper.rotation.y = Math.PI / 2;
            } else {
              wrapper.rotation.y = -Math.PI / 2;
            }
          } else if (lowercaseName.includes('에어컨') || lowercaseName.includes('air')) {
            wrapper.rotation.y = Math.PI;
          }

          model.traverse(node => {
            if (node.isMesh) {
              node.castShadow = true;
              node.receiveShadow = true;
              if (node.material) {
                node.material.roughness = 0.8;
                node.material.metalness = 0.1;
              }
            }
          });

          scene.add(wrapper);
          
          loadedCount++;
          if (loadedCount >= totalToLoad) {
            loadingEl.style.opacity = 0;
          }
        }, undefined, (err) => {
          console.error('Loader error:', err);
          loadedCount++;
          if (loadedCount >= totalToLoad) {
            loadingEl.style.opacity = 0;
          }
        });
      });
    }

    loader.load('assets/models/' + glbName, (gltf) => {
      const loadedApt = gltf.scene;
      loadedApt.name = 'apartment_glb';
      
      // Compute bounding box and normalize size
      loadedApt.updateMatrixWorld(true);
      const box = getPercentileBoundingBox(loadedApt);
      const size = box.getSize(new THREE.Vector3());
      const maxDim = Math.max(size.x, size.z);
      
      if (maxDim > 0) {
        // Scale to fit roomSize
        const targetScale = (roomSize * 0.95) / maxDim;
        loadedApt.scale.set(targetScale, targetScale, targetScale);
        loadedApt.updateMatrixWorld(true);
        
        // Center on floor (y = 0)
        const centeredBox = getPercentileBoundingBox(loadedApt);
        const center = centeredBox.getCenter(new THREE.Vector3());
        loadedApt.position.set(-center.x, -centeredBox.min.y, -center.z);
      }
      
      scene.add(loadedApt);

      loadedApt.traverse(node => {
        if (node.isMesh) {
          node.castShadow = true;
          node.receiveShadow = true;
          if (node.material) {
            node.material.roughness = 0.6;
            node.material.metalness = 0.2;
          }
        }
      });

      loadAppliances();
    }, undefined, (err) => {
      console.warn("Could not load assets/models/" + glbName + ", generating high-fidelity simulated dollhouse fallback.");
      generateSimulatedApartment();
      loadAppliances();
    });



    // === Selection & Raycasting Logic ===
    let pointerDownTime = 0;
    let pointerDownX = 0;
    let pointerDownY = 0;

    window.addEventListener('pointerdown', (e) => {
      pointerDownTime = Date.now();
      pointerDownX = e.clientX;
      pointerDownY = e.clientY;
    });

    window.addEventListener('pointerup', (e) => {
      const duration = Date.now() - pointerDownTime;
      const dist = Math.hypot(e.clientX - pointerDownX, e.clientY - pointerDownY);
      if (duration < 300 && dist < 10) {
        onSceneClick(e);
      }
    });

    function onSceneClick(event) {
      if (event.target.closest('#swapPanel')) {
        return;
      }

      mouse.x = (event.clientX / window.innerWidth) * 2 - 1;
      mouse.y = -(event.clientY / window.innerHeight) * 2 + 1;

      raycaster.setFromCamera(mouse, camera);

      const appliances = [];
      scene.traverse(node => {
        if (node.isGroup && node.name && node.name.startsWith('appliance_')) {
          appliances.push(node);
        }
      });

      const intersects = raycaster.intersectObjects(appliances, true);

      if (intersects.length > 0) {
        let hit = intersects[0].object;
        while (hit && hit.parent && hit !== scene) {
          if (hit.name && hit.name.startsWith('appliance_')) {
            break;
          }
          hit = hit.parent;
        }

        if (hit && hit.name && hit.name.startsWith('appliance_')) {
          selectAppliance(hit);
        } else {
          clearSelection();
        }
      } else {
        clearSelection();
      }
    }

    function selectAppliance(group) {
      clearSelectionWithoutHidingPanel();
      selectedGroup = group;

      boxHelper = new THREE.BoxHelper(group, 0xe6007e);
      scene.add(boxHelper);

      const id = group.name.replace('appliance_', '');
      const el = elements.find(item => item.id === id);
      if (el) {
        showSwapPanel(el);
      }
    }

    function clearSelectionWithoutHidingPanel() {
      if (boxHelper) {
        scene.remove(boxHelper);
        if (boxHelper.geometry) boxHelper.geometry.dispose();
        if (boxHelper.material) {
          if (Array.isArray(boxHelper.material)) {
            boxHelper.material.forEach(m => m.dispose());
          } else {
            boxHelper.material.dispose();
          }
        }
        boxHelper = null;
      }
      selectedGroup = null;
    }

    function clearSelection() {
      clearSelectionWithoutHidingPanel();
      hideSwapPanel();
    }

    function showSwapPanel(el) {
      const swapPanel = document.getElementById('swapPanel');
      const categoryBadge = document.getElementById('swap-category-badge');
      const titleEl = document.getElementById('swap-title');
      const codeEl = document.getElementById('swap-code');
      const container = document.getElementById('alternatives-container');
      
      const category = getCategoryFromName(el.name);
      categoryBadge.innerText = getCategoryDisplayName(category);
      titleEl.innerText = el.name;
      codeEl.innerText = el.code || 'LG 가전';
      
      container.innerHTML = '';
      
      const list = productsDb[category] || [];
      
      if (list.length === 0) {
        container.innerHTML = '<div style="color: #b0b5c0; font-size: 12px; margin: auto;">제안 가능한 대체 가전이 없습니다.</div>';
      } else {
        list.forEach(item => {
          const isCurrent = item.code === el.code;
          
          const card = document.createElement('div');
          card.className = 'swap-card' + (isCurrent ? ' current' : '');
          card.style.flex = '0 0 185px';
          card.style.background = isCurrent ? 'rgba(230, 0, 126, 0.15)' : 'rgba(255, 255, 255, 0.08)';
          card.style.border = isCurrent ? '1.5px solid #e6007e' : '1px solid rgba(255, 255, 255, 0.15)';
          card.style.borderRadius = '16px';
          card.style.padding = '14px';
          card.style.display = 'flex';
          card.style.flexDirection = 'column';
          card.style.justifyContent = 'space-between';
          card.style.boxSizing = 'border-box';
          
          let imgHtml = '';
          if (item.front_image) {
            let imgSrc = item.front_image;
            if (!imgSrc.startsWith('assets/')) imgSrc = 'assets/' + imgSrc;
            if (!imgSrc.startsWith('assets/assets/')) imgSrc = 'assets/' + imgSrc;
            imgHtml = `<img src="${imgSrc}" style="width: 100%; height: 75px; object-fit: contain; margin-bottom: 8px; border-radius: 4px;" onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';">`;
          }
          
          card.innerHTML = `
            <div style="display: flex; flex-direction: column; height: 100%; justify-content: space-between;">
              <div>
                ${imgHtml}
                <div style="display: none; height: 75px; background: rgba(255,255,255,0.05); border-radius: 4px; margin-bottom: 8px; align-items: center; justify-content: center; font-size: 24px; color: rgba(255,255,255,0.3)">✦</div>
                <div style="font-size: 13px; font-weight: bold; line-height: 1.3; overflow: hidden; text-overflow: ellipsis; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; margin-bottom: 4px;">${item.name}</div>
                <div style="font-size: 11px; color: #b0b5c0;">W ${Math.round(item.width_mm/10)} x H ${Math.round(item.height_mm/10)} x D ${Math.round(item.depth_mm/10)} cm</div>
              </div>
              <button class="swap-action-btn" ${isCurrent ? 'disabled' : ''} onclick="triggerSwap('${el.id}', '${item.code}', '${item.name.replace(/'/g, "\\'")}', '${item.model_3d_url || ''}', ${item.width_mm/10}, ${item.height_mm/10}, ${item.depth_mm/10})" style="
                width: 100%;
                padding: 6px 4px;
                background: ${isCurrent ? 'transparent' : '#e6007e'};
                border: ${isCurrent ? '1px solid rgba(230,0,126,0.4)' : 'none'};
                color: ${isCurrent ? '#e6007e' : 'white'};
                font-size: 10.5px;
                font-weight: bold;
                border-radius: 8px;
                margin-top: 10px;
                cursor: pointer;
                outline: none;
                transition: background 0.2s;
                display: flex;
                flex-direction: column;
                align-items: center;
                gap: 2px;
              ">
                ${isCurrent 
                  ? '<span>현재 배치됨</span>' 
                  : `<span>구독 ${getAppliancePrices(category, item.code).sub}</span>
                     <span style="font-size: 8.5px; opacity: 0.85; font-weight: normal;">일시불 ${getAppliancePrices(category, item.code).used}</span>`
                }
              </button>
            </div>
          `;
          
          container.appendChild(card);
        });
      }
      
      swapPanel.style.bottom = '0px';
    }

    function getAppliancePrices(category, itemCode) {
      let basePrice = 1000000;
      if (category === 'refrigerators') {
        basePrice = 1200000;
      } else if (category === 'washers') {
        basePrice = 700000;
      } else if (category === 'dryers') {
        basePrice = 800000;
      } else if (category === 'air-conditioners') {
        basePrice = 1500000;
      }
      
      let hash = 0;
      for (let i = 0; i < itemCode.length; i++) {
        hash = itemCode.charCodeAt(i) + ((hash << 5) - hash);
      }
      let factor = 0.8 + (Math.abs(hash % 4) * 0.1);
      let finalPrice = Math.round((basePrice * factor) / 10000) * 10000;
      let subPrice = Math.round((finalPrice / 24) / 100) * 100;
      
      return {
        used: (finalPrice / 10000) + '만원',
        sub: '월 ' + subPrice.toLocaleString() + '원'
      };
    }

    function hideSwapPanel() {
      const swapPanel = document.getElementById('swapPanel');
      if (swapPanel) {
        swapPanel.style.bottom = '-370px';
      }
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

    function getCategoryDisplayName(cat) {
      switch(cat) {
        case 'refrigerators': return '냉장고';
        case 'washers': return '세탁기';
        case 'dryers': return '건조기';
        case 'air-conditioners': return '에어컨';
        default: return '가전';
      }
    }

    function triggerSwap(id, code, name, model3DUrl, width, height, depth) {
      swapApplianceInScene(id, code, name, model3DUrl, width, height, depth);
      
      const payload = JSON.stringify({
        action: 'swap',
        id: id,
        code: code,
        name: name,
        model3DUrl: model3DUrl,
        dx: width,
        dy: height,
        dz: depth
      });

      if (window.ApplianceChannel && window.ApplianceChannel.postMessage) {
        window.ApplianceChannel.postMessage(payload);
      } else {
        console.log('ApplianceChannel not found, testing/web message fallback.');
        window.parent.postMessage(payload, '*');
      }
    }

    function swapApplianceInScene(id, code, name, model3DUrl, width, height, depth) {
      const wrapperName = 'appliance_' + id;
      const oldWrapper = scene.getObjectByName(wrapperName);
      if (!oldWrapper) {
        console.error('Old appliance model wrapper not found in scene:', wrapperName);
        return;
      }

      const positionX = oldWrapper.position.x;
      const positionY = oldWrapper.position.y;
      const positionZ = oldWrapper.position.z;
      const rotationY = oldWrapper.rotation.y;

      scene.remove(oldWrapper);

      let src = model3DUrl;
      if (src) {
        if (!src.startsWith('assets/')) {
          src = 'assets/' + src;
        }
        if (!src.startsWith('assets/assets/')) {
          src = 'assets/' + src;
        }
      } else {
        src = getModelSrc(name);
      }

      loadingEl.innerText = '가전 모델 교체 중...';
      loadingEl.style.opacity = 1;

      loader.load(src, (gltf) => {
        const model = gltf.scene;
        model.updateMatrixWorld(true);

        const box = getPercentileBoundingBox(model);
        const size = box.getSize(new THREE.Vector3());

        const sizeX = size.x;
        const sizeY = size.y;
        const sizeZ = size.z;

        let scaleX = width / sizeX;
        let scaleY = height / sizeY;
        let scaleZ = depth / sizeZ;

        let rotateModel = 0;
        if (sizeZ > sizeX && width > depth) {
          scaleX = width / sizeZ;
          scaleZ = depth / sizeX;
          rotateModel = Math.PI / 2;
        }

        model.scale.set(scaleX, scaleY, scaleZ);
        model.rotation.y = rotateModel;
        model.updateMatrixWorld(true);

        const adjustedBox = getPercentileBoundingBox(model);
        const bottomY = adjustedBox.min.y;
        const center = adjustedBox.getCenter(new THREE.Vector3());

        const newWrapper = new THREE.Group();
        newWrapper.name = wrapperName;

        model.position.set(-center.x, -bottomY, -center.z);
        newWrapper.add(model);

        newWrapper.position.set(positionX, positionY, positionZ);
        newWrapper.rotation.y = rotationY;

        model.traverse(node => {
          if (node.isMesh) {
            node.castShadow = true;
            node.receiveShadow = true;
            if (node.material) {
              node.material.roughness = 0.8;
              node.material.metalness = 0.1;
            }
          }
        });

        scene.add(newWrapper);
        
        const elementIndex = elements.findIndex(item => item.id === id);
        if (elementIndex !== -1) {
          elements[elementIndex].code = code;
          elements[elementIndex].name = name;
          elements[elementIndex].model3DUrl = model3DUrl;
          elements[elementIndex].dx = width;
          elements[elementIndex].dy = height;
          elements[elementIndex].dz = depth;
        }
        
        selectAppliance(newWrapper);
        
        loadingEl.style.opacity = 0;
      }, undefined, (err) => {
        console.error('Error loading swap model GLB:', err);
        loadingEl.style.opacity = 0;
      });
    }

    window.addEventListener('resize', () => {
      camera.aspect = window.innerWidth / window.innerHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(window.innerWidth, window.innerHeight);
    });

    function animate() {
      requestAnimationFrame(animate);
      controls.update();
      renderer.render(scene, camera);
    }
    animate();
  </script>
</body>
</html>
''';
}
