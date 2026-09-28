import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Escena: cielo físico, una esfera y un piso plano. Arrastrar = orbitar,
/// pellizcar = acercar/alejar. Los valores se guardan para que la cámara
/// sea la misma instancia que el motor lee cada frame.
class EscenaScreen extends StatefulWidget {
  const EscenaScreen({super.key});

  @override
  State<EscenaScreen> createState() => _EscenaScreenState();
}

class _EscenaScreenState extends State<EscenaScreen> {
  final Scene _scene = Scene();
  final PerspectiveCamera _cam = PerspectiveCamera(
    position: vm.Vector3(0, 3, 9),
    target: vm.Vector3(0, 1, 0),
    fovRadiansY: 55 * math.pi / 180,
  );

  bool _ready = false;
  String _error = '';

  double _yaw = 0.6;
  double _pitch = 0.32;
  double _dist = 9;
  double _yaw0 = 0;
  double _pitch0 = 0;
  double _dist0 = 9;

  @override
  void initState() {
    super.initState();
    _arrancar();
  }

  Future<void> _arrancar() async {
    try {
      await Scene.initializeStaticResources();
      if (!mounted) return;

      // Cielo físico: da IBL, sol y fondo de una.
      final cielo = PhysicalSkySource(
        sunDirection: vm.Vector3(0.35, 0.55, -0.7).normalized(),
        turbidity: 3.5,
        rayleighCoefficient: 1.6,
        mieCoefficient: 0.004,
        groundColor: vm.Vector3(0.10, 0.11, 0.12),
      );
      _scene.skybox = Skybox(cielo);
      _scene.skyEnvironment = SkyEnvironment(cielo);
      _scene.sunLight = SunLight(cielo, castsShadow: true);

      // Niebla suave para que el piso se funda con el horizonte.
      _scene.fog.enabled = true;
      _scene.fog.color = vm.Vector3(0.62, 0.72, 0.85);
      _scene.fog.density = 0.012;

      // Esfera: metal pulido, refleja el cielo.
      final esfera = Node(
        mesh: Mesh(
          SphereGeometry(radius: 1.6, segments: 64, rings: 32),
          PhysicallyBasedMaterial()
            ..baseColorFactor = vm.Vector4(0.85, 0.20, 0.45, 1.0)
            ..metallicFactor = 0.85
            ..roughnessFactor = 0.18,
        ),
      );
      esfera.position = vm.Vector3(0, 1.7, 0);
      _scene.add(esfera);

      // Piso plano en XZ (mira a +Y), con segmentos por si se deforma.
      final piso = Node(
        mesh: Mesh(
          PlaneGeometry(width: 60, depth: 60, segmentsX: 1, segmentsZ: 1),
          PhysicallyBasedMaterial()
            ..baseColorFactor = vm.Vector4(0.32, 0.34, 0.38, 1.0)
            ..metallicFactor = 0.0
            ..roughnessFactor = 0.85,
        ),
      );
      _scene.add(piso);

      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _orbitar(double dyaw, double dpitch) {
    _yaw = _yaw0 + dyaw;
    _pitch = (_pitch0 + dpitch).clamp(-1.45, 1.45);
    _aplicar();
  }

  void _zoom(double factor) {
    _dist = (_dist0 * factor).clamp(2.5, 40.0);
    _aplicar();
  }

  /// Esférica → posición de la cámara, y mira al centro.
  void _aplicar() {
    final cp = math.cos(_pitch);
    _cam.target = vm.Vector3(0, 1.4, 0);
    _cam.position = vm.Vector3(
      math.sin(_yaw) * cp * _dist,
      1.4 + math.sin(_pitch) * _dist,
      math.cos(_yaw) * cp * _dist,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mr = takeMemoryReport();
    return Scaffold(
      appBar: AppBar(title: const Text('Escena')),
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
                      child: GestureDetector(
                        onScaleStart: (d) {
                          _yaw0 = _yaw;
                          _pitch0 = _pitch;
                          _dist0 = _dist;
                        },
                        onScaleUpdate: (d) {
                          if (d.pointerCount > 1) {
                            _zoom(d.scale);
                          } else {
                            _orbitar(
                              d.focalPointDelta.dx * 0.008,
                              -d.focalPointDelta.dy * 0.008,
                            );
                          }
                        },
                        child: SceneView(
                          _scene,
                          cameraBuilder: (elapsed) => _cam,
                        ),
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
                          'GPU ${(mr.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
