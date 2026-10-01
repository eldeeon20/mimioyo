import 'package:vector_math/vector_math.dart' as vm;

import 'bloque.dart';
import 'chunk.dart';
import 'generador.dart';

/// Resultado del rayo: celda sólida golpeada + celda previa (aire,
/// donde se pone un bloque nuevo).
class Golpe {
  final int x, y, z;
  final int px, py, pz;
  final Bloque bloque;
  const Golpe(this.x, this.y, this.z, this.px, this.py, this.pz, this.bloque);
}

/// Mundo voxel: diccionario de chunks + generación + raycast.
class Mundo {
  /// Chunks por lado: 1 → 3x3 (48x48 bloques).
  final int alcance;
  final Generador generador;
  final Map<String, Chunk> _chunks = {};

  Mundo({this.alcance = 1, Generador? generador})
      : generador = generador ?? const Generador();

  static String clave(int cx, int cz) => '$cx,$cz';

  /// División floor: -1 está en el chunk -1, no en el 0.
  static int _cx(int x) => (x / Chunk.lado).floor();
  static int _cz(int z) => (z / Chunk.lado).floor();

  Iterable<Chunk> get chunks => _chunks.values;

  Chunk? chunkDe(int cx, int cz) => _chunks[clave(cx, cz)];

  /// Fuera del mundo o del alto: aire (los bordes dibujan cara: isla).
  Bloque get(int x, int y, int z) {
    if (y < 0 || y >= Chunk.alto) return Bloque.aire;
    final c = chunkDe(_cx(x), _cz(z));
    if (c == null) return Bloque.aire;
    final lx = x - c.cx * Chunk.lado;
    final lz = z - c.cz * Chunk.lado;
    return c.get(lx, y, lz);
  }

  /// Escribe si la celda existe. Retorna los chunks a remallar
  /// (el propio + vecinos si tocó el borde).
  List<Chunk> set(int x, int y, int z, Bloque b) {
    if (y < 0 || y >= Chunk.alto) return const [];
    final cx = _cx(x);
    final cz = _cz(z);
    final c = chunkDe(cx, cz);
    if (c == null) return const [];
    c.set(x - cx * Chunk.lado, y, z - cz * Chunk.lado, b);
    final out = [c];
    final lx = x - cx * Chunk.lado;
    final lz = z - cz * Chunk.lado;
    if (lx == 0) {
      final v = chunkDe(cx - 1, cz);
      if (v != null) out.add(v);
    }
    if (lx == Chunk.lado - 1) {
      final v = chunkDe(cx + 1, cz);
      if (v != null) out.add(v);
    }
    if (lz == 0) {
      final v = chunkDe(cx, cz - 1);
      if (v != null) out.add(v);
    }
    if (lz == Chunk.lado - 1) {
      final v = chunkDe(cx, cz + 1);
      if (v != null) out.add(v);
    }
    return out;
  }

  /// Genera todos los chunks (terreno + árboles).
  void generar() {
    _chunks.clear();
    for (var cx = -alcance; cx <= alcance; cx++) {
      for (var cz = -alcance; cz <= alcance; cz++) {
        _chunks[clave(cx, cz)] = Chunk(cx, cz);
      }
    }
    for (final c in _chunks.values) {
      for (var x = 0; x < Chunk.lado; x++) {
        for (var z = 0; z < Chunk.lado; z++) {
          final gx = c.cx * Chunk.lado + x;
          final gz = c.cz * Chunk.lado + z;
          final h = generador
              .altura(gx, gz)
              .clamp(1, Chunk.alto - 6)
              .toInt();
          // Cuenca: la columna sigue hasta el nivel del agua (lagos).
          final tope =
              h <= Generador.nivelAgua ? Generador.nivelAgua : h;
          for (var y = 0; y <= tope; y++) {
            c.set(x, y, z, generador.capa(y, h));
          }
          if (generador.esArbol(gx, gz, h)) {
            _plantar(gx, h + 1, gz);
          }
        }
      }
    }
  }

  void _plantar(int x, int y, int z) {
    for (var i = 0; i < 3; i++) {
      _setDirecto(x, y + i, z, Bloque.madera);
    }
    for (var dx = -2; dx <= 2; dx++) {
      for (var dz = -2; dz <= 2; dz++) {
        for (var dy = 0; dy <= 1; dy++) {
          if (dx.abs() + dz.abs() + dy > 4) continue;
          if (dx == 0 && dz == 0 && dy == 0) continue;
          final actual = get(x + dx, y + 2 + dy, z + dz);
          if (!actual.solido) {
            _setDirecto(x + dx, y + 2 + dy, z + dz, Bloque.hojas);
          }
        }
      }
    }
  }

  void _setDirecto(int x, int y, int z, Bloque b) {
    final c = chunkDe(_cx(x), _cz(z));
    if (c == null) return;
    c.set(x - c.cx * Chunk.lado, y, z - c.cz * Chunk.lado, b);
  }

  /// Raycast voxel (Amanatides & Woo): avanza celda a celda hasta
  /// chocar con un sólido o agotar [maxDist]. null = sin golpe.
  Golpe? trazar(vm.Vector3 origen, vm.Vector3 dir, double maxDist) {
    var x = origen.x.floor();
    var y = origen.y.floor();
    var z = origen.z.floor();
    final pasoX = dir.x > 0 ? 1 : (dir.x < 0 ? -1 : 0);
    final pasoY = dir.y > 0 ? 1 : (dir.y < 0 ? -1 : 0);
    final pasoZ = dir.z > 0 ? 1 : (dir.z < 0 ? -1 : 0);
    final deltaX = dir.x == 0 ? double.infinity : (1 / dir.x.abs());
    final deltaY = dir.y == 0 ? double.infinity : (1 / dir.y.abs());
    final deltaZ = dir.z == 0 ? double.infinity : (1 / dir.z.abs());
    var maxX = dir.x == 0
        ? double.infinity
        : ((pasoX > 0 ? (x + 1 - origen.x) : (origen.x - x)) / dir.x.abs());
    var maxY = dir.y == 0
        ? double.infinity
        : ((pasoY > 0 ? (y + 1 - origen.y) : (origen.y - y)) / dir.y.abs());
    var maxZ = dir.z == 0
        ? double.infinity
        : ((pasoZ > 0 ? (z + 1 - origen.z) : (origen.z - z)) / dir.z.abs());

    var px = x, py = y, pz = z;
    if (get(x, y, z).solido) {
      return Golpe(x, y, z, px, py, pz, get(x, y, z));
    }
    var t = 0.0;
    while (t <= maxDist) {
      if (maxX < maxY && maxX < maxZ) {
        px = x;
        x += pasoX;
        t = maxX;
        maxX += deltaX;
      } else if (maxY < maxZ) {
        py = y;
        y += pasoY;
        t = maxY;
        maxY += deltaY;
      } else {
        pz = z;
        z += pasoZ;
        t = maxZ;
        maxZ += deltaZ;
      }
      if (t > maxDist) return null;
      final b = get(x, y, z);
      if (b.solido) return Golpe(x, y, z, px, py, pz, b);
    }
    return null;
  }
}
