import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'debug.dart';
import 'main.dart' show HardwareScreen;

/// Escena 3D: cielo, esfera y piso plano. Arrastrar = mirar a los lados,
/// pellizcar = acercar/alejar.
///
/// La cámara searma nueva en cada frame (cameraBuilder) porque si se
/// reusa la instancia el motor se queda con la transformada vieja.
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

  // Estado de la cámara (lo lee el builder cada frame).
  double _yaw = 0.0;
  double _pitch = 0.28;
  double _dist = 11.0;
  double _yaw0 = 0.0;
  double _pitch0 = 0.0;
  double _dist0 = 11.0;
  vm.Vector3 _target = vm.Vector3(0, 1.4, 0);

  @override
  void initState() {
    super.initState();
    _arrancar();
  }

  Future<void> _arrancar() async {
    try {
      await Scene.initializeStaticResources();
      if (!mounted) return;

      // Cielo BARATO: gradiente. El PhysicalSkySource (scattering
      // atmosférico full-screen) son 5 fps en gama media.
      final cielo = GradientSkySource(
        zenithColor: vm.Vector3(0.20, 0.42, 0.80),
        horizonColor: vm.Vector3(0.75, 0.82, 0.90),
        groundColor: vm.Vector3(0.14, 0.14, 0.16),
        sunDirection: vm.Vector3(0.35, 0.55, -0.7).normalized(),
        sunColor: vm.Vector3(1.0, 0.95, 0.85),
      );
      _scene.skybox = Skybox(cielo);

      // Luz direccional aparte (barata), sin IBL rebake.
      _scene.directionalLight = DirectionalLight(
        direction: vm.Vector3(-0.35, -0.55, 0.7).normalized(),
        color: vm.Vector3(1.0, 0.96, 0.88),
        intensity: 2.4,
        castsShadow: _sombras,
        shadowCascadeCount: 1,
        shadowMapResolution: 512,
        shadowMaxDistance: 40.0,
      );

      _scene.fog.enabled = true;
      _scene.fog.color = vm.Vector3(0.68, 0.76, 0.86);
      _scene.fog.density = 0.010;

      // Esfera: metal pulido, refleja el cielo.
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

      // Piso plano en XZ (mira a +Y).
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

      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Esférica → cámara, en una instancia nueva.
  vm.PerspectiveCamera _camara() {
    final cp = math.cos(_pitch);
    return PerspectiveCamera(
      position: vm.Vector3(
        math.sin(_yaw) * cp * _dist,
        _target.y + math.sin(_pitch) * _dist,
        math.cos(_yaw) * cp * _dist,
      ),
      target: _target,
      fovRadiansY: 55 * math.pi / 180,
    );
  }

  void _mirar(double dx, double dy) {
    setState(() {
      _yaw = _yaw0 + dx;
      _pitch = (_pitch0 - dy).clamp(-1.35, 1.35);
    });
  }

  /// [escala] > 1 = dedos hacia afuera = ACERCAR (divide la distancia).
  void _zoom(double escala) {
    setState(() => _dist = (_dist0 / escala).clamp(3.0, 40.0));
  }

  @override
  Widget build(BuildContext context) {
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
              if (v == 'debug') {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const DebugScreen()),
                );
              } else if (v == 'info') {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const HardwareScreen()),
                );
              } else if (v == 'sombras') {
                setState(() => _sombras = !_sombras);
                final dl = _scene.directionalLight;
                if (dl != null) dl.castsShadow = _sombras;
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
          : !_ready
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    Positioned.fill(
                      // Listener (no GestureDetector): la escena se come los
                      // gestos, pero el Listener translúcido los ve igual.
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: (_) {
                          _yaw0 = _yaw;
                          _pitch0 = _pitch;
                          _dist0 = _dist;
                        },
                        onPointerMove: (e) {
                          if (e.buttons != 0 || true) {
                            _mirar(e.delta.dx * 0.006, e.delta.dy * 0.006);
                          }
                        },
                        onPointerSignal: (e) {
                          if (e is PointerScrollEvent) {
                            _yaw0 = _yaw;
                            _pitch0 = _pitch;
                            _dist0 = _dist;
                            _zoom(1 + e.scrollDelta.dy * 0.0015);
                          }
                        },
                        child: SceneView(
                          _scene,
                          cameraBuilder: (elapsed) => _camara(),
                        ),
                      ),
                    ),
                    // Pellizcar aparte: pinch va por pointer count.
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onScaleUpdate: (d) {
                          if (d.pointerCount > 1) _zoom(d.scale);
                        },
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
                          'yaw ${_yaw.toStringAsFixed(2)}  '
                          'dist ${_dist.toStringAsFixed(1)}  '
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
