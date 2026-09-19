import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/consulta_tabla.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_selector_rango.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/auditoria.dart';
import '../estado/auditoria_controlador.dart';

/// La palabra que hay que escribir para depurar TODA la bitácora, sin filtros.
const _palabraConfirmacion = 'ELIMINAR';

/// Abre la hoja de depuración de la bitácora.
///
/// Los filtros con que arranca son los que la lista ya tiene puestos, pero la
/// hoja los CAMBIA por su cuenta: la lista de la app se recorta en el teléfono
/// sobre los últimos cambios y no tiene fechas, mientras que la depuración se
/// hace en el servidor sobre TODA la bitácora. Por eso la hoja lleva sus propios
/// selectores y le dice a la persona cuántos registros se van a borrar de
/// verdad, no cuántos ve en pantalla.
Future<void> mostrarDepuracion(
  BuildContext context, {
  String? accion,
  String? usuario,
  String? entidad,
}) {
  // Se lee ANTES de abrir y se vuelve a declarar dentro: la hoja cuelga del
  // Navigator y no ve el acento de la pantalla que la abrió.
  final acento = Acento.de(context);

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colores.superficie,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Dimen.radioPanel)),
    ),
    builder: (context) => Acento(
      color: acento,
      child: _HojaDepurar(accion: accion, usuario: usuario, entidad: entidad),
    ),
  );
}

class _HojaDepurar extends ConsumerStatefulWidget {
  const _HojaDepurar({this.accion, this.usuario, this.entidad});

  final String? accion;
  final String? usuario;
  final String? entidad;

  @override
  ConsumerState<_HojaDepurar> createState() => _HojaDepurarState();
}

class _HojaDepurarState extends ConsumerState<_HojaDepurar> {
  final _confirmacion = TextEditingController();

  late String? _accion = widget.accion;
  late String? _usuario = widget.usuario;
  late String? _entidad = widget.entidad;
  DateTimeRange? _rango;

  /// Cuántos registros deja a la vista la consulta de ahora mismo.
  late Future<int> _total;

  bool _eliminando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _total = _contar();
    // El botón depende de lo que se teclea en la confirmación.
    _confirmacion.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirmacion.dispose();
    super.dispose();
  }

  /// La consulta que se cuenta y se borra: UNA sola, para que lo que se le
  /// enseña a la persona sea exactamente lo que se elimina. Los nombres de
  /// columna son los que lee `AuditoriaRepository.Filtrar`.
  ConsultaTabla get _consulta => ConsultaTabla(
    filtros: [
      if (_rango != null) FiltroTabla.dias('fecha', _rango!.start, _rango!.end),
      if (_usuario != null) FiltroTabla(columna: 'usuario', valor: _usuario!),
      if (_entidad != null) FiltroTabla(columna: 'entidad', valor: _entidad!),
      if (_accion != null) FiltroTabla(columna: 'accion', valor: _accion!),
    ],
  );

  bool get _sinFiltros => _consulta.filtros.isEmpty;

  Future<int> _contar() => ref.read(auditoriaProvider.notifier).contar(_consulta);

  /// Cambia un filtro y vuelve a contar. La confirmación escrita se borra: si
  /// se tecleó ELIMINAR con todo abierto y luego se puso y quitó un filtro, no
  /// debe valer para lo que ya es otra depuración.
  void _cambiar(VoidCallback cambio) {
    if (_eliminando) return;
    _confirmacion.clear();
    setState(() {
      cambio();
      _error = null;
      _total = _contar();
    });
  }

  Future<void> _eliminar() async {
    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);
    final notificador = ref.read(auditoriaProvider.notifier);

    setState(() {
      _eliminando = true;
      _error = null;
    });

    try {
      final eliminados = await notificador.depurar(_consulta);
      mensajero.mostrar(
        eliminados == 1
            ? 'Se eliminó 1 registro'
            : 'Se eliminaron ${_miles(eliminados)} registros',
      );
      if (mounted) navegador.pop();
    } on ApiExcepcion catch (e) {
      if (!mounted) return;
      setState(() {
        _eliminando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final resumen = ref.watch(resumenAuditoriaProvider).valueOrNull;
    final confirmado =
        !_sinFiltros ||
        _confirmacion.text.trim().toUpperCase() == _palabraConfirmacion;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      child: Padding(
        padding: EdgeInsets.only(
          left: Dimen.espacio4,
          right: Dimen.espacio4,
          bottom: Dimen.espacio4 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colores.peligro.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Dimen.radioCampo),
                  ),
                  child: const Icon(Icons.delete_sweep_outlined, size: 20, color: Colores.peligro),
                ),
                const SizedBox(width: Dimen.espacio3),
                const Expanded(
                  child: Text(
                    'Depurar auditoría',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colores.tinta,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimen.espacio3),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Conteo(total: _total),
                    const SizedBox(height: Dimen.espacio4),

                    GrupoFiltro<String?>(
                      titulo: 'Usuario',
                      icono: Icons.person_outline,
                      valor: _usuario,
                      opciones: _opciones(resumen?.usuarios, _usuario, 'Todos'),
                      onCambio: (v) => _cambiar(() => _usuario = v),
                    ),
                    const SizedBox(height: Dimen.espacio3),
                    GrupoFiltro<String?>(
                      titulo: 'Entidad',
                      icono: Icons.category_outlined,
                      valor: _entidad,
                      opciones: _opciones(resumen?.entidades, _entidad, 'Todas'),
                      onCambio: (v) => _cambiar(() => _entidad = v),
                    ),
                    const SizedBox(height: Dimen.espacio3),
                    GrupoFiltro<String?>(
                      titulo: 'Acción',
                      icono: Icons.bolt_outlined,
                      valor: _accion,
                      opciones: const [
                        OpcionFiltro<String?>(null, 'Todas'),
                        OpcionFiltro<String?>(AccionAuditoria.creado, 'Creados'),
                        OpcionFiltro<String?>(AccionAuditoria.actualizado, 'Actualizados'),
                        OpcionFiltro<String?>(AccionAuditoria.eliminado, 'Eliminados'),
                      ],
                      onCambio: (v) => _cambiar(() => _accion = v),
                    ),
                    const SizedBox(height: Dimen.espacio3),
                    AppSelectorRango(
                      rango: _rango,
                      primerDia: DateTime(2020),
                      onCambio: (r) => _cambiar(() => _rango = r),
                    ),
                    const SizedBox(height: Dimen.espacio4),

                    if (_sinFiltros) ...[
                      const AppAlerta(
                        'No hay ningún filtro: se borrará toda la bitácora.',
                        tono: AlertaTono.aviso,
                      ),
                      const SizedBox(height: Dimen.espacio3),
                      AppCampo(
                        controlador: _confirmacion,
                        etiqueta: 'Escribe $_palabraConfirmacion para confirmar',
                        habilitado: !_eliminando,
                      ),
                      const SizedBox(height: Dimen.espacio2),
                    ],
                    const Text(
                      'Queda un registro con quién depuró, cuántos y con qué filtros.',
                      style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: Dimen.espacio3),
                      AppAlerta(_error!),
                    ],
                    const SizedBox(height: Dimen.espacio4),
                  ],
                ),
              ),
            ),

            FutureBuilder<int>(
              future: _total,
              builder: (context, instantanea) {
                final total = instantanea.data;

                return AppBoton(
                  texto: total == null
                      ? 'Eliminar'
                      : 'Eliminar ${_miles(total)} ${total == 1 ? 'registro' : 'registros'}',
                  icono: Icons.delete_outline,
                  color: Colores.peligro,
                  cargando: _eliminando,
                  // Sin saber cuántos son —cargando o con error— no se borra:
                  // la persona tiene que ver el número antes de aceptar.
                  onPressed: total != null && total > 0 && confirmado ? _eliminar : null,
                );
              },
            ),
            const SizedBox(height: Dimen.espacio3),
            AppBoton(
              texto: 'Cancelar',
              variante: BotonVariante.secundario,
              onPressed: _eliminando ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  /// La lista de un selector, con "Todos" al principio. Si el valor puesto no
  /// está —la lista de la bitácora todavía no llegó, o la trajo sin ese
  /// valor— se deja a la vista: un selector vacío que sigue recortando borraría
  /// algo distinto de lo que se ve.
  static List<OpcionFiltro<String?>> _opciones(
    List<String>? lista,
    String? valor,
    String todos,
  ) => [
    OpcionFiltro<String?>(null, todos),
    if (valor != null && !(lista?.contains(valor) ?? false)) OpcionFiltro<String?>(valor, valor),
    for (final o in lista ?? const <String>[]) OpcionFiltro<String?>(o, o),
  ];
}

/// Cuántos registros se van a borrar, según el servidor.
class _Conteo extends StatelessWidget {
  const _Conteo({required this.total});

  final Future<int> total;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: total,
      builder: (context, instantanea) {
        if (instantanea.hasError) {
          final e = instantanea.error;
          return AppAlerta(
            e is ApiExcepcion ? e.texto : 'No pudimos contar los registros.',
          );
        }

        final n = instantanea.data;
        if (n == null) {
          return const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: Dimen.espacio2),
              Text(
                'Contando registros...',
                style: TextStyle(fontSize: 13.5, color: Colores.tintaSuave),
              ),
            ],
          );
        }

        return Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 13.5, height: 1.4, color: Colores.tintaSuave),
            children: [
              const TextSpan(text: 'Se eliminarán '),
              TextSpan(
                text: '${_miles(n)} ${n == 1 ? 'registro' : 'registros'}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colores.tinta),
              ),
              const TextSpan(
                text:
                    ' de la bitácora: todos los que cumplen estos filtros, aunque la '
                    'lista no los muestre. No se puede deshacer.',
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 12345 -> 12,345, como se lee en el panel web.
String _miles(int n) => n.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);
