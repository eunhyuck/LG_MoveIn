import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'web_3d_viewer.dart';

class Web3DViewerWeb extends Web3DViewer {
  const Web3DViewerWeb({super.key, super.modelUrl, super.frontImage, super.elements});

  @override
  Widget build(BuildContext context) {
    if (elements != null) {
      return _buildFullRoom3D(context);
    } else {
      return _buildSingleModel3D(context);
    }
  }

  Widget _buildSingleModel3D(BuildContext context) {
    final String viewType = 'model-viewer-${modelUrl.hashCode}-${frontImage.hashCode}';
    String resolvedUrl = modelUrl ?? '';
    if (resolvedUrl.startsWith('assets/')) {
      resolvedUrl = 'assets/$resolvedUrl';
    }

    final String srcDoc = '''
<!DOCTYPE html>
<html>
<head>
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
    }
  </style>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/GLTFLoader.js"></script>
</head>
<body>
  <div id="loading">LG 3D 가전 로딩 중...</div>
  <div id="canvas3d"></div>

  <script>
    const container = document.getElementById('canvas3d');
    const loadingEl = document.getElementById('loading');

    const scene = new THREE.Scene();
    
    const camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 0.1, 100);
    camera.position.set(2, 1.5, 2);

    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    renderer.setPixelRatio(window.devicePixelRatio);
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.0;
    container.appendChild(renderer.domElement);

    const controls = new THREE.OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    controls.dampingFactor = 0.05;
    controls.maxPolarAngle = Math.PI / 2 - 0.05;
    controls.minDistance = 0.5;
    controls.maxDistance = 10;
    controls.autoRotate = true;
    controls.autoRotateSpeed = 2.0;

    // Lights
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.85);
    scene.add(ambientLight);

    const dirLight = new THREE.DirectionalLight(0xffffff, 0.9);
    dirLight.position.set(5, 8, 3);
    dirLight.castShadow = true;
    dirLight.shadow.mapSize.width = 1024;
    dirLight.shadow.mapSize.height = 1024;
    scene.add(dirLight);

    // Subtle grid/shadow receiver
    const floorGeo = new THREE.PlaneGeometry(10, 10);
    const floorMat = new THREE.ShadowMaterial({ opacity: 0.15 });
    const floor = new THREE.Mesh(floorGeo, floorMat);
    floor.rotation.x = -Math.PI / 2;
    floor.position.y = -0.5;
    floor.receiveShadow = true;
    scene.add(floor);

    // Loader
    const loader = new THREE.GLTFLoader();
    loader.load('$resolvedUrl', (gltf) => {
      const model = gltf.scene;

      model.updateMatrixWorld(true);

      // Center and normalize model size to fit nicely in 2x2x2 bounding box
      const box = new THREE.Box3().setFromObject(model);
      const size = box.getSize(new THREE.Vector3());
      const maxDim = Math.max(size.x, size.y, size.z);
      const scale = 1.2 / maxDim; // Normalize to fit nicely
      model.scale.set(scale, scale, scale);

      model.updateMatrixWorld(true);

      const centeredBox = new THREE.Box3().setFromObject(model);
      const center = centeredBox.getCenter(new THREE.Vector3());
      
      const wrapper = new THREE.Group();
      model.position.set(-center.x, -centeredBox.min.y - 0.5, -center.z);
      wrapper.add(model);

      // Rotate to show front by default
      const lowercaseName = '$resolvedUrl'.toLowerCase();
      if (lowercaseName.includes('refrigerator') || lowercaseName.includes('haier')) {
        wrapper.rotation.y = Math.PI; // Face camera
      } else if (lowercaseName.includes('washer') || lowercaseName.includes('dryer') || lowercaseName.includes('washing')) {
        wrapper.rotation.y = -Math.PI / 2;
      } else if (lowercaseName.includes('air')) {
        wrapper.rotation.y = Math.PI;
      }

      // Materials & Shadows
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
      loadingEl.style.opacity = 0;
    }, undefined, (err) => {
      console.error(err);
      loadingEl.style.opacity = 0;
    });

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

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..srcdoc = srcDoc;
      return iframe;
    });

    return HtmlElementView(viewType: viewType);
  }

  Widget _buildFullRoom3D(BuildContext context) {
    final String jsonStr = jsonEncode(elements);
    final String viewType = 'room-3d-${jsonStr.hashCode}';

    final String srcDoc = '''
<!DOCTYPE html>
<html>
<head>
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
    }
  </style>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/GLTFLoader.js"></script>
</head>
<body>
  <div id="loading">LG 3D 가전 배치 공간 로딩 중...</div>
  <div id="canvas3d"></div>

  <script>
    const container = document.getElementById('canvas3d');
    const loadingEl = document.getElementById('loading');

    const scene = new THREE.Scene();
    
    const camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 1, 2000);
    camera.position.set(450, 350, 450);

    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    renderer.setPixelRatio(window.devicePixelRatio);
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.0;
    container.appendChild(renderer.domElement);

    const controls = new THREE.OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    controls.dampingFactor = 0.05;
    controls.maxPolarAngle = Math.PI / 2 - 0.02; 
    controls.minDistance = 50;
    controls.maxDistance = 1000;

    // Lights
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.7);
    scene.add(ambientLight);

    const dirLight = new THREE.DirectionalLight(0xffffff, 0.85);
    dirLight.position.set(300, 500, 200);
    dirLight.castShadow = true;
    dirLight.shadow.mapSize.width = 2048;
    dirLight.shadow.mapSize.height = 2048;
    dirLight.shadow.bias = -0.0005;
    scene.add(dirLight);

    const hemiLight = new THREE.HemisphereLight(0xffffff, 0x444444, 0.35);
    hemiLight.position.set(0, 500, 0);
    scene.add(hemiLight);

    // Floor (Realistic 6m x 6m room)
    const floorGeo = new THREE.BoxGeometry(600, 1, 600);
    const floorMat = new THREE.MeshStandardMaterial({ 
      color: 0xf3f4f6, 
      roughness: 0.6,
      metalness: 0.1
    });
    const floor = new THREE.Mesh(floorGeo, floorMat);
    floor.position.y = -0.5;
    floor.receiveShadow = true;
    scene.add(floor);

    // Wall Planes (Height 2.4m)
    const wallMat = new THREE.MeshStandardMaterial({ 
      color: 0xffffff, 
      roughness: 0.9,
      side: THREE.DoubleSide
    });
    
    // Back Wall (Z = -300)
    const backWall = new THREE.Mesh(new THREE.PlaneGeometry(600, 240), wallMat);
    backWall.position.set(0, 120, -300);
    backWall.receiveShadow = true;
    scene.add(backWall);

    // Left Wall (X = -300)
    const leftWall = new THREE.Mesh(new THREE.PlaneGeometry(600, 240), wallMat);
    leftWall.rotation.y = Math.PI / 2;
    leftWall.position.set(-300, 120, 0);
    leftWall.receiveShadow = true;
    scene.add(leftWall);

    // Grid helper on floor (each square = 20cm x 20cm)
    const gridHelper = new THREE.GridHelper(600, 30, 0x8a877f, 0xe2e4e8);
    gridHelper.position.y = 0.05;
    scene.add(gridHelper);

    // Load Appliances
    const elements = $jsonStr;
    const loader = new THREE.GLTFLoader();
    let loadedCount = 0;
    const totalToLoad = elements.filter(el => el.isLG).length;

    if (totalToLoad === 0) {
      loadingEl.style.opacity = 0;
    }

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
      return 'assets/' + path;
    }

    elements.forEach(el => {
      if (!el.isLG) return;

      const src = getModelSrc(el.name);
      loader.load(src, (gltf) => {
        const model = gltf.scene;

        // Force world matrix update so bounding box calculates correctly
        model.updateMatrixWorld(true);

        // Calculate size and scale
        const box = new THREE.Box3().setFromObject(model);
        const size = box.getSize(new THREE.Vector3());

        const sizeX = size.x;
        const sizeY = size.y;
        const sizeZ = size.z;

        // Scale to fit real spec in cm
        let scaleX = el.dx / sizeX;
        let scaleY = el.dy / sizeY;
        let scaleZ = el.dz / sizeZ;

        // Swap X and Z scale factors if the model was designed facing sideways (Z is longer than X)
        // so that the model's longest side matches the target width (el.dx)
        if (sizeZ > sizeX && el.dx > el.dz) {
          scaleX = el.dx / sizeZ;
          scaleZ = el.dz / sizeX;
        }

        model.scale.set(scaleX, scaleY, scaleZ);

        // Force world matrix update again after scaling to recalculate correct bounding box
        model.updateMatrixWorld(true);

        // Adjust vertical alignment (sit on floor) and calculate center for centering pivot
        const adjustedBox = new THREE.Box3().setFromObject(model);
        const bottomY = adjustedBox.min.y;
        const center = adjustedBox.getCenter(new THREE.Vector3());

        // Create a wrapper group to act as the pivot point
        const wrapper = new THREE.Group();
        
        // Position the model inside the wrapper so that its bottom-center is at (0, 0, 0)
        model.position.set(-center.x, -bottomY, -center.z);
        wrapper.add(model);

        // Position coordinates mapped from percentage (-100..100) to 6m bounds (-300..300)
        wrapper.position.x = el.x * 3.0;
        
        let targetY = el.y;
        if (el.name.toLowerCase().includes('벽걸이') || el.name.toLowerCase().includes('wall')) {
          targetY = 180; // Mount high on the wall
        }
        
        wrapper.position.y = targetY;
        wrapper.position.z = el.z * 3.0;

        // Rotate the wrapper to face the room center instead of the walls
        const lowercaseName = el.name.toLowerCase();
        if (lowercaseName.includes('냉장고') || lowercaseName.includes('refrigerator')) {
          wrapper.rotation.y = Math.PI; // Rotate 180 deg to show front doors
        } else if (lowercaseName.includes('세탁기') || lowercaseName.includes('washer') ||
                   lowercaseName.includes('건조기') || lowercaseName.includes('dryer')) {
          if (el.x < 0) {
            wrapper.rotation.y = Math.PI / 2; // Face right
          } else {
            wrapper.rotation.y = -Math.PI / 2; // Face left
          }
        } else if (lowercaseName.includes('에어컨') || lowercaseName.includes('air')) {
          wrapper.rotation.y = Math.PI; // Face forward
        }

        // Enable shadows and adjust material parameters to be bright without an environment map
        model.traverse(node => {
          if (node.isMesh) {
            node.castShadow = true;
            node.receiveShadow = true;
            if (node.material) {
              node.material.roughness = 0.8; // increase diffuse roughness
              node.material.metalness = 0.1; // lower metalness to prevent black void reflections
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

    // Handle Window Resize
    window.addEventListener('resize', () => {
      camera.aspect = window.innerWidth / window.innerHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(window.innerWidth, window.innerHeight);
    });

    // Animation Loop
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

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..srcdoc = srcDoc;
      return iframe;
    });

    return HtmlElementView(viewType: viewType);
  }
}

Web3DViewer getWeb3DViewer({String? modelUrl, String? frontImage, List<Map<String, dynamic>>? elements}) {
  return Web3DViewerWeb(modelUrl: modelUrl, frontImage: frontImage, elements: elements);
}
