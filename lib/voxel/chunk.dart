import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';

import 'bloque.dart';

/// Un chunk de 16x16 columnas con [alto] bloques de altura.
class Chunk {
  static const lado = 16;
  static const alto = 32;

  final int cx;
  final int cz;
  final Uint8List celdas = Uint8List(lado * alto * lado);

  Chunk(this.cx, this.cz);

  static int _indice(int x, int y, int z) => (y * lado + z) * lado + x;

  Bloque get(int x, int y, int z) {
    if (x < 0 || x >= lado || z < 0 || z >= lado || y < 0 || y >= alto) {
      return Bloque.aire;
    }
    return Bloque.values[celdas[_indice(x, y, z)]];
  }

  void set(int x, int y, int z, Bloque b) {
    if (x < 0 || x >= lado || z < 0 || z >= lado || y < 0 || y >= alto) return;
    celdas[_indice(x, y, z)] = b.index;
  }
}

// ── Caras del cubo unidad ─────────────────────────────────────────────
// Esquinas en orden antihorario visto desde afuera (culling trasero
// activo). Tris: (0,1,2) y (0,2,3). Verificado por producto cruzado.

class _Cara {
  final int dx, dy, dz;
  final List<List<int>> esquinas;
  const _Cara(this.dx, this.dy, this.dz, this.esquinas);
}

const _caras = [
  _Cara(1, 0, 0, [
    [1, 0, 1],
    [1, 0, 0],
    [1, 1, 0],
    [1, 1, 1],
  ]),
  _Cara(-1, 0, 0, [
    [0, 0, 0],
    [0, 0, 1],
    [0, 1, 1],
    [0, 1, 0],
  ]),
  _Cara(0, 1, 0, [
    [0, 1, 1],
    [1, 1, 1],
    [1, 1, 0],
    [0, 1, 0],
  ]),
  _Cara(0, -1, 0, [
    [0, 0, 0],
    [1, 0, 0],
    [1, 0, 1],
    [0, 0, 1],
  ]),
  _Cara(0, 0, 1, [
    [0, 0, 1],
    [1, 0, 1],
    [1, 1, 1],
    [0, 1, 1],
  ]),
  _Cara(0, 0, -1, [
    [1, 0, 0],
    [0, 0, 0],
    [0, 1, 0],
    [1, 1, 0],
  ]),
];

/// Sombreado falso por orientación: multiplica el color del bloque.
double _sombraCara(_Cara c) {
  if (c.dy > 0) return 1.0;
  if (c.dy < 0) return 0.55;
  if (c.dx != 0) return 0.8;
  return 0.7;
}

/// Acumulador de malla por material.
class _Acum {
  final pos = <double>[];
  final col = <double>[];
  final idx = <int>[];

  void cara(int gx, int y, int gz, _Cara cara, ({double x, double y, double z}) rgb) {
    final s = _sombraCara(cara);
    final base = pos.length ~/ 3;
    for (final e in cara.esquinas) {
      pos.add((gx + e[0]).toDouble());
      pos.add((y + e[1]).toDouble());
      pos.add((gz + e[2]).toDouble());
      col.add(rgb.x * s);
      col.add(rgb.y * s);
      col.add(rgb.z * s);
      col.add(1.0);
    }
    idx.add(base);
    idx.add(base + 1);
    idx.add(base + 2);
    idx.add(base);
    idx.add(base + 2);
    idx.add(base + 3);
  }

  MeshData? build() => idx.isEmpty
      ? null
      : MeshData.build(
          positions: Float32List.fromList(pos),
          colors: Float32List.fromList(col),
          indices: idx,
        );
}

/// Malla del chunk en DOS pasadas: opacos y agua (materiales distintos).
///
/// Culling:
/// - opaco: cara visible si el vecino NO es opaco (aire, agua, borde).
/// - agua:  cara visible solo contra aire (contra sólido ya dibujó el
///   sólido; contra agua no hay cara interna).
///
/// null = ese material no tiene caras (chunk vacío, sin agua, etc.).
({MeshData? opaco, MeshData? agua}) mallarChunk(
  Chunk chunk,
  Bloque Function(int x, int y, int z) verGlobal,
) {
  final op = _Acum();
  final ag = _Acum();

  for (var y = 0; y < Chunk.alto; y++) {
    for (var z = 0; z < Chunk.lado; z++) {
      for (var x = 0; x < Chunk.lado; x++) {
        final b = chunk.get(x, y, z);
        if (b == Bloque.aire) continue;
        final colores = coloresDe(b);
        final esAgua = b.liquido;
        final ac = esAgua ? ag : op;
        final gx = chunk.cx * Chunk.lado + x;
        final gz = chunk.cz * Chunk.lado + z;
        for (final cara in _caras) {
          final vecino = verGlobal(gx + cara.dx, y + cara.dy, gz + cara.dz);
          final visible = esAgua
              ? vecino == Bloque.aire
              : !vecino.opaco;
          if (!visible) continue;
          final col = cara.dy > 0
              ? colores.arriba
              : (cara.dy < 0 ? colores.abajo : colores.lado);
          ac.cara(gx, y, gz, cara, (x: col.x, y: col.y, z: col.z));
        }
      }
    }
  }

  return (opaco: op.build(), agua: ag.build());
}
