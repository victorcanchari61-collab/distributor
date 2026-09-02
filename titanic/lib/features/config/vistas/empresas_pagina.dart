import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../datos/config_modelos.dart';
import '../estado/config_controlador.dart';
import 'empresa_formulario.dart';

/// Datos de la empresa con la que opera el sistema.
class EmpresasPagina extends ConsumerWidget {
  const EmpresasPagina({super.key});

  static const ruta = '/config/empresa';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppListaPagina<Empresa>(
      titulo: 'Empresa',
      ruta: ruta,
      estado: ref.watch(empresasProvider),
      visibles: ref.watch(empresasFiltradasProvider),
      busqueda: ref.watch(busquedaEmpresasProvider),
      onBuscar: (t) => ref.read(busquedaEmpresasProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por razón social o RUC',
      onRecargar: () => ref.read(empresasProvider.notifier).recargar(),
      onNuevo: () => _abrirFormulario(context, null),
      textoNuevo: 'Nueva',
      iconoVacio: Icons.domain_outlined,
      singular: 'empresa',
      plural: 'empresas',
      fila: (context, empresa) => _TarjetaEmpresa(
        empresa: empresa,
        color: resolverRuta(ruta).grupo?.color ?? Colores.marca,
        onEditar: () => _abrirFormulario(context, empresa),
        onActivar: () => _activar(context, ref, empresa),
        onHabilitacion: () => _cambiarHabilitacion(context, ref, empresa),
      ),
    );
  }

  Future<void> _abrirFormulario(BuildContext context, Empresa? empresa) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EmpresaFormulario(empresa: empresa)),
    );
  }

  Future<void> _activar(
    BuildContext context,
    WidgetRef ref,
    Empresa empresa,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Operar con ${empresa.nombreComercial}',
      // El sistema trabaja siempre con una sola empresa: activar esta apaga
      // la anterior, y conviene decirlo antes de tocar el boton.
      mensaje:
          'Pasa a ser la empresa del sistema y la que estuviera activa deja de serlo. Los documentos nuevos saldrán con estos datos.',
      textoConfirmar: 'Activar',
    );
    if (!ok || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);

    try {
      await ref.read(empresasProvider.notifier).activar(empresa);
      mensajero.showSnackBar(
        SnackBar(content: Text('${empresa.nombreComercial} está activa')),
      );
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }

  Future<void> _cambiarHabilitacion(
    BuildContext context,
    WidgetRef ref,
    Empresa empresa,
  ) async {
    final mensajero = ScaffoldMessenger.of(context);

    if (empresa.activa && empresa.habilitada) {
      mensajero.showSnackBar(
        const SnackBar(
          content: Text(
            'No se puede retirar la empresa activa. Activa otra primero.',
          ),
        ),
      );
      return;
    }

    final ok = await confirmarAccion(
      context,
      titulo:
          '${empresa.habilitada ? 'Retirar' : 'Habilitar'} ${empresa.nombreComercial}',
      mensaje: empresa.habilitada
          ? 'Se guarda pero deja de poder activarse. Puedes volver a habilitarla cuando quieras.'
          : 'Vuelve a estar disponible para activarse.',
      textoConfirmar: empresa.habilitada ? 'Retirar' : 'Habilitar',
      tono: empresa.habilitada ? ConfirmTono.aviso : ConfirmTono.pregunta,
    );
    if (!ok || !context.mounted) return;

    try {
      await ref.read(empresasProvider.notifier).cambiarHabilitacion(empresa);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            empresa.habilitada
                ? '${empresa.nombreComercial} retirada'
                : '${empresa.nombreComercial} habilitada',
          ),
        ),
      );
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }
}

class _TarjetaEmpresa extends StatelessWidget {
  const _TarjetaEmpresa({
    required this.empresa,
    required this.color,
    required this.onEditar,
    required this.onActivar,
    required this.onHabilitacion,
  });

  final Empresa empresa;
  final Color color;
  final VoidCallback onEditar;
  final VoidCallback onActivar;
  final VoidCallback onHabilitacion;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Razón social', empresa.razonSocial),
    CampoDetalle('Dirección', empresa.direccion),
    CampoDetalle('Departamento', empresa.departamento, enTarjeta: false),
    CampoDetalle('Provincia', empresa.provincia, enTarjeta: false),
    CampoDetalle('Distrito', empresa.distrito, enTarjeta: false),
    CampoDetalle('Teléfono', empresa.telefono, enTarjeta: false),
    CampoDetalle('Correo', empresa.email, enTarjeta: false),
    CampoDetalle('Sitio web', empresa.sitioWeb, enTarjeta: false),
    CampoDetalle('Representante', empresa.representanteLegal, enTarjeta: false),
    CampoDetalle(
      'Estado',
      empresa.activa
          ? 'Activa'
          : empresa.habilitada
          ? 'Disponible'
          : 'Retirada',
      widget: AppEtiqueta(
        empresa.activa
            ? 'Activa'
            : empresa.habilitada
            ? 'Disponible'
            : 'Retirada',
        tono: empresa.activa
            ? EtiquetaTono.exito
            : empresa.habilitada
            ? EtiquetaTono.neutral
            : EtiquetaTono.aviso,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.domain_outlined,
      color: color,
      titulo: empresa.nombreComercial.isEmpty
          ? empresa.razonSocial
          : empresa.nombreComercial,
      insignia: AppEtiqueta('RUC ${empresa.ruc}'),
      campos: _campos,
      onTap: () => mostrarDetalle(
        context,
        icono: Icons.domain_outlined,
        color: color,
        titulo: empresa.nombreComercial.isEmpty
            ? empresa.razonSocial
            : empresa.nombreComercial,
        subtitulo: 'RUC ${empresa.ruc}',
        insignia: empresa.activa
            ? const AppEtiqueta('Activa', tono: EtiquetaTono.exito)
            : null,
        campos: _campos,
        acciones: [
          if (!empresa.activa && empresa.habilitada)
            AppBoton(
              texto: 'Activar',
              variante: BotonVariante.secundario,
              onPressed: () {
                Navigator.of(context).pop();
                onActivar();
              },
            ),
          AppBoton(
            texto: 'Editar',
            onPressed: () {
              Navigator.of(context).pop();
              onEditar();
            },
          ),
        ],
      ),
      acciones: [
        IconButton(
          onPressed: onEditar,
          tooltip: 'Editar',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.edit_outlined, size: 18, color: Colores.marca),
        ),
        // La empresa activa no ofrece "activar": ya lo esta.
        if (!empresa.activa && empresa.habilitada)
          IconButton(
            onPressed: onActivar,
            tooltip: 'Operar con esta empresa',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.check_circle_outline,
              size: 18,
              color: Colores.exito,
            ),
          ),
        IconButton(
          onPressed: onHabilitacion,
          tooltip: empresa.habilitada ? 'Retirar' : 'Habilitar',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            empresa.habilitada ? Icons.block : Icons.restore,
            size: 18,
            color: empresa.habilitada ? Colores.advertencia : Colores.exito,
          ),
        ),
      ],
    );
  }
}
