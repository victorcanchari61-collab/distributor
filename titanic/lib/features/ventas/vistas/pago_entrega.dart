import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../finanzas/datos/metodo_pago.dart';
import '../datos/pedido.dart';

double _numero(String texto) =>
    double.tryParse(texto.trim().replaceAll(',', '.')) ?? 0;

/// A centavos: lo que se suma y se envía no puede tener más decimales que lo
/// que se muestra, o "cobrado" y "a cobrar" discreparían por una fracción.
double _centavos(double n) => (n * 100).round() / 100;

/// Un pago de la lista. Mientras [guardado] es falso la fila se está
/// escribiendo: no cuenta para el total y hay que guardarla o cancelarla antes
/// de convertir.
class FilaPagoEntrega {
  FilaPagoEntrega({
    this.tipo,
    this.metodoPagoId,
    String montoInicial = '',
    this.guardado = false,
  }) : monto = TextEditingController(text: montoInicial);

  String? tipo;
  int? metodoPagoId;
  final TextEditingController monto;
  bool guardado;

  /// Lo que valía antes de empezar a editarla, para poder cancelar.
  ({String? tipo, int? metodoPagoId, String monto})? previo;

  /// Lo tecleado, ya como número y a centavos.
  double get valor => _centavos(_numero(monto.text));

  void dispose() => monto.dispose();
}

/// Lo que dicen los pagos guardados frente al total a cobrar.
///
/// Solo cuentan las filas guardadas; una que todavía se está escribiendo
/// ([pendiente]) impide convertir hasta que se guarde o se cancele.
class ResumenPago {
  const ResumenPago._({
    required this.usadas,
    required this.pendiente,
    required this.total,
    required this.pagado,
  });

  factory ResumenPago(List<FilaPagoEntrega> filas, double total) {
    final usadas = [
      for (final f in filas)
        if (f.guardado) f,
    ];
    return ResumenPago._(
      usadas: usadas,
      pendiente: filas.any((f) => !f.guardado),
      total: _centavos(total),
      pagado: _centavos(usadas.fold<double>(0, (suma, f) => suma + f.valor)),
    );
  }

  /// Los pagos guardados: lo único que se envía.
  final List<FilaPagoEntrega> usadas;
  final bool pendiente;
  final double total;
  final double pagado;

  double get saldo => _centavos(total - pagado);

  /// Lo cobrado pasa de lo que se entrega.
  bool get sobra => pagado > total + 0.001;

  /// Lo cobrado cubre el total: la venta queda al contado.
  bool get completo => pagado > 0 && pagado >= total - 0.001;
}

/// La pestaña de pago al entregar, con la misma lógica que la de la web: una
/// lista de pagos que se escribe en la propia fila.
///
/// La condición de pago del pedido es solo lo acordado: al repartir, quien iba
/// a pagar a crédito a veces paga todo o una parte, y quien iba al contado a
/// veces paga solo una parte o nada. Aquí se registra lo que de verdad se
/// cobra, en uno o varios métodos, y la venta queda al contado si eso cubre el
/// total o a crédito con ese adelanto si no.
///
/// Las filas las tiene quien abre la hoja —hacen falta al convertir y para el
/// número de la pestaña—: aquí se editan en el sitio y se avisa con [onCambio].
class PagoEntrega extends StatefulWidget {
  const PagoEntrega({
    super.key,
    required this.condicionPago,
    required this.metodos,
    required this.filas,
    required this.total,
    required this.onCambio,
  });

  /// Lo acordado con el cliente: CONTADO o CREDITO. Solo informa.
  final String condicionPago;

  final AsyncValue<List<MetodoPagoOpcion>> metodos;
  final List<FilaPagoEntrega> filas;

  /// Lo que se cobra: lo entregado, ya con los recortes.
  final double total;

  final VoidCallback onCambio;

  @override
  State<PagoEntrega> createState() => _PagoEntregaState();
}

class _PagoEntregaState extends State<PagoEntrega> {
  String? _aviso;

  /// La fila que se está escribiendo, para llevarla a la vista.
  final _claveEdicion = GlobalKey();

  @override
  void initState() {
    super.initState();
    // La pestaña se arma de nuevo cada vez que se vuelve a ella: si quedó una
    // fila sin guardar —es lo que bloquea la conversión—, se lleva a la vista
    // en vez de dejar que se la busque más abajo.
    if (widget.filas.any((f) => !f.guardado)) _verEdicion();
  }

  List<MetodoPagoOpcion> get _metodos =>
      widget.metodos.valueOrNull ?? const <MetodoPagoOpcion>[];

  String _nombreMetodo(int? id) {
    for (final m in _metodos) {
      if (m.id == id) return m.nombre;
    }
    return '—';
  }

  /// Toda edición pasa por aquí: limpia el aviso y le cuenta a la hoja que las
  /// filas cambiaron, para que recalcule el badge y quite el error de arriba.
  void _cambiar(VoidCallback mutar) {
    setState(() {
      _aviso = null;
      mutar();
    });
    widget.onCambio();
  }

  void _avisar(String mensaje) {
    setState(() => _aviso = mensaje);
    // El aviso agranda la fila y puede empujar sus botones fuera de pantalla.
    _verEdicion();
  }

  /*
   * Lleva la fila en edición a la vista.
   *
   * La lista queda debajo del aviso y las tarjetas, y en un teléfono el
   * "Agregar pago" la dejaba justo al borde o fuera de pantalla: se tocaba el
   * botón y parecía que no había pasado nada.
   */
  void _verEdicion() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contexto = _claveEdicion.currentContext;
      if (contexto == null || !contexto.mounted) return;
      Scrollable.ensureVisible(
        contexto,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _agregar() {
    _cambiar(() => widget.filas.add(FilaPagoEntrega()));
    _verEdicion();
  }

  /// Pasa una fila guardada a modo edición, recordando lo que tenía.
  void _editar(FilaPagoEntrega fila) {
    _cambiar(() {
      fila.previo = (
        tipo: fila.tipo,
        metodoPagoId: fila.metodoPagoId,
        monto: fila.monto.text,
      );
      fila.guardado = false;
    });
    _verEdicion();
  }

  void _cancelar(FilaPagoEntrega fila) => _cambiar(() {
    final previo = fila.previo;
    // Una fila que ya existía vuelve a lo que tenía; una nueva se descarta.
    if (previo == null) {
      _descartar(fila);
      return;
    }
    fila.tipo = previo.tipo;
    fila.metodoPagoId = previo.metodoPagoId;
    fila.monto.text = previo.monto;
    fila.guardado = true;
    fila.previo = null;
  });

  void _quitar(FilaPagoEntrega fila) => _cambiar(() => _descartar(fila));

  /// Saca la fila y suelta su controlador, pero después del cuadro: mientras
  /// dura este, su campo de monto sigue en pantalla leyendo de él.
  void _descartar(FilaPagoEntrega fila) {
    widget.filas.remove(fila);
    WidgetsBinding.instance.addPostFrameCallback((_) => fila.dispose());
  }

  void _guardar(FilaPagoEntrega fila) {
    FocusScope.of(context).unfocus();
    if (fila.tipo == null || fila.metodoPagoId == null) {
      return _avisar('Elige el tipo y el método de pago.');
    }
    if (!(fila.valor > 0)) return _avisar('El monto debe ser mayor que cero.');

    // Lo ya guardado más esta fila no puede pasarse del total.
    final otros = widget.filas
        .where((f) => f.guardado && f != fila)
        .fold<double>(0, (suma, f) => suma + f.valor);
    final cobraria = _centavos(otros + fila.valor);
    if (cobraria > _centavos(widget.total) + 0.001) {
      return _avisar(
        'Con este pago se cobraría ${formatoSoles(cobraria)} y la venta es de '
        '${formatoSoles(widget.total)}. Baja el monto.',
      );
    }

    _cambiar(() {
      fila.guardado = true;
      fila.previo = null;
    });
  }

  /*
   * "Cobrar todo": un pago con lo que falta, en efectivo si hay un método así,
   * que es lo que se cobra casi siempre en la puerta del cliente. Si no hay
   * efectivo queda la fila abierta para elegir el método.
   */
  void _cobrarTodo(double saldo) {
    MetodoPagoOpcion? efectivo;
    for (final m in _metodos) {
      if (m.tipo == TipoMetodoPago.efectivo) {
        efectivo = m;
        break;
      }
    }
    final falta = saldo > 0 ? saldo : 0.0;

    _cambiar(
      () => widget.filas.add(
        FilaPagoEntrega(
          tipo: efectivo == null ? null : TipoMetodoPago.efectivo,
          metodoPagoId: efectivo?.id,
          montoInicial: falta > 0 ? falta.toStringAsFixed(2) : '',
          guardado: efectivo != null && falta > 0,
        ),
      ),
    );
    if (efectivo == null) _verEdicion();
  }

  void _elegirTipo(FilaPagoEntrega fila, String? tipo) {
    if (tipo == null || tipo == fila.tipo) return;
    final delTipo = _metodos.where((m) => m.tipo == tipo).toList();

    _cambiar(() {
      fila.tipo = tipo;
      // Con un solo método de ese tipo —el efectivo casi siempre— no hay nada
      // que elegir: se completa solo. Con varios, se elige a mano.
      fila.metodoPagoId = delTipo.length == 1 ? delTipo.first.id : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = ResumenPago(widget.filas, widget.total);
    final editando = widget.filas.any((f) => !f.guardado);
    final cargando = widget.metodos.isLoading && !widget.metodos.hasValue;
    final sinMetodos = widget.metodos.hasValue && _metodos.isEmpty;
    final credito = widget.condicionPago == CondicionPago.credito;
    // Solo una fila se edita a la vez, pero la clave global no admite repetirse:
    // se le da a la primera y no a "las que estén abiertas".
    FilaPagoEntrega? enEdicion;
    for (final f in widget.filas) {
      if (!f.guardado) {
        enEdicion = f;
        break;
      }
    }

    // Column y no ListView: la lista es corta y así toda la pestaña está armada,
    // que es lo que necesita Scrollable.ensureVisible para llegar a la fila.
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: Dimen.espacio3,
              vertical: Dimen.espacio2,
            ),
            decoration: BoxDecoration(
              color: Colores.fondo,
              borderRadius: BorderRadius.circular(Dimen.radioCampo),
            ),
            child: Wrap(
              spacing: Dimen.espacio2,
              runSpacing: Dimen.espacio1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Acordado con el cliente:',
                  style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
                ),
                AppEtiqueta(
                  credito ? 'Crédito' : 'Contado',
                  tono: credito ? EtiquetaTono.aviso : EtiquetaTono.exito,
                ),
                const Text(
                  'Es solo una referencia: manda lo que se cobre ahora. Lo que no se cobre '
                  'queda a crédito.',
                  style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
                ),
              ],
            ),
          ),
          const SizedBox(height: Dimen.espacio3),

          // Tres a la vez, como en la web: en una fila que se desliza, "Queda a
          // crédito" —lo que más pesa al cobrar— quedaba fuera de pantalla.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _Dato('A cobrar', formatoSoles(r.total))),
                const SizedBox(width: Dimen.espacio2),
                Expanded(
                  child: _Dato(
                    'Cobrado ahora',
                    formatoSoles(r.pagado),
                    color: Colores.exito,
                  ),
                ),
                const SizedBox(width: Dimen.espacio2),
                Expanded(
                  child: _Dato(
                    'Queda a crédito',
                    formatoSoles(r.saldo > 0 ? r.saldo : 0),
                    color: r.saldo > 0 ? Colores.advertencia : Colores.tinta,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Dimen.espacio3),

          // Sin cobro no se dice nada: las tarjetas ya muestran que todo queda a crédito.
          if (r.sobra) ...[
            AppAlerta(
              'Lo cobrado supera el total en ${formatoSoles(r.pagado - r.total)}. '
              'Corrige los montos.',
            ),
            const SizedBox(height: Dimen.espacio3),
          ] else if (r.completo) ...[
            const AppAlerta(
              'Cobrado completo: la venta queda al contado.',
              tono: AlertaTono.exito,
            ),
            const SizedBox(height: Dimen.espacio3),
          ] else if (r.pagado > 0) ...[
            AppAlerta(
              'Cobro parcial: la venta queda a crédito y el cliente debe ${formatoSoles(r.saldo)}.',
              tono: AlertaTono.aviso,
            ),
            const SizedBox(height: Dimen.espacio3),
          ],

          if (sinMetodos) ...[
            const AppAlerta(
              'No hay métodos de pago activos. Créalos en Finanzas → Métodos de pago para '
              'poder registrar un cobro.',
              tono: AlertaTono.aviso,
            ),
            const SizedBox(height: Dimen.espacio3),
          ],

          // Sin poder leer los métodos no se puede cobrar: decir "no hay ninguno"
          // sería mentir, así que se muestra el motivo real.
          if (widget.metodos.hasError && !widget.metodos.hasValue) ...[
            AppAlerta(
              widget.metodos.error is ApiExcepcion
                  ? (widget.metodos.error as ApiExcepcion).texto
                  : 'No pudimos cargar los métodos de pago.',
            ),
            const SizedBox(height: Dimen.espacio3),
          ],

          const Text(
            'Pagos',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colores.tinta,
            ),
          ),
          const SizedBox(height: Dimen.espacio2),
          Row(
            children: [
              Expanded(
                child: AppBoton(
                  texto: 'Cobrar todo',
                  variante: BotonVariante.secundario,
                  tam: BotonTam.sm,
                  icono: Icons.account_balance_wallet_outlined,
                  onPressed:
                      editando || r.saldo <= 0 || cargando || _metodos.isEmpty
                      ? null
                      : () => _cobrarTodo(r.saldo),
                ),
              ),
              const SizedBox(width: Dimen.espacio2),
              Expanded(
                child: AppBoton(
                  texto: 'Agregar pago',
                  tam: BotonTam.sm,
                  icono: Icons.add,
                  onPressed: editando || _metodos.isEmpty ? null : _agregar,
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimen.espacio3),

          if (widget.filas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Dimen.espacio3),
              child: Text(
                'Todavía no se cobró nada. Si el cliente pagó algo, agrégalo; si no, la venta '
                'queda a crédito.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
              ),
            ),

          for (final fila in widget.filas) ...[
            fila.guardado
                ? _filaGuardada(fila, editando)
                : _filaEnEdicion(
                    context,
                    fila,
                    esLaAbierta: identical(fila, enEdicion),
                  ),
            const SizedBox(height: Dimen.espacio2),
          ],
        ],
      ),
    );
  }

  Widget _filaGuardada(FilaPagoEntrega fila, bool editando) {
    final monto = formatoSoles(fila.valor);

    return Container(
      key: ObjectKey(fila),
      padding: const EdgeInsets.only(left: Dimen.espacio3),
      decoration: BoxDecoration(
        color: Colores.fondo,
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Row(
        children: [
          // El tipo va bajo el método y no a su lado: "Billetera digital" más un
          // monto de cuatro cifras dejaban al nombre sin sitio en 320 de ancho.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Dimen.espacio2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nombreMetodo(fila.metodoPagoId),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (fila.tipo != null) ...[
                    const SizedBox(height: 2),
                    AppEtiqueta(
                      TipoMetodoPago.etiqueta(fila.tipo!),
                      tono: EtiquetaTono.modulo,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Text(
            monto,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          IconButton(
            tooltip: 'Editar pago de $monto',
            visualDensity: VisualDensity.compact,
            onPressed: editando ? null : () => _editar(fila),
            icon: Icon(
              Icons.edit_outlined,
              size: 18,
              color: editando ? Colores.tintaTenue : Colores.tintaSuave,
            ),
          ),
          IconButton(
            tooltip: 'Quitar pago de $monto',
            visualDensity: VisualDensity.compact,
            onPressed: editando ? null : () => _quitar(fila),
            icon: Icon(
              Icons.delete_outline,
              size: 18,
              color: editando ? Colores.tintaTenue : Colores.peligro,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaEnEdicion(
    BuildContext context,
    FilaPagoEntrega fila, {
    required bool esLaAbierta,
  }) {
    final delTipo = _metodos.where((m) => m.tipo == fila.tipo).toList();

    return Container(
      key: esLaAbierta ? _claveEdicion : ObjectKey(fila),
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        border: Border.all(color: Acento.de(context)),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSelector<String>(
            valor: fila.tipo,
            etiqueta: 'Tipo de pago',
            icono: Icons.category_outlined,
            opciones: [
              for (final t in TipoMetodoPago.todos)
                Opcion(t, TipoMetodoPago.etiqueta(t)),
            ],
            onCambio: (v) => _elegirTipo(fila, v),
          ),
          const SizedBox(height: Dimen.espacio3),
          AppSelector<int>(
            valor: fila.metodoPagoId,
            etiqueta: 'Método',
            icono: Icons.payments_outlined,
            habilitado: fila.tipo != null,
            opciones: [for (final m in delTipo) Opcion(m.id, m.nombre)],
            onCambio: (v) => _cambiar(() => fila.metodoPagoId = v),
          ),
          const SizedBox(height: Dimen.espacio3),
          AppCampo(
            controlador: fila.monto,
            etiqueta: 'Monto',
            icono: Icons.attach_money,
            pista: '0.00',
            tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: Dimen.espacio3),
          // Aquí y no arriba de la pestaña: quien guarda está mirando esta fila,
          // y un aviso fuera de pantalla se leería como "el botón no hace nada".
          if (_aviso != null) ...[
            AppAlerta(_aviso!),
            const SizedBox(height: Dimen.espacio3),
          ],
          Row(
            children: [
              Expanded(
                child: AppBoton(
                  texto: 'Cancelar',
                  variante: BotonVariante.secundario,
                  tam: BotonTam.sm,
                  onPressed: () => _cancelar(fila),
                ),
              ),
              const SizedBox(width: Dimen.espacio2),
              Expanded(
                child: AppBoton(
                  texto: 'Guardar pago',
                  tam: BotonTam.sm,
                  icono: Icons.check,
                  onPressed: () => _guardar(fila),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Un indicador del cobro: etiqueta chica y el monto debajo.
class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor, {this.color = Colores.tinta});

  final String etiqueta;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimen.espacio2,
        vertical: Dimen.espacio2,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            etiqueta,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colores.tintaSuave,
            ),
          ),
          const SizedBox(height: 2),
          // Los tres caben en un tercio del ancho: un monto de cuatro cifras se
          // achica antes que cortarse.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
