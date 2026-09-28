

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'debug.dart';
import 'main.dart' show HardwareScreen;

/// Escena 3D: cielo, esfera y piso. Arrastrar orbita, pellizcar hace dolly.
///
/// La cámara NO se pasa a SceneView: se arma como un nodo con
/// CameraComponent, y el OrbitCameraController escribe su transformada con
/// lookAtFrom en cada update. CameraControls le pasa el input del táctil.
/// Así el movimiento queda suavizado por el controlador (en vez de saltar).
class EscenaScreen extends StatefulWidget {
  const EscenaScreen({super.key});

  @override
  State<EscenaScreen> createState() => _EscenaScreenState();
}

class _EscenaScreenState extends State<EscenaScreen> {
  final Scene _scene = Scene();

  bool _ready = false;
  String _error = '';
  bool _sombras = false;

  OrbitCameraController? _orbit;

  @override
  void initState() {
    super.initState();
    _arrancar();
  }

  Future<void> _arrancar() async {
    try {
      await Scene.initializeStaticResources();
      if (!mounted) return;

      // ── Cielo ──────────────────────────────────────────────────────────
      // GradientSkySource: el PhysicalSkySource (scattering atmosférico
      // full-screen) da 5 fps en gama media.
      final cielo = GradientSkySource(
        zenithColor: vm.Vector3(0.20, 0.42, 0.80),
        horizonColor: vm.Vector3(0.75, 0.82, 0.90),
        groundColor: vm.Vector3(0.14, 0.14, 0.16),
        sunDirection: vm.Vector3(0.35, 0.55, -0.7).normalized(),
        sunColor: vm.Vector3(1.0, 0.95, 0.85),
      );
      _scene.skybox = Skybox(cielo);

      // ── Luz ────────────────────────────────────────────────────────────
      // Solo los overrides que usan los ejemplos: el resto defaults.
      _scene.directionalLight = DirectionalLight(
        direction: vm.Vector3(-0.35, -0.55, 0.7).normalized(),
        intensity: 3.0,
        castsShadow: _sombras,
        shadowMaxDistance: 35.0,
      );
      _scene.environmentIntensity = 0.6;

      _scene.fog.enabled = true;
      _scene.fog.color = vm.Vector3(0.68, 0.76, 0.86);
      _scene.fog.density = 0.010;

      // ── Esfera ─────────────────────────────────────────────────────────
      final esfera = Node(
        mesh: Mesh(
          SphereGeometry(radius: 1.6, segments: 48, rings: 24),
          PhysicallyBasedMaterial()
            ..baseColorFactor = vm.Vector4(0.85, 0.20, 0.45, 1.0)
            ..metallicFactor = 0.8
            ..roughnessFactor = 0.2,
        ),
      );
      esfera.position = vm.Vector3(0, 1.7, 0);
      _scene.add(esfera);

      // ── Piso ───────────────────────────────────────────────────────────
      _scene.add(
        Node(
          mesh: Mesh(
            PlaneGeometry(width: 60, depth: 60, segmentsX: 1, segmentsZ: 1),
            PhysicallyBasedMaterial()
              ..baseColorFactor = vm.Vector4(0.32, 0.34, 0.38, 1.0)
              ..metallicFactor = 0.0
              ..roughnessFactor = 0.85,
          ),
        ),
      );

      // ── Cámara (nodo + componente + controlador) ───────────────────────
      final camara = Node()
        ..addComponent(
          CameraComponent(
            projection: PerspectiveProjection(
              fovRadiansY: 55 * vm.degrees2Radians,
            ),
            activateOnMount: true,
          ),
        )
        ..addComponent(
          OrbitCameraController(
            target: vm.Vector3(0, 1.4, 0),
            distance: 11.0,
            polar: 0.3,
            minDistance: 3.0,
            maxDistance: 40.0,
          ),
        );
      _orbit = camara.getComponent<OrbitCameraController>();
      _scene.add(camara);

      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _orbit;
    final mr = takeMemoryReport();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black26,
        foregroundColor: Colors.white,
        title: const Text('Escena', style: TextStyle(color: Colors.white)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.view_in_ar_rounded),
            color: Colors.white,
            tooltip: 'Menú',
            onSelected: (v) {
              if (v == 'sombras') {
                setState(() => _sombras = !_sombras);
                final dl = _scene.directionalLight;
                if (dl != null) dl.castsShadow = _sombras;
              } else if (v == 'debug') {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const DebugScreen()),
                );
              } else if (v == 'info') {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const HardwareScreen()),
                );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'sombras',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_sombras
                      ? Icons.light_mode
                      : Icons.light_mode_outlined),
                  title: Text('Sombras ${_sombras ? 'ON' : 'OFF'}'),
                ),
              ),
              const PopupMenuItem(
                value: 'debug',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.bug_report_outlined),
                  title: Text('Debug'),
                ),
              ),
              const PopupMenuItem(
                value: 'info',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.phone_android),
                  title: Text('Hardware'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _error.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('No se pudo crear la escena:\n$_error',
                    textAlign: TextAlign.center),
              ),
            )
          : !_ready || ctrl == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    Positioned.fill(
                      child: CameraControls(
                        controller: ctrl,
                        child: SceneView(_scene),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'dist ${ctrl.distance.toStringAsFixed(1)}  '
                          'GPU ${(mr.totalBytes / 1048576).toStringAsFixed(0)} MB',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
