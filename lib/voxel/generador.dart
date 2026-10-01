import 'bloque.dart';

/// Terreno procedural determinista: mismas coords, mismo mundo.
/// Ruido de valor suavizado sobre grilla de 8 + detalle de 3.
/// Donde la altura queda bajo el nivel del agua (6) nace un lago.
class Generador {
  final int semilla;
  static const nivelAgua = 6;

  const Generador({this.semilla = 1337});

  double _hash(int x, int z) {
    var h = x * 374761393 + z * 668265263 + semilla * 1442695041;
    h = (h ^ (h >> 13)) * 1274126177;
    h ^= h >> 16;
    return (h & 0x7fffffff) / 0x7fffffff;
  }

  double _suave(double t) => t * t * (3 - 2 * t);

  double _ruido(int x, int z, int paso) {
    final x0 = (x ~/ paso) * paso;
    final z0 = (z ~/ paso) * paso;
    final fx = _suave((x - x0) / paso);
    final fz = _suave((z - z0) / paso);
    final a = _hash(x0, z0);
    final b = _hash(x0 + paso, z0);
    final c = _hash(x0, z0 + paso);
    final d = _hash(x0 + paso, z0 + paso);
    return a + (b - a) * fx + (c - a) * fz + (a - b - c + d) * fx * fz;
  }

  /// Altura de la superficie (pasto) en coords de mundo.
  int altura(int x, int z) {
    final base = _ruido(x, z, 8);
    final detalle = _ruido(x + 1000, z - 1000, 3);
    return 8 + (base * 10 + detalle * 3).round();
  }

  /// ¿Hay árbol con tronco en (x, h, z)? Raro y separado del borde.
  bool esArbol(int x, int z, int h) {
    if (h < 9) return false;
    return _hash(x * 2 + 7, z * 2 - 3) < 0.015;
  }

  /// Bloque de la columna en altura y (bajo la superficie).
  Bloque capa(int y, int h) {
    if (y > h) {
      // Cuenca inundada: agua hasta el nivel del lago.
      if (h <= nivelAgua && y <= nivelAgua) return Bloque.agua;
      return Bloque.aire;
    }
    if (y == h) return Bloque.pasto;
    if (y >= h - 2) return Bloque.tierra;
    return Bloque.piedra;
  }
}
