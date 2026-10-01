import 'package:flutter/material.dart';

/// Joystick virtual táctil: arrastrar desde el centro produce un
/// vector normalizado (-1..1) en [alCambiar]; soltar devuelve (0,0).
///
/// Coordenadas de pantalla: dy negativo = hacia ARRIBA (forward).
class Joystick extends StatefulWidget {
  final double radio;
  final void Function(double x, double y) alCambiar;

  const Joystick({
    super.key,
    this.radio = 56,
    required this.alCambiar,
  });

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  Offset _knob = Offset.zero; // normalizado (-1..1)
  bool _presionado = false;

  void _procesar(Offset local) {
    final centro = Offset(widget.radio, widget.radio);
    final d = (local - centro) / widget.radio;
    final mag = d.distance;
    final n = mag > 1.0 ? d / mag : d;
    setState(() => _knob = n);
    widget.alCambiar(n.dx, n.dy);
  }

  void _soltar() {
    setState(() {
      _knob = Offset.zero;
      _presionado = false;
    });
    widget.alCambiar(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.radio * 2;
    return GestureDetector(
      onPanStart: (e) {
        setState(() => _presionado = true);
        _procesar(e.localPosition);
      },
      onPanUpdate: (e) => _procesar(e.localPosition),
      onPanEnd: (_) => _soltar(),
      onPanCancel: _soltar,
      child: Container(
        width: d + 24,
        height: d + 24,
        decoration: BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: Center(
          child: Transform.translate(
            offset: Offset(_knob.dx * widget.radio, _knob.dy * widget.radio),
            child: Container(
              width: widget.radio * 0.8,
              height: widget.radio * 0.8,
              decoration: BoxDecoration(
                color: _presionado
                    ? Colors.white70
                    : Colors.white38,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
