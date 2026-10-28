import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../compartido/widgets/app_acciones_flotantes.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_buscador.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_pestanas.dart';
import '../../../compartido/widgets/app_shell.dart';
import '../../../compartido/widgets/app_vacio.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../maestros/vistas/categorizacion_hoja.dart';
import '../datos/crm.dart';
import '../estado/crm_controlador.dart';
import 'crm_comun.dart';
import 'seguimiento_compras.dart';
import 'seguimiento_gestiones.dart';
import 'seguimiento_resumen.dart';

enum PestanaSeguimiento { resumen, seguimiento, compras, documentos }

const _submodulo = 'crm.seguimiento';

/// Gestión y seguimiento de clientes: se busca un cliente y aparece su ficha
/// (resumen, seguimiento, compras y documentos).
///
/// Los reportes de Clientes con caída e inactivos la abren ya con el cliente
/// elegido: `/crm/seguimiento?cliente=17&pestana=seguimiento`.
class SeguimientoPagina extends ConsumerStatefulWidget {
  const SeguimientoPagina({super.key, this.clienteId, this.pestana});

  static const ruta = '/crm/seguimiento';

  final int? clienteId;
  final String? pestana;

  @override
  ConsumerState<SeguimientoPagina> createState() => _SeguimientoPaginaState();
}

class _SeguimientoPaginaState extends ConsumerState<SeguimientoPagina> {
  late PestanaSeguimiento _pestana = PestanaSeguimiento.values.firstWhere(
    (p) => p.name == widget.pestana,
    orElse: () => PestanaSeguimiento.resumen,
  );

  @override
  void didUpdateWidget(SeguimientoPagina anterior) {
    super.didUpdateWidget(anterior);
    // Otro cliente elegido desde un reporte: se respeta la pestaña que traiga.
    if (anterior.clienteId != widget.clienteId) {
      _pestana = PestanaSeguimiento.values.firstWhere(
        (p) => p.name == widget.pestana,
        orElse: () => PestanaSeguimiento.resumen,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final grupo = resolverRuta(SeguimientoPagina.ruta).grupo;
    final color = grupo?.color ?? Colores.marca;
    final id = widget.clienteId;
    final puedeCrear = puede(ref, _submodulo, Accion.crear);

    return AppShell(
      titulo: 'Gestión y seguimiento',
      subtitulo: grupo?.titulo,
      acentado: color,
      rutaActual: SeguimientoPagina.ruta,
      accionFlotante: id != null && puedeCrear
          ? AppAccionesFlotantes(
              colorUnica: color,
              acciones: [
                AccionGlobal(
                  etiqueta: 'Registrar gestión',
                  icono: Icons.add_comment_outlined,
                  color: AccionGlobal.verde,
                  onTap: () => mostrarFormularioGestion(context, clienteId: id),
                ),
              ],
            )
          : null,
      child: id == null
          ? const _Buscador()
          : _Ficha(
              id: id,
              pestana: _pestana,
              onPestana: (p) => setState(() => _pestana = p),
            ),
    );
  }
}

// ------------------------------------------------------------------ Buscador

/// Sin cliente elegido: se busca por nombre, documento o código.
class _Buscador extends ConsumerWidget {
  const _Buscador();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texto = ref.watch(busquedaClienteSeguimientoProvider);
    final resultados = ref.watch(clientesBuscadosProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Dimen.espacio4),
          child: AppBuscador(
            valor: texto,
            onCambio: (t) =>
                ref.read(busquedaClienteSeguimientoProvider.notifier).state = t,
            pista: 'Buscar cliente por nombre, documento o código',
          ),
        ),
        Expanded(
          child: texto.trim().length < 2
              ? const AppVacio(
                  icono: Icons.person_search_outlined,
                  titulo: 'Elige un cliente para empezar',
                  detalle:
                      'Búscalo por nombre, documento o código para ver su '
                      'ficha, registrar una gestión y dejar programado el '
                      'siguiente contacto.',
                )
              : resultados.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => AppVacio(
                    icono: Icons.wifi_off_outlined,
                    titulo: 'No se pudo buscar',
                    detalle: e is ApiExcepcion ? e.texto : null,
                  ),
                  data: (lista) => lista.isEmpty
                      ? const AppVacio(
                          icono: Icons.search_off,
                          titulo: 'Sin resultados',
                          detalle:
                              'Ningún cliente coincide con lo que buscaste.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            Dimen.espacio4,
                            0,
                            Dimen.espacio4,
                            Dimen.espacio5,
                          ),
                          itemCount: lista.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: Dimen.espacio2),
                          itemBuilder: (context, i) {
                            final c = lista[i];
                            return ListTile(
                              tileColor: Colores.superficie,
                              shape: RoundedRectangleBorder(
                                side: const BorderSide(color: Colores.linea),
                                borderRadius: BorderRadius.circular(
                                  Dimen.radioCampo,
                                ),
                              ),
                              leading: Icon(
                                Icons.storefront_outlined,
                                color: Acento.de(context),
                              ),
                              title: Text(
                                c.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${c.codigo} · ${c.documento}'
                                '${c.mercado == null ? '' : ' · ${c.mercado}'}',
                              ),
                              trailing: c.activo
                                  ? null
                                  : const AppEtiqueta(
                                      'Inactivo',
                                      tono: EtiquetaTono.aviso,
                                    ),
                              onTap: () => context.go(
                                '${SeguimientoPagina.ruta}?cliente=${c.id}',
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------- Ficha

class _Ficha extends ConsumerWidget {
  const _Ficha({
    required this.id,
    required this.pestana,
    required this.onPestana,
  });

  final int id;
  final PestanaSeguimiento pestana;
  final ValueChanged<PestanaSeguimiento> onPestana;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ficha = ref.watch(fichaClienteProvider(id));

    return ficha.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppVacio(
        icono: Icons.wifi_off_outlined,
        titulo: 'No se pudo cargar la ficha',
        detalle: e is ApiExcepcion ? e.texto : null,
        accion: TextButton(
          onPressed: () => ref.invalidate(fichaClienteProvider(id)),
          child: const Text('Reintentar'),
        ),
      ),
      data: (f) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(fichaClienteProvider(id));
          ref.invalidate(gestionesClienteProvider(id));
          ref.invalidate(comprasClienteProvider(id));
          ref.invalidate(documentosClienteProvider(id));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Dimen.espacio4,
            Dimen.espacio3,
            Dimen.espacio4,
            Dimen.espacio6 * 2,
          ),
          children: [
            _Cabecera(ficha: f),
            const SizedBox(height: Dimen.espacio3),
            AppPestanas<PestanaSeguimiento>(
              activa: pestana,
              onCambio: onPestana,
              pestanas: const [
                Pestana(
                  PestanaSeguimiento.resumen,
                  'Resumen',
                  icono: Icons.person_outline,
                ),
                Pestana(
                  PestanaSeguimiento.seguimiento,
                  'Seguimiento',
                  icono: Icons.assignment_outlined,
                ),
                Pestana(
                  PestanaSeguimiento.compras,
                  'Compras',
                  icono: Icons.shopping_cart_outlined,
                ),
                Pestana(
                  PestanaSeguimiento.documentos,
                  'Documentos',
                  icono: Icons.description_outlined,
                ),
              ],
            ),
            const SizedBox(height: Dimen.espacio3),
            switch (pestana) {
              PestanaSeguimiento.resumen => TabResumen(
                ficha: f,
                alVerSeguimiento: () =>
                    onPestana(PestanaSeguimiento.seguimiento),
              ),
              PestanaSeguimiento.seguimiento => TabSeguimiento(clienteId: id),
              PestanaSeguimiento.compras => TabCompras(clienteId: id),
              PestanaSeguimiento.documentos => TabDocumentos(clienteId: id),
            },
          ],
        ),
      ),
    );
  }
}

/// El cliente arriba de todo: quién es, cómo está y cómo contactarlo.
class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.ficha});

  final FichaCliente ficha;

  @override
  Widget build(BuildContext context) {
    final c = ficha.cliente;
    final p = ficha.periodo;

    return Container(
      padding: const EdgeInsets.all(Dimen.espacio4),
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioPanel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.nombre,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => context.go(SeguimientoPagina.ruta),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Cambiar'),
              ),
            ],
          ),
          Wrap(
            spacing: Dimen.espacio2,
            runSpacing: Dimen.espacio1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              EtiquetaEstadoCaida(c.estado),
              if (c.categoriaCodigo != null)
                InsigniaCategoria(
                  codigo: c.categoriaCodigo!,
                  nombre: c.categoria,
                  color: c.categoriaColor,
                ),
              if (!c.activo)
                const AppEtiqueta('Inactivo', tono: EtiquetaTono.aviso),
              Text(
                '${c.codigo} · ${c.tipoDoc} ${c.documento}',
                style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
              ),
            ],
          ),
          const SizedBox(height: Dimen.espacio2),
          if (c.telefono != null && c.telefono!.trim().isNotEmpty)
            InkWell(
              onTap: () => abrirWhatsapp(context, c.telefono!),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(
                      Icons.call_outlined,
                      size: 15,
                      color: Colores.tintaSuave,
                    ),
                    const SizedBox(width: Dimen.espacio2),
                    Text(c.telefono!, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: Dimen.espacio2),
                    const Icon(
                      Icons.chat_outlined,
                      size: 15,
                      color: Colores.exito,
                    ),
                  ],
                ),
              ),
            ),
          if (c.direccion != null && c.direccion!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 15,
                    color: Colores.tintaSuave,
                  ),
                  const SizedBox(width: Dimen.espacio2),
                  Expanded(
                    child: Text(
                      c.direccion!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Dimen.espacio3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Dimen.espacio3),
            decoration: BoxDecoration(
              color: c.estado.color.withValues(alpha: 0.08),
              border: Border.all(color: c.estado.color.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(Dimen.radioCampo),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${c.estado.etiqueta} · ${c.estado.rango}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: c.estado.color,
                  ),
                ),
                Text(
                  solesConSigno(p.variacion),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: c.estado.color,
                  ),
                ),
                Text(
                  '${p.caidaPct == null ? 'Sin comparación' : porcentaje(-p.caidaPct!)} '
                  'frente a ${p.etiquetaAnterior} · antes ${soles(p.ventasAnterior)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Colores.tintaSuave,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un aviso de permiso para quien solo puede mirar.
class AvisoSoloLectura extends StatelessWidget {
  const AvisoSoloLectura({super.key});

  @override
  Widget build(BuildContext context) => const AppAlerta(
    'Puedes ver el seguimiento, pero no registrar gestiones.',
    tono: AlertaTono.aviso,
  );
}
