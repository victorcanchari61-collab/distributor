import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_shell.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/arqueo_caja.dart';
import '../estado/finanzas_controlador.dart';

/// Cierre de caja del dia: cuanto se esperaba en efectivo contra lo contado
/// a mano, y el historial de cierres ya registrados.
class ArqueoDiarioPagina extends ConsumerStatefulWidget {
  const ArqueoDiarioPagina({super.key});

  static const ruta = '/finanzas/arqueo';

  @override
  ConsumerState<ArqueoDiarioPagina> createState() =>
      _ArqueoDiarioPaginaState();
}

class _ArqueoDiarioPaginaState extends ConsumerState<ArqueoDiarioPagina> {
  final _montoContado = TextEditingController();
  final _observacion = TextEditingController();

  bool _guardando = false;
  String? _error;

  /// Fecha del ultimo arqueo con el que se prellenaron los campos, para saber
  /// cuando el resumen cambio de dia y hay que volver a prellenar.
  int? _idPrellenado;
  bool _prellenadoVacio = false;

  @override
  void dispose() {
    _montoContado.dispose();
    _observacion.dispose();
    super.dispose();
  }

  void _prellenar(ArqueoResumen resumen) {
    final arqueo = resumen.arqueo;
    if (arqueo != null) {
      if (_idPrellenado == arqueo.id) return;
      _montoContado.text = arqueo.montoContado.toStringAsFixed(2);
      _observacion.text = arqueo.observacion ?? '';
      _idPrellenado = arqueo.id;
      _prellenadoVacio = false;
    } else if (!_prellenadoVacio) {
      _montoContado.clear();
      _observacion.clear();
      _idPrellenado = null;
      _prellenadoVacio = true;
    }
  }

  Future<void> _elegirFecha() async {
    final actual = ref.read(fechaArqueoProvider);
    final elegida = await showDatePicker(
      context: context,
      initialDate: actual,
      firstDate: DateTime(actual.year - 2),
      lastDate: DateTime.now(),
    );
    if (elegida != null) {
      ref.read(fechaArqueoProvider.notifier).state = elegida;
      _idPrellenado = null;
      _prellenadoVacio = false;
    }
  }

  Future<void> _registrar(ArqueoResumen resumen) async {
    FocusScope.of(context).unfocus();
    final monto = double.tryParse(_montoContado.text.replaceAll(',', '.'));
    if (monto == null) {
      setState(() => _error = 'Ingresa un monto contado valido.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final mensajero = ScaffoldMessenger.of(context);
    final fecha = ref.read(fechaArqueoProvider);
    final esNuevo = resumen.arqueo == null;

    try {
      await ref.read(historialArqueoProvider.notifier).registrar({
        'fecha': fecha.toIso8601String().substring(0, 10),
        'montoContado': monto,
        'observacion': _observacion.text.trim().isEmpty
            ? null
            : _observacion.text.trim(),
      });

      if (!mounted) return;
      setState(() => _guardando = false);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(esNuevo ? 'Cierre de caja registrado' : 'Cierre de caja actualizado'),
        ),
      );
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = resolverRuta(ArqueoDiarioPagina.ruta).grupo?.color ?? Colores.marca;
    final resumenAsync = ref.watch(resumenArqueoProvider);
    final fecha = ref.watch(fechaArqueoProvider);
    final historialAsync = ref.watch(historialArqueoProvider);

    resumenAsync.whenData(_prellenar);

    final montoContado = double.tryParse(_montoContado.text.replaceAll(',', '.'));
    final montoEsperado = resumenAsync.valueOrNull?.montoEsperado;
    final diferencia = montoContado != null && montoEsperado != null
        ? montoContado - montoEsperado
        : null;

    return AppShell(
      titulo: 'Arqueo diario',
      subtitulo: resolverRuta(ArqueoDiarioPagina.ruta).grupo?.titulo,
      acentado: color,
      rutaActual: ArqueoDiarioPagina.ruta,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(resumenArqueoProvider);
          await Future.wait([
            ref.read(resumenArqueoProvider.future),
            ref.read(historialArqueoProvider.notifier).recargar(),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, Dimen.espacio3, 0, Dimen.espacio6),
          children: [
            AppFilaDatos(
              tarjetas: [
                AppTarjetaDato(
                  etiqueta: 'Cobrado en efectivo',
                  valor: resumenAsync.when(
                    data: (r) => 'S/ ${r.cobradoEfectivo.toStringAsFixed(2)}',
                    loading: () => '—',
                    error: (_, _) => '—',
                  ),
                  icono: Icons.payments_outlined,
                  tono: DatoTono.exito,
                ),
                AppTarjetaDato(
                  etiqueta: 'Pagado en efectivo',
                  valor: resumenAsync.when(
                    data: (r) => 'S/ ${r.pagadoEfectivo.toStringAsFixed(2)}',
                    loading: () => '—',
                    error: (_, _) => '—',
                  ),
                  icono: Icons.shopping_bag_outlined,
                  tono: DatoTono.aviso,
                ),
                AppTarjetaDato(
                  etiqueta: 'Esperado en caja',
                  valor: resumenAsync.when(
                    data: (r) => 'S/ ${r.montoEsperado.toStringAsFixed(2)}',
                    loading: () => '—',
                    error: (_, _) => '—',
                  ),
                  icono: Icons.account_balance_wallet_outlined,
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: Dimen.espacio4),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Selector de fecha del cierre.
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio3),
                    decoration: BoxDecoration(
                      color: Colores.superficie,
                      border: Border.all(color: Colores.linea),
                      borderRadius: BorderRadius.circular(Dimen.radioCampo),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 18, color: Colores.tintaTenue),
                        const SizedBox(width: Dimen.espacio3),
                        Expanded(
                          child: Text(_fechaLarga(fecha), style: const TextStyle(fontSize: 14, color: Colores.tinta)),
                        ),
                        IconButton(
                          onPressed: _elegirFecha,
                          icon: const Icon(Icons.edit_calendar_outlined),
                          tooltip: 'Cambiar fecha',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Dimen.espacio4),

                  if (_error != null) ...[
                    AppAlerta(_error!),
                    const SizedBox(height: Dimen.espacio4),
                  ],

                  AppCampo(
                    controlador: _montoContado,
                    etiqueta: 'Monto contado',
                    pista: '0.00',
                    icono: Icons.calculate_outlined,
                    tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
                    habilitado: !_guardando,
                    alEnviar: () => setState(() {}),
                  ),
                  const SizedBox(height: Dimen.espacio4),

                  AppCampo(
                    controlador: _observacion,
                    etiqueta: 'Observación',
                    pista: 'Notas del cierre',
                    icono: Icons.notes_outlined,
                    opcional: true,
                    habilitado: !_guardando,
                  ),
                  const SizedBox(height: Dimen.espacio3),

                  if (diferencia != null)
                    Row(
                      children: [
                        const Text(
                          'Diferencia: ',
                          style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
                        ),
                        Text(
                          'S/ ${diferencia.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: diferencia == 0
                                ? Colores.exito
                                : diferencia < 0
                                    ? Colores.peligro
                                    : color,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: Dimen.espacio4),

                  AppBoton(
                    texto: resumenAsync.valueOrNull?.arqueo == null
                        ? 'Registrar cierre'
                        : 'Actualizar cierre',
                    cargando: _guardando,
                    color: color,
                    onPressed: resumenAsync.valueOrNull == null
                        ? null
                        : () => _registrar(resumenAsync.value!),
                  ),
                  const SizedBox(height: Dimen.espacio5),

                  Text(
                    'Historial',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colores.tinta),
                  ),
                  const SizedBox(height: Dimen.espacio2),
                ],
              ),
            ),

            historialAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(Dimen.espacio5),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(Dimen.espacio4),
                child: Text(
                  e is ApiExcepcion ? e.texto : 'No pudimos cargar el historial.',
                  style: const TextStyle(fontSize: 13, color: Colores.tintaSuave),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(Dimen.espacio4),
                      child: Text(
                        'Todavía no hay cierres registrados.',
                        style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
                      child: Column(
                        children: [
                          for (final item in items) ...[
                            _FilaArqueo(arqueo: item, color: color),
                            const SizedBox(height: Dimen.espacio2),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaArqueo extends StatelessWidget {
  const _FilaArqueo({required this.arqueo, required this.color});

  final ArqueoCaja arqueo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorDiferencia = arqueo.diferencia == 0
        ? Colores.exito
        : arqueo.diferencia < 0
            ? Colores.peligro
            : color;

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fecha(arqueo.fecha),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colores.tinta),
              ),
              Text(
                'S/ ${arqueo.diferencia.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colorDiferencia),
              ),
            ],
          ),
          const SizedBox(height: Dimen.espacio1),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Esperado S/ ${arqueo.montoEsperado.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
                ),
              ),
              Expanded(
                child: Text(
                  'Contado S/ ${arqueo.montoContado.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
                ),
              ),
            ],
          ),
          if (arqueo.usuario != null) ...[
            const SizedBox(height: Dimen.espacio1),
            Text(
              arqueo.usuario!,
              style: const TextStyle(fontSize: 11.5, color: Colores.tintaTenue),
            ),
          ],
        ],
      ),
    );
  }
}

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

String _fechaLarga(DateTime f) {
  const meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
  return '${f.day} de ${meses[f.month - 1]} de ${f.year}';
}
