import 'package:flutter/material.dart';

import '../../core/tema/acento.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';
import '../../features/maestros/datos/producto.dart';
import '../formato.dart';

/// Una línea ya cargada en el documento, tal como se edita en pantalla.
class LineaDocumento {
  LineaDocumento({
    required this.productoId,
    required this.producto,
    required this.codigo,
    required this.unidadBase,
    required this.presentaciones,
    required this.presentacionId,
    required this.cantidad,
    required this.importe,
  });

  final int productoId;
  final String producto;
  final String codigo;
  final String unidadBase;

  /// Las que valen para este documento, ya filtradas por venta o compra.
  final List<Presentacion> presentaciones;

  /// 0 = la unidad base.
  int presentacionId;
  double cantidad;

  /// Precio si se vende, costo si se compra. De UNA presentación completa.
  double importe;

  double get subtotal => cantidad * importe;

  String get nombrePresentacion {
    for (final p in presentaciones) {
      if (p.id == presentacionId) return p.nombre;
    }
    return unidadBase;
  }
}

/// Los productos ya agregados al documento, editables sin salir de la pantalla.
///
/// Antes cada línea era una tarjeta de solo lectura y corregir una cantidad
/// abría otra hoja. Con cinco productos eso son cinco hojas para arreglar lo
/// que se escribió mal una vez. Aquí la unidad, la cantidad y el precio se
/// tocan en el sitio, que es también la razón de que la hoja de selección
/// múltiple ya no pida el precio: se pone acá, donde se ve el subtotal.
class AppLineasProducto extends StatelessWidget {
  const AppLineasProducto({
    super.key,
    required this.lineas,
    required this.onCambio,
    required this.onEliminar,
    this.etiquetaImporte = 'Precio S/',
    this.disponible,
    this.error,
    this.habilitado = true,
  });

  final List<LineaDocumento> lineas;

  /// Se llama tras tocar cualquier campo, para que el formulario recalcule.
  final VoidCallback onCambio;

  final void Function(LineaDocumento) onEliminar;

  final String etiquetaImporte;

  /// Stock por producto en el almacén del documento, en unidad base.
  ///
  /// Va dentro del desplegable de unidad —"Saco (disp. 19.89)"— porque lo que
  /// hace falta saber no es cuánto hay en total, sino cuántos sacos entran con
  /// lo que hay.
  final Map<int, double>? disponible;

  final String? error;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.shopping_basket_outlined, size: 18, color: Acento.de(context)),
            const SizedBox(width: Dimen.espacio2),
            const Text(
              'Productos',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colores.tinta),
            ),
            const Spacer(),
            Text(
              lineas.isEmpty
                  ? 'ninguno todavía'
                  : '${lineas.length} ${lineas.length == 1 ? 'ítem agregado' : 'ítems agregados'}',
              style: TextStyle(fontSize: 12.5, color: Acento.de(context)),
            ),
          ],
        ),

        if (error != null) ...[
          const SizedBox(height: Dimen.espacio1),
          Text(error!, style: const TextStyle(fontSize: 12, color: Colores.peligro)),
        ],

        const SizedBox(height: Dimen.espacio3),

        if (lineas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Dimen.espacio3),
            child: Text(
              'Todavía no agregaste productos.',
              style: TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
            ),
          ),

        for (var i = 0; i < lineas.length; i++) ...[
          _TarjetaLinea(
            numero: i + 1,
            linea: lineas[i],
            etiquetaImporte: etiquetaImporte,
            disponible: disponible?[lineas[i].productoId],
            habilitado: habilitado,
            onCambio: onCambio,
            onEliminar: () => onEliminar(lineas[i]),
          ),
          const SizedBox(height: Dimen.espacio3),
        ],
      ],
    );
  }
}

class _TarjetaLinea extends StatefulWidget {
  const _TarjetaLinea({
    required this.numero,
    required this.linea,
    required this.etiquetaImporte,
    required this.disponible,
    required this.habilitado,
    required this.onCambio,
    required this.onEliminar,
  });

  final int numero;
  final LineaDocumento linea;
  final String etiquetaImporte;
  final double? disponible;
  final bool habilitado;
  final VoidCallback onCambio;
  final VoidCallback onEliminar;

  @override
  State<_TarjetaLinea> createState() => _TarjetaLineaState();
}

class _TarjetaLineaState extends State<_TarjetaLinea> {
  late final _cantidad = TextEditingController(text: formatoNumero(widget.linea.cantidad));
  late final _importe = TextEditingController(text: _dosDecimales(widget.linea.importe));

  static String _dosDecimales(double v) => v == 0 ? '' : v.toStringAsFixed(2);

  @override
  void dispose() {
    _cantidad.dispose();
    _importe.dispose();
    super.dispose();
  }

  double _numero(String texto) => double.tryParse(texto.replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final linea = widget.linea;

    return Container(
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // El número da de qué hablar cuando alguien dicta por teléfono
              // qué línea corregir.
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Acento.suave(context), shape: BoxShape.circle),
                child: Text(
                  '${widget.numero}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Acento.de(context),
                  ),
                ),
              ),
              const SizedBox(width: Dimen.espacio2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      linea.producto,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colores.tinta,
                      ),
                    ),
                    Text(
                      linea.codigo,
                      style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.habilitado ? widget.onEliminar : null,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, size: 18, color: Colores.peligro),
                tooltip: 'Quitar del documento',
              ),
            ],
          ),
          const SizedBox(height: Dimen.espacio2),

          _Unidad(
            linea: linea,
            disponible: widget.disponible,
            habilitado: widget.habilitado,
            onCambio: (v) {
              setState(() => linea.presentacionId = v);
              widget.onCambio();
            },
          ),
          const SizedBox(height: Dimen.espacio3),

          Row(
            children: [
              Expanded(
                child: _Numero(
                  etiqueta: 'Cant.',
                  controlador: _cantidad,
                  habilitado: widget.habilitado,
                  onCambio: (v) {
                    setState(() => linea.cantidad = _numero(v));
                    widget.onCambio();
                  },
                ),
              ),
              const SizedBox(width: Dimen.espacio3),
              Expanded(
                child: _Numero(
                  etiqueta: widget.etiquetaImporte,
                  controlador: _importe,
                  habilitado: widget.habilitado,
                  onCambio: (v) {
                    setState(() => linea.importe = _numero(v));
                    widget.onCambio();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimen.espacio2),

          Align(
            alignment: Alignment.centerRight,
            child: Text.rich(
              TextSpan(
                text: 'Subtotal ',
                style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
                children: [
                  TextSpan(
                    text: 'S/ ${linea.subtotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Acento.de(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// La unidad de la línea, con cuánto queda disponible en esa misma unidad.
class _Unidad extends StatelessWidget {
  const _Unidad({
    required this.linea,
    required this.disponible,
    required this.habilitado,
    required this.onCambio,
  });

  final LineaDocumento linea;
  final double? disponible;
  final bool habilitado;
  final ValueChanged<int> onCambio;

  /// Cuánto hay, contado en la presentación que se elige.
  ///
  /// Un saco de 50 con 994 kg en almacén son 19.88 sacos: decir "994" bajo una
  /// línea que se carga por sacos obliga a dividir de cabeza en plena venta.
  String? _texto(double factor) {
    final hay = disponible;
    if (hay == null) return null;
    if (factor <= 0) return null;
    return ' (disp. ${formatoNumero(double.parse((hay / factor).toStringAsFixed(2)))})';
  }

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Unidad',
        constraints: BoxConstraints(minHeight: Dimen.campoLg),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: linea.presentacionId,
          isExpanded: true,
          items: [
            DropdownMenuItem(value: 0, child: Text('${linea.unidadBase}${_texto(1) ?? ''}')),
            for (final p in linea.presentaciones.where((p) => !p.esBase))
              DropdownMenuItem(value: p.id, child: Text('${p.nombre}${_texto(p.factor) ?? ''}')),
          ],
          onChanged: habilitado ? (v) => onCambio(v ?? 0) : null,
          style: const TextStyle(fontSize: 14, color: Colores.tinta),
        ),
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero({
    required this.etiqueta,
    required this.controlador,
    required this.habilitado,
    required this.onCambio,
  });

  final String etiqueta;
  final TextEditingController controlador;
  final bool habilitado;
  final ValueChanged<String> onCambio;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      enabled: habilitado,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onCambio,
      style: const TextStyle(fontSize: 15, color: Colores.tinta),
      decoration: InputDecoration(
        labelText: etiqueta,
        constraints: const BoxConstraints(minHeight: Dimen.campoLg),
      ),
    );
  }
}
