import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../debug.dart';
import '../escena.dart';
import '../main.dart' show HardwareScreen;
import 'agua.dart';
import 'bloque.dart';
import 'chunk.dart';
import 'controles/botones.dart';
import 'controles/joystick.dart';
import 'generador.dart';
import 'jugador.dart';
import 'mundo.dart';

/// Pantalla del juego voxel estilo Minecraft.
///
/// - Cámara orbital que sigue la cabeza del jugador (pellizcar = zoom).
/// - Joystick (izq.) para caminar, botones (der.) para saltar/agachar.
/// - Crosshair + Poner/Sacar sobre el bloque de la mira (raycast DDA).
/// - Agua con flujo: la colocada cae y se esparce (FisicaAgua).
///
/// Estructura: cada chunk son DOS nodos (opaco + agua, materiales
/// distintos); al editar solo se remallan los chunks tocados.
class JuegoScreen extends StatefulWidget {
  const JuegoScreen({super.key});

  @override
  State<JuegoScreen> createState() => _JuegoScreenState();
}

class _JuegoScreenState extends State<JuegoScreen>
    with SingleTickerProviderStateMixin {
  final Scene _scene = Scene();
  final Mundo _mundo = Mundo(alcance: 1);

  final Map<String, Node> _nodosOp = {};
  final Map<String, Node> _nodosAg = {};

  late final PhysicallyBasedMaterial _material;
  late final PhysicallyBasedMaterial _materialAgua;
  late final Ticker _ticker;
  Timer? _timerAgua;

  Jugador? _jugador;
  OrbitCameraController? _orbit;
  Node? _camara;

  bool _ready = false;
  String _error = '';
  Bloque _seleccion = Bloque.pasto;
  String _info = '';

  // Entrada de juego.
  double _joyX = 0, _joyY = 0;
  bool _saltando = false;
  bool _agachando = false;

  Duration _ultimo = Duration.zero;

  @override
  void initState() {
    super.initState();
    _material = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(1, 1, 1, 1)
      ..roughnessFactor = 0.9
      ..metallicFactor = 0.0;
    _materialAgua = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(1, 1, 1, 0.6)
      ..roughnessFactor = 0.1
      ..metallicFactor = 0.0
      ..doubleSided = true;
    _ticker = createTicker(_paso)..start();
    _arrancar();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _timerAgua?.cancel();
    super.dispose();
  }

  // ── Arranque de escena ──────────────────────────────────────────────

  Future<void> _arrancar() async {
    try {
      await Scene.initializeStaticResources();
      if (!mounted) return;

      _scene.skybox = Skybox(
        GradientSkySource(
          zenithColor: vm.Vector3(0.20, 0.42, 0.80),
          horizonColor: vm.Vector3(0.75, 0.82, 0.90),
          groundColor: vm.Vector3(0.14, 0.14, 0.16),
          sunDirection: vm.Vector3(0.35, 0.55, -0.7).normalized(),
          sunColor: vm.Vector3(1.0, 0.95, 0.85),
        ),
      );
      _scene.directionalLight = DirectionalLight(
        direction: vm.Vector3(-0.35, -0.55, 0.7).normalized(),
        intensity: 3.0,
      );
      _scene.environmentIntensity = 0.6;
      _scene.fog.enabled = true;
      _scene.fog.color = vm.Vector3(0.68, 0.76, 0.86);
      _scene.fog.density = 0.008;

      _mundo.generar();
      final spawn = _buscarSpawn();
      _jugador = Jugador(x: spawn.x, y: spawn.y, z: spawn.z);

      for (final c in _mundo.chunks) {
        final clave = Mundo.clave(c.cx, c.cz);
        final nodoOp = Node()..frustumCulled = false;
        final nodoAg = Node()..frustumCulled = false;
        _nodosOp[clave] = nodoOp;
        _nodosAg[clave] = nodoAg;
        _scene.add(nodoOp);
        _scene.add(nodoAg);
        _remallar(c);
      }

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
            target: _jugador!.cabeza,
            distance: 10.0,
            polar: 0.7,
            minDistance: 3.0,
            maxDistance: 30.0,
          ),
        );
      _orbit = camara.getComponent<OrbitCameraController>();
      _camara = camara;
      _scene.add(camara);

      _timerAgua = Timer.periodic(const Duration(milliseconds: 400), (_) {
        for (final c in FisicaAgua.tick(_mundo)) {
          _remallar(c);
        }
      });

      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Terreno seco cerca del centro; si todo es lago, alto a mano.
  vm.Vector3 _buscarSpawn() {
    for (var r = 0; r < 14; r++) {
      for (var dx = -r; dx <= r; dx++) {
        for (var dz = -r; dz <= r; dz++) {
          final h = _mundo.generador.altura(8 + dx, 8 + dz);
          if (h > Generador.nivelAgua && h < Chunk.alto - 3) {
            return vm.Vector3(8 + dx + 0.5, h + 1.0, 8 + dz + 0.5);
          }
        }
      }
    }
    return vm.Vector3(8.5, 20.0, 8.5);
  }

  void _remallar(Chunk c) {
    final par = mallarChunk(c, _mundo.get);
    final clave = Mundo.clave(c.cx, c.cz);
    final op = _nodosOp[clave];
    if (op != null) {
      op.mesh = par.opaco == null
          ? null
          : Mesh(MeshGeometry.fromMeshData(par.opaco), _material);
      op.markBoundsDirty();
    }
    final ag = _nodosAg[clave];
    if (ag != null) {
      ag.mesh = par.agua == null
          ? null
          : Mesh(MeshGeometry.fromMeshData(par.agua), _materialAgua);
      ag.markBoundsDirty();
    }
  }

  // ── Loop de juego (física del jugador, por frame) ───────────────────

  void _paso(Duration t) {
    if (!_ready) {
      _ultimo = t;
      return;
    }
    var dt = (t - _ultimo).inMicroseconds / 1e6;
    _ultimo = t;
    if (dt <= 0) return;
    dt = dt.clamp(0.0, 0.05).toDouble();

    final jug = _jugador;
    final cam = _camara;
    final ctrl = _orbit;
    if (jug == null || cam == null || ctrl == null) return;

    // Dirección de movimiento relativa a la mirada de la cámara.
    final cabeza = jug.cabeza;
    final camPos = cam.position;
    var adelante = vm.Vector3(cabeza.x - camPos.x, 0, cabeza.z - camPos.z);
    if (adelante.length2 < 1e-6) {
      adelante = vm.Vector3(0, 0, -1);
    } else {
      adelante.normalize();
    }
    final derecha = adelante.cross(vm.Vector3(0, 1, 0));
    final dir = adelante * (-_joyY) + derecha * _joyX;
    if (dir.length2 > 1e-6) dir.normalize();

    jug.paso(dt, _mundo, dirMundo: dir, saltar: _saltando, agachar: _agachando);
    ctrl.target = jug.cabeza;
  }

  // ── Mira y edición ─────────────────────────────────────────────────

  /// Rayo desde la cámara hacia la cabeza del jugador (bajo la mira).
  Golpe? _bajoLaMira() {
    final cam = _camara;
    final jug = _jugador;
    if (cam == null || jug == null) return null;
    final origen = cam.position;
    final dir = (jug.cabeza - origen).normalized();
    final alcance = origen.distanceTo(jug.cabeza) + 6.0;
    return _mundo.trazar(origen, dir, alcance);
  }

  bool _chocaJugador(int x, int y, int z) {
    final j = _jugador;
    if (j == null) return false;
    final p = j.posicion;
    final h = Jugador.ancho / 2;
    return x + 1 > p.x - h &&
        x < p.x + h &&
        y + 1 > p.y &&
        y < p.y + j.alto &&
        z + 1 > p.z - h &&
        z < p.z + h;
  }

  void _poner() {
    final g = _bajoLaMira();
    if (g == null) {
      setState(() => _info = 'sin objetivo');
      return;
    }
    if (_mundo.get(g.px, g.py, g.pz).solido) {
      setState(() => _info = 'ocupado');
      return;
    }
    if (_chocaJugador(g.px, g.py, g.pz)) {
      setState(() => _info = 'te chocás');
      return;
    }
    final tocados = _mundo.set(g.px, g.py, g.pz, _seleccion);
    if (_seleccion.liquido) {
      FisicaAgua.colocar(g.px, g.py, g.pz);
    }
    for (final c in tocados) {
      _remallar(c);
    }
    setState(() => _info = '${_seleccion.name} @ ${g.px},${g.py},${g.pz}');
  }

  void _sacar() {
    final g = _bajoLaMira();
    if (g == null) {
      setState(() => _info = 'sin objetivo');
      return;
    }
    if (g.bloque == Bloque.aire) {
      setState(() => _info = 'ya es aire');
      return;
    }
    if (g.bloque.liquido) FisicaAgua.quitar(g.x, g.y, g.z);
    final tocados = _mundo.set(g.x, g.y, g.z, Bloque.aire);
    for (final c in tocados) {
      _remallar(c);
    }
    setState(() => _info = 'fuera ${g.bloque.name}');
  }

  void _regenerar() {
    FisicaAgua.limpiar();
    _mundo.generar();
    final spawn = _buscarSpawn();
    final j = _jugador;
    if (j != null) {
      j.posicion.setValues(spawn.x, spawn.y, spawn.z);
      j.velocidad.setZero();
    }
    for (final c in _mundo.chunks) {
      _remallar(c);
    }
    setState(() => _info = 'mundo nuevo');
  }

  // ── UI ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ctrl = _orbit;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black26,
        foregroundColor: Colors.white,
        title: const Text('Mimioyo voxel', style: TextStyle(color: Colors.white)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            color: Colors.white,
            tooltip: 'Menú',
            onSelected: (v) {
              if (v == 'nuevo') {
                _regenerar();
              } else if (v == 'demo') {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const EscenaScreen()),
                );
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
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'nuevo',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.refresh),
                  title: Text('Mundo nuevo'),
                ),
              ),
              PopupMenuItem(
                value: 'demo',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.view_in_ar_rounded),
                  title: Text('Demo esfera'),
                ),
              ),
              PopupMenuItem(
                value: 'debug',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.bug_report_outlined),
                  title: Text('Debug'),
                ),
              ),
              PopupMenuItem(
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
                child: Text('No se pudo crear el mundo:\n$_error',
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
                    const Center(
                      child: Icon(Icons.add, color: Colors.white70, size: 28),
                    ),
                    if (_info.isNotEmpty)
                      Positioned(
                        left: 12,
                        top: kToolbarHeight + 52,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_info,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ),
                      ),
                    // Joystick (izquierda, sobre la barra).
                    Positioned(
                      left: 16,
                      bottom: 92,
                      child: Joystick(
                        alCambiar: (x, y) {
                          _joyX = x;
                          _joyY = y;
                        },
                      ),
                    ),
                    // Botones (derecha, sobre la barra).
                    Positioned(
                      right: 16,
                      bottom: 92,
                      child: Column(
                        children: [
                          BotonJuego(
                            icono: Icons.arrow_upward,
                            etiqueta: 'SALTAR',
                            alPresionar: () => _saltando = true,
                            alSoltar: () => _saltando = false,
                          ),
                          const SizedBox(height: 12),
                          BotonToggle(
                            icono: Icons.north_east,
                            etiqueta: 'AGACHAR',
                            alCambiar: (v) => _agachando = v,
                          ),
                        ],
                      ),
                    ),
                    // Barra: selector + poner/sacar.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: Colors.black45,
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    for (final b in BloqueX.construibles)
                                      _slotBloque(b),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _poner,
                              child: const Text('Poner'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              onPressed: _sacar,
                              child: const Text('Sacar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _slotBloque(Bloque b) {
    final c = coloresDe(b).lado;
    final color = Color.fromRGBO(
      (c.x * 255).round(),
      (c.y * 255).round(),
      (c.z * 255).round(),
      1,
    );
    final sel = b == _seleccion;
    return GestureDetector(
      onTap: () => setState(() => _seleccion = b),
      child: Container(
        width: 44,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: sel ? Colors.white : Colors.white24,
            width: sel ? 3 : 1,
          ),
        ),
        child: Center(
          child: Text(
            b.name.substring(0, 2).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black, blurRadius: 2)],
            ),
          ),
        ),
      ),
    );
  }
}
