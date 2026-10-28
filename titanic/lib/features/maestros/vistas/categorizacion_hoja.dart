import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/categorizacion.dart';
import '../estado/maestros_controlador.dart';

/// La insignia de la categoría de un cliente: su letra con el color que tenga.
class InsigniaCategoria extends StatelessWidget {
  const InsigniaCategoria({
    super.key,
    required this.codigo,
    this.nombre,
    this.color,
  });

  final String codigo;
  final String? nombre;
  final String? color;

  @override
  Widget build(BuildContext context) {
    final base = colorDeCategoria(color);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        nombre == null || nombre!.isEmpty ? codigo : '$codigo · $nombre',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: base,
        ),
      ),
    );
  }
}

/// Abre la categorización de clientes (Socio, Distribuidor, Mayorista...).
///
/// Quien tiene Editar ajusta el ciclo y los tramos, y calcula. El resto (el
/// vendedor, por ejemplo) ve lo mismo en modo lectura: sin eso, la categoría de
/// sus clientes sería una letra sin significado.
Future<void> mostrarCategorizacion(BuildContext context, WidgetRef ref) {
  final acento = Acento.de(context);
  final puedeEditar = puede(ref, 'crm.categorizacion', Accion.editar);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colores.superficie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(Dimen.radioPanel),
      ),
    ),
    builder: (_) => Acento(
      color: acento,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _HojaCategorizacion(puedeEditar: puedeEditar),
      ),
    ),
  );
}

/// Una categoría mientras se edita: el monto es texto para poder escribirlo sin
/// que se reformatee.
class _Fila {
  _Fila(CategoriaCliente c)
    : codigo = c.codigo,
      color = c.color,
      nombre = TextEditingController(text: c.nombre),
      desde = TextEditingController(text: _entero(c.desde));

  final String codigo;
  String color;
  final TextEditingController nombre;
  final TextEditingController desde;

  static String _entero(double n) =>
      n == n.roundToDouble() ? n.toInt().toString() : n.toString();
}

class _HojaCategorizacion extends ConsumerStatefulWidget {
  const _HojaCategorizacion({required this.puedeEditar});

  final bool puedeEditar;

  @override
  ConsumerState<_HojaCategorizacion> createState() =>
      _HojaCategorizacionState();
}

class _HojaCategorizacionState extends ConsumerState<_HojaCategorizacion> {
  Categorizacion? _datos;
  List<_Fila> _filas = const [];
  CicloCategorizacion _ciclo = CicloCategorizacion.trimestral;
  String? _error;
  bool _guardando = false;
  bool _calculando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _soltar();
    super.dispose();
  }

  void _soltar() {
    for (final f in _filas) {
      f.nombre.dispose();
      f.desde.dispose();
    }
  }

  void _aplicar(Categorizacion c) {
    _soltar();
    setState(() {
      _datos = c;
      _ciclo = c.ciclo;
      _filas = [for (final x in c.categorias) _Fila(x)];
      _error = null;
    });
  }

  Future<void> _cargar() async {
    try {
      _aplicar(await ref.read(maestrosApiProvider).categorizacion());
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos cargar las categorías.');
    }
  }

  /// Valida y guarda lo que se ve. Devuelve lo guardado, o null si no se pudo.
  Future<Categorizacion?> _persistir(Aviso aviso) async {
    final montos = [for (final f in _filas) double.tryParse(f.desde.text)];
    if (montos.any((m) => m == null || m < 0)) {
      aviso.error('Los montos tienen que ser números desde 0.');
      return null;
    }
    if (_filas.any((f) => f.nombre.text.trim().isEmpty)) {
      aviso.error('Toda categoría necesita un nombre.');
      return null;
    }

    try {
      return await ref.read(maestrosApiProvider).guardarCategorizacion({
        'ciclo': _ciclo.clave,
        'categorias': [
          for (var i = 0; i < _filas.length; i++)
            {
              'codigo': _filas[i].codigo,
              'nombre': _filas[i].nombre.text.trim(),
              'color': _filas[i].color,
              'desde': montos[i],
            },
        ],
      });
    } on ApiExcepcion catch (e) {
      aviso.error(e.mensaje);
    } catch (_) {
      aviso.error('No pudimos guardar la configuración.');
    }
    return null;
  }

  /// Las categorías de cada cliente cambiaron: la lista de atrás las vuelve a
  /// pedir.
  void _refrescarClientes() => ref.read(clientesProvider.notifier).recargar();

  Future<void> _guardar() async {
    final aviso = Aviso.de(context);
    final navegador = Navigator.of(context);

    setState(() => _guardando = true);
    final guardado = await _persistir(aviso);
    if (!mounted) return;
    setState(() => _guardando = false);
    if (guardado == null) return;

    aviso.mostrar(
      guardado.recalculado
          ? 'Configuración guardada: las categorías se recalcularon con el '
                'ciclo ${guardado.ciclo.etiqueta.toLowerCase()}.'
          : 'Configuración guardada.',
    );
    if (guardado.recalculado) _refrescarClientes();
    navegador.pop();
  }

  Future<void> _calcular() async {
    final aviso = Aviso.de(context);

    final acepto = await confirmarAccion(
      context,
      titulo: '¿Calcular las categorías ahora?',
      mensaje:
          'Guarda estos montos y asigna a cada cliente su categoría según lo '
          'comprado en el último ciclo cerrado.',
      textoConfirmar: 'Calcular',
    );
    if (!acepto || !mounted) return;

    setState(() => _calculando = true);
    try {
      final guardado = await _persistir(aviso);
      if (guardado == null) return;

      // Si el ciclo cambió, guardar ya recalculó: calcular otra vez sería
      // repetir lo mismo.
      final calculado = guardado.recalculado
          ? guardado
          : await ref.read(maestrosApiProvider).calcularCategorizacion();
      if (!mounted) return;

      _aplicar(calculado);
      aviso.mostrar('Categorías calculadas.');
      _refrescarClientes();
    } on ApiExcepcion catch (e) {
      aviso.error(e.mensaje);
    } catch (_) {
      aviso.error('No pudimos calcular las categorías.');
    } finally {
      if (mounted) setState(() => _calculando = false);
    }
  }

  String _dia(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _monto(double n) => n.round().toString();

  @override
  Widget build(BuildContext context) {
    final datos = _datos;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Dimen.espacio4,
          0,
          Dimen.espacio4,
          Dimen.espacio5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.puedeEditar
                  ? 'Categorización de clientes'
                  : 'Categorías de clientes',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Dimen.espacio3),

            if (_error != null) AppAlerta(_error!),
            if (datos == null && _error == null)
              const Padding(
                padding: EdgeInsets.all(Dimen.espacio6),
                child: Center(child: CircularProgressIndicator()),
              ),

            if (datos != null) ...[
              if (widget.puedeEditar)
                ..._editor(datos)
              else
                Text(
                  'Cada cliente recibe una categoría según el monto total de '
                  'sus compras durante el ${_ciclo.evalua}. La categoría se '
                  'actualiza automáticamente ${_ciclo.renueva}.',
                  style: const TextStyle(color: Colores.tintaSuave),
                ),
              const SizedBox(height: Dimen.espacio4),

              for (var i = 0; i < _filas.length; i++) _tarjeta(i),

              const SizedBox(height: Dimen.espacio2),
              Text(
                widget.puedeEditar
                    ? 'El «hasta» es lo que falta para llegar a la categoría '
                          'de arriba: así los tramos nunca dejan huecos ni se '
                          'pisan. Cambiar el ciclo recalcula las categorías al '
                          'guardar; cambiar los montos, solo al calcular.'
                    : 'Los montos están en soles, con IGV y sin ventas '
                          'anuladas.',
                style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
              ),

              if (widget.puedeEditar) ...[
                const SizedBox(height: Dimen.espacio4),
                AppBoton(
                  texto: 'Calcular ahora',
                  icono: Icons.calculate_outlined,
                  variante: BotonVariante.secundario,
                  cargando: _calculando,
                  onPressed: _guardando ? null : _calcular,
                ),
                const SizedBox(height: Dimen.espacio2),
                AppBoton(
                  texto: 'Guardar configuración',
                  icono: Icons.save_outlined,
                  cargando: _guardando,
                  onPressed: _calculando ? null : _guardar,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// El ciclo y lo que evalúa: solo para quien puede cambiarlos.
  List<Widget> _editor(Categorizacion datos) {
    final periodo = datos.periodos[_ciclo];

    return [
      const Text(
        'CICLO DE ACTUALIZACIÓN',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colores.tintaSuave,
        ),
      ),
      const SizedBox(height: Dimen.espacio2),
      Wrap(
        spacing: Dimen.espacio2,
        children: [
          for (final c in CicloCategorizacion.values)
            ChoiceChip(
              label: Text(c.etiqueta),
              selected: _ciclo == c,
              onSelected: (_) => setState(() => _ciclo = c),
            ),
        ],
      ),
      const SizedBox(height: Dimen.espacio3),
      _dato(
        'Compras evaluadas (${_ciclo.etiqueta.toLowerCase()})',
        periodo == null
            ? '—'
            : '${_dia(periodo.evaluadoDesde)} – ${_dia(periodo.evaluadoHasta)}',
      ),
      const SizedBox(height: Dimen.espacio2),
      _dato(
        'Fecha en que cambiará el resultado',
        periodo == null
            ? '—'
            : _dia(periodo.vigenteHasta.add(const Duration(days: 1))),
        nota: periodo == null
            ? null
            : 'El actual rige desde el ${_dia(periodo.vigenteDesde)}',
      ),
    ];
  }

  Widget _dato(String etiqueta, String valor, {String? nota}) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: Dimen.espacio3,
      vertical: Dimen.espacio2,
    ),
    decoration: BoxDecoration(
      border: Border.all(color: Colores.linea),
      borderRadius: BorderRadius.circular(Dimen.radioCampo),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colores.tintaSuave,
          ),
        ),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (nota != null)
          Text(
            nota,
            style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
          ),
      ],
    ),
  );

  /// Una categoría: su nombre y color, y el tramo de soles que cubre.
  Widget _tarjeta(int i) {
    final fila = _filas[i];
    final arriba = i == 0 ? null : double.tryParse(_filas[i - 1].desde.text);
    final hasta = arriba == null ? null : arriba - 1;
    final ultima = i == _filas.length - 1;

    final Widget cabecera = widget.puedeEditar
        ? Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: colorDeCategoria(fila.color),
                child: Text(
                  fila.codigo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: Dimen.espacio3),
              Expanded(
                child: TextField(
                  controller: fila.nombre,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    isDense: true,
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: Dimen.espacio2),
              DropdownButton<String>(
                value: fila.color,
                underline: const SizedBox.shrink(),
                onChanged: (v) => setState(() => fila.color = v ?? fila.color),
                items: [
                  for (final e in coloresCategoria.entries)
                    DropdownMenuItem(
                      value: e.key,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 7,
                            backgroundColor: e.value.color,
                          ),
                          const SizedBox(width: 6),
                          Text(e.value.etiqueta),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          )
        : Row(
            children: [
              InsigniaCategoria(
                codigo: fila.codigo,
                nombre: fila.nombre.text,
                color: fila.color,
              ),
              const Spacer(),
              Text(
                '${datos!.categorias[i].clientes} clientes',
                style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
              ),
            ],
          );

    return Container(
      margin: const EdgeInsets.only(bottom: Dimen.espacio2),
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cabecera,
          const SizedBox(height: Dimen.espacio2),
          Row(
            children: [
              Expanded(
                child: widget.puedeEditar
                    ? TextField(
                        controller: fila.desde,
                        // La última arranca en cero: así nadie queda sin
                        // categoría.
                        enabled: !ultima,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Desde (S/)',
                          isDense: true,
                        ),
                      )
                    : Text(
                        'Desde S/ ${_monto(double.tryParse(fila.desde.text) ?? 0)}',
                      ),
              ),
              const SizedBox(width: Dimen.espacio3),
              Expanded(
                child: Text(
                  hasta == null ? 'Hasta A MÁS' : 'Hasta S/ ${_monto(hasta)}',
                  textAlign: widget.puedeEditar
                      ? TextAlign.start
                      : TextAlign.end,
                  style: const TextStyle(color: Colores.tintaSuave),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Categorizacion? get datos => _datos;
}
