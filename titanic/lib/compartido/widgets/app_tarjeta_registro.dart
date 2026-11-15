import 'package:flutter/material.dart';

import '../../core/tema/acento.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';

/// El número de fila de un registro en su lista (1, 2, 3...).
///
/// Lo pone `AppListaPagina` alrededor de cada fila y la tarjeta lo lee para su
/// esquina: así todas las listas lo muestran sin que cada pantalla lo pase.
class NumeroFila extends InheritedWidget {
  const NumeroFila({super.key, required this.numero, required super.child});

  final int numero;

  static int? de(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NumeroFila>()?.numero;

  @override
  bool updateShouldNotify(NumeroFila anterior) => anterior.numero != numero;
}

/// Marca la fila de acciones de una tarjeta: dentro, `AppIconoAccion` se
/// dibuja como botón de color (como en el panel web) y no como un ícono suelto.
class AccionesDeTarjeta extends InheritedWidget {
  const AccionesDeTarjeta({super.key, required super.child});

  static bool dentro(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccionesDeTarjeta>() != null;

  @override
  bool updateShouldNotify(AccionesDeTarjeta anterior) => false;
}

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
/// Copia el bloque movil de `SysDataTable`: arriba el identificador, debajo
/// sus acciones y luego los datos en pares etiqueta / valor.
///
/// En una lista lleva en la esquina su número de fila, en el color del módulo
/// ([NumeroFila]). Las acciones van en su propia fila y como botones de color:
/// en la misma fila que el número del documento le quitaban lugar y "PD-0039"
/// se cortaba en "PD…".
class AppTarjetaRegistro extends StatelessWidget {
  const AppTarjetaRegistro({
    super.key,
    required this.icono,
    required this.color,
    required this.titulo,
    required this.campos,
    this.insignia,
    this.estado,
    this.acciones,
    this.onTap,
  });

  final IconData icono;
  final Color color;

  /// Lo que identifica al registro: el documento en clientes y proveedores.
  final String titulo;

  /// Etiqueta junto al titulo cuando IDENTIFICA al registro: el codigo del
  /// producto, el tipo de documento del cliente. Un estado no va aqui.
  final Widget? insignia;

  /// El estado del registro, que se pinta como una fila mas al final.
  ///
  /// Separado de [insignia] a proposito: pegado al numero del documento
  /// competia con el, y el estado es un dato del registro como la fecha o el
  /// proveedor, no parte de su nombre.
  final Widget? estado;

  final List<CampoDetalle> campos;

  /// Iconos de accion de la esquina superior derecha.
  final List<Widget>? acciones;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final visibles = campos.where((c) => c.enTarjeta).toList();
    final numero = NumeroFila.de(context);
    final acento = Acento.de(context);
    final hayAcciones = acciones != null && acciones!.isNotEmpty;
    final radio = BorderRadius.circular(Dimen.radioCampo);

    return Material(
      color: Colores.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: radio,
        side: const BorderSide(color: Colores.linea),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(Dimen.espacio3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Con número en la esquina el ícono sobra: se deja el
                      // lugar del número.
                      if (numero == null) ...[
                        Icon(icono, size: 17, color: color),
                        const SizedBox(width: Dimen.espacio2),
                      ] else
                        SizedBox(width: _anchoNumero(numero) + 2),
                      // El identificador entero, como la etiqueta del web.
                      Flexible(child: _Identificador(titulo)),
                      if (insignia != null) const SizedBox(width: Dimen.espacio2),
                      ?insignia,
                    ],
                  ),
                  if (hayAcciones) ...[
                    const SizedBox(height: Dimen.espacio2),
                    _FilaAcciones(acento: acento, acciones: acciones!),
                  ],
                  const SizedBox(height: Dimen.espacio2),
                  for (final campo in visibles) FilaDato(campo),
                  if (estado != null)
                    FilaDato(CampoDetalle('Estado', null, widget: estado)),
                ],
              ),
            ),
            if (numero != null)
              Positioned(
                top: 0,
                left: 0,
                child: _Numero(numero: numero, color: acento),
              ),
          ],
        ),
      ),
    );
  }
}

double _anchoNumero(int numero) => numero < 10
    ? 26
    : numero < 100
    ? 32
    : 40;

/// La esquina con el número de fila, en el color del módulo.
class _Numero extends StatelessWidget {
  const _Numero({required this.numero, required this.color});

  final int numero;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _anchoNumero(numero),
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          bottomRight: Radius.circular(10),
        ),
      ),
      child: Text(
        '$numero',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// El número del documento o el nombre, en una etiqueta clara: se lee de un
/// vistazo y no compite con los botones.
class _Identificador extends StatelessWidget {
  const _Identificador(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: Colores.tinta,
        ),
      ),
    );
  }
}

/// Las acciones de la tarjeta, en su propia fila y como botones con fondo.
///
/// `AppIconoAccion` se dibuja solo como botón de color (ver
/// [AccionesDeTarjeta]); a los `IconButton` sueltos se les da aquí un fondo
/// en el tono del módulo, para que todos se lean como botones.
class _FilaAcciones extends StatelessWidget {
  const _FilaAcciones({required this.acento, required this.acciones});

  final Color acento;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    return AccionesDeTarjeta(
      child: IconButtonTheme(
        data: IconButtonThemeData(
          style: IconButton.styleFrom(
            backgroundColor: acento.withValues(alpha: 0.12),
            foregroundColor: acento,
            minimumSize: const Size(38, 32),
            fixedSize: const Size(38, 32),
            padding: EdgeInsets.zero,
            // Sin el área de toque extra de 48: si no, quedaba más abajo que los demás botones.
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.standard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: acciones,
        ),
      ),
    );
  }
}
