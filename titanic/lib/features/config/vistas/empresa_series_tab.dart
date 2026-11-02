import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/config_modelos.dart';
import '../estado/config_controlador.dart';

/// Las series de comprobantes de la empresa y hasta qué número llegó cada una.
///
/// El último número se escribe a mano porque quien ya venía facturando (con otro sistema o con la plataforma de SUNAT)
/// tiene que continuar desde donde iba: el próximo comprobante sale con ese número más uno.
class EmpresaSeriesTab extends ConsumerStatefulWidget {
  const EmpresaSeriesTab({
    super.key,
    required this.empresaId,
    required this.puedeEditar,
  });

  final int empresaId;
  final bool puedeEditar;

  @override
  ConsumerState<EmpresaSeriesTab> createState() => _EmpresaSeriesTabState();
}

class _EmpresaSeriesTabState extends ConsumerState<EmpresaSeriesTab> {
  List<SerieCpe>? _series;
  String? _error;

  // La serie nueva.
  String _tipo = '01';
  String _aplicaA = '01';
  final _serie = TextEditingController();
  final _ultimo = TextEditingController(text: '0');
  bool _agregando = false;

  bool get _esNota => _tipo == '07' || _tipo == '08';

  /// La letra con la que SUNAT exige que empiece la serie.
  String get _letra => _esNota
      ? (_aplicaA == '03' ? 'B' : 'F')
      : (_tipo == '03' ? 'B' : 'F');

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _serie.dispose();
    _ultimo.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final lista = await ref
          .read(configApiProvider)
          .series(widget.empresaId);
      if (mounted) {
        setState(() {
          _series = lista;
          _error = null;
        });
      }
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.texto);
    }
  }

  Future<void> _agregar() async {
    final mensajero = Aviso.de(context);
    setState(() => _agregando = true);
    try {
      final creada = await ref.read(configApiProvider).crearSerie(
        widget.empresaId,
        {
          'tipo': _tipo,
          'serie': _serie.text.trim().toUpperCase(),
          'aplicaA': _esNota ? _aplicaA : null,
          'ultimoNumero': int.tryParse(_ultimo.text.trim()) ?? 0,
          'activa': true,
        },
      );
      _serie.clear();
      _ultimo.text = '0';
      mensajero.mostrar('Serie ${creada.serie} creada');
      await _cargar();
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    } finally {
      if (mounted) setState(() => _agregando = false);
    }
  }

  Future<void> _estandar() async {
    final mensajero = Aviso.de(context);
    try {
      final lista = await ref
          .read(configApiProvider)
          .crearSeriesEstandar(widget.empresaId);
      if (mounted) setState(() => _series = lista);
      mensajero.mostrar('Series estándar creadas');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  Future<void> _guardar(SerieCpe s, Map<String, dynamic> cuerpo) async {
    final mensajero = Aviso.de(context);
    try {
      final guardada = await ref
          .read(configApiProvider)
          .actualizarSerie(widget.empresaId, s.id, cuerpo);
      mensajero.mostrar('Serie ${guardada.serie} guardada');
      await _cargar();
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  Future<void> _eliminar(SerieCpe s) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Eliminar la serie ${s.serie}',
      mensaje:
          'Se quita la serie. Solo se puede si todavía no emitió ningún comprobante.',
      textoConfirmar: 'Eliminar',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref
          .read(configApiProvider)
          .eliminarSerie(widget.empresaId, s.id);
      mensajero.mostrar('Serie ${s.serie} eliminada');
      await _cargar();
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  @override
  Widget build(BuildContext context) {
    final series = _series;

    return ListView(
      padding: const EdgeInsets.all(Dimen.espacio4),
      children: [
        const Text(
          'Cada serie lleva su propia numeración. Si la empresa ya emitía comprobantes, escribe en «Último número» el '
          'último que usó: el siguiente saldrá con ese número más uno. Si hay varias series activas del mismo '
          'documento, se usa la primera.',
          style: TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
        ),
        const SizedBox(height: Dimen.espacio4),
        if (_error != null) ...[
          AppAlerta(_error!),
          const SizedBox(height: Dimen.espacio4),
        ],
        if (series == null && _error == null)
          const Padding(
            padding: EdgeInsets.all(Dimen.espacio6),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (series != null && series.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Dimen.espacio4),
            child: Text(
              'Esta empresa todavía no tiene series: agrégalas abajo o crea las estándar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
            ),
          )
        else if (series != null)
          for (final s in series)
            _FilaSerie(
              key: ValueKey('${s.id}-${s.ultimoNumero}-${s.activa}'),
              serie: s,
              puedeEditar: widget.puedeEditar,
              onGuardar: (cuerpo) => _guardar(s, cuerpo),
              onEliminar: () => _eliminar(s),
            ),
        if (widget.puedeEditar) ...[
          const SizedBox(height: Dimen.espacio4),
          Container(
            padding: const EdgeInsets.all(Dimen.espacio3),
            decoration: BoxDecoration(
              border: Border.all(color: Colores.linea),
              borderRadius: BorderRadius.circular(Dimen.radioCampo),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Agregar una serie',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: Dimen.espacio3),
                AppSelector<String>(
                  valor: _tipo,
                  etiqueta: 'Documento',
                  icono: Icons.description_outlined,
                  opciones: const [
                    Opcion('01', 'Factura'),
                    Opcion('03', 'Boleta'),
                    Opcion('07', 'Nota de crédito'),
                    Opcion('08', 'Nota de débito'),
                  ],
                  onCambio: (v) => setState(() => _tipo = v ?? _tipo),
                ),
                if (_esNota) ...[
                  const SizedBox(height: Dimen.espacio3),
                  AppSelector<String>(
                    valor: _aplicaA,
                    etiqueta: 'Corrige',
                    icono: Icons.rule_outlined,
                    opciones: const [
                      Opcion('01', 'Facturas'),
                      Opcion('03', 'Boletas'),
                    ],
                    onCambio: (v) => setState(() => _aplicaA = v ?? _aplicaA),
                  ),
                ],
                const SizedBox(height: Dimen.espacio3),
                Row(
                  children: [
                    Expanded(
                      child: AppCampo(
                        controlador: _serie,
                        etiqueta: 'Serie',
                        pista: '${_letra}001',
                        maxLargo: 4,
                        formateadores: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9]'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Dimen.espacio3),
                    Expanded(
                      child: AppCampo(
                        controlador: _ultimo,
                        etiqueta: 'Último número',
                        tipoTeclado: TextInputType.number,
                        formateadores: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Dimen.espacio2),
                Text(
                  'Empieza con $_letra: así lo exige SUNAT para este documento.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colores.tintaSuave,
                  ),
                ),
                const SizedBox(height: Dimen.espacio3),
                Row(
                  children: [
                    Expanded(
                      child: AppBoton(
                        texto: 'Series estándar',
                        variante: BotonVariante.secundario,
                        onPressed: _estandar,
                      ),
                    ),
                    const SizedBox(width: Dimen.espacio2),
                    Expanded(
                      child: AppBoton(
                        texto: 'Agregar',
                        cargando: _agregando,
                        onPressed: _serie.text.trim().length == 4
                            ? _agregar
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Una serie con su último número editable, su estado y sus botones de guardar y eliminar.
class _FilaSerie extends StatefulWidget {
  const _FilaSerie({
    super.key,
    required this.serie,
    required this.puedeEditar,
    required this.onGuardar,
    required this.onEliminar,
  });

  final SerieCpe serie;
  final bool puedeEditar;
  final ValueChanged<Map<String, dynamic>> onGuardar;
  final VoidCallback onEliminar;

  @override
  State<_FilaSerie> createState() => _FilaSerieState();
}

class _FilaSerieState extends State<_FilaSerie> {
  late final _serie = TextEditingController(text: widget.serie.serie);
  late final _ultimo = TextEditingController(
    text: '${widget.serie.ultimoNumero}',
  );
  late bool _activa = widget.serie.activa;

  @override
  void dispose() {
    _serie.dispose();
    _ultimo.dispose();
    super.dispose();
  }

  bool get _sucia =>
      _serie.text.trim().toUpperCase() != widget.serie.serie ||
      (int.tryParse(_ultimo.text.trim()) ?? -1) != widget.serie.ultimoNumero ||
      _activa != widget.serie.activa;

  @override
  Widget build(BuildContext context) {
    final s = widget.serie;
    final corrige = s.aplicaA == null
        ? ''
        : ' · de ${s.aplicaA == '01' ? 'facturas' : 'boletas'}';

    return Container(
      margin: const EdgeInsets.only(bottom: Dimen.espacio3),
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${SerieCpe.nombreTipo(s.tipo)}$corrige',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${s.emitidos} emitidos',
                style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
              ),
            ],
          ),
          const SizedBox(height: Dimen.espacio3),
          Row(
            children: [
              Expanded(
                child: AppCampo(
                  controlador: _serie,
                  etiqueta: 'Serie',
                  maxLargo: 4,
                  // El nombre de una serie que ya emitio no se toca.
                  habilitado: widget.puedeEditar && s.emitidos == 0,
                  formateadores: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  ],
                  alEnviar: () => setState(() {}),
                ),
              ),
              const SizedBox(width: Dimen.espacio3),
              Expanded(
                child: AppCampo(
                  controlador: _ultimo,
                  etiqueta: 'Último número',
                  habilitado: widget.puedeEditar,
                  tipoTeclado: TextInputType.number,
                  formateadores: [FilteringTextInputFormatter.digitsOnly],
                  alEnviar: () => setState(() {}),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Activa', style: TextStyle(fontSize: 13)),
                  value: _activa,
                  onChanged: widget.puedeEditar
                      ? (v) => setState(() => _activa = v)
                      : null,
                ),
              ),
              if (widget.puedeEditar) ...[
                IconButton(
                  tooltip: 'Eliminar',
                  onPressed: s.emitidos > 0 ? null : widget.onEliminar,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colores.peligro,
                ),
                AppBoton(
                  texto: 'Guardar',
                  expandido: false,
                  tam: BotonTam.md,
                  onPressed: () {
                    // Se revisa al tocar: el campo no avisa de cada tecla.
                    if (!_sucia) return;
                    widget.onGuardar({
                      'tipo': s.tipo,
                      'serie': _serie.text.trim().toUpperCase(),
                      'aplicaA': s.aplicaA,
                      'ultimoNumero': int.tryParse(_ultimo.text.trim()) ?? 0,
                      'activa': _activa,
                    });
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
