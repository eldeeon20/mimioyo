import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'debug.dart';
import 'escena.dart';

void main() {
  runApp(const MimioyoApp());
}

class MimioyoApp extends StatelessWidget {
  const MimioyoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mimioyo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HardwareScreen(),
    );
  }
}

class HardwareScreen extends StatefulWidget {
  const HardwareScreen({super.key});

  @override
  State<HardwareScreen> createState() => _HardwareScreenState();
}

class _HardwareScreenState extends State<HardwareScreen> {
  static const _channel = MethodChannel('mimioyo/hardware');

  String _modelo = '?';
  String _fabricante = '?';
  String _android = '?';
  double _ramTotal = 0;
  double _ramLibre = 0;
  double _almacenTotal = 0;
  double _almacenLibre = 0;
  String _gpuRenderer = '?';
  String _gpuVendor = '?';
  String _gpuVersion = '?';
  String _openGL = '?';
  bool _vulkanHardware = false;
  String _glEsFeature = '?';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final datos = await _channel.invokeMethod<Map<dynamic, dynamic>>('info');
      if (datos != null && mounted) {
        setState(() {
          _modelo = '${datos['modelo'] ?? '?'}';
          _fabricante = '${datos['fabricante'] ?? '?'}';
          _android = '${datos['android'] ?? '?'}';
          _ramTotal = (datos['ramTotalGb'] as num?)?.toDouble() ?? 0;
          _ramLibre = (datos['ramLibreGb'] as num?)?.toDouble() ?? 0;
          _almacenTotal = (datos['almacenTotalGb'] as num?)?.toDouble() ?? 0;
          _almacenLibre = (datos['almacenLibreGb'] as num?)?.toDouble() ?? 0;
          _gpuRenderer = '${datos['gpuRenderer'] ?? '?'}';
          _gpuVendor = '${datos['gpuVendor'] ?? '?'}';
          _gpuVersion = '${datos['gpuVersion'] ?? '?'}';
          _openGL = '${datos['openGL'] ?? '?'}';
          _vulkanHardware = (datos['vulkanNivel'] as num?)?.toInt() != 0;
          _glEsFeature = '${datos['openGLEsReq'] ?? '?'}';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mimioyo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.view_in_ar_rounded),
            tooltip: 'Menú',
            onSelected: (v) {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => v == 'escena'
                      ? const EscenaScreen()
                      : const DebugScreen(),
                ),
              );
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'escena',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.threed_rotation),
                  title: Text('Escena 3D'),
                ),
              ),
              PopupMenuItem(
                value: 'debug',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.bug_report_outlined),
                  title: Text('Debug GL/Vulkan'),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _seccion('Teléfono', [
            _fila('Modelo', _modelo),
            _fila('Fabricante', _fabricante),
            _fila('Android', _android),
          ]),
          _seccion('RAM', [
            _fila('Total', '${_ramTotal.toStringAsFixed(1)} GB'),
            _fila('Libre', '${_ramLibre.toStringAsFixed(1)} GB'),
            _barra(_ramTotal > 0 ? _ramLibre / _ramTotal : 0, 'Libre'),
          ]),
          _seccion('Almacenamiento', [
            _fila('Total', '${_almacenTotal.toStringAsFixed(1)} GB'),
            _fila('Libre', '${_almacenLibre.toStringAsFixed(1)} GB'),
            _barra(_almacenTotal > 0 ? _almacenLibre / _almacenTotal : 0, 'Libre'),
          ]),
          _seccion('GPU', [
            _fila('Renderer', _gpuRenderer),
            _fila('Vendor', _gpuVendor),
            _fila('Versión', _gpuVersion),
          ]),
          _seccion('Graficos', [
            _fila('Vulkan', _vulkanHardware ? 'Sí' : 'No'),
            _fila('OpenGL ES', _openGL),
            _fila('ES (requerido)', _glEsFeature),
          ]),
        ],
      ),
    );
  }

  Widget _seccion(String titulo, List<Widget> hijos) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...hijos,
          ],
        ),
      ),
    );
  }

  Widget _fila(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: const TextStyle(fontSize: 14)),
          Text(
            valor,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _barra(double fraccion, String etiqueta) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$etiqueta: ${(fraccion * 100).toStringAsFixed(0)}%'),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: fraccion.clamp(0.0, 1.0),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}
