import 'package:flutter/material.dart';

import '../../../compartido/widgets/app_pestanas.dart';
import '../datos/almacen.dart';

/// Una pestaña por almacén, más "Todos", como en Stock y Kardex del panel web.
///
/// Es pestaña y no filtro: cambiarla cambia todo el conjunto de datos (otro
/// stock, otros movimientos), no recorta una lista ya cargada. Se arma sobre
/// `AppPestanas` para que se vea igual que el resto de pestañas de la app.
/// Va en el hueco `pestanas` de `AppListaPagina`. `valor` null es "Todos".
class AlmacenTabs extends StatelessWidget {
  const AlmacenTabs({
    super.key,
    required this.almacenes,
    required this.valor,
    required this.onCambio,
  });

  final List<Almacen> almacenes;
  final int? valor;
  final ValueChanged<int?> onCambio;

  @override
  Widget build(BuildContext context) {
    if (almacenes.isEmpty) return const SizedBox.shrink();

    return AppPestanas<int?>(
      activa: valor,
      onCambio: onCambio,
      pestanas: [
        const Pestana<int?>(null, 'Todos', icono: Icons.all_inbox_outlined),
        for (final a in almacenes)
          Pestana<int?>(a.id, a.nombre, icono: Icons.warehouse_outlined),
      ],
    );
  }
}
