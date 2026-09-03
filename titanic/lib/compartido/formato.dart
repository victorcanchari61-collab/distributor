/// Sin decimales de sobra: 50 en vez de 50.00, pero 12.5 se conserva.
String formatoNumero(double n) => n % 1 == 0 ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
