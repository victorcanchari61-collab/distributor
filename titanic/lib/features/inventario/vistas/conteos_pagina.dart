import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_buscador.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../compartido/widgets/app_shell.dart';
import '../../../compartido/widgets/app_vacio.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/motivo.dart';
import '../datos/stock.dart';
import '../estado/inventario_controlador.dart';

/// Conteo ciclico: cuentas fisicamente lo que hay y el sistema arma los
/// ajustes de SOBRANTE/FALTANTE por la diferencia. No es un documento propio,
/// es un asistente que termina llamando a Ajustes.
class ConteosPagina extends ConsumerStatefulWidget {
  const ConteosPagina({super.key});

  static const ruta = '/inv/conteos';

  @override
  ConsumerState<ConteosPagina> createState() => _ConteosPaginaState();
}

class _ConteosPaginaState extends ConsumerState<ConteosPagina> {
  final Map<int, TextEditingController> _contados = {};
  String _busqueda = '';
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _contados.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controlador(Stock s) =>
      _contados.putIfAbsent(s.productoId, () => TextEditingController());

  double? _diferencia(Stock s) {
    final ctrl = _contados[s.productoId];
    if (ctrl == null || ctrl.text.trim().isEmpty) return null;
    final contado = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
    if (contado == null) return null;
    return contado - s.stock;
  }

  Future<void> _registrar(List<Stock> stock) async {
    final almacenId = ref.read(almacenConteoProvider);
    if (almacenId == null) return;

    final sobrantes = <Stock, double>{};
    final faltantes = <Stock, double>{};
    for (final s in stock) {
      final diff = _diferencia(s);
      if (diff == null || diff == 0) continue;
      if (diff > 0) {
        sobrantes[s] = diff;
      } else {
        faltantes[s] = -diff;
      }
    }

    if (sobrantes.isEmpty && faltantes.isEmpty) {
      setState(() => _error = 'No hay diferencias que registrar.');
      return;
    }

    final ok = await confirmarAccion(
      context,
      titulo: 'Registrar conteo',
      mensaje:
          'Se crearán ajustes por ${sobrantes.length} sobrante(s) y ${faltantes.length} faltante(s). '
          'No se puede deshacer.',
      textoConfirmar: 'Registrar',
      tono: ConfirmTono.pregunta,
    );
    if (!ok || !mounted) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    final motivos = ref.read(motivosProvider).valueOrNull ?? const <Motivo>[];
    Motivo? buscarMotivo(String codigo) {
      for (final m in motivos) {
        if (m.codigo == codigo) return m;
      }
      return null;
    }

    final motivoSobrante = buscarMotivo('SOBRANTE');
    final motivoFaltante = buscarMotivo('FALTANTE');

    if ((sobrantes.isNotEmpty && motivoSobrante == null) ||
        (faltantes.isNotEmpty && motivoFaltante == null)) {
      setState(() {
        _guardando = false;
        _error = 'Revisa Ajustes → Motivos: falta el motivo SOBRANTE o FALTANTE.';
      });
      return;
    }

    final mensajero = ScaffoldMessenger.of(context);

    try {
      if (sobrantes.isNotEmpty) {
        await ref.read(ajustesProvider.notifier).crear({
          'almacenId': almacenId,
          'motivoId': motivoSobrante!.id,
          'flete': 0,
          'detalle': [
            for (final entrada in sobrantes.entries)
              {'productoId': entrada.key.productoId, 'cantidad': entrada.value},
          ],
        });
      }
      if (faltantes.isNotEmpty) {
        await ref.read(ajustesProvider.notifier).crear({
          'almacenId': almacenId,
          'motivoId': motivoFaltante!.id,
          'flete': 0,
          'detalle': [
            for (final entrada in faltantes.entries)
              {'productoId': entrada.key.productoId, 'cantidad': entrada.value},
          ],
        });
      }

      setState(() {
        _guardando = false;
        for (final c in _contados.values) {
          c.clear();
        }
      });
      mensajero.showSnackBar(const SnackBar(content: Text('Conteo registrado')));
      ref.invalidate(stockConteoProvider);
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = resolverRuta(ConteosPagina.ruta).grupo?.color ?? Colores.marca;
    final almacenes = ref.watch(almacenesActivosProvider);
    final almacenId = ref.watch(almacenConteoProvider);
    final stockAsync = ref.watch(stockConteoProvider);

    return AppShell(
      titulo: 'Conteos cíclicos',
      subtitulo: resolverRuta(ConteosPagina.ruta).grupo?.titulo,
      acentado: color,
      rutaActual: ConteosPagina.ruta,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Dimen.espacio4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  AppAlerta(_error!),
                  const SizedBox(height: Dimen.espacio3),
                ],
                AppSelector<int>(
                  valor: almacenId,
                  etiqueta: 'Almacén a contar',
                  icono: Icons.warehouse_outlined,
                  opciones: [for (final a in almacenes) Opcion<int>(a.id, a.nombre)],
                  onCambio: (v) => ref.read(almacenConteoProvider.notifier).state = v,
                ),
                if (almacenId != null) ...[
                  const SizedBox(height: Dimen.espacio3),
                  AppBuscador(
                    valor: _busqueda,
                    onCambio: (t) => setState(() => _busqueda = t),
                    pista: 'Buscar por código o nombre',
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: almacenId == null
                ? const AppVacio(
                    icono: Icons.fact_check_outlined,
                    titulo: 'Elige un almacén',
                    detalle: 'Para empezar a contar, primero elige el almacén.',
                  )
                : stockAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => AppVacio(
                      icono: Icons.wifi_off_outlined,
                      titulo: 'No se pudo cargar',
                      detalle: e is ApiExcepcion ? e.texto : 'No pudimos cargar el stock.',
                    ),
                    data: (stock) {
                      final visibles = _busqueda.isEmpty
                          ? stock
                          : stock.where((s) => s.buscable.contains(_busqueda.toLowerCase())).toList();
                      if (visibles.isEmpty) {
                        return const AppVacio(
                          icono: Icons.inventory_2_outlined,
                          titulo: 'Sin productos',
                          detalle: 'Este almacén no tiene stock registrado.',
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          Dimen.espacio4,
                          0,
                          Dimen.espacio4,
                          Dimen.espacio6 * 2,
                        ),
                        itemCount: visibles.length,
                        separatorBuilder: (context, i) => const SizedBox(height: Dimen.espacio2),
                        itemBuilder: (context, i) => _FilaConteo(
                          stock: visibles[i],
                          controlador: _controlador(visibles[i]),
                          diferencia: _diferencia(visibles[i]),
                          onCambio: () => setState(() {}),
                        ),
                      );
                    },
                  ),
          ),
          if (almacenId != null)
            Padding(
              padding: const EdgeInsets.all(Dimen.espacio4),
              child: AppBoton(
                texto: 'Registrar conteo',
                cargando: _guardando,
                onPressed: () => _registrar(stockAsync.valueOrNull ?? const []),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilaConteo extends StatelessWidget {
  const _FilaConteo({
    required this.stock,
    required this.controlador,
    required this.diferencia,
    required this.onCambio,
  });

  final Stock stock;
  final TextEditingController controlador;
  final double? diferencia;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context) {
    final diff = diferencia;
    return Container(
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stock.producto,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colores.tinta),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sistema: ${formatoNumero(stock.stock)} ${stock.unidadBase}'
                  '${diff == null || diff == 0 ? '' : ' · ${diff > 0 ? '+' : ''}${formatoNumero(diff)}'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: diff == null || diff == 0
                        ? Colores.tintaSuave
                        : (diff > 0 ? Colores.exito : Colores.peligro),
                    fontWeight: diff == null || diff == 0 ? FontWeight.normal : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Dimen.espacio3),
          SizedBox(
            width: 110,
            child: AppCampo(
              controlador: controlador,
              etiqueta: 'Contado',
              tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
              alEnviar: onCambio,
            ),
          ),
        ],
      ),
    );
  }
}
