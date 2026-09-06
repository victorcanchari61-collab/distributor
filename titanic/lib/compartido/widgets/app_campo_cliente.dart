import 'package:flutter/material.dart';

import '../../features/maestros/datos/cliente.dart';
import 'app_campo_busqueda.dart';

/// El campo para elegir cliente en pedidos y notas de venta.
///
/// Existe como función y no se arma en cada formulario para que los dos digan
/// lo mismo: los mismos filtros, el mismo subtítulo y el mismo criterio de qué
/// clientes se ofrecen. Cuando estaba suelto, uno filtraba los inactivos y el
/// otro no.
Widget campoCliente({
  required List<Cliente> clientes,
  required String? elegido,
  required void Function(Cliente) onElegir,
  String? error,
  bool habilitado = true,
}) {
  // Los desactivados no se ofrecen: no se le vende a un cliente dado de baja,
  // y verlo en la lista solo lleva a elegirlo y toparse con el error al grabar.
  final activos = clientes.where((c) => c.activo).toList();

  return AppCampoBusqueda<Cliente>(
    etiqueta: 'Cliente',
    icono: Icons.contacts_outlined,
    pista: 'Escribe el nombre o el documento',
    items: activos,
    textoElegido: elegido,
    error: error,
    habilitado: habilitado,
    titulo: (c) => c.nombre,
    subtitulo: (c) {
      // Lo que distingue a dos bodegas con nombre parecido: su documento y
      // dónde para. El mercado va primero porque es lo que el vendedor tiene
      // en la cabeza cuando está en la calle.
      final partes = <String>['${c.tipoDoc} ${c.documento}'];
      if (c.mercado != null && c.mercado!.isNotEmpty) partes.add(c.mercado!);
      if (c.ruta != null && c.ruta!.isNotEmpty) partes.add(c.ruta!);
      return partes.join(' · ');
    },
    buscable: (c) => c.buscable,
    filtros: [
      FiltroBusqueda<Cliente>('Mercado', (c) => c.mercado),
      FiltroBusqueda<Cliente>('Ruta', (c) => c.ruta),
      FiltroBusqueda<Cliente>('Día', (c) => c.diaVisita),
    ],
    onElegir: onElegir,
  );
}
