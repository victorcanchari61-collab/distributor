import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_pdf.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/red/tiempo_real_provider.dart';
import '../../../core/tema/colores.dart';
import '../datos/comprobante.dart';
import '../estado/comprobantes_controlador.dart';
import '../../ventas/vistas/nota_venta_formulario.dart';
import '../../../core/red/excepciones.dart';
import '../../../compartido/widgets/app_aviso.dart';
import 'emitir_nota_hoja.dart';
import 'enviar_whatsapp_hoja.dart';

/// Facturas, boletas y notas de crédito y débito: la misma pantalla con otro tipo, cada una con su entrada en el menú
/// y su permiso. Cada comprobante muestra en qué quedó frente a SUNAT, se ve su PDF y se envía por WhatsApp.
class FacturasPagina extends StatelessWidget {
  const FacturasPagina({super.key});

  static const ruta = '/fact/facturas';

  @override
  Widget build(BuildContext context) =>
      const ComprobantesLista(tipo: TipoCpe.factura, ruta: ruta);
}

class BoletasPagina extends StatelessWidget {
  const BoletasPagina({super.key});

  static const ruta = '/fact/boletas';

  @override
  Widget build(BuildContext context) =>
      const ComprobantesLista(tipo: TipoCpe.boleta, ruta: ruta);
}

class NotasCreditoPagina extends StatelessWidget {
  const NotasCreditoPagina({super.key});

  static const ruta = '/fact/notascredito';

  @override
  Widget build(BuildContext context) =>
      const ComprobantesLista(tipo: TipoCpe.notaCredito, ruta: ruta);
}

class NotasDebitoPagina extends StatelessWidget {
  const NotasDebitoPagina({super.key});

  static const ruta = '/fact/notasdebito';

  @override
  Widget build(BuildContext context) =>
      const ComprobantesLista(tipo: TipoCpe.notaDebito, ruta: ruta);
}

String _titulo(String tipo) => switch (tipo) {
  TipoCpe.factura => 'Facturas',
  TipoCpe.boleta => 'Boletas',
  TipoCpe.notaCredito => 'Notas de crédito',
  _ => 'Notas de débito',
};

IconData _icono(String tipo) => switch (tipo) {
  TipoCpe.factura => Icons.receipt_outlined,
  TipoCpe.boleta => Icons.confirmation_number_outlined,
  TipoCpe.notaCredito => Icons.remove_circle_outline,
  _ => Icons.add_circle_outline,
};

EtiquetaTono _tonoEstado(String estado) => switch (estado) {
  EstadoCpe.aceptado => EtiquetaTono.exito,
  EstadoCpe.rechazado => EtiquetaTono.peligro,
  _ => EtiquetaTono.aviso,
};

EtiquetaTono _tonoWhatsApp(String? estado) => switch (estado) {
  EstadoWhatsAppCpe.encolado => EtiquetaTono.exito,
  EstadoWhatsAppCpe.error => EtiquetaTono.peligro,
  EstadoWhatsAppCpe.sinTelefono => EtiquetaTono.aviso,
  _ => EtiquetaTono.neutral,
};

class ComprobantesLista extends ConsumerWidget {
  const ComprobantesLista({super.key, required this.tipo, required this.ruta});

  final String tipo;
  final String ruta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final submodulo = TipoCpe.submodulo(tipo);
    final todos =
        ref.watch(comprobantesProvider(tipo)).valueOrNull ??
        const <Comprobante>[];
    final aceptados = todos.where((c) => c.aceptado).length;
    final rechazados = todos
        .where((c) => c.estado == EstadoCpe.rechazado)
        .length;
    final pendientes = todos
        .where(
          (c) => c.estado == EstadoCpe.generado || c.estado == EstadoCpe.error,
        )
        .length;

    // Si SUNAT responde o se envía algo desde otro lado, la lista se pone al día sola.
    escucharCambios(ref, [
      'comprobantes',
    ], () => ref.invalidate(comprobantesProvider(tipo)));

    return AppListaPagina<Comprobante>(
      titulo: _titulo(tipo),
      ruta: ruta,
      estado: ref.watch(comprobantesProvider(tipo)),
      visibles: ref.watch(comprobantesFiltradosProvider(tipo)),
      busqueda: ref.watch(busquedaComprobantesProvider(tipo)),
      onBuscar: (t) =>
          ref.read(busquedaComprobantesProvider(tipo).notifier).state = t,
      pistaBusqueda: 'Buscar por número o cliente',
      onRecargar: () =>
          ref.read(comprobantesProvider(tipo).notifier).recargar(),
      // Crear directo: abre la venta directa con este comprobante ya elegido (registra la venta y lo emite a SUNAT).
      onNuevo:
          (tipo == TipoCpe.factura || tipo == TipoCpe.boleta) &&
              puede(ref, submodulo, Accion.crear) &&
              puede(ref, 'fact.notaventa', Accion.crear)
          ? () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NotaVentaFormulario(comprobanteInicial: tipo),
              ),
            )
          : null,
      textoNuevo: tipo == TipoCpe.factura ? 'Nueva factura' : 'Nueva boleta',
      iconoVacio: _icono(tipo),
      tituloVacio: 'Todavía no hay ${_titulo(tipo).toLowerCase()}',
      detalleVacio: tipo == TipoCpe.factura || tipo == TipoCpe.boleta
          ? 'Se emiten desde Notas de venta en el panel web.'
          : 'Se emiten desde Facturas o Boletas, sobre un comprobante aceptado.',
      singular: tipo == TipoCpe.notaCredito || tipo == TipoCpe.notaDebito
          ? 'nota'
          : TipoCpe.corto(tipo).toLowerCase(),
      plural: _titulo(tipo).toLowerCase(),
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Emitidos',
          valor: '${todos.length}',
          icono: _icono(tipo),
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Aceptados',
          valor: '$aceptados',
          icono: Icons.check_circle_outline,
          tono: DatoTono.exito,
        ),
        AppTarjetaDato(
          etiqueta: 'Sin respuesta',
          valor: '$pendientes',
          icono: Icons.schedule,
          tono: pendientes > 0 ? DatoTono.aviso : DatoTono.neutral,
        ),
        AppTarjetaDato(
          etiqueta: 'Rechazados',
          valor: '$rechazados',
          icono: Icons.cancel_outlined,
          tono: rechazados > 0 ? DatoTono.peligro : DatoTono.neutral,
        ),
      ],
      fila: (context, c) => _TarjetaComprobante(
        comprobante: c,
        color: color,
        puedeExportar: puede(ref, submodulo, Accion.exportar),
        puedeReenviar: puede(ref, submodulo, Accion.crear),
        // Las notas que el usuario puede emitir sobre una factura o boleta aceptada.
        tiposNota: [
          if (c.aceptado &&
              (c.tipo == TipoCpe.factura || c.tipo == TipoCpe.boleta)) ...[
            if (puede(ref, TipoCpe.submodulo(TipoCpe.notaCredito), Accion.crear))
              TipoCpe.notaCredito,
            if (puede(ref, TipoCpe.submodulo(TipoCpe.notaDebito), Accion.crear))
              TipoCpe.notaDebito,
          ],
        ],
        onReenviar: () => _reenviar(context, ref, c),
      ),
    );
  }
}

/// Vuelve a mandar a SUNAT un comprobante que quedo sin respuesta, y pone en la lista lo que respondio.
Future<void> _reenviar(BuildContext context, WidgetRef ref, Comprobante c) async {
  final mensajero = Aviso.de(context);
  try {
    final nuevo = await ref.read(comprobantesApiProvider).reenviar(c.id);
    ref.read(comprobantesProvider(c.tipo).notifier).reemplazar(nuevo);
    if (nuevo.aceptado) {
      mensajero.mostrar('${nuevo.numeroCompleto} aceptado por SUNAT');
    } else {
      mensajero.error(
        '${nuevo.numeroCompleto}: ${nuevo.mensajeSunat ?? EstadoCpe.etiqueta(nuevo.estado)}',
      );
    }
  } on ApiExcepcion catch (e) {
    mensajero.error(e.texto);
  }
}

class _TarjetaComprobante extends StatelessWidget {
  const _TarjetaComprobante({
    required this.comprobante,
    required this.color,
    required this.puedeExportar,
    required this.puedeReenviar,
    required this.tiposNota,
    required this.onReenviar,
  });

  final Comprobante comprobante;
  final Color color;
  final bool puedeExportar;
  final bool puedeReenviar;

  /// Notas (07, 08) que se pueden emitir sobre este comprobante. Vacio: ninguna.
  final List<String> tiposNota;
  final VoidCallback onReenviar;

  Comprobante get _c => comprobante;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Cliente', _c.clienteNombre),
    CampoDetalle(
      'Documento',
      _c.clienteDocumento == '-' ? 'Sin documento' : _c.clienteDocumento,
    ),
    CampoDetalle('Emisión', diaCorto(_c.fechaEmision)),
    CampoDetalle('Total', 'S/ ${_c.total.toStringAsFixed(2)}'),
    if (_c.afectadoNumero != null) CampoDetalle('Corrige a', _c.afectadoNumero),
    if (_c.notaVentaNumero != null && _c.afectadoNumero == null)
      CampoDetalle('Nota de venta', _c.notaVentaNumero),
    if (_c.desMotivo != null) CampoDetalle('Motivo', _c.desMotivo),
    if (_c.notas.isNotEmpty)
      CampoDetalle(
        'Notas',
        _c.notas
            .map(
              (n) =>
                  '${n.tipo == TipoCpe.notaCredito ? 'NC' : 'ND'} ${n.numeroCompleto}',
            )
            .join(', '),
      ),
    CampoDetalle(
      'WhatsApp',
      null,
      widget: AppEtiqueta(
        EstadoWhatsAppCpe.etiqueta(_c.whatsAppEstado),
        tono: _tonoWhatsApp(_c.whatsAppEstado),
      ),
    ),
    if (_c.whatsAppTelefono != null)
      CampoDetalle('Enviado a', _c.whatsAppTelefono, enTarjeta: false),
    if (_c.mensajeSunat != null)
      CampoDetalle('SUNAT', _c.mensajeSunat, enTarjeta: false),
    if (_c.esPrueba)
      CampoDetalle(
        'Entorno',
        'Pruebas: sin validez tributaria',
        enTarjeta: false,
      ),
  ];

  bool get _hayMenu =>
      puedeExportar ||
      tiposNota.isNotEmpty ||
      (puedeReenviar &&
          (_c.estado == EstadoCpe.generado || _c.estado == EstadoCpe.error));

  Future<void> _elegir(BuildContext context, String accion) async {
    switch (accion) {
      case 'xml':
      case 'cdr':
        final xml = accion == 'xml';
        final error = await abrirPdfDeRuta(
          ruta: '/comprobante/${_c.id}/$accion',
          nombre: xml ? '${_c.nombreArchivo}.xml' : 'R-${_c.nombreArchivo}.zip',
        );
        if (error != null && context.mounted) Aviso.de(context).error(error);
      case 'reenviar':
        onReenviar();
      case 'nota':
        await abrirEmitirNota(context, _c, tiposNota);
    }
  }

  Widget get _estado =>
      AppEtiqueta(EstadoCpe.etiqueta(_c.estado), tono: _tonoEstado(_c.estado));

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: _icono(_c.tipo),
      color: color,
      titulo: _c.numeroCompleto,
      estado: _estado,
      campos: _campos,
      onTap: () => mostrarDetalle(
        context,
        icono: _icono(_c.tipo),
        color: color,
        titulo: _c.numeroCompleto,
        subtitulo: _c.clienteNombre,
        estado: _estado,
        campos: _campos,
      ),
      acciones: [
        if (puedeExportar)
          IconButton(
            onPressed: () => mostrarOpcionesPdf(
              context,
              documento: DocumentoPdf.comprobante,
              id: _c.id,
              numero: _c.numeroCompleto,
            ),
            tooltip: 'PDF',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          ),
        if (puedeExportar && _c.aceptado)
          IconButton(
            onPressed: () => abrirEnvioWhatsApp(context, _c),
            tooltip: 'Enviar documento por WhatsApp',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.send_outlined,
              size: 18,
              color: Colores.exito,
            ),
          ),
        // XML, CDR, reenvio a SUNAT y notas: en un menu, porque en la esquina de la tarjeta no caben tantos iconos.
        if (_hayMenu)
          PopupMenuButton<String>(
            tooltip: 'Más',
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_vert, size: 18),
            onSelected: (v) => _elegir(context, v),
            itemBuilder: (_) => [
              if (puedeExportar)
                const PopupMenuItem(value: 'xml', child: Text('Descargar XML')),
              if (puedeExportar && _c.tieneCdr)
                const PopupMenuItem(value: 'cdr', child: Text('Descargar CDR')),
              if (puedeReenviar &&
                  (_c.estado == EstadoCpe.generado ||
                      _c.estado == EstadoCpe.error))
                const PopupMenuItem(
                  value: 'reenviar',
                  child: Text('Reenviar a SUNAT'),
                ),
              if (tiposNota.isNotEmpty)
                const PopupMenuItem(
                  value: 'nota',
                  child: Text('Emitir nota de crédito o débito'),
                ),
            ],
          ),
      ],
    );
  }
}
