/// Sin decimales de sobra: 50 en vez de 50.00, pero 12.5 se conserva.
String formatoNumero(double n) =>
    n % 1 == 0 ? n.toStringAsFixed(0) : n.toStringAsFixed(2);

/// Importe en soles, siempre con dos decimales: en un cuadre de caja "S/ 12.5"
/// se lee como un monto a medio escribir.
String formatoSoles(double n) => 'S/ ${n.toStringAsFixed(2)}';
