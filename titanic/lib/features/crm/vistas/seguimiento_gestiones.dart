import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/fechas.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_botones_formulario.dart';
import '../../../compartido/widgets/app_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/crm.dart';
import '../estado/crm_controlador.dart';
import 'crm_comun.dart';

const _submodulo = 'crm.seguimiento';

/// La hora que se propone para el siguiente contacto.
const _horaPorDefecto = TimeOfDay(hour: 10, minute: 0);

/// "2026-10-30T10:00:00": hora de Perú, sin zona, como la pide el servidor.
String _aIso(DateTime dia, TimeOfDay hora) =>
    '${diaIso(dia)}T${hora.hour.toString().padLeft(2, '0')}:'
    '${hora.minute.toString().padLeft(2, '0')}:00';

/// La pestaña Seguimiento: lo último que se habló, lo que queda programado y el
/// historial de gestiones.
class TabSeguimiento extends ConsumerWidget {
  const TabSeguimiento({super.key, required this.clienteId});

  final int clienteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(gestionesClienteProvider(clienteId));
    final puedeEditar = puede(ref, _submodulo, Accion.editar);

    return datos.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(Dimen.espacio6),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppAlerta(
        e is ApiExcepcion ? e.mensaje : 'No pudimos cargar las gestiones.',
      ),
      data: (d) {
        final ultima = d.items.firstOrNull;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DatoRecuadro(
                    'Último contacto',
                    ultima == null ? '—' : fechaDia(ultima.fecha),
                    nota: ultima == null
                        ? 'sin gestiones'
                        : '${ultima.tipoEtiqueta} · ${ultima.resultadoEtiqueta}',
                  ),
                ),
                const SizedBox(width: Dimen.espacio2),
                Expanded(
                  child: DatoRecuadro(
                    'Próxima gestión',
                    d.proximaGestion?.proximoSeguimiento == null
                        ? '—'
                        : fechaDia(d.proximaGestion!.proximoSeguimiento),
                    color: d.proximaGestion?.vencida == true
                        ? Colores.peligro
                        : null,
                    nota: d.proximaGestion == null
                        ? 'sin contacto programado'
                        : d.proximaGestion!.proximaAccion ?? 'programada',
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimen.espacio2),
            DatoRecuadro('Gestiones del año', '${d.totalAnio}'),
            const SizedBox(height: Dimen.espacio4),
            const Text(
              'Historial de gestiones',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Dimen.espacio2),
            if (d.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Dimen.espacio3),
                child: Text(
                  'Todavía no hay gestiones con este cliente.',
                  style: TextStyle(color: Colores.tintaSuave),
                ),
              ),
            for (final g in d.items)
              _TarjetaGestion(
                gestion: g,
                clienteId: clienteId,
                puedeEditar: puedeEditar,
              ),
          ],
        );
      },
    );
  }
}

class _TarjetaGestion extends ConsumerWidget {
  const _TarjetaGestion({
    required this.gestion,
    required this.clienteId,
    required this.puedeEditar,
  });

  final Gestion gestion;
  final int clienteId;
  final bool puedeEditar;

  Future<void> _reprogramar(BuildContext context, WidgetRef ref) async {
    final aviso = Aviso.de(context);
    final api = ref.read(crmApiProvider);
    final actual = gestion.proximoSeguimiento ?? DateTime.now();
    final hoy = DateTime.now();

    final dia = await showDatePicker(
      context: context,
      initialDate: actual.isBefore(hoy) ? hoy : actual,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: DateTime(hoy.year + 2),
      helpText: 'Nueva fecha del contacto',
    );
    if (dia == null || !context.mounted) return;

    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(actual),
    );
    if (hora == null) return;

    try {
      await api.reprogramar(gestion.id, _aIso(dia, hora));
      ref.invalidate(gestionesClienteProvider(clienteId));
      ref.invalidate(fichaClienteProvider(clienteId));
      aviso.mostrar('Contacto reprogramado.');
    } on ApiExcepcion catch (e) {
      aviso.error(e.mensaje);
    } catch (_) {
      aviso.error('No pudimos reprogramar el contacto.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = gestion;
    final tono = colorDeTono(g.tono);

    return Container(
      margin: const EdgeInsets.only(bottom: Dimen.espacio2),
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                g.tipoContacto?.icono ?? Icons.chat_outlined,
                size: 18,
                color: tono,
              ),
              const SizedBox(width: Dimen.espacio2),
              Expanded(
                child: Text(
                  g.resultadoEtiqueta,
                  style: TextStyle(fontWeight: FontWeight.w700, color: tono),
                ),
              ),
              Text(
                fechaHora(g.fecha),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Colores.tintaSuave,
                ),
              ),
            ],
          ),
          Text(
            '${g.tipoEtiqueta}${g.registradoPor == null ? '' : ' · ${g.registradoPor}'}',
            style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
          ),
          if (g.comentario != null && g.comentario!.trim().isNotEmpty) ...[
            const SizedBox(height: Dimen.espacio1),
            Text(g.comentario!, style: const TextStyle(fontSize: 13)),
          ],
          if (g.proximoSeguimiento != null) ...[
            const SizedBox(height: Dimen.espacio2),
            Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 16,
                  color: g.vencida ? Colores.peligro : Colores.tintaSuave,
                ),
                const SizedBox(width: Dimen.espacio1),
                Expanded(
                  child: Text(
                    '${fechaHora(g.proximoSeguimiento!)}'
                    '${g.proximoTipoContacto == null ? '' : ' · ${g.proximoTipoContacto!.etiqueta}'}'
                    '${g.proximaAccion == null ? '' : ' · ${g.proximaAccion}'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: g.vencida ? Colores.peligro : Colores.tinta,
                    ),
                  ),
                ),
                AppEtiqueta(
                  g.programado
                      ? (g.vencida ? 'Vencido' : 'Programado')
                      : 'Cumplido',
                  tono: g.programado
                      ? (g.vencida ? EtiquetaTono.peligro : EtiquetaTono.aviso)
                      : EtiquetaTono.exito,
                ),
              ],
            ),
          ],
          if (puedeEditar && g.programado) ...[
            const SizedBox(height: Dimen.espacio1),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _reprogramar(context, ref),
                  icon: const Icon(Icons.update, size: 16),
                  label: const Text('Reprogramar'),
                ),
                TextButton.icon(
                  onPressed: () => mostrarFormularioGestion(
                    context,
                    clienteId: clienteId,
                    editar: g,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editar'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- Formulario

/// La hoja para registrar una gestión, o editar la programada: cómo se contactó,
/// qué resultó y, si hace falta, cuándo y cómo será el siguiente contacto.
Future<void> mostrarFormularioGestion(
  BuildContext context, {
  required int clienteId,
  Gestion? editar,
}) => abrirHoja<void>(
  context,
  (_) => _FormularioGestion(clienteId: clienteId, editar: editar),
);

class _FormularioGestion extends ConsumerStatefulWidget {
  const _FormularioGestion({required this.clienteId, this.editar});

  final int clienteId;
  final Gestion? editar;

  @override
  ConsumerState<_FormularioGestion> createState() => _FormularioGestionState();
}

class _FormularioGestionState extends ConsumerState<_FormularioGestion> {
  final _comentario = TextEditingController();
  final _accion = TextEditingController();

  TipoContacto _tipo = TipoContacto.llamada;
  String? _resultado;
  bool _programar = false;
  TipoContacto _tipoProximo = TipoContacto.llamada;
  DateTime? _dia;
  TimeOfDay _hora = _horaPorDefecto;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final g = widget.editar;
    if (g != null) {
      _tipo = g.tipoContacto ?? TipoContacto.llamada;
      _resultado = g.resultado;
      _comentario.text = g.comentario ?? '';
      if (g.proximoSeguimiento != null) {
        _programar = true;
        _tipoProximo = g.proximoTipoContacto ?? TipoContacto.llamada;
        _dia = g.proximoSeguimiento;
        _hora = TimeOfDay.fromDateTime(g.proximoSeguimiento!);
        _accion.text = g.proximaAccion ?? '';
      }
    }
  }

  @override
  void dispose() {
    _comentario.dispose();
    _accion.dispose();
    super.dispose();
  }

  Future<void> _elegirDia() async {
    final hoy = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _dia ?? hoy,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: DateTime(hoy.year + 2),
      helpText: 'Fecha del próximo contacto',
    );
    if (d != null) setState(() => _dia = d);
  }

  Future<void> _elegirHora() async {
    final h = await showTimePicker(context: context, initialTime: _hora);
    if (h != null) setState(() => _hora = h);
  }

  Future<void> _guardar() async {
    if (_resultado == null) {
      setState(() => _error = 'Elige el resultado de la gestión.');
      return;
    }
    if (_programar && _dia == null) {
      setState(() => _error = 'Elige la fecha del próximo contacto.');
      return;
    }

    final aviso = Aviso.de(context);
    final navegador = Navigator.of(context);
    final api = ref.read(crmApiProvider);
    final comentario = _comentario.text.trim();
    final accion = _accion.text.trim();

    final cuerpo = <String, dynamic>{
      'tipoContacto': _tipo.clave,
      'resultado': _resultado,
      if (comentario.isNotEmpty) 'comentario': comentario,
      if (_programar) ...{
        'proximoSeguimiento': _aIso(_dia!, _hora),
        'proximoTipoContacto': _tipoProximo.clave,
        if (accion.isNotEmpty) 'proximaAccion': accion,
      },
    };

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final editando = widget.editar;
      if (editando == null) {
        await api.registrar(widget.clienteId, cuerpo);
      } else {
        await api.actualizar(editando.id, cuerpo);
      }
      ref.invalidate(gestionesClienteProvider(widget.clienteId));
      ref.invalidate(fichaClienteProvider(widget.clienteId));
      aviso.mostrar(
        editando == null ? 'Gestión registrada.' : 'Gestión actualizada.',
      );
      navegador.pop();
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos guardar la gestión.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _chipsTipo(TipoContacto valor, ValueChanged<TipoContacto> alCambiar) =>
      Wrap(
        spacing: Dimen.espacio2,
        children: [
          for (final t in TipoContacto.values)
            ChoiceChip(
              avatar: Icon(t.icono, size: 16),
              label: Text(t.etiqueta),
              selected: valor == t,
              onSelected: _guardando ? null : (_) => alCambiar(t),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final catalogo = ref.watch(catalogoSeguimientoProvider);
    final resultados = catalogo.valueOrNull?.resultados ?? const [];
    final elegido = resultados.where((r) => r.clave == _resultado).firstOrNull;

    return HojaBase(
      titulo: widget.editar == null ? 'Registrar gestión' : 'Editar gestión',
      pie: AppBotonesFormulario(
        onCancelar: () => Navigator.of(context).pop(),
        onGuardar: _guardar,
        textoGuardar: _programar ? 'Guardar y programar' : 'Guardar gestión',
        cargando: _guardando,
      ),
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AppAlerta(_error!),
            const SizedBox(height: Dimen.espacio3),
          ],

          const Text(
            'Tipo de contacto',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Dimen.espacio2),
          _chipsTipo(_tipo, (t) => setState(() => _tipo = t)),
          const SizedBox(height: Dimen.espacio4),

          DropdownButtonFormField<String>(
            initialValue: _resultado,
            decoration: const InputDecoration(labelText: 'Resultado'),
            items: [
              for (final r in resultados)
                DropdownMenuItem(
                  value: r.clave,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 5,
                        backgroundColor: colorDeTono(r.tono),
                      ),
                      const SizedBox(width: Dimen.espacio2),
                      Text(r.etiqueta),
                    ],
                  ),
                ),
            ],
            onChanged: _guardando
                ? null
                : (v) => setState(() => _resultado = v),
          ),
          if (elegido != null)
            Padding(
              padding: const EdgeInsets.only(top: Dimen.espacio1),
              child: Text(
                elegido.cuando,
                style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
              ),
            ),
          const SizedBox(height: Dimen.espacio3),

          TextField(
            controller: _comentario,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            enabled: !_guardando,
            decoration: const InputDecoration(
              labelText: 'Comentario',
              hintText: 'Escribe un breve comentario...',
            ),
          ),
          const SizedBox(height: Dimen.espacio2),

          // Material y no Container con fondo: el Switch de adentro pinta sus
          // efectos sobre el Material más cercano.
          Material(
            color: Acento.de(context).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(Dimen.radioCampo),
            child: Padding(
              padding: const EdgeInsets.all(Dimen.espacio3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _programar,
                    onChanged: _guardando
                        ? null
                        : (v) => setState(() => _programar = v),
                    title: const Text('¿Programar el próximo contacto?'),
                    subtitle: const Text(
                      'Define cómo y cuándo volverás a hablar con él.',
                    ),
                  ),
                  if (_programar) ...[
                    const SizedBox(height: Dimen.espacio2),
                    _chipsTipo(
                      _tipoProximo,
                      (t) => setState(() => _tipoProximo = t),
                    ),
                    const SizedBox(height: Dimen.espacio3),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _guardando ? null : _elegirDia,
                            icon: const Icon(Icons.event_outlined, size: 18),
                            label: Text(
                              _dia == null ? 'Fecha' : fechaDia(_dia),
                            ),
                          ),
                        ),
                        const SizedBox(width: Dimen.espacio2),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _guardando ? null : _elegirHora,
                            icon: const Icon(Icons.schedule, size: 18),
                            label: Text(_hora.format(context)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Dimen.espacio3),
                    TextField(
                      controller: _accion,
                      maxLength: 200,
                      enabled: !_guardando,
                      decoration: const InputDecoration(
                        labelText: 'Acción a realizar',
                        hintText: 'Ej.: Enviar cotización',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
