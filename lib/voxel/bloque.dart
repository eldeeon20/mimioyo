import 'package:vector_math/vector_math.dart' as vm;

/// Tipos de bloque del mundo voxel (aire, base, agua y "mods").
enum Bloque {
  aire,
  pasto,
  tierra,
  piedra,
  madera,
  hojas,
  arena,
  agua,
  // mods
  ladrillo,
  cristal,
  nieve,
  oro,
  obsidiana,
  musgo,
  magma,
}

/// Color por cara de un bloque (componentes 0-1, alpha en el vértice
/// siempre 1: la transparencia del agua la maneja su material).
class ColoresBloque {
  final vm.Vector4 arriba;
  final vm.Vector4 lado;
  final vm.Vector4 abajo;
  const ColoresBloque(this.arriba, this.lado, this.abajo);
}

vm.Vector4 _c(double r, double g, double b) => vm.Vector4(r, g, b, 1.0);

/// Paleta estilo Minecraft simple. Un solo color por cara alcanza:
/// el sombreado direccional lo aplica el meshing.
ColoresBloque coloresDe(Bloque b) {
  switch (b) {
    case Bloque.aire:
      final n = _c(0, 0, 0);
      return ColoresBloque(n, n, n);
    case Bloque.pasto:
      return ColoresBloque(
        _c(0.38, 0.72, 0.25),
        _c(0.47, 0.34, 0.20),
        _c(0.45, 0.32, 0.19),
      );
    case Bloque.tierra:
      final t = _c(0.45, 0.32, 0.19);
      return ColoresBloque(t, t, t);
    case Bloque.piedra:
      final p = _c(0.50, 0.50, 0.53);
      return ColoresBloque(p, p, p);
    case Bloque.madera:
      final m = _c(0.42, 0.30, 0.16);
      return ColoresBloque(m, m, m);
    case Bloque.hojas:
      final h = _c(0.22, 0.55, 0.22);
      return ColoresBloque(h, h, h);
    case Bloque.arena:
      final a = _c(0.85, 0.76, 0.52);
      return ColoresBloque(a, a, a);
    case Bloque.agua:
      final w = _c(0.16, 0.38, 0.78);
      return ColoresBloque(w, w, w);
    // mods
    case Bloque.ladrillo:
      final l = _c(0.62, 0.27, 0.23);
      return ColoresBloque(l, l, l);
    case Bloque.cristal:
      final g = _c(0.72, 0.86, 0.92);
      return ColoresBloque(g, g, g);
    case Bloque.nieve:
      final n = _c(0.94, 0.96, 0.98);
      return ColoresBloque(n, n, n);
    case Bloque.oro:
      final o = _c(0.94, 0.78, 0.20);
      return ColoresBloque(o, o, o);
    case Bloque.obsidiana:
      final ob = _c(0.10, 0.06, 0.16);
      return ColoresBloque(ob, ob, ob);
    case Bloque.musgo:
      final m = _c(0.30, 0.52, 0.24);
      return ColoresBloque(m, m, m);
    case Bloque.magma:
      return ColoresBloque(
        _c(0.95, 0.45, 0.10),
        _c(0.80, 0.30, 0.08),
        _c(0.70, 0.22, 0.05),
      );
  }
}

extension BloqueX on Bloque {
  /// Bloquea el rayo y el jugador (aire y agua no).
  bool get solido => this != Bloque.aire && this != Bloque.agua;

  /// Llena la cara: entre dos opacos no se dibuja caras.
  bool get opaco => solido;

  bool get liquido => this == Bloque.agua;

  /// Lo que el jugador puede atravesar (aire, agua).
  bool get atravesable => !solido;

  /// Lo que ofrece el selector para construir.
  static const construibles = [
    Bloque.pasto,
    Bloque.tierra,
    Bloque.piedra,
    Bloque.madera,
    Bloque.hojas,
    Bloque.arena,
    Bloque.agua,
    Bloque.ladrillo,
    Bloque.cristal,
    Bloque.nieve,
    Bloque.oro,
    Bloque.obsidiana,
    Bloque.musgo,
    Bloque.magma,
  ];
}
