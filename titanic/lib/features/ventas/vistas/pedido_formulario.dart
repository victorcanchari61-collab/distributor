import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/presentaciones_uso.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_botones_formulario.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_campo_cliente.dart';
import '../../../compartido/widgets/app_lineas_producto.dart';
import '../../../compartido/widgets/app_panel_producto.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../facturacion/datos/facturacion_api.dart';
import '../../facturacion/datos/lista_precio.dart';
import '../../facturacion/estado/facturacion_controlador.dart';
import '../../inventario/datos/almacen.dart';
import '../../inventario/estado/inventario_controlador.dart';
import '../../maestros/datos/cliente.dart';
import '../../maestros/datos/producto.dart';
import '../../maestros/estado/maestros_controlador.dart';
import '../datos/cotizacion.dart';
import '../datos/pedido.dart';
import '../estado/ventas_controlador.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_hoja.dart';

/// Alta y edicion de un pedido. Solo se edita mientras esta Pendiente.
///
/// Un pedido nuevo se puede armar con una cotizacion que mando el cliente desde
/// el portal web: llega ya jalada desde la bandeja ([cotizacion]) o se jala con
/// el boton de arriba. Al guardarlo, la cotizacion queda atendida.
class PedidoFormulario extends ConsumerStatefulWidget {
  const PedidoFormulario({super.key, this.pedido, this.cotizacion});

  final Pedido? pedido;

  /// La cotizacion del portal con la que se arma este pedido nuevo.
  final Cotizacion? cotizacion;

  @override
  ConsumerState<PedidoFormulario> createState() => _PedidoFormularioState();
}

class _PedidoFormularioState extends ConsumerState<PedidoFormulario> {
  late final _observacion = TextEditingController(
    text: widget.pedido?.observacion ?? _notaDe(widget.cotizacion) ?? '',
  );

  late int? _clienteId =
      widget.pedido?.clienteId ?? widget.cotizacion?.clienteId;
  late String? _clienteNombre =
      widget.pedido?.cliente ?? widget.cotizacion?.cliente;

  /// La cotizacion jalada: al guardar el pedido queda atendida.
  late Cotizacion? _cotizacion = widget.cotizacion;

  /// Sus lineas esperan al catalogo (como las de un pedido existente): sin el,
  /// no habria presentaciones que ofrecer para cambiar de unidad.
  late Cotizacion? _cotizacionPorPoner = widget.cotizacion;

  /// Lo que debe el cliente elegido, para avisarlo bajo el campo. Nulo si no debe o si no se eligió ahora.
  String? _clienteDeuda;
  late int? _listaPrecioId =
      widget.pedido?.listaPrecioId ?? widget.cotizacion?.listaPrecioId;
  late String _condicionPago =
      widget.pedido?.condicionPago ?? CondicionPago.contado;
  late bool _reservaStock = widget.pedido?.reservaStock ?? false;
  late int? _almacenReservaId = widget.pedido?.almacenId;

  final List<LineaDocumento> _lineas = [];

  /// Las lineas de un pedido que ya existe, una vez cargado el catalogo.
  ///
  /// Necesitan las presentaciones del producto para poder cambiar de unidad, y
  /// esas vienen del catalogo, que llega por red: armarlas en initState las
  /// dejaria sin unidades que ofrecer.
  bool _lineasPuestas = false;

  void _ponerLineasExistentes(List<Producto> catalogo) {
    final detalle = widget.pedido?.detalle ?? const <LineaVenta>[];
    if (_lineasPuestas || detalle.isEmpty || catalogo.isEmpty) return;
    _lineasPuestas = true;

    final porId = {for (final p in catalogo) p.id: p};
    final nuevas = [
      for (final l in detalle)
        LineaDocumento(
          productoId: l.productoId,
          producto: l.producto,
          codigo: porId[l.productoId]?.codigo ?? '',
          unidadBase: l.unidadBase,
          // Todas las del producto: el selector decide cuáles ofrece según el
          // uso, y una unidad que ya no se vende así sigue mostrándose (marcada)
          // en la línea guardada.
          presentaciones:
              porId[l.productoId]?.presentaciones ?? const <Presentacion>[],
          uso: UsoPresentacion.venta,
          presentacionId: l.presentacionId ?? 0,
          cantidad: l.cantidadPresentacion,
          // El precio pactado, tal cual se guardo: el de unidad base por el
          // factor devolvia 13.5999 donde se habia puesto 13.60.
          importe: l.precioPresentacion,
        ),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _lineas.addAll(nuevas));
    });
  }

  /// La nota del cliente, con el numero de la cotizacion delante.
  static String? _notaDe(Cotizacion? c) {
    if (c?.nota == null) return null;
    final texto = '${c!.numero}: ${c.nota}';
    return texto.length > 250 ? texto.substring(0, 250) : texto;
  }

  List<LineaDocumento> _lineasDe(Cotizacion c, List<Producto> catalogo) {
    final porId = {for (final p in catalogo) p.id: p};
    return [
      for (final l in c.detalle)
        LineaDocumento(
          productoId: l.productoId,
          producto: l.producto,
          codigo: porId[l.productoId]?.codigo ?? l.codigo,
          unidadBase: porId[l.productoId]?.unidadBase ?? '',
          presentaciones:
              porId[l.productoId]?.presentaciones ?? const <Presentacion>[],
          uso: UsoPresentacion.venta,
          presentacionId: l.presentacionId,
          cantidad: l.cantidad,
          // El precio que vio el cliente: el vendedor lo corrige si cambio.
          importe: l.precioPresentacion,
        ),
    ];
  }

  void _ponerLineasDeCotizacion(List<Producto> catalogo) {
    final c = _cotizacionPorPoner;
    if (c == null || catalogo.isEmpty) return;
    _cotizacionPorPoner = null;
    final nuevas = _lineasDe(c, catalogo);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(
          () => _lineas
            ..clear()
            ..addAll(nuevas),
        );
      }
    });
  }

  /// Jalar una cotizacion en espera: el pedido queda con su cliente, sus
  /// productos, los precios que vio el cliente y su nota.
  Future<void> _jalar() async {
    final elegida = await mostrarHoja<Cotizacion>(
      context,
      titulo: 'Jalar cotización',
      subtitulo: _clienteId == null
          ? 'Las que mandaron tus clientes y siguen en espera'
          : 'Las de ${_clienteNombre ?? 'este cliente'} en espera',
      cuerpo: _ListaJalar(
        cargar: ref
            .read(ventasApiProvider)
            .cotizaciones(
              estado: EstadoCotizacion.enEspera,
              clienteId: _clienteId,
            ),
      ),
    );
    if (elegida == null || !mounted) return;
    final catalogo =
        ref.read(productosProvider).valueOrNull ?? const <Producto>[];
    setState(() {
      _cotizacion = elegida;
      _clienteId = elegida.clienteId;
      _clienteNombre = elegida.cliente;
      _clienteDeuda = null;
      _errorCliente = null;
      _listaPrecioId = elegida.listaPrecioId;
      _observacion.text = _notaDe(elegida) ?? '';
      if (catalogo.isEmpty) {
        _cotizacionPorPoner = elegida;
      } else {
        _lineas
          ..clear()
          ..addAll(_lineasDe(elegida, catalogo));
      }
      _errorLineas = null;
    });
  }

  bool _guardando = false;
  String? _error;
  String? _errorCliente;
  String? _errorLineas;
  String? _errorAlmacen;

  bool get _esNuevo => widget.pedido == null;

  double get _total => _lineas.fold<double>(0, (n, f) => n + f.subtotal);

  /// El almacén principal (marcado en Almacenes); si no hubiera, el más antiguo.
  int? _primerAlmacenId(List<Almacen> almacenes) {
    if (almacenes.isEmpty) return null;
    for (final a in almacenes) {
      if (a.esPrincipal) return a.id;
    }
    return almacenes.map((a) => a.id).reduce((a, b) => a < b ? a : b);
  }

  /*
   * El principal por defecto: quien tiene un solo depósito nunca lo elige.
   *
   * NO se hace en initState: los almacenes llegan por red y en ese momento la
   * lista casi siempre está vacía todavía, así que el campo se quedaba en
   * blanco para siempre. Se resuelve en el build, la primera vez que la lista
   * trae algo — y solo esa vez, para no pisar lo que la persona elija después.
   */
  bool _almacenPuesto = false;

  void _ponerAlmacenPorDefecto(List<Almacen> almacenes) {
    if (_almacenPuesto || almacenes.isEmpty) return;
    _almacenPuesto = true;
    if (_almacenReservaId != null) return;

    final principal = _primerAlmacenId(almacenes);
    if (principal == null) return;

    // En el build no se puede llamar a setState; se agenda para el cuadro
    // siguiente, que llega antes de que la pantalla se pinte.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _almacenReservaId = principal);
    });
  }

  @override
  void dispose() {
    _observacion.dispose();
    super.dispose();
  }

  bool _validar() {
    setState(() {
      _errorCliente = _clienteId == null ? 'Elige el cliente.' : null;
      _errorLineas = _lineas.isEmpty ? 'Agrega al menos un producto.' : null;
      _errorAlmacen = _reservaStock && _almacenReservaId == null
          ? 'Elige el almacén.'
          : null;
    });
    return _errorCliente == null &&
        _errorLineas == null &&
        _errorAlmacen == null;
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_validar()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    final cuerpo = <String, dynamic>{
      'clienteId': _clienteId,
      'listaPrecioId': _listaPrecioId,
      'condicionPago': _condicionPago,
      'observacion': _observacion.text.trim().isEmpty
          ? null
          : _observacion.text.trim(),
      'reservaStock': _reservaStock,
      'almacenId': _reservaStock ? _almacenReservaId : null,
      // Solo al crear: la cotizacion jalada queda atendida con este pedido.
      if (_esNuevo) 'cotizacionId': _cotizacion?.id,
      'detalle': [
        for (final f in _lineas)
          {
            'productoId': f.productoId,
            'presentacionId': f.presentacionId == 0 ? null : f.presentacionId,
            'cantidad': f.cantidad,
            'precioUnitario': f.importe,
          },
      ],
    };

    try {
      if (_esNuevo) {
        await ref.read(pedidosProvider.notifier).crear(cuerpo);
      } else {
        await ref
            .read(pedidosProvider.notifier)
            .actualizar(widget.pedido!.id, cuerpo);
      }

      navegador.pop();
      mensajero.mostrar(
        !_esNuevo
            ? 'Pedido actualizado'
            : _cotizacion != null
            ? 'Pedido creado: ${_cotizacion!.numero} quedó atendida'
            : 'Pedido creado',
      );
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  /// Agrega las lineas elegidas, vengan del panel o de la hoja multiple.
  /*
   * Lo ultimo agregado va arriba.
   *
   * Cargando veinte productos, lo que se acaba de poner es lo que hay que
   * mirar, y al final de una lista larga queda fuera de pantalla. Arriba cae
   * justo debajo del buscador, donde ya estan los ojos. insertAll y no un
   * insert por vuelta: asi los elegidos de una tanda conservan entre si el
   * orden en que se marcaron.
   */
  void _agregarLineas(List<LineaElegida> elegidas) {
    setState(() {
      _lineas.insertAll(0, [
        for (final e in elegidas)
          LineaDocumento(
            productoId: e.producto.id,
            producto: e.producto.nombre,
            codigo: e.producto.codigo,
            unidadBase: e.producto.unidadBase,
            presentaciones: e.producto.presentaciones,
            uso: UsoPresentacion.venta,
            presentacionId: e.presentacionId,
            cantidad: e.cantidad,
            importe: e.importe,
          ),
      ]);
      _errorLineas = null;
    });
  }

  /*
   * La lista con la que se cobra.
   *
   * Sin elegir es "la predeterminada", que es la que el backend aplica a un
   * cliente sin lista propia: para pedir precios hay que resolver ese vacio a
   * un id de verdad.
   */
  int? _listaEfectiva(List<ListaPrecio> listas) {
    if (_listaPrecioId != null) return _listaPrecioId;
    for (final l in listas) {
      if (l.esPredeterminada) return l.id;
    }
    return null;
  }

  /// Precio de una presentacion por esa cantidad: el de la lista elegida y, si esa lista no lo
  /// tiene, el de referencia del producto. Así nada sale en cero por una lista a medio armar.
  Future<PrecioResuelto?> _precioDeLista(
    List<ListaPrecio> listas,
    int presentacionId,
    double cantidad,
  ) async {
    return ref
        .read(facturacionApiProvider)
        .precioVenta(presentacionId, cantidad, listaId: _listaEfectiva(listas));
  }

  @override
  Widget build(BuildContext context) {
    final listas =
        ref.watch(listasPrecioProvider).valueOrNull ?? const <ListaPrecio>[];
    final almacenes = ref.watch(almacenesActivosProvider);
    _ponerAlmacenPorDefecto(almacenes);
    _ponerLineasExistentes(
      ref.watch(productosProvider).valueOrNull ?? const <Producto>[],
    );
    _ponerLineasDeCotizacion(
      ref.watch(productosProvider).valueOrNull ?? const <Producto>[],
    );

    // Su propio Scaffold: no cuelga de AppShell, asi que declara aqui el
    // acento del modulo. Sin esto los componentes compartidos y las hojas que
    // se abran desde dentro saldrian con el azul de marca.
    return Acento.modulo(
      'fact',
      (context) => Scaffold(
        appBar: AppBar(
          title: Text(
            _esNuevo ? 'Nuevo pedido' : 'Editar pedido',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1),
          ),
          // Lo que el cliente mando desde el portal: arma el pedido con eso.
          actions: [
            if (_esNuevo)
              TextButton.icon(
                onPressed: _guardando ? null : _jalar,
                icon: const Icon(Icons.request_quote_outlined, size: 18),
                label: const Text('Jalar'),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(Dimen.espacio4),
          children: [
            if (_error != null) ...[
              AppAlerta(_error!),
              const SizedBox(height: Dimen.espacio4),
            ],
            if (_cotizacion != null) ...[
              _AvisoCotizacion(
                numero: _cotizacion!.numero,
                onSoltar: () => setState(() => _cotizacion = null),
              ),
              const SizedBox(height: Dimen.espacio4),
            ],

            campoCliente(
              clientes:
                  ref
                      .watch(clientesParaVenderProvider('pedidos'))
                      .valueOrNull ??
                  const <Cliente>[],
              // Mientras el catalogo viene, el buscador lo dice en vez de
              // afirmar que no hay ningun cliente.
              cargando: ref
                  .watch(clientesParaVenderProvider('pedidos'))
                  .isLoading,
              elegido: _clienteNombre,
              deuda: _clienteDeuda,
              error: _errorCliente,
              habilitado: !_guardando,
              onElegir: (c) => setState(() {
                // La cotizacion es de un cliente: cambiarlo la suelta (sus
                // productos se quedan, por si sirven).
                if (_cotizacion != null && c.id != _clienteId) {
                  _cotizacion = null;
                }
                _clienteId = c.id;
                _clienteNombre = c.nombre;
                _clienteDeuda = c.textoDeuda;
                _errorCliente = null;
              }),
            ),
            const SizedBox(height: Dimen.espacio4),

            // La lista de precios no se elige aquí: el pedido se toma con la lista del cliente (o la
            // predeterminada) y el precio sale solo. Sigue existiendo por dentro y se ve en la nota
            // de venta.

            // Lo que se acordo, no lo que se cobro: el repartidor llega y tiene
            // que saber si deja la mercaderia contra el dinero o si va fiada.
            AppSelector<String>(
              valor: _condicionPago,
              etiqueta: 'Condición de pago',
              icono: Icons.handshake_outlined,
              habilitado: !_guardando,
              opciones: const [
                Opcion(CondicionPago.contado, 'Contado · se cobra al entregar'),
                Opcion(CondicionPago.credito, 'Crédito · se deja fiado'),
              ],
              onCambio: (v) =>
                  setState(() => _condicionPago = v ?? CondicionPago.contado),
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _observacion,
              etiqueta: 'Observación',
              icono: Icons.notes_outlined,
              opcional: true,
              maxLargo: 250,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            AppSelector<int>(
              valor: _almacenReservaId,
              etiqueta: 'Almacén',
              icono: Icons.warehouse_outlined,
              error: _errorAlmacen,
              opciones: [
                for (final a in almacenes)
                  Opcion<int>(
                    a.id,
                    a.esPrincipal ? '${a.nombre} (principal)' : a.nombre,
                  ),
              ],
              onCambio: (v) => setState(() => _almacenReservaId = v),
            ),
            const SizedBox(height: Dimen.espacio2),

            CheckboxListTile(
              value: _reservaStock,
              onChanged: (v) => setState(() => _reservaStock = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Reservar stock',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Colores.tinta,
                ),
              ),
              subtitle: const Text(
                'Aparta el stock de ese almacén mientras el pedido esté pendiente, para que '
                'no se pueda prometer dos veces. Se libera al confirmar o anular.',
                style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
              ),
            ),
            const SizedBox(height: Dimen.espacio5),

            /*
           * El stock que se ofrece es el del almacen desde donde se despacha
           * (por defecto el principal), no el total de la empresa: prometerle
           * a un cliente algo que esta en otro deposito es prometer lo que no
           * hay.
           */
            AppPanelProducto(
              productos:
                  (ref.watch(productosProvider).valueOrNull ??
                          const <Producto>[])
                      .where((p) => p.activo && p.controlaStock)
                      .toList(),
              cargando: ref.watch(productosProvider).isLoading,
              paraVenta: true,
              uso: UsoPresentacion.venta,
              stock: ref
                  .watch(stockDisponibleProvider(_almacenReservaId))
                  .valueOrNull,
              reservado: ref
                  .watch(stockReservadoProvider(_almacenReservaId))
                  .valueOrNull,
              habilitado: !_guardando,
              // El precio lo pone la lista, no la memoria del vendedor.
              resolverPrecio: (presentacionId, cantidad) =>
                  _precioDeLista(listas, presentacionId, cantidad),
              claveLista: _listaEfectiva(listas),
              onAgregar: _agregarLineas,
            ),
            const SizedBox(height: Dimen.espacio5),

            // Lo agregado va DEBAJO del buscador: se lee como lo que acaba de
            // caer ahi, y el buscador no se aleja segun crece el documento.
            AppLineasProducto(
              lineas: _lineas,
              error: _errorLineas,
              habilitado: !_guardando,
              disponible: ref
                  .watch(stockDisponibleProvider(_almacenReservaId))
                  .valueOrNull,
              onCambio: () => setState(() {}),
              onEliminar: (l) => setState(() => _lineas.remove(l)),
            ),
            const SizedBox(height: Dimen.espacio4),

            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total: S/ ${_total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Acento.de(context),
                ),
              ),
            ),
            const SizedBox(height: Dimen.espacio6),

            AppBotonesFormulario(
              onCancelar: () => Navigator.of(context).pop(),
              onGuardar: _guardar,
              textoGuardar: _esNuevo ? 'Registrar' : 'Guardar',
              cargando: _guardando,
            ),
            const SizedBox(height: Dimen.espacio5),
          ],
        ),
      ),
    );
  }
}

/// "Armado con la cotizacion CT-0004", con la opcion de soltarla.
class _AvisoCotizacion extends StatelessWidget {
  const _AvisoCotizacion({required this.numero, required this.onSoltar});

  final String numero;
  final VoidCallback onSoltar;

  @override
  Widget build(BuildContext context) {
    final acento = Acento.de(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Dimen.espacio3,
        Dimen.espacio2,
        Dimen.espacio1,
        Dimen.espacio2,
      ),
      decoration: BoxDecoration(
        color: acento.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
        border: Border.all(color: acento.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.request_quote_outlined, size: 20, color: acento),
          const SizedBox(width: Dimen.espacio2),
          Expanded(
            child: Text(
              'Armado con la cotización $numero: al guardar queda atendida. '
              'Revisa precios y cantidades.',
              style: const TextStyle(fontSize: 13, color: Colores.tinta),
            ),
          ),
          TextButton(onPressed: onSoltar, child: const Text('Soltar')),
        ],
      ),
    );
  }
}

/// Las cotizaciones en espera para elegir una. Devuelve la elegida al cerrar.
class _ListaJalar extends StatelessWidget {
  const _ListaJalar({required this.cargar});

  final Future<List<Cotizacion>> cargar;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Cotizacion>>(
      future: cargar,
      builder: (context, foto) {
        if (foto.hasError) {
          final e = foto.error;
          return AppAlerta(
            e is ApiExcepcion ? e.texto : 'No pudimos cargar las cotizaciones.',
          );
        }
        if (!foto.hasData) {
          return const Padding(
            padding: EdgeInsets.all(Dimen.espacio5),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final lista = foto.data!;
        if (lista.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: Dimen.espacio5),
            child: Text(
              'No hay cotizaciones en espera. Aparecen aquí apenas el cliente '
              'las manda desde el portal.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final c in lista)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.request_quote_outlined,
                  color: Acento.de(context),
                ),
                title: Text(
                  '${c.numero} · ${c.cliente}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colores.tinta,
                  ),
                ),
                subtitle: Text(
                  '${c.detalle.length} '
                  '${c.detalle.length == 1 ? 'producto' : 'productos'} · '
                  'S/ ${c.total.toStringAsFixed(2)}'
                  '${c.nota == null ? '' : '\nNota: ${c.nota}'}',
                  style: const TextStyle(fontSize: 12.5),
                ),
                trailing: FilledButton(
                  onPressed: () => Navigator.of(context).pop(c),
                  child: const Text('Jalar'),
                ),
              ),
          ],
        );
      },
    );
  }
}
