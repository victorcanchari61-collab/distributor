import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_pdf.dart';
import '../../../compartido/widgets/app_sin_permiso.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/permisos/sin_permiso.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/red/tiempo_real_provider.dart';
import '../../../core/tema/colores.dart';
import '../datos/comprobante.dart';
import '../estado/comprobantes_controlador.dart';
import '../../ventas/estado/ventas_controlador.dart';
import '../../ventas/vistas/nota_venta_formulario.dart';
import '../../../core/red/excepciones.dart';
import '../../../compartido/widgets/app_aviso.dart';
import 'dar_de_baja_hoja.dart';
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
  // Dada de baja: la factura ya no vale, no hay nada pendiente ni que corregir.
  EstadoCpe.baja => EtiquetaTono.neutral,
  _ => EtiquetaTono.aviso,
};

EtiquetaTono _tonoBaja(String? estado) => switch (estado) {
  EstadoBajaCpe.aceptada => EtiquetaTono.exito,
  EstadoBajaCpe.rechazada => EtiquetaTono.peligro,
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
      // Crear directo: abre la venta directa en modo factura o boleta. El servidor registra la venta (que no sale en
      // Notas de venta), descuenta el stock y emite el comprobante; solo pide el permiso de crear de este tipo.
      onNuevo: (tipo == TipoCpe.factura || tipo == TipoCpe.boleta)
          ? permitir(
              puede(ref, submodulo, Accion.crear),
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NotaVentaFormulario(directo: tipo),
                ),
              ),
            )
          : null,
      textoNuevo: tipo == TipoCpe.factura ? 'Nueva factura' : 'Nueva boleta',
      iconoVacio: _icono(tipo),
      tituloVacio: 'Todavía no hay ${_titulo(tipo).toLowerCase()}',
      detalleVacio: tipo == TipoCpe.factura || tipo == TipoCpe.boleta
          ? 'Se emiten con "${tipo == TipoCpe.factura ? 'Nueva factura' : 'Nueva boleta'}" o desde Notas de venta.'
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
        puedeAnular: puede(ref, submodulo, Accion.anular),
        // Una nota se ofrece sobre una factura o boleta aceptada; las que el
        // usuario puede emitir salen en tiposNota (vacio: la opcion va en gris).
        ofreceNota:
            c.aceptado &&
            (c.tipo == TipoCpe.factura || c.tipo == TipoCpe.boleta),
        tiposNota: [
          if (puede(ref, TipoCpe.submodulo(TipoCpe.notaCredito), Accion.crear))
            TipoCpe.notaCredito,
          if (puede(ref, TipoCpe.submodulo(TipoCpe.notaDebito), Accion.crear))
            TipoCpe.notaDebito,
        ],
        onReenviar: () => _reenviar(context, ref, c),
        onConsultarBaja: () => _consultarBaja(context, ref, c),
      ),
    );
  }
}

/// Pregunta a SUNAT por una baja que quedó pendiente y pone en la lista lo que respondió.
Future<void> _consultarBaja(
  BuildContext context,
  WidgetRef ref,
  Comprobante c,
) async {
  final mensajero = Aviso.de(context);
  try {
    final nuevo = await ref.read(comprobantesApiProvider).consultarBaja(c.id);
    ref.read(comprobantesProvider(c.tipo).notifier).reemplazar(nuevo);
    if (nuevo.bajaEstado == EstadoBajaCpe.aceptada) {
      // La baja aceptada anula la venta de la factura.
      ref.invalidate(notasVentaProvider);
    }
    final r = mensajeDeBaja(nuevo, consulta: true);
    if (r.esError) {
      mensajero.error(r.texto);
    } else {
      mensajero.mostrar(r.texto);
    }
  } on ApiExcepcion catch (e) {
    mensajero.error(e.texto);
  }
}

/// Vuelve a mandar a SUNAT un comprobante que quedo sin respuesta, y pone en la lista lo que respondio.
Future<void> _reenviar(
  BuildContext context,
  WidgetRef ref,
  Comprobante c,
) async {
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
    required this.puedeAnular,
    required this.ofreceNota,
    required this.tiposNota,
    required this.onReenviar,
    required this.onConsultarBaja,
  });

  final Comprobante comprobante;
  final Color color;
  final bool puedeExportar;
  final bool puedeReenviar;

  /// Puede pedir y consultar la baja de una factura (permiso `anular`).
  final bool puedeAnular;

  /// Si por su estado y tipo admite una nota de crédito o débito.
  final bool ofreceNota;

  /// Notas (07, 08) que este usuario puede emitir. Vacio: no tiene permiso.
  final List<String> tiposNota;
  final VoidCallback onReenviar;
  final VoidCallback onConsultarBaja;

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
    // La factura o boleta directa no tiene nota de venta: no hay "de NV-…" que mostrar.
    if (_c.notaVentaNumero != null &&
        !_c.ventaDirecta &&
        _c.afectadoNumero == null)
      CampoDetalle('Nota de venta', _c.notaVentaNumero),
    if (_c.bajaEstado != null)
      CampoDetalle(
        'Baja',
        null,
        widget: AppEtiqueta(
          EstadoBajaCpe.etiqueta(_c.bajaEstado!),
          tono: _tonoBaja(_c.bajaEstado),
        ),
      ),
    if (_c.bajaMotivo != null)
      CampoDetalle('Motivo de baja', _c.bajaMotivo, enTarjeta: false),
    if (_c.bajaMensaje != null && _c.bajaEstado == EstadoBajaCpe.rechazada)
      CampoDetalle('Respuesta de baja', _c.bajaMensaje, enTarjeta: false),
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

  // Lo que el estado del comprobante permite; el permiso se ve aparte, en gris.
  bool get _puedeDarDeBaja => _c.puedeDarDeBaja(DateTime.now());

  bool get _puedeConsultarBaja => _c.bajaEstado == EstadoBajaCpe.pendiente;

  Future<void> _elegir(BuildContext context, String accion) async {
    if (esValorSinPermiso(accion)) {
      avisarSinPermiso(context);
      return;
    }
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
      case 'baja':
        await abrirDarDeBaja(context, _c);
      case 'consultar_baja':
        onConsultarBaja();
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
        AppIconoAccion(
          icono: Icons.picture_as_pdf_outlined,
          tooltip: 'PDF',
          onPressed: permitir(
            puedeExportar,
            () => mostrarOpcionesPdf(
              context,
              documento: DocumentoPdf.comprobante,
              id: _c.id,
              numero: _c.numeroCompleto,
            ),
          ),
        ),
        if (_c.aceptado)
          AppIconoAccion(
            icono: Icons.send_outlined,
            tooltip: 'Enviar documento por WhatsApp',
            color: Colores.exito,
            onPressed: permitir(
              puedeExportar,
              () => abrirEnvioWhatsApp(context, _c),
            ),
          ),
        // XML, CDR, reenvio a SUNAT y notas: en un menu, porque en la esquina
        // de la tarjeta no caben tantos iconos. Lo que falta por permiso sale
        // en gris y avisa al tocarlo.
        PopupMenuButton<String>(
          tooltip: 'Más',
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.more_vert, size: 18),
          onSelected: (v) => _elegir(context, v),
          itemBuilder: (_) => [
            itemMenu('xml', 'Descargar XML', permitido: puedeExportar),
            if (_c.tieneCdr)
              itemMenu('cdr', 'Descargar CDR', permitido: puedeExportar),
            if (_c.estado == EstadoCpe.generado || _c.estado == EstadoCpe.error)
              itemMenu(
                'reenviar',
                'Reenviar a SUNAT',
                permitido: puedeReenviar,
              ),
            if (ofreceNota)
              itemMenu(
                'nota',
                'Emitir nota de crédito o débito',
                permitido: tiposNota.isNotEmpty,
              ),
            if (_puedeDarDeBaja)
              itemMenu('baja', 'Dar de baja', permitido: puedeAnular),
            if (_puedeConsultarBaja)
              itemMenu(
                'consultar_baja',
                'Consultar la baja en SUNAT',
                permitido: puedeAnular,
              ),
          ],
        ),
      ],
    );
  }
}
