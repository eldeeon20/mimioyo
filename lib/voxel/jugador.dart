import 'package:vector_math/vector_math.dart' as vm;

import 'bloque.dart';
import 'chunk.dart';
import 'mundo.dart';

/// Jugador en tercera persona (la cámara orbita la cabeza).
///
/// Física simple: gravedad, salto, colisión AABB contra bloques
/// sólidos (aire y agua se atraviesan), natación básica en agua
/// y postura agachado (más bajo y más lento).
class Jugador {
  static const double ancho = 0.6; // caja: 0.6 x [alto] x 0.6
  static const double altoParado = 1.8;
  static const double altoAgachado = 1.4;
  static const double ojo = 1.62; // altura de los ojos (parado)
  static const double velBase = 4.5;
  static const double velAgachado = 1.8;
  static const double velAgua = 2.8;
  static const double gravedad = 25.0;
  static const double impulsoSalto = 8.5;
  static const double velNado = 4.0;

  /// Posición de los PIES (centro en x/z).
  final vm.Vector3 posicion;
  final vm.Vector3 velocidad = vm.Vector3.zero();

  bool enSuelo = false;
  bool agachado = false;
  bool enAgua = false;

  Jugador({required double x, required double y, required double z})
      : posicion = vm.Vector3(x, y, z);

  double get alto => agachado ? altoAgachado : altoParado;

  /// Altura de los ojos según postura.
  double get alturaOjo => agachado ? ojo - 0.35 : ojo;

  vm.Vector3 get cabeza =>
      vm.Vector3(posicion.x, posicion.y + alturaOjo, posicion.z);

  /// Centro del cuerpo (para chequear agua).
  vm.Vector3 get centro =>
      vm.Vector3(posicion.x, posicion.y + alto * 0.5, posicion.z);

  /// Un paso de física. [dirMundo] = dirección horizontal deseada
  /// (unitaria o cero), [saltar] = pulsado, [agachar] = mantener.
  void paso(double dt, Mundo m, {required vm.Vector3 dirMundo,
      required bool saltar, required bool agachar}) {
    agachado = agachar;

    // ¿El cuerpo está en agua? (celda del centro)
    final c = centro;
    enAgua = m.get(c.x.floor(), c.y.floor(), c.z.floor()).liquido ||
        m.get(c.x.floor(), (posicion.y + 0.3).floor(), c.z.floor()).liquido;

    // Gravedad / nado.
    if (enAgua) {
      velocidad.y -= gravedad * 0.25 * dt;
      velocidad.y *= (1 - 4 * dt).clamp(0.0, 1.0); // fricción
      if (saltar) velocidad.y = velNado; // mantenerse a flote
      velocidad.y = velocidad.y.clamp(-3.0, velNado).toDouble();
    } else {
      velocidad.y -= gravedad * dt;
      if (saltar && enSuelo) {
        velocidad.y = impulsoSalto;
        enSuelo = false;
      }
    }

    // Movimiento horizontal deseado.
    final vel = agachado
        ? velAgachado
        : (enAgua ? velAgua : velBase);
    velocidad.x = dirMundo.x * vel;
    velocidad.z = dirMundo.z * vel;

    // Mover por ejes con colisión.
    enSuelo = false;
    _moverEje(m, 0, velocidad.x * dt);
    _moverEje(m, 1, velocidad.y * dt);
    _moverEje(m, 2, velocidad.z * dt);

    // ¿Cayó contra algo? (movimiento Y positivo hacia abajo).
    if (velocidad.y <= 0 && _tocaSuelo(m)) {
      enSuelo = true;
      velocidad.y = 0;
    }

    // No salir del alto del mundo.
    if (posicion.y < 1) posicion.y = 1;
    final tope = Chunk.alto.toDouble();
    if (posicion.y + alto >= tope) {
      posicion.y = tope - alto;
      if (velocidad.y > 0) velocidad.y = 0;
    }
  }

  bool _tocaSuelo(Mundo m) {
    final y = (posicion.y - 0.05).floor();
    final x0 = (posicion.x - ancho / 2).floor();
    final x1 = (posicion.x + ancho / 2).floor();
    final z0 = (posicion.z - ancho / 2).floor();
    final z1 = (posicion.z + ancho / 2).floor();
    for (var x = x0; x <= x1; x++) {
      for (var z = z0; z <= z1; z++) {
        if (m.get(x, y, z).solido) return true;
      }
    }
    return false;
  }

  /// Mueve por un eje y, si la cara líder chocó, la reubica al
  /// borde exacto de la celda (sin flote, sin atravesar).
  void _moverEje(Mundo m, int eje, double delta) {
    if (delta == 0) return;
    if (eje == 0) {
      posicion.x += delta;
    } else if (eje == 1) {
      posicion.y += delta;
    } else {
      posicion.z += delta;
    }
    final c = _celdaLider(m, eje, delta);
    if (c == null) return;
    const eps = 0.001;
    if (eje == 0) {
      posicion.x = delta > 0
          ? c - ancho / 2 - eps
          : c + 1 + ancho / 2 + eps;
    } else if (eje == 1) {
      posicion.y = delta > 0 ? c - alto - eps : c + 1 + eps;
      velocidad.y = 0;
    } else {
      posicion.z = delta > 0
          ? c - ancho / 2 - eps
          : c + 1 + ancho / 2 + eps;
    }
  }

  /// Índice de la celda que bloquea la cara líder del movimiento, o
  /// null si no chocó. Solo chequea la cara que va en la dirección
  /// del avance (cheaper y sin falsos positivos internos).
  int? _celdaLider(Mundo m, int eje, double delta) {
    final x0 = (posicion.x - ancho / 2).floor();
    final x1 = (posicion.x + ancho / 2).floor();
    final y0 = posicion.y.floor();
    final y1 = (posicion.y + alto - 0.001).floor();
    final z0 = (posicion.z - ancho / 2).floor();
    final z1 = (posicion.z + ancho / 2).floor();

    int lider;
    if (eje == 0) {
      lider = delta > 0 ? x1 : x0;
      for (var y = y0; y <= y1; y++) {
        for (var z = z0; z <= z1; z++) {
          if (m.get(lider, y, z).solido) return lider;
        }
      }
      return null;
    }
    if (eje == 1) {
      lider = delta > 0 ? y1 : y0;
      for (var x = x0; x <= x1; x++) {
        for (var z = z0; z <= z1; z++) {
          if (m.get(x, lider, z).solido) return lider;
        }
      }
      return null;
    }
    lider = delta > 0 ? z1 : z0;
    for (var x = x0; x <= x1; x++) {
      for (var y = y0; y <= y1; y++) {
        if (m.get(x, y, lider).solido) return lider;
      }
    }
    return null;
  }
}
