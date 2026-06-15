import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'web_3d_viewer.dart';

class Web3DViewerStub extends Web3DViewer {
  const Web3DViewerStub({super.key, super.modelUrl, super.frontImage, super.elements});

  @override
  Widget build(BuildContext context) {
    if (elements != null) {
      return FullRoom3DViewer(elements: elements!);
    }

    final resolvedUrl = modelUrl ?? 'assets/models/haier_refrigerator.glb';
    return ModelViewer(
      backgroundColor: const Color(0xFFF8F9FC),
      src: resolvedUrl,
      alt: "LG Appliance 3D model",
      ar: false,
      autoRotate: true,
      cameraControls: true,
    );
  }
}

class FullRoom3DViewer extends StatefulWidget {
  final List<Map<String, dynamic>> elements;
  const FullRoom3DViewer({super.key, required this.elements});

  @override
  State<FullRoom3DViewer> createState() => _FullRoom3DViewerState();
}

class _FullRoom3DViewerState extends State<FullRoom3DViewer> {
  HttpServer? _server;
  WebViewController? _controller;
  String? _serverUrl;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  Future<void> _startServer() async {
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final serverUrl = 'http://127.0.0.1:$port/';
      
      setState(() {
        _server = server;
        _serverUrl = serverUrl;
      });

      // Initialize WebViewController
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent);
      
      controller.loadRequest(Uri.parse(serverUrl));
      
      setState(() {
        _controller = controller;
      });

      server.listen((HttpRequest request) async {
        final response = request.response;
        final path = request.uri.path;

        if (path == '/' || path == '/index.html') {
          final htmlContent = _buildHtml();
          final bytes = utf8.encode(htmlContent);
          response
            ..statusCode = HttpStatus.ok
            ..headers.add('Content-Type', 'text/html;charset=UTF-8')
            ..headers.add('Content-Length', bytes.length.toString())
            ..headers.add('Access-Control-Allow-Origin', '*')
            ..add(bytes);
          await response.close();
        } else if (path.endsWith('.glb')) {
          String assetKey = path;
          if (assetKey.startsWith('/')) {
            assetKey = assetKey.substring(1);
          }
          final assetsIndex = assetKey.indexOf('assets/');
          if (assetsIndex != -1) {
            assetKey = assetKey.substring(assetsIndex);
          } else {
            if (!assetKey.startsWith('assets/')) {
              assetKey = 'assets/$assetKey';
            }
          }
          if (assetKey.startsWith('assets/assets/')) {
            assetKey = assetKey.replaceFirst('assets/assets/', 'assets/');
          }

          try {
            final data = await rootBundle.load(assetKey);
            final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
            response
              ..statusCode = HttpStatus.ok
              ..headers.add('Content-Type', 'application/octet-stream')
              ..headers.add('Content-Length', bytes.length.toString())
              ..headers.add('Access-Control-Allow-Origin', '*')
              ..add(bytes);
          } catch (e) {
            debugPrint('Failed to load asset $assetKey: $e');
            response.statusCode = HttpStatus.notFound;
          }
          await response.close();
        } else {
          response.statusCode = HttpStatus.notFound;
          await response.close();
        }
      });
    } catch (e) {
      debugPrint('Failed to start loopback server: $e');
    }
  }

  @override
  void dispose() {
    _server?.close(force: true);
    super.dispose();
  }

  String _buildHtml() {
    final elementsJson = jsonEncode(widget.elements);
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
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
      top: 16px;
      right: 16px;
      z-index: 1000;
      display: flex;
      gap: 8px;
    }
    .control-btn {
      background: rgba(255, 255, 255, 0.85);
      backdrop-filter: blur(8px);
      border: 1.5px solid #e2e4e8;
      padding: 8px 14px;
      border-radius: 20px;
      font-family: sans-serif;
      font-size: 11px;
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
  </style>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/PointerLockControls.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/GLTFLoader.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/nipplejs@0.10.2/dist/nipplejs.min.js"></script>
</head>
<body>
  <div id="loading">LG 3D 가전 배치 공간 로딩 중...</div>
  
  <!-- UI Mode Switcher -->
  <div id="controls-panel">
    <button id="btn-orbit" class="control-btn active">전체 3D 보기 (Orbit)</button>
    <button id="btn-fps" class="control-btn">1인칭 탐색 (FPS)</button>
  </div>

  <!-- FPS Mode Guide Overlay (Desktop Only) -->
  <div id="fps-instructions">
    <div class="instructions-card">
      <div style="font-size: 16px; font-weight: bold; margin-bottom: 12px; color: #e6007e; display: flex; align-items: center; justify-content: center; gap: 6px;">
        <span>✦</span> 1인칭 가상공간 체험
      </div>
      <div style="font-size: 12px; color: #e2e4e8; line-height: 1.6; margin-bottom: 20px; text-align: left;">
        화면을 클릭하면 마우스 시점 조작이 활성화됩니다.<br><br>
        • 이동: <b>W, A, S, D</b> 또는 방향키<br>
        • 시점: 마우스 회전<br>
        • 조작 종료: <b>ESC</b> 키 입력
      </div>
      <button style="background: #e6007e; border: none; color: white; padding: 10px 24px; font-weight: bold; border-radius: 20px; font-size: 12px; cursor: pointer; box-shadow: 0 4px 10px rgba(230,0,126,0.3);">입장하기</button>
    </div>
  </div>

  <!-- Mobile Control Elements -->
  <div id="joystickZone" style="position: absolute; bottom: 30px; left: 30px; width: 100px; height: 100px; z-index: 1001; pointer-events: auto; display: none;"></div>
  <div id="lookArea" style="position: absolute; top: 0; right: 0; width: 60%; height: 100%; z-index: 900; touch-action: none; display: none;"></div>

  <div id="canvas3d"></div>

  <script>
    const container = document.getElementById('canvas3d');
    const loadingEl = document.getElementById('loading');

    // Parse layout areaSize from elements
    const elements = $elementsJson;
    const areaSize = (elements.length > 0 && elements[0].areaSize) ? elements[0].areaSize : '84㎡ (25평)';
    
    let roomSize = 600;
    let glbName = 'apartment_25py.glb';
    if (areaSize.includes('18평') || areaSize.includes('59㎡')) {
      roomSize = 450;
      glbName = 'apartment_18py.glb';
    } else if (areaSize.includes('34평') || areaSize.includes('114㎡')) {
      roomSize = 800;
      glbName = 'apartment_34py.glb';
    }

    const scene = new THREE.Scene();
    
    const camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 1, 2000);
    camera.position.set(roomSize * 0.75, roomSize * 0.58, roomSize * 0.75);

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
    controls.maxDistance = 1000;

    // First-Person Controls (FPS)
    const fpsControls = new THREE.PointerLockControls(camera, renderer.domElement);
    scene.add(fpsControls.getObject());

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

    // Living Room Rug (Under the sofa)
    const rug = new THREE.Mesh(new THREE.PlaneGeometry(240, 160), new THREE.MeshStandardMaterial({ 
      map: createRugTexture(), 
      roughness: 0.95 
    }));
    rug.rotation.x = -Math.PI / 2;
    rug.position.set(0, 0.2, 80);
    rug.receiveShadow = true;
    scene.add(rug);

    // Modern Sofa Group
    const sofaGroup = new THREE.Group();
    const fabricMat = new THREE.MeshStandardMaterial({ color: 0x3f3f46, roughness: 0.85 }); // charcoal grey fabric
    const metalLegMat = new THREE.MeshStandardMaterial({ color: 0x1e293b, metalness: 0.85, roughness: 0.2 });

    // Seat base
    const sofaBase = new THREE.Mesh(new THREE.BoxGeometry(180, 20, 80), fabricMat);
    sofaBase.position.y = 15;
    sofaBase.castShadow = true;
    sofaBase.receiveShadow = true;
    sofaGroup.add(sofaBase);

    // Seat cushions
    const cushion1 = new THREE.Mesh(new THREE.BoxGeometry(84, 12, 70), fabricMat);
    cushion1.position.set(-43, 27, 2);
    cushion1.castShadow = true;
    sofaGroup.add(cushion1);
    
    const cushion2 = new THREE.Mesh(new THREE.BoxGeometry(84, 12, 70), fabricMat);
    cushion2.position.set(43, 27, 2);
    cushion2.castShadow = true;
    sofaGroup.add(cushion2);

    // Backrest
    const backrest = new THREE.Mesh(new THREE.BoxGeometry(180, 48, 16), fabricMat);
    backrest.position.set(0, 45, -34);
    backrest.castShadow = true;
    sofaGroup.add(backrest);

    // Armrests
    const leftArm = new THREE.Mesh(new THREE.BoxGeometry(16, 38, 80), fabricMat);
    leftArm.position.set(-90, 28, 0);
    leftArm.castShadow = true;
    sofaGroup.add(leftArm);

    const rightArm = new THREE.Mesh(new THREE.BoxGeometry(16, 38, 80), fabricMat);
    rightArm.position.set(90, 28, 0);
    rightArm.castShadow = true;
    sofaGroup.add(rightArm);

    // Legs
    for (let lx of [-85, 85]) {
      for (let lz of [-35, 35]) {
        const leg = new THREE.Mesh(new THREE.CylinderGeometry(2, 1.5, 10), metalLegMat);
        leg.position.set(lx, 5, lz);
        leg.castShadow = true;
        sofaGroup.add(leg);
      }
    }
    sofaGroup.position.set(0, 0, 80);
    scene.add(sofaGroup);

    // Sleek Walnut Wood TV Cabinet stand
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
    standGroup.position.set(0, 0, -250);
    scene.add(standGroup);

    // Corner Houseplant pot
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
    plantGroup.position.set(130, 0, -240);
    scene.add(plantGroup);

    // Grid helper on floor (each square = 20cm x 20cm)
    const gridHelper = new THREE.GridHelper(roomSize, roomSize / 20, 0x8a877f, 0xe2e4e8);
    gridHelper.position.y = 0.05;
    scene.add(gridHelper);

    // --- High-fidelity Apartment Dollhouse Generator (Fallback) ---
    function generateSimulatedApartment() {
      const aptGroup = new THREE.Group();
      aptGroup.name = "simulated_apartment";

      // Poche wall materials: beige sides, solid black tops
      const sideMat = new THREE.MeshStandardMaterial({ color: 0xeae6df, roughness: 0.95 });
      const topMat = new THREE.MeshBasicMaterial({ color: 0x1a1a1a }); // black poche top
      const wallMaterials = [sideMat, sideMat, topMat, sideMat, sideMat, sideMat];
      
      const wallHeight = 120; // 120cm slice height (classic dollhouse view)
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

        // Base low wall under window
        const base = new THREE.Mesh(new THREE.BoxGeometry(w, baseH, d), wallMaterials);
        base.position.y = baseH / 2;
        base.castShadow = true;
        base.receiveShadow = true;
        windowGroup.add(base);

        // Glass panel
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

        // White frame borders
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

        windowGroup.name = "window";
        aptGroup.add(windowGroup);
      }

      const half = roomSize / 2;

      if (roomSize === 450) {
        // 18-pyeong layout (2 Rooms, Living/Kitchen, 1 Bath)
        addWall(0, -half, roomSize, wallThickness); // Back outer wall
        addWall(-half, 0, wallThickness, roomSize); // Left outer wall
        addWall(half, 0, wallThickness, roomSize);  // Right outer wall
        
        // Front walls with windows
        addWall(-150, half, 150, wallThickness);
        addWindow(0, half, 150, wallThickness);
        addWall(150, half, 150, wallThickness);

        // Bedroom 1 (Master)
        addWall(-112.5, 37.5, 112.5, wallThickness);
        addWall(-56.25, 112.5, wallThickness, 150);

        // Bathroom - Top left
        addWall(-150, -37.5, 120, wallThickness);
        addWall(-90, -75, wallThickness, 75);

        const bathFloorGeo = new THREE.PlaneGeometry(120, 75);
        const bathFloorMat = new THREE.MeshStandardMaterial({ color: 0x7f8c8d, roughness: 0.8 });
        const bathFloor = new THREE.Mesh(bathFloorGeo, bathFloorMat);
        bathFloor.rotation.x = -Math.PI / 2;
        bathFloor.position.set(-150, 0.5, -75);
        aptGroup.add(bathFloor);

        // Kitchen Counter
        const counterMat = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.5 });
        const counter = new THREE.Mesh(new THREE.BoxGeometry(35, 85, 120), counterMat);
        counter.position.set(190, 85/2, -120);
        aptGroup.add(counter);
      } 
      else if (roomSize === 800) {
        // 34-pyeong layout (Matched to real_blueprint.png)
        // Outer boundaries of layout
        addWall(0, -434, 800, wallThickness); // Back Wall
        addWall(-400, 0, wallThickness, 868); // Left outer Wall
        addWall(400, 0, wallThickness, 868);  // Right outer Wall
        addWall(0, 434, 800, wallThickness);  // Bottom Wall

        // Vertical wall separating staircase/elevator column from apartment
        addWall(210, 0, wallThickness, 868);

        // Internal Room Divider Walls
        // Vertical wall between Column 1 (left) and Column 2 (center)
        addWall(-176, -74, wallThickness, 720);
        // Vertical wall between Column 2 and Column 3
        addWall(27, -287, wallThickness, 294);
        // Horizontal wall separating Balcony (top)
        addWall(-95, -324, 610, wallThickness);
        // Horizontal wall between Bed 2.69 and Bath
        addWall(-288, -86, 224, wallThickness);
        // Horizontal wall between Bath and Master Bed
        addWall(-288, 21, 224, wallThickness);
        // Horizontal wall between Bed 2.20 and Living Room
        addWall(118, -54, 183, wallThickness);
        // Bottom balcony partition
        addWall(-95, 286, 610, wallThickness);

        // --- Floor Overlays ---
        // Bathroom Floor (middle-left)
        const bathFloorGeo = new THREE.PlaneGeometry(224, 107);
        const bathFloorMat = new THREE.MeshStandardMaterial({ color: 0x5a5f66, roughness: 0.8 });
        const bathFloor = new THREE.Mesh(bathFloorGeo, bathFloorMat);
        bathFloor.rotation.x = -Math.PI / 2;
        bathFloor.position.set(-288, 0.5, -32);
        aptGroup.add(bathFloor);

        // Kitchen Counter (L-shape along bottom and right kitchen walls)
        const counterMat = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.5 });
        const counter = new THREE.Mesh(new THREE.BoxGeometry(100, 85, 40), counterMat);
        counter.position.set(-74, 85/2, -100);
        aptGroup.add(counter);
      } 
      else {
        // Default 25-pyeong layout (Matched to the black-and-white APARTMENT 84 SQM FLOOR PLAN blueprint)
        // Outer boundaries
        addWall(0, -300, 600, wallThickness); // Back Wall
        addWall(-300, 0, wallThickness, 600); // Left outer Wall
        addWall(300, 0, wallThickness, 600);  // Right outer Wall
        
        // Front wall partition (with bedroom windows & balcony sliding glass door)
        addWall(-200, 300, 200, wallThickness);
        addWindow(0, 300, 200, wallThickness); // Living room front window
        addWall(200, 300, 200, wallThickness);

        // Horizontal line splitting top half and bottom half
        addWall(-75, 0, 450, wallThickness);

        // Vertical line separating Left side from Center/Hallway
        addWall(0, -90, wallThickness, 420);

        // Bathroom 4.1 sqm (middle-left)
        addWall(-150, 60, wallThickness, 120);
        addWall(-225, 120, 150, wallThickness);

        // Bedroom 2 (bottom-left) and Bedroom 2 (bottom-center) separator
        addWall(-100, 210, wallThickness, 180);

        // Bedroom 2 (bottom-center) and Bedroom 3 separator
        addWall(100, 210, wallThickness, 180);

        // Bedroom 3 and Foyer/Kitchen separator
        addWall(200, 150, wallThickness, 300);

        // Bathroom 5.2 sqm (top-center)
        addWall(150, -50, wallThickness, 100);
        addWall(75, 0, 150, wallThickness);

        // Kitchen / Dining separator
        addWall(250, 120, 100, wallThickness);

        // Balcony partition (top-right)
        addWindow(200, -240, 200, wallThickness);

        // --- Custom Floor Overlays (Tiling & Balcony) ---
        // Public Bath Floor (top-center, dark tiles)
        const publicBathFloor = new THREE.Mesh(new THREE.PlaneGeometry(150, 100), new THREE.MeshStandardMaterial({ color: 0x5a5f66, roughness: 0.8 }));
        publicBathFloor.rotation.x = -Math.PI / 2;
        publicBathFloor.position.set(75, 0.5, -50);
        publicBathFloor.receiveShadow = true;
        aptGroup.add(publicBathFloor);

        // Master Bath Floor (middle-left)
        const masterBathFloor = new THREE.Mesh(new THREE.PlaneGeometry(150, 120), new THREE.MeshStandardMaterial({ color: 0x6c727a, roughness: 0.8 }));
        masterBathFloor.rotation.x = -Math.PI / 2;
        masterBathFloor.position.set(-225, 0.5, 60);
        masterBathFloor.receiveShadow = true;
        aptGroup.add(masterBathFloor);

        // Entrance Tiled Floor (foyer)
        const entranceFloor = new THREE.Mesh(new THREE.PlaneGeometry(80, 180), new THREE.MeshStandardMaterial({ color: 0xdcdde1, roughness: 0.6 }));
        entranceFloor.rotation.x = -Math.PI / 2;
        entranceFloor.position.set(260, 0.5, 210);
        entranceFloor.receiveShadow = true;
        aptGroup.add(entranceFloor);

        // Kitchen Floor: Light Marble look (bottom-right)
        const kitFloor = new THREE.Mesh(new THREE.PlaneGeometry(100, 120), new THREE.MeshStandardMaterial({ color: 0xf5f6fa, roughness: 0.2, metalness: 0.1 }));
        kitFloor.rotation.x = -Math.PI / 2;
        kitFloor.position.set(250, 0.5, 60);
        kitFloor.receiveShadow = true;
        aptGroup.add(kitFloor);

        // Balcony Floor (top-right)
        const balconyFloor = new THREE.Mesh(new THREE.PlaneGeometry(200, 60), new THREE.MeshStandardMaterial({ color: 0xbfc7cc, roughness: 0.7 }));
        balconyFloor.rotation.x = -Math.PI / 2;
        balconyFloor.position.set(200, 0.5, -270);
        balconyFloor.receiveShadow = true;
        aptGroup.add(balconyFloor);

        // --- Architectural Kitchen Counter Group ---
        const counterMat = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.5 });
        const topMat = new THREE.MeshStandardMaterial({ color: 0x2f3542, roughness: 0.2, metalness: 0.2 }); // grey marble countertop
        
        // Counter block (along kitchen bottom wall)
        const counter = new THREE.Mesh(new THREE.BoxGeometry(100, 85, 40), counterMat);
        counter.position.set(250, 85/2, 100);
        counter.castShadow = true;
        counter.receiveShadow = true;
        aptGroup.add(counter);

        const counterTop = new THREE.Mesh(new THREE.BoxGeometry(102, 4, 42), topMat);
        counterTop.position.set(250, 85 + 2, 100);
        counterTop.castShadow = true;
        aptGroup.add(counterTop);

        // Side counter (along kitchen right wall)
        const counterSide = new THREE.Mesh(new THREE.BoxGeometry(40, 85, 100), counterMat);
        counterSide.position.set(280, 85/2, 50);
        counterSide.castShadow = true;
        aptGroup.add(counterSide);

        const counterSideTop = new THREE.Mesh(new THREE.BoxGeometry(42, 4, 102), topMat);
        counterSideTop.position.set(280, 85 + 2, 50);
        counterSideTop.castShadow = true;
        aptGroup.add(counterSideTop);

        // Bath Glass screens
        const glassMat = new THREE.MeshStandardMaterial({ color: 0xa5d6a7, transparent: true, opacity: 0.35, roughness: 0.1 });
        const bathGlass = new THREE.Mesh(new THREE.BoxGeometry(2, 130, 45), glassMat);
        bathGlass.position.set(-150, 130/2, 60);
        aptGroup.add(bathGlass);
      }

      scene.add(aptGroup);
    }

    const loader = new THREE.GLTFLoader();

    function getModelSrc(name) {
      const lowercase = name.toLowerCase();
      let path = '';
      if (lowercase.includes('냉장고') || lowercase.includes('refrigerator')) {
        path = 'assets/models/haier_refrigerator.glb';
      } else if (lowercase.includes('건조기') || lowercase.includes('dryer')) {
        path = 'assets/models/washer_dryer_machine.glb';
      } else if (lowercase.includes('세탁기') || lowercase.includes('washer')) {
        path = 'assets/models/washing_machine.glb';
      } else if (lowercase.includes('에어컨') || lowercase.includes('air')) {
        path = 'assets/models/air_conditioner.glb';
      } else {
        path = 'assets/models/haier_refrigerator.glb';
      }
      return path; // Return raw relative model path, server will resolve it
    }

    function loadAppliances() {
      const elements = $elementsJson;
      let loadedCount = 0;
      const totalToLoad = elements.filter(el => el.isLG).length;

      if (totalToLoad === 0) {
        loadingEl.style.opacity = 0;
      }

      elements.forEach(el => {
        if (!el.isLG) return;

        const src = getModelSrc(el.name);
        loader.load(src, (gltf) => {
          const model = gltf.scene;

          model.updateMatrixWorld(true);

          // Calculate size and scale
          const box = new THREE.Box3().setFromObject(model);
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

          const adjustedBox = new THREE.Box3().setFromObject(model);
          const bottomY = adjustedBox.min.y;
          const center = adjustedBox.getCenter(new THREE.Vector3());

          const wrapper = new THREE.Group();
          wrapper.name = 'appliance_' + el.id;
          
          model.position.set(-center.x, -bottomY, -center.z);
          wrapper.add(model);

          wrapper.position.x = el.x * 3.0;
          
          let targetY = el.y;
          if (el.name.toLowerCase().includes('벽걸이') || el.name.toLowerCase().includes('wall')) {
            targetY = 180;
          }
          
          wrapper.position.y = targetY;
          wrapper.position.z = el.z * 3.0;

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

    // Try loading 3D apartment blueprint model from server
    loader.load('assets/models/' + glbName, (gltf) => {
      const loadedApt = gltf.scene;
      loadedApt.name = 'apartment_glb';
      scene.add(loadedApt);

      loadedApt.traverse(node => {
        if (node.isMesh) {
          node.castShadow = true;
          node.receiveShadow = true;
        }
      });

      loadAppliances();
    }, undefined, (err) => {
      console.warn("Could not load assets/models/" + glbName + ", generating high-fidelity simulated dollhouse fallback.");
      generateSimulatedApartment();
      loadAppliances();
    });


    // === Navigation Controls Logic ===
    let currentMode = 'orbit'; // 'orbit' or 'fps'
    const isMobile = true; // Hardcoded true inside mobile webview context

    const btnOrbit = document.getElementById('btn-orbit');
    const btnFps = document.getElementById('btn-fps');
    const fpsInstructions = document.getElementById('fps-instructions');
    const joystickZone = document.getElementById('joystickZone');
    const lookArea = document.getElementById('lookArea');

    function setMode(mode) {
      currentMode = mode;
      if (mode === 'orbit') {
        btnOrbit.classList.add('active');
        btnFps.classList.remove('active');
        fpsInstructions.style.display = 'none';
        joystickZone.style.display = 'none';
        lookArea.style.display = 'none';
        
        fpsControls.unlock();
        controls.enabled = true;
        
        // Reset camera to standard top-down overview
        camera.position.set(roomSize * 0.75, roomSize * 0.58, roomSize * 0.75);
        controls.target.set(0, 0, 0);
      } else {
        btnOrbit.classList.remove('active');
        btnFps.classList.add('active');
        controls.enabled = false;
        
        // Eye level height at room center
        camera.position.set(0, 150, 150);
        camera.lookAt(0, 150, -100);
        
        fpsInstructions.style.display = 'none';
        joystickZone.style.display = 'block';
        lookArea.style.display = 'block';
        initJoystick();
      }
    }

    btnOrbit.addEventListener('click', () => setMode('orbit'));
    btnFps.addEventListener('click', () => setMode('fps'));

    // Mobile joystick setup
    let joystick = null;
    let mobileMove = { x: 0, y: 0 };
    
    function initJoystick() {
      if (joystick) return;
      joystick = nipplejs.create({
        zone: joystickZone,
        mode: 'static',
        position: { left: '50px', bottom: '50px' },
        color: '#e6007e',
        size: 80,
      });
      
      joystick.on('move', (_, d) => {
        if (d.vector) {
          mobileMove.x = d.vector.x;
          mobileMove.y = d.vector.y;
        }
      });
      
      joystick.on('end', () => {
        mobileMove.x = 0;
        mobileMove.y = 0;
      });
    }

    // Mobile swipe to look around
    let lookId = null, lastLX = 0, lastLY = 0;
    let yaw = 0, pitch = 0;
    
    lookArea.addEventListener('touchstart', (e) => {
      const t = e.touches[0];
      lookId = t.identifier;
      lastLX = t.clientX;
      lastLY = t.clientY;
    }, { passive: true });

    lookArea.addEventListener('touchmove', (e) => {
      for (const t of e.touches) {
        if (t.identifier === lookId) {
          const dx = t.clientX - lastLX;
          const dy = t.clientY - lastLY;
          lastLX = t.clientX;
          lastLY = t.clientY;
          
          yaw -= dx * 0.005;
          pitch -= dy * 0.005;
          pitch = Math.max(-Math.PI / 2.5, Math.min(Math.PI / 2.5, pitch));
          
          camera.rotation.order = 'YXZ';
          camera.rotation.y = yaw;
          camera.rotation.x = pitch;
        }
      }
    }, { passive: true });

    lookArea.addEventListener('touchend', () => {
      lookId = null;
    });

    // Camera boundaries clamping
    function clampInside(pos) {
      pos.y = 150; // Lock height at average eye level (1.5m)
      const margin = 20; // Margin distance from walls
      const limit = (roomSize / 2) - margin;
      pos.x = Math.max(-limit, Math.min(limit, pos.x));
      pos.z = Math.max(-limit, Math.min(limit, pos.z));
    }

    const clock = new THREE.Clock();

    window.addEventListener('resize', () => {
      camera.aspect = window.innerWidth / window.innerHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(window.innerWidth, window.innerHeight);
    });

    function animate() {
      requestAnimationFrame(animate);
      
      const dt = clock.getDelta();
      
      if (currentMode === 'orbit') {
        controls.update();
      } else if (currentMode === 'fps') {
        if (mobileMove.x !== 0 || mobileMove.y !== 0) {
          const fwd = mobileMove.y * SPEED * dt;
          const rgt = mobileMove.x * SPEED * dt;
          
          const sin = Math.sin(camera.rotation.y);
          const cos = Math.cos(camera.rotation.y);
          
          camera.position.x += (-sin * fwd) + (cos * rgt);
          camera.position.z += (-cos * fwd) + (-sin * rgt);
        }
        clampInside(camera.position);
      }
      
      renderer.render(scene, camera);
    }
    const SPEED = 220.0; // speed units (cm per second)
    animate();
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE6007E)),
        ),
      );
    }
    return WebViewWidget(controller: _controller!);
  }
}

Web3DViewer getWeb3DViewer({
  String? modelUrl,
  String? frontImage,
  List<Map<String, dynamic>>? elements,
}) {
  return Web3DViewerStub(
    modelUrl: modelUrl,
    frontImage: frontImage,
    elements: elements,
  );
}

