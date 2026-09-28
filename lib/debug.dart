import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';

/// Pantalla de debug: compatibilidad real de GL/Vulkan, RAM y almacenamiento,
/// refrescando sola. Todos los números vienen del MethodChannel de Kotlin.
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  static const _channel = MethodChannel('mimioyo/hardware');
  Timer? _timer;
  Map<dynamic, dynamic>? _d;

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _cargar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final d =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('info');
      if (mounted) setState(() => _d = d);
    } catch (_) {}
  }

  double _g(dynamic v) => (v as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final mr = takeMemoryReport();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _titulo('Gráficos'),
                _fila('Vulkan (hardware)',
                    d['vulkanHardware'] == true ? 'Sí' : 'No'),
                _fila('Vulkan (nivel)', '${d['vulkanNivel'] ?? 0}'),
                _fila('Vulkan (version)', '${d['vulkanVersion'] ?? 0}'),
                _fila('OpenGL ES (req)', '${d['openGLEsReq'] ?? '?'}'),
                _fila('Impeller', d['impeller'] == true ? 'Sí' : 'No'),
                _fila('Flutter GPU', d['flutterGpu'] == true ? 'Sí' : 'No'),
                _fila('Renderer', '${d['gpuRenderer'] ?? '?'}'),
                _fila('Vendor', '${d['gpuVendor'] ?? '?'}'),
                _fila('Versión GL', '${d['openGL'] ?? '?'}'),
                if ('${d['gpuError'] ?? ''}'.isNotEmpty)
                  _fila('Error GPU', '${d['gpuError']}'),
                _fila('Escena lista', Scene.isReadyToRender ? 'Sí' : 'No'),
                _fila('Memoria GPU', '${(mr.totalBytes / 1048576).toStringAsFixed(1)} MB'),
                for (final c in mr.categories.take(5))
                  _fila('  ${c.name}',
                      '${((c.bytes ?? 0) / 1048576).toStringAsFixed(1)} MB (${c.count})'),
                _titulo('RAM'),
                _barra('Total', _g(d['ramTotalGb']), _g(d['ramTotalGb'])),
                _barra(
                    'Libre',
                    _g(d['ramLibreGb']),
                    _g(d['ramTotalGb'])),
                _fila('Presión de memoria',
                    d['ramBajo'] == true ? 'ALTA' : 'normal'),
                _titulo('Almacenamiento'),
                _barra('Total', _g(d['almacenTotalGb']), _g(d['almacenTotalGb'])),
                _barra(
                    'Libre',
                    _g(d['almacenLibreGb']),
                    _g(d['almacenTotalGb'])),
                _titulo('Dispositivo'),
                _fila('Modelo', '${d['modelo'] ?? '?'}'),
                _fila('Fabricante', '${d['fabricante'] ?? '?'}'),
                _fila('Android', '${d['android'] ?? '?'}'),
              ],
            ),
    );
  }

  Widget _titulo(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(
          t.toUpperCase(),
          style: const TextStyle(
              fontSize: 12,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
              color: Colors.deepPurple),
        ),
      );

  Widget _fila(String k, String v) => ListTile(
        dense: true,
        title: Text(k, style: const TextStyle(fontSize: 14)),
        subtitle: Text(v, style: const TextStyle(fontSize: 13)),
      );

  Widget _barra(String k, double v, double total) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$k: ${v.toStringAsFixed(1)} GB / '
                '${total.toStringAsFixed(1)} GB'),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: total > 0 ? (v / total).clamp(0.0, 1.0) : 0,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
}
