import 'bloque.dart';
import 'chunk.dart';
import 'mundo.dart';

/// Física de agua simple: solo el agua COLOCADA por el jugador fluye
/// (la del generador —lagos— es estática y no se toca).
///
/// Reglas por tick:
/// - CAE mientras el de abajo esté aire (sin límite de distancia).
/// - Se ESPARCE al costado hasta [maxDist] celdas de la fuente.
/// - Lo que quedó fuera del alcance se EVAPORA (vuelve a aire).
///
/// El registro vive en esta clase (estático): `colocar` al poner un
/// bloque de agua, `quitar` al sacarlo, `limpiar` al regenerar.
class FisicaAgua {
  static const int maxDist = 5;
  static const int maxCeldas = 6000;

  /// Celda conocida (debe seguir siendo agua) -> distancia a la fuente.
  static final Map<(int, int, int), int> _registrado = {};

  static void colocar(int x, int y, int z) => _registrado[(x, y, z)] = 0;
  static void quitar(int x, int y, int z) => _registrado.remove((x, y, z));
  static void limpiar() => _registrado.clear();

  /// Un tick de flujo. Retorna los chunks a remallar
  /// (set vacío = nada cambió).
  static Set<Chunk> tick(Mundo m) {
    if (_registrado.isEmpty) return const {};

    // BFS por celda: la caída NO suma dist; el costado suma 1.
    final alcanzado = <(int, int, int), int>{};
    final cola = <(int, int, int, int)>[]; // x, y, z, dist

    for (final e in _registrado.entries) {
      final (x, y, z) = e.key;
      if (y < 0 || y >= Chunk.alto) continue;
      if (!m.get(x, y, z).liquido) continue; // la sacaron a mano
      alcanzado[e.key] = e.value;
      cola.add((x, y, z, e.value));
    }

    var procesadas = 0;
    var i = 0;
    while (i < cola.length && procesadas < maxCeldas) {
      final (x, y, z, d) = cola[i++];
      procesadas++;

      // caer: hacia abajo, distancia igual (las cascadas no decaen).
      if (y > 0 && m.get(x, y - 1, z) == Bloque.aire) {
        final k = (x, y - 1, z);
        if (!alcanzado.containsKey(k)) {
          alcanzado[k] = d;
          cola.add((x, y - 1, z, d));
        }
      }

      // esparcir: costado, distancia +1 con tope.
      if (d + 1 <= maxDist) {
        const vecinos = [
          (1, 0),
          (-1, 0),
          (0, 1),
          (0, -1),
        ];
        for (final (dx, dz) in vecinos) {
          final nx = x + dx;
          final nz = z + dz;
          if (m.get(nx, y, nz) != Bloque.aire) continue;
          final k = (nx, y, nz);
          if (!alcanzado.containsKey(k)) {
            alcanzado[k] = d + 1;
            cola.add((nx, y, nz, d + 1));
          }
        }
      }
    }

    // Aplicar diferencias.
    final tocados = <Chunk>{};
    for (final e in alcanzado.entries) {
      final (x, y, z) = e.key;
      if (!m.get(x, y, z).liquido) {
        tocados.addAll(m.set(x, y, z, Bloque.agua));
        _registrado[e.key] = e.value;
      }
    }
    for (final k in _registrado.keys.toList()) {
      if (alcanzado.containsKey(k)) continue;
      // Fuera de alcance o sacada a mano: evaporar.
      if (m.get(k.$1, k.$2, k.$3).liquido) {
        tocados.addAll(m.set(k.$1, k.$2, k.$3, Bloque.aire));
      }
      _registrado.remove(k);
    }
    return tocados;
  }
}
