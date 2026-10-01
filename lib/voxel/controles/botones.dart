import 'package:flutter/material.dart';

/// Botón circular grande para táctil (saltar, agachar, etc).
/// [alPresionar] al tocar; [alSoltar] al levantar/cancelar (opcional,
/// para acciones mantenidas como el salto).
class BotonJuego extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final bool activo;
  final VoidCallback? alPresionar;
  final VoidCallback? alSoltar;

  const BotonJuego({
    super.key,
    required this.icono,
    required this.etiqueta,
    this.activo = false,
    required this.alPresionar,
    this.alSoltar,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: alPresionar == null ? null : (_) => alPresionar!(),
      onTapUp: alSoltar == null ? null : (_) => alSoltar!(),
      onTapCancel: alSoltar,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: activo ? Colors.white70 : Colors.black45,
          shape: BoxShape.circle,
          border: Border.all(
            color: activo ? Colors.white : Colors.white24,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icono,
              color: activo ? Colors.black87 : Colors.white,
              size: 26,
            ),
            Text(
              etiqueta,
              style: TextStyle(
                fontSize: 8,
                color: activo ? Colors.black87 : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón con toggle (agacharse: se mantiene hasta volver a tocar).
class BotonToggle extends StatefulWidget {
  final IconData icono;
  final String etiqueta;
  final ValueChanged<bool> alCambiar;

  const BotonToggle({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.alCambiar,
  });

  @override
  State<BotonToggle> createState() => _BotonToggleState();
}

class _BotonToggleState extends State<BotonToggle> {
  bool _activo = false;

  @override
  Widget build(BuildContext context) {
    return BotonJuego(
      icono: widget.icono,
      etiqueta: widget.etiqueta,
      activo: _activo,
      alPresionar: () {
        setState(() => _activo = !_activo);
        widget.alCambiar(_activo);
      },
    );
  }
}
