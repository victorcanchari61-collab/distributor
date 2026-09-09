import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_campo_cliente.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../maestros/datos/cliente.dart';
import '../../maestros/estado/maestros_controlador.dart';
import '../datos/arqueo.dart';
import '../datos/metodo_pago.dart';
import '../estado/arqueo_controlador.dart';
import '../estado/finanzas_controlador.dart';
import 'arqueo_pagina.dart';

/// Un gasto de la ruta mientras se está escribiendo el cuadre.
class _Gasto {
  const _Gasto({
    required this.motivoGastoId,
    required this.motivo,
    required this.monto,
    this.descripcion,
  });

  final int motivoGastoId;
  final String motivo;
  final double monto;
  final String? descripcion;
}

/// Un pago digital declarado mientras se está escribiendo el cuadre.
class _PagoDigital {
  const _PagoDigital({
    required this.metodoPagoId,
    required this.metodo,
    required this.monto,
    this.clienteId,
    this.cliente,
    this.numeroOperacion,
  });

  final int? clienteId;
  final String? cliente;
  final int metodoPagoId;
  final String metodo;
  final String? numeroOperacion;
  final double monto;
}

/// El cuadre de una persona en un día.
///
/// Es pantalla propia y no hoja modal: entre los cobros del sistema, el
/// efectivo, los gastos y los pagos digitales no hay hoja que quepa en un
/// móvil sin dejar la mitad del cuadre fuera de la vista.
class CuadrePagina extends ConsumerStatefulWidget {
  const CuadrePagina({super.key, required this.fecha, required this.usuarioId});

  final DateTime fecha;
  final int usuarioId;

  @override
  ConsumerState<CuadrePagina> createState() => _CuadrePaginaState();
}

class _CuadrePaginaState extends ConsumerState<CuadrePagina> {
  final _billetes = TextEditingController();
  final _monedas = TextEditingController();
  final _observacion = TextEditingController();

  final _gastos = <_Gasto>[];
  final _pagos = <_PagoDigital>[];

  /// Lo declarado solo se copia a los campos una vez: si se volviera a copiar
  /// en cada build, cada tecleo se perderia al recargar el detalle.
  bool _precargado = false;

  bool _guardando = false;
  String? _error;

  ClaveCuadre get _clave => (fecha: widget.fecha, usuarioId: widget.usuarioId);

  @override
  void dispose() {
    _billetes.dispose();
    _monedas.dispose();
    _observacion.dispose();
    super.dispose();
  }

  double get _billetesNum => _aNumero(_billetes.text);
  double get _monedasNum => _aNumero(_monedas.text);
  double get _totalGastos => _gastos.fold(0, (n, g) => n + g.monto);
  double get _totalDigital => _pagos.fold(0, (n, p) => n + p.monto);

  static double _aNumero(String texto) =>
      double.tryParse(texto.trim().replaceAll(',', '.')) ?? 0;

  void _precargar(DetalleCuadre detalle) {
    if (_precargado) return;
    _precargado = true;

    final arqueo = detalle.arqueo;
    if (arqueo == null) return;

    _billetes.text = arqueo.billetes == 0 ? '' : formatoNumero(arqueo.billetes);
    _monedas.text = arqueo.monedas == 0 ? '' : formatoNumero(arqueo.monedas);
    _observacion.text = arqueo.observacion ?? '';

    _gastos
      ..clear()
      ..addAll([
        for (final g in arqueo.gastos)
          _Gasto(
            motivoGastoId: g.motivoGastoId,
            motivo: g.motivoGasto,
            monto: g.monto,
            descripcion: g.descripcion,
          ),
      ]);

    _pagos
      ..clear()
      ..addAll([
        for (final p in arqueo.pagosDigitales)
          _PagoDigital(
            clienteId: p.clienteId,
            cliente: p.cliente,
            metodoPagoId: p.metodoPagoId,
            metodo: p.metodoPago,
            numeroOperacion: p.numeroOperacion,
            monto: p.monto,
          ),
      ]);
  }

  Future<void> _agregarGasto() async {
    final motivos = ref.read(motivosGastoActivosProvider);
    if (motivos.isEmpty) {
      setState(
        () => _error =
            'No hay motivos de gasto en el catálogo. Créalos antes de declarar gastos.',
      );
      return;
    }

    final gasto = await showModalBottomSheet<_Gasto>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colores.superficie,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Dimen.radioPanel),
        ),
      ),
      builder: (_) => _HojaGasto(motivos: motivos),
    );

    if (gasto != null) setState(() => _gastos.add(gasto));
  }

  Future<void> _agregarPago() async {
    // Solo los que no son efectivo: un pago digital declarado con método
    // "efectivo" cuadraria contra el lado equivocado.
    final metodos = ref
        .read(metodosPagoActivosProvider)
        .where((m) => m.tipo != TipoMetodoPago.efectivo)
        .toList();

    if (metodos.isEmpty) {
      setState(
        () => _error =
            'No hay métodos de pago digitales activos. Actívalos en Métodos de pago.',
      );
      return;
    }

    final clientes =
        ref.read(clientesProvider).valueOrNull ?? const <Cliente>[];

    final pago = await showModalBottomSheet<_PagoDigital>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colores.superficie,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Dimen.radioPanel),
        ),
      ),
      builder: (_) => _HojaPagoDigital(metodos: metodos, clientes: clientes),
    );

    if (pago != null) setState(() => _pagos.add(pago));
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _guardando = true;
      _error = null;
    });

    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);

    try {
      final arqueo = await registrarCuadre(ref, {
        'fecha': widget.fecha.toIso8601String().substring(0, 10),
        'usuarioId': widget.usuarioId,
        'billetes': _billetesNum,
        'monedas': _monedasNum,
        'observacion': _observacion.text.trim().isEmpty
            ? null
            : _observacion.text.trim(),
        'gastos': [
          for (final g in _gastos)
            {
              'motivoGastoId': g.motivoGastoId,
              'monto': g.monto,
              'descripcion': g.descripcion,
            },
        ],
        'pagosDigitales': [
          for (final p in _pagos)
            {
              'clienteId': p.clienteId,
              'metodoPagoId': p.metodoPagoId,
              'numeroOperacion': p.numeroOperacion,
              'monto': p.monto,
            },
        ],
      });

      navegador.pop();
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            arqueo.faltante > 0
                ? 'Cuadre guardado. Queda una deuda de ${formatoSoles(arqueo.faltante)}.'
                : 'Cuadre guardado',
          ),
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
    final detalleAsync = ref.watch(detalleCuadreProvider(_clave));

    // Su propio Scaffold: no cuelga de AppShell, asi que declara aqui el
    // acento del modulo.
    return Acento.modulo(
      'finanzas',
      (context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Cuadre del día',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1),
          ),
        ),
        body: detalleAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(Dimen.espacio4),
              child: AppAlerta(
                e is ApiExcepcion ? e.texto : 'No pudimos cargar el detalle.',
              ),
            ),
          ),
          data: (detalle) {
            _precargar(detalle);
            return _formulario(context, detalle);
          },
        ),
      ),
    );
  }

  Widget _formulario(BuildContext context, DetalleCuadre detalle) {
    final color = Acento.de(context);

    final efectivoReal = _billetesNum + _monedasNum + _totalGastos;
    final difEfectivo = efectivoReal - detalle.efectivoSistema;
    final difBancos = _totalDigital - detalle.bancosSistema;

    // Los faltantes de cada lado se suman sin dejar que un sobrante compense,
    // igual que en el backend: un Yape que no llegó es dinero perdido aunque
    // ese día trajera efectivo de más.
    final faltante =
        (difEfectivo < 0 ? -difEfectivo : 0.0) +
        (difBancos < 0 ? -difBancos : 0.0);
    final sobrante =
        (difEfectivo > 0 ? difEfectivo : 0.0) +
        (difBancos > 0 ? difBancos : 0.0);

    return ListView(
      padding: const EdgeInsets.all(Dimen.espacio4),
      children: [
        _Cabecera(detalle: detalle, color: color),
        const SizedBox(height: Dimen.espacio4),

        if (_error != null) ...[
          AppAlerta(_error!),
          const SizedBox(height: Dimen.espacio4),
        ],

        // Sin ver de quién se cobró no hay forma de encontrar el faltante:
        // esta lista es la que se repasa con la persona delante.
        _Seccion(
          titulo: 'Cobros en efectivo',
          nota: 'Lo que el sistema dice que cobró',
          hijos: [
            if (detalle.efectivo.isEmpty)
              const _Vacio('No hay cobros en efectivo ese día.')
            else
              for (final c in detalle.efectivo) _FilaCobro(cobro: c),
            const Divider(height: Dimen.espacio5),
            _FilaTotal(
              etiqueta: 'Total del sistema',
              valor: detalle.efectivoSistema,
              color: color,
            ),
          ],
        ),
        const SizedBox(height: Dimen.espacio4),

        _Seccion(
          titulo: 'Efectivo que trae',
          hijos: [
            AppCampo(
              controlador: _billetes,
              etiqueta: 'Billetes',
              pista: '0.00',
              icono: Icons.payments_outlined,
              tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
              habilitado: !_guardando,
              alEnviar: () => setState(() {}),
            ),
            const SizedBox(height: Dimen.espacio3),
            AppCampo(
              controlador: _monedas,
              etiqueta: 'Monedas',
              pista: '0.00',
              icono: Icons.toll_outlined,
              tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
              habilitado: !_guardando,
              alEnviar: () => setState(() {}),
            ),
            const SizedBox(height: Dimen.espacio2),
            // Los montos se teclean pero la diferencia solo se recalcula al
            // refrescar: este botón evita tener que cerrar el teclado a ciegas.
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _guardando
                    ? null
                    : () {
                        FocusScope.of(context).unfocus();
                        setState(() {});
                      },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Recalcular'),
              ),
            ),
          ],
        ),
        const SizedBox(height: Dimen.espacio4),

        _Seccion(
          titulo: 'Gastos de la ruta',
          nota: 'Suman al efectivo: ese dinero salió de lo cobrado',
          hijos: [
            if (_gastos.isEmpty)
              const _Vacio('No declaró gastos.')
            else
              for (final (i, g) in _gastos.indexed)
                _FilaLinea(
                  titulo: g.motivo,
                  detalle: g.descripcion,
                  monto: g.monto,
                  onQuitar: _guardando
                      ? null
                      : () => setState(() => _gastos.removeAt(i)),
                ),
            const SizedBox(height: Dimen.espacio2),
            AppBoton(
              texto: 'Agregar gasto',
              variante: BotonVariante.secundario,
              tam: BotonTam.md,
              icono: Icons.add,
              onPressed: _guardando ? null : _agregarGasto,
            ),
          ],
        ),
        const SizedBox(height: Dimen.espacio4),

        _Seccion(
          titulo: 'Efectivo',
          hijos: [
            _FilaTotal(
              etiqueta: 'Billetes + monedas + gastos',
              valor: efectivoReal,
              color: color,
            ),
            _FilaTotal(
              etiqueta: 'Según el sistema',
              valor: detalle.efectivoSistema,
            ),
            const Divider(height: Dimen.espacio5),
            _FilaTotal(
              etiqueta: 'Diferencia',
              valor: difEfectivo,
              color: _colorDiferencia(difEfectivo),
              fuerte: true,
            ),
          ],
        ),
        const SizedBox(height: Dimen.espacio4),

        _Seccion(
          titulo: 'Cobros digitales',
          nota: 'Lo que el sistema ya tiene registrado',
          hijos: [
            if (detalle.digital.isEmpty)
              const _Vacio('No hay cobros digitales ese día.')
            else
              for (final c in detalle.digital) _FilaCobro(cobro: c),
            const Divider(height: Dimen.espacio5),
            _FilaTotal(
              etiqueta: 'Total del sistema',
              valor: detalle.bancosSistema,
              color: color,
            ),
          ],
        ),
        const SizedBox(height: Dimen.espacio4),

        _Seccion(
          titulo: 'Pagos digitales que declara',
          hijos: [
            if (_pagos.isEmpty)
              const _Vacio('No declaró pagos digitales.')
            else
              for (final (i, p) in _pagos.indexed)
                _FilaLinea(
                  titulo: p.metodo,
                  detalle: [
                    if (p.cliente != null) p.cliente!,
                    if (p.numeroOperacion != null &&
                        p.numeroOperacion!.isNotEmpty)
                      'Op. ${p.numeroOperacion}',
                  ].join(' · '),
                  monto: p.monto,
                  onQuitar: _guardando
                      ? null
                      : () => setState(() => _pagos.removeAt(i)),
                ),
            const SizedBox(height: Dimen.espacio2),
            AppBoton(
              texto: 'Agregar pago digital',
              variante: BotonVariante.secundario,
              tam: BotonTam.md,
              icono: Icons.add,
              onPressed: _guardando ? null : _agregarPago,
            ),
          ],
        ),
        const SizedBox(height: Dimen.espacio4),

        _Seccion(
          titulo: 'Digital',
          hijos: [
            _FilaTotal(
              etiqueta: 'Lo que declara',
              valor: _totalDigital,
              color: color,
            ),
            _FilaTotal(
              etiqueta: 'Según el sistema',
              valor: detalle.bancosSistema,
            ),
            const Divider(height: Dimen.espacio5),
            _FilaTotal(
              etiqueta: 'Diferencia',
              valor: difBancos,
              color: _colorDiferencia(difBancos),
              fuerte: true,
            ),
          ],
        ),
        const SizedBox(height: Dimen.espacio4),

        if (faltante > 0)
          AppAlerta(
            'Faltan ${formatoSoles(faltante)}. Al guardar queda como deuda de '
            '${detalle.usuario}, hasta que se le descuente o lo reponga.',
          )
        else if (sobrante > 0)
          AppAlerta(
            'Trae ${formatoSoles(sobrante)} de más. No se le acumula a favor: casi '
            'siempre es un cobro mal registrado, así que conviene revisarlo.',
            tono: AlertaTono.aviso,
          )
        else
          const AppAlerta(
            'Cuadra: no falta ni sobra dinero.',
            tono: AlertaTono.exito,
          ),
        const SizedBox(height: Dimen.espacio4),

        AppCampo(
          controlador: _observacion,
          etiqueta: 'Observación',
          pista: 'Qué explica la diferencia',
          icono: Icons.notes_outlined,
          opcional: true,
          maxLargo: 300,
          habilitado: !_guardando,
        ),
        const SizedBox(height: Dimen.espacio5),

        AppBoton(
          texto: detalle.arqueo == null ? 'Guardar cuadre' : 'Corregir cuadre',
          cargando: _guardando,
          onPressed: _guardar,
        ),
        const SizedBox(height: Dimen.espacio3),
        AppBoton(
          texto: 'Cancelar',
          variante: BotonVariante.secundario,
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: Dimen.espacio5),
      ],
    );
  }

  static Color _colorDiferencia(double diferencia) => diferencia == 0
      ? Colores.exito
      : diferencia < 0
      ? Colores.peligro
      : Colores.advertencia;
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.detalle, required this.color});

  final DetalleCuadre detalle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Row(
        children: [
          Icon(Icons.person_outline, size: 20, color: color),
          const SizedBox(width: Dimen.espacio3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detalle.usuario,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colores.tinta,
                  ),
                ),
                Text(
                  fechaCorta(detalle.fecha),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Colores.tintaSuave,
                  ),
                ),
              ],
            ),
          ),
          if (detalle.arqueo != null)
            AppEtiqueta(
              EstadoCuadre.etiqueta(
                detalle.arqueo!.diferenciaEfectivo == 0 &&
                        detalle.arqueo!.diferenciaBancos == 0
                    ? EstadoCuadre.cuadrado
                    : EstadoCuadre.conDiferencia,
              ),
              tono: detalle.arqueo!.faltante > 0
                  ? EtiquetaTono.peligro
                  : EtiquetaTono.exito,
            ),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.hijos, this.nota});

  final String titulo;
  final String? nota;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Colores.tinta,
            ),
          ),
          if (nota != null)
            Text(
              nota!,
              style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
            ),
          const SizedBox(height: Dimen.espacio3),
          ...hijos,
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Dimen.espacio2),
    child: Text(
      texto,
      style: const TextStyle(fontSize: 12.5, color: Colores.tintaTenue),
    ),
  );
}

/// Un cobro del sistema: de quién vino y cuánto.
class _FilaCobro extends StatelessWidget {
  const _FilaCobro({required this.cobro});

  final CobroDelDia cobro;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        cobro.cliente.isEmpty ? 'Sin cliente' : cobro.cliente,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colores.tinta,
                        ),
                      ),
                    ),
                    if (cobro.esDeudaAnterior) ...[
                      const SizedBox(width: Dimen.espacio2),
                      const AppEtiqueta(
                        'Deuda anterior',
                        tono: EtiquetaTono.aviso,
                      ),
                    ],
                  ],
                ),
                Text(
                  '${cobro.documento} · ${cobro.metodoPago}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Colores.tintaSuave,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Dimen.espacio2),
          Text(
            formatoSoles(cobro.monto),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colores.tinta,
            ),
          ),
        ],
      ),
    );
  }
}

/// Una línea declarada por la persona: gasto o pago digital.
class _FilaLinea extends StatelessWidget {
  const _FilaLinea({
    required this.titulo,
    required this.monto,
    this.detalle,
    this.onQuitar,
  });

  final String titulo;
  final String? detalle;
  final double monto;
  final VoidCallback? onQuitar;

  @override
  Widget build(BuildContext context) {
    final tieneDetalle = detalle != null && detalle!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colores.tinta,
                  ),
                ),
                if (tieneDetalle)
                  Text(
                    detalle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colores.tintaSuave,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            formatoSoles(monto),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colores.tinta,
            ),
          ),
          IconButton(
            onPressed: onQuitar,
            tooltip: 'Quitar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18, color: Colores.peligro),
          ),
        ],
      ),
    );
  }
}

class _FilaTotal extends StatelessWidget {
  const _FilaTotal({
    required this.etiqueta,
    required this.valor,
    this.color,
    this.fuerte = false,
  });

  final String etiqueta;
  final double valor;
  final Color? color;
  final bool fuerte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: TextStyle(
                fontSize: fuerte ? 13.5 : 12.5,
                fontWeight: fuerte ? FontWeight.w600 : FontWeight.w400,
                color: fuerte ? Colores.tinta : Colores.tintaSuave,
              ),
            ),
          ),
          Text(
            formatoSoles(valor),
            style: TextStyle(
              fontSize: fuerte ? 15 : 13,
              fontWeight: FontWeight.w700,
              color: color ?? Colores.tinta,
            ),
          ),
        ],
      ),
    );
  }
}

/// Alta de un gasto de la ruta. Son tres campos: cabe en una hoja.
class _HojaGasto extends StatefulWidget {
  const _HojaGasto({required this.motivos});

  final List<MotivoGasto> motivos;

  @override
  State<_HojaGasto> createState() => _HojaGastoState();
}

class _HojaGastoState extends State<_HojaGasto> {
  final _monto = TextEditingController();
  final _descripcion = TextEditingController();

  int? _motivoId;
  String? _errorMotivo;
  String? _errorMonto;

  @override
  void dispose() {
    _monto.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  void _agregar() {
    final monto = double.tryParse(_monto.text.trim().replaceAll(',', '.'));
    setState(() {
      _errorMotivo = _motivoId == null ? 'Elige el motivo.' : null;
      _errorMonto = monto == null || monto <= 0
          ? 'Ingresa un monto mayor a 0.'
          : null;
    });
    if (_errorMotivo != null || _errorMonto != null) return;

    final motivo = widget.motivos.firstWhere((m) => m.id == _motivoId);
    Navigator.of(context).pop(
      _Gasto(
        motivoGastoId: motivo.id,
        motivo: motivo.nombre,
        monto: monto!,
        descripcion: _descripcion.text.trim().isEmpty
            ? null
            : _descripcion.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Dimen.espacio4,
        right: Dimen.espacio4,
        top: Dimen.espacio2,
        bottom: Dimen.espacio4 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Gasto de la ruta',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colores.tinta,
            ),
          ),
          const SizedBox(height: Dimen.espacio4),

          AppSelector<int>(
            valor: _motivoId,
            etiqueta: 'Motivo',
            icono: Icons.local_gas_station_outlined,
            error: _errorMotivo,
            opciones: [for (final m in widget.motivos) Opcion(m.id, m.nombre)],
            onCambio: (v) => setState(() {
              _motivoId = v;
              _errorMotivo = null;
            }),
          ),
          const SizedBox(height: Dimen.espacio3),

          AppCampo(
            controlador: _monto,
            etiqueta: 'Monto',
            pista: '0.00',
            icono: Icons.calculate_outlined,
            tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
            error: _errorMonto,
          ),
          const SizedBox(height: Dimen.espacio3),

          AppCampo(
            controlador: _descripcion,
            etiqueta: 'Descripción',
            icono: Icons.notes_outlined,
            opcional: true,
            maxLargo: 200,
          ),
          const SizedBox(height: Dimen.espacio4),

          AppBoton(texto: 'Agregar', onPressed: _agregar),
        ],
      ),
    );
  }
}

/// Alta de un pago digital declarado.
class _HojaPagoDigital extends StatefulWidget {
  const _HojaPagoDigital({required this.metodos, required this.clientes});

  final List<MetodoPago> metodos;
  final List<Cliente> clientes;

  @override
  State<_HojaPagoDigital> createState() => _HojaPagoDigitalState();
}

class _HojaPagoDigitalState extends State<_HojaPagoDigital> {
  final _numeroOperacion = TextEditingController();
  final _monto = TextEditingController();

  int? _clienteId;
  String? _clienteNombre;
  int? _metodoId;

  String? _errorMetodo;
  String? _errorMonto;

  @override
  void dispose() {
    _numeroOperacion.dispose();
    _monto.dispose();
    super.dispose();
  }

  void _agregar() {
    final monto = double.tryParse(_monto.text.trim().replaceAll(',', '.'));
    setState(() {
      _errorMetodo = _metodoId == null ? 'Elige el método de pago.' : null;
      _errorMonto = monto == null || monto <= 0
          ? 'Ingresa un monto mayor a 0.'
          : null;
    });
    if (_errorMetodo != null || _errorMonto != null) return;

    final metodo = widget.metodos.firstWhere((m) => m.id == _metodoId);
    Navigator.of(context).pop(
      _PagoDigital(
        clienteId: _clienteId,
        cliente: _clienteNombre,
        metodoPagoId: metodo.id,
        metodo: metodo.nombre,
        numeroOperacion: _numeroOperacion.text.trim().isEmpty
            ? null
            : _numeroOperacion.text.trim(),
        monto: monto!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Dimen.espacio4,
        right: Dimen.espacio4,
        top: Dimen.espacio2,
        bottom: Dimen.espacio4 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pago digital declarado',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colores.tinta,
            ),
          ),
          const SizedBox(height: Dimen.espacio4),

          // El cliente es opcional: en la ruta a veces llega un Yape suelto que
          // todavía no se sabe a quién aplicar, y exigirlo impediría declararlo.
          campoCliente(
            clientes: widget.clientes,
            elegido: _clienteNombre,
            onElegir: (c) => setState(() {
              _clienteId = c.id;
              _clienteNombre = c.nombre;
            }),
          ),
          const SizedBox(height: Dimen.espacio3),

          AppSelector<int>(
            valor: _metodoId,
            etiqueta: 'Método de pago',
            icono: Icons.account_balance_outlined,
            error: _errorMetodo,
            opciones: [for (final m in widget.metodos) Opcion(m.id, m.nombre)],
            onCambio: (v) => setState(() {
              _metodoId = v;
              _errorMetodo = null;
            }),
          ),
          const SizedBox(height: Dimen.espacio3),

          AppCampo(
            controlador: _numeroOperacion,
            etiqueta: 'N° de operación',
            icono: Icons.confirmation_number_outlined,
            opcional: true,
            maxLargo: 50,
          ),
          const SizedBox(height: Dimen.espacio3),

          AppCampo(
            controlador: _monto,
            etiqueta: 'Monto',
            pista: '0.00',
            icono: Icons.calculate_outlined,
            tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
            error: _errorMonto,
          ),
          const SizedBox(height: Dimen.espacio4),

          AppBoton(texto: 'Agregar', onPressed: _agregar),
        ],
      ),
    );
  }
}
