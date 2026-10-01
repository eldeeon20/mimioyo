import 'dart:ui' show Offset;

import 'package:flutter_scene/scene.dart';

/// OrbitCameraController con el arrastre vertical invertido:
/// bajar el dedo baja la cámara y subir el dedo la sube
/// (el paquete lo trae al revés de lo esperado en móvil).
///
/// El paneo horizontal, el pellizco (zoom) y el resto del
/// comportamiento quedan idénticos al controlador base.
class CamaraOrbit extends OrbitCameraController {
  CamaraOrbit({
    super.target,
    super.distance,
    super.azimuth,
    super.polar,
    super.minDistance,
    super.maxDistance,
  });

  @override
  void handleDragUpdate(Offset delta) =>
      super.handleDragUpdate(Offset(delta.dx, -delta.dy));
}
