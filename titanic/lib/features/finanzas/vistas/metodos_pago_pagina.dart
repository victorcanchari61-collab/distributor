import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../datos/metodo_pago.dart';
import '../estado/finanzas_controlador.dart';
import 'metodo_pago_formulario.dart';

/// Listado de metodos de pago: efectivo, billetera digital, transferencia...
/// el mismo catalogo lo usan Compras, Cuentas por cobrar y por pagar, Mis
/// cobros y el Arqueo diario.
class MetodosPagoPagina extends ConsumerWidget {
  const MetodosPagoPagina({super.key});

  static const ruta = '/finanzas/metodospago';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todos = ref.watch(metodosPagoProvider).valueOrNull ?? const <MetodoPago>[];

    return AppListaPagina<MetodoPago>(
      titulo: 'Métodos de pago',
      ruta: ruta,
      estado: ref.watch(metodosPagoProvider),
      visibles: ref.watch(metodosPagoFiltradosProvider),
      busqueda: ref.watch(busquedaMetodosPagoProvider),
      onBuscar: (t) => ref.read(busquedaMetodosPagoProvider.notifier).state = t,
      pistaBusqueda: 'Buscar método de pago',
      onRecargar: () => ref.read(metodosPagoProvider.notifier).recargar(),
      onNuevo: () => _abrirFormulario(context, null),
      textoNuevo: 'Nuevo método',
      iconoVacio: Icons.payments_outlined,
      singular: 'método de pago',
      plural: 'métodos de pago',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Métodos de pago',
          valor: '${todos.length}',
          icono: Icons.payments_outlined,
          color: color,
        ),
      ],
      fila: (context, metodo) => _TarjetaMetodoPago(
        metodo: metodo,
        color: color,
        onEditar: () => _abrirFormulario(context, metodo),
        onEstado: () => _cambiarEstado(context, ref, metodo),
      ),
    );
  }

  Future<void> _abrirFormulario(BuildContext context, MetodoPago? metodo) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MetodoPagoFormulario(metodo: metodo)),
    );
  }

  Future<void> _cambiarEstado(
    BuildContext context,
    WidgetRef ref,
    MetodoPago metodo,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: '${metodo.activo ? 'Desactivar' : 'Activar'} ${metodo.nombre}',
      mensaje: metodo.activo
          ? 'Deja de ofrecerse en compras, cobros y pagos nuevos. Lo ya registrado se conserva.'
          : 'Vuelve a estar disponible para elegirse.',
      textoConfirmar: metodo.activo ? 'Desactivar' : 'Activar',
      tono: metodo.activo ? ConfirmTono.aviso : ConfirmTono.pregunta,
    );
    if (!ok || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);

    try {
      await ref.read(metodosPagoProvider.notifier).cambiarEstado(metodo);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            metodo.activo
                ? '${metodo.nombre} desactivado'
                : '${metodo.nombre} activado',
          ),
        ),
      );
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }
}

class _TarjetaMetodoPago extends StatelessWidget {
  const _TarjetaMetodoPago({
    required this.metodo,
    required this.color,
    required this.onEditar,
    required this.onEstado,
  });

  final MetodoPago metodo;
  final Color color;
  final VoidCallback onEditar;
  final VoidCallback onEstado;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Banco', metodo.banco),
    CampoDetalle('Número', metodo.numeroCuenta),
    CampoDetalle('CCI', metodo.cci),
    CampoDetalle('Titular', metodo.titular),
    CampoDetalle(
      'Estado',
      metodo.activo ? 'Activo' : 'Inactivo',
      widget: AppEtiqueta(
        metodo.activo ? 'Activo' : 'Inactivo',
        tono: metodo.activo ? EtiquetaTono.exito : EtiquetaTono.aviso,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.payments_outlined,
      color: color,
      titulo: metodo.nombre,
      insignia: AppEtiqueta(TipoMetodoPago.etiqueta(metodo.tipo)),
      campos: _campos,
      onTap: () => _abrirDetalle(context),
      acciones: [
        IconButton(
          onPressed: onEditar,
          tooltip: 'Editar',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.edit_outlined, size: 18, color: Acento.de(context)),
        ),
        IconButton(
          onPressed: onEstado,
          tooltip: metodo.activo ? 'Desactivar' : 'Activar',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            metodo.activo ? Icons.block : Icons.check_circle_outline,
            size: 18,
            color: metodo.activo ? Colores.advertencia : Colores.exito,
          ),
        ),
      ],
    );
  }

  Future<void> _abrirDetalle(BuildContext context) {
    return mostrarDetalle(
      context,
      icono: Icons.payments_outlined,
      color: color,
      titulo: metodo.nombre,
      subtitulo: TipoMetodoPago.etiqueta(metodo.tipo),
      insignia: !metodo.activo
          ? const AppEtiqueta('Inactivo', tono: EtiquetaTono.aviso)
          : null,
      campos: _campos,
      acciones: [
        AppBoton(
          texto: metodo.activo ? 'Desactivar' : 'Activar',
          variante: BotonVariante.secundario,
          expandido: true,
          onPressed: () {
            Navigator.of(context).pop();
            onEstado();
          },
        ),
        AppBoton(
          texto: 'Editar',
          expandido: true,
          onPressed: () {
            Navigator.of(context).pop();
            onEditar();
          },
        ),
      ],
    );
  }
}
