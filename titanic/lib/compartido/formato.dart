/// Sin decimales de sobra: 50 en vez de 50.00, pero 12.5 se conserva.
String formatoNumero(double n) =>
    n % 1 == 0 ? n.toStringAsFixed(0) : n.toStringAsFixed(2);

/// Importe en soles, siempre con dos decimales: en un cuadre de caja "S/ 12.5"
/// se lee como un monto a medio escribir.
String formatoSoles(double n) => 'S/ ${n.toStringAsFixed(2)}';

/// Un costo por unidad base, como se pinta en una lista o en una ficha.
///
/// Dos decimales, que es como se cobra. Cuatro solo cuando el centimo se come
/// el numero: el costo se guarda por unidad base y el sobre de 30 g sale a
/// S/ 0.0025 el gramo, donde "S/ 0.00" no dice nada. La misma regla que la web.
String formatoCosto(double n) =>
    n < 0.01 ? n.toStringAsFixed(4) : n.toStringAsFixed(2);

/// Lo que cuesta una presentacion completa: el costo de la unidad base por su
/// factor, al centimo.
///
/// Al centimo porque asi la vuelta cierra: S/ 289 el saco de 45.6 kg se guarda
/// como 6.33771930 el kilo y volvia como 288.9991 —la multiplicacion arrastra
/// basura de coma flotante— hasta que se redondeo a dos decimales.
double costoDePresentacion(double costoBase, double factor) =>
    double.parse((costoBase * factor).toStringAsFixed(2));
