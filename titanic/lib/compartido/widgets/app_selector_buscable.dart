import 'package:flutter/material.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';
import 'app_buscador.dart';
import 'app_hoja.dart';
import 'app_vacio.dart';

/// Hoja para elegir un registro de una lista larga (producto, proveedor,
/// compra...), donde un `AppSelector` comun se desbordaria. Filtra en vivo
/// con el mismo texto de busqueda de las listas del resto de la app.
Future<T?> mostrarSelectorBuscable<T>({
  required BuildContext context,
  required String titulo,
  required List<T> items,
  required String Function(T item) buscable,
  required Widget Function(T item) fila,
  String pistaBusqueda = 'Buscar...',
}) {
  // Fuera del builder: la hoja se vuelve a armar cuando el teclado aparece o se
  // va, y aquí dentro el texto buscado volvía a quedar vacío.
  var texto = '';
  return abrirHoja<T>(context, (context) {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        final visibles = texto.isEmpty
            ? items
            : items
                  .where(
                    (i) =>
                        buscable(i).toLowerCase().contains(texto.toLowerCase()),
                  )
                  .toList();

        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EncabezadoHoja(titulo),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Dimen.espacio4,
                  Dimen.espacio3,
                  Dimen.espacio4,
                  Dimen.espacio3,
                ),
                child: AppBuscador(
                  valor: texto,
                  onCambio: (v) => setSheetState(() => texto = v),
                  pista: pistaBusqueda,
                ),
              ),
              Expanded(
                child: visibles.isEmpty
                    ? const AppVacio(
                        icono: Icons.search_off,
                        titulo: 'Sin resultados',
                        detalle: 'Nada coincide con lo que buscaste.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          Dimen.espacio4,
                          0,
                          Dimen.espacio4,
                          Dimen.espacio4,
                        ),
                        itemCount: visibles.length,
                        separatorBuilder: (context, i) =>
                            const SizedBox(height: Dimen.espacio2),
                        itemBuilder: (context, i) {
                          final item = visibles[i];
                          return InkWell(
                            borderRadius: BorderRadius.circular(
                              Dimen.radioCampo,
                            ),
                            onTap: () => Navigator.of(context).pop(item),
                            child: Container(
                              padding: const EdgeInsets.all(Dimen.espacio3),
                              decoration: BoxDecoration(
                                color: Colores.fondo,
                                borderRadius: BorderRadius.circular(
                                  Dimen.radioCampo,
                                ),
                              ),
                              child: fila(item),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  });
}
