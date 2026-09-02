import 'package:flutter/material.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';

/// Un dato del registro: la etiqueta de la columna y su valor.
///
/// Es el equivalente de una columna de `SysDataTable` en el panel web: la misma
/// lista alimenta la tarjeta del listado y la hoja de detalle, para que no haya
/// dos definiciones del mismo registro.
class CampoDetalle {
  const CampoDetalle(
    this.etiqueta,
    this.valor, {
    this.widget,
    this.enTarjeta = true,
  });

  final String etiqueta;

  /// Texto plano. Vacio o null se pinta como raya, igual que en el web.
  final String? valor;

  /// Reemplaza al texto cuando el dato es una etiqueta de color.
  final Widget? widget;

  /// Los campos secundarios solo salen en la hoja de detalle.
  final bool enTarjeta;

  bool get vacio => widget == null && (valor == null || valor!.trim().isEmpty);
}

/// Fila etiqueta / valor, alineada a los extremos como en la tabla del web.
class FilaDato extends StatelessWidget {
  const FilaDato(this.campo, {super.key});

  final CampoDetalle campo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            campo.etiqueta,
            style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
          ),
          const SizedBox(width: Dimen.espacio3),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child:
                  campo.widget ??
                  Text(
                    campo.vacio ? '—' : campo.valor!,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: campo.vacio ? Colores.tintaTenue : Colores.tinta,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de un registro en el listado.
///
/// Copia el bloque movil de `SysDataTable`: arriba el identificador con su
/// icono y sus acciones, debajo los datos en pares etiqueta / valor.
class AppTarjetaRegistro extends StatelessWidget {
  const AppTarjetaRegistro({
    super.key,
    required this.icono,
    required this.color,
    required this.titulo,
    required this.campos,
    this.insignia,
    this.acciones,
    this.onTap,
  });

  final IconData icono;
  final Color color;

  /// Lo que identifica al registro: el documento en clientes y proveedores.
  final String titulo;

  /// Etiqueta junto al titulo, por ejemplo el tipo de documento.
  final Widget? insignia;

  final List<CampoDetalle> campos;

  /// Iconos de accion de la esquina superior derecha.
  final List<Widget>? acciones;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final visibles = campos.where((c) => c.enTarjeta).toList();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Dimen.radioCampo),
      child: Container(
        padding: const EdgeInsets.all(Dimen.espacio3),
        decoration: BoxDecoration(
          color: Colores.superficie,
          border: Border.all(color: Colores.linea),
          borderRadius: BorderRadius.circular(Dimen.radioCampo),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, size: 17, color: color),
                const SizedBox(width: Dimen.espacio2),
                Flexible(
                  child: Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colores.tinta,
                    ),
                  ),
                ),
                if (insignia != null) const SizedBox(width: Dimen.espacio2),
                ?insignia,
                const Spacer(),
                ...?acciones,
              ],
            ),
            const SizedBox(height: Dimen.espacio2),
            for (final campo in visibles) FilaDato(campo),
          ],
        ),
      ),
    );
  }
}
