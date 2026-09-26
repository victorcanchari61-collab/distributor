import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_botones_formulario.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/metodo_pago.dart';
import '../estado/finanzas_controlador.dart';
import '../../../compartido/widgets/app_aviso.dart';

/// Alta y edicion de un metodo de pago.
///
/// Igual que en el panel web: el Efectivo no elige cuenta (entra a la caja de
/// quien cobra); la billetera digital y la transferencia si, porque hay que
/// saber a que cuenta llega la plata. La billetera ademas lleva su numero de
/// celular, que es con lo que se la reconoce entre varias de la misma cuenta.
class MetodoPagoFormulario extends ConsumerStatefulWidget {
  const MetodoPagoFormulario({super.key, this.metodo});

  /// Null cuando es un metodo nuevo.
  final MetodoPago? metodo;

  @override
  ConsumerState<MetodoPagoFormulario> createState() =>
      _MetodoPagoFormularioState();
}

class _MetodoPagoFormularioState extends ConsumerState<MetodoPagoFormulario> {
  late final _nombre = TextEditingController(text: widget.metodo?.nombre ?? '');
  late final _numero = TextEditingController(text: widget.metodo?.numero ?? '');

  late String _tipo = widget.metodo?.tipo ?? TipoMetodoPago.efectivo;
  late int? _cuentaId = widget.metodo?.cuentaFinancieraId;

  bool _guardando = false;
  String? _error;
  String? _errorNombre;
  String? _errorNumero;
  String? _errorCuenta;

  bool get _esNuevo => widget.metodo == null;
  bool get _esBilletera => _tipo == TipoMetodoPago.billeteraDigital;
  bool get _llevaCuenta => _tipo != TipoMetodoPago.efectivo;

  @override
  void dispose() {
    _nombre.dispose();
    _numero.dispose();
    super.dispose();
  }

  bool _validar() {
    setState(() {
      _errorNombre = _nombre.text.trim().isEmpty ? 'Ingresa el nombre.' : null;
      _errorNumero = _esBilletera && _numero.text.trim().isEmpty
          ? 'Indica el número de celular de esta billetera.'
          : null;
      _errorCuenta = _llevaCuenta && _cuentaId == null
          ? 'Elige a qué cuenta va la plata.'
          : null;
    });
    return _errorNombre == null && _errorNumero == null && _errorCuenta == null;
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
      'nombre': _nombre.text.trim(),
      'tipo': _tipo,
      // El backend rechaza el numero fuera de la billetera y la cuenta en el
      // Efectivo: se mandan vacios en vez de arrastrar lo que quedo escrito
      // antes de cambiar el tipo.
      'numero': _esBilletera ? _numero.text.trim() : null,
      'cuentaFinancieraId': _llevaCuenta ? _cuentaId : null,
      if (!_esNuevo) 'activo': widget.metodo!.activo,
    };

    try {
      await ref
          .read(metodosPagoProvider.notifier)
          .guardar(id: widget.metodo?.id, cuerpo: cuerpo);

      navegador.pop();
      mensajero.mostrar(
        _esNuevo ? 'Método de pago creado' : 'Método de pago actualizado',
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
    // Su propio Scaffold: no cuelga de AppShell, asi que declara aqui el
    // acento del modulo. Sin esto los componentes compartidos y las hojas que
    // se abran desde dentro saldrian con el azul de marca.
    return Acento.modulo(
      'finanzas',
      (context) => Scaffold(
        appBar: AppBar(
          title: Text(
            _esNuevo ? 'Nuevo método de pago' : 'Editar método de pago',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(Dimen.espacio4),
          children: [
            if (_error != null) ...[
              AppAlerta(_error!),
              const SizedBox(height: Dimen.espacio4),
            ],

            AppSelector<String>(
              valor: _tipo,
              etiqueta: 'Tipo',
              icono: Icons.category_outlined,
              habilitado: !_guardando,
              opciones: [
                for (final t in TipoMetodoPago.todos)
                  Opcion(t, TipoMetodoPago.etiqueta(t)),
              ],
              onCambio: (v) =>
                  setState(() => _tipo = v ?? TipoMetodoPago.efectivo),
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _nombre,
              etiqueta: 'Nombre',
              pista: 'Yape, Plin, BCP Cuenta Corriente...',
              icono: Icons.label_outline,
              error: _errorNombre,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            if (_esBilletera) ...[
              AppCampo(
                controlador: _numero,
                etiqueta: 'Número de celular',
                icono: Icons.smartphone_outlined,
                tipoTeclado: TextInputType.phone,
                formateadores: [FilteringTextInputFormatter.digitsOnly],
                maxLargo: 20,
                error: _errorNumero,
                habilitado: !_guardando,
              ),
              const SizedBox(height: Dimen.espacio4),
            ],

            if (_llevaCuenta) ...[
              _SelectorCuenta(
                valor: _cuentaId,
                error: _errorCuenta,
                habilitado: !_guardando,
                onCambio: (v) => setState(() => _cuentaId = v),
              ),
              const SizedBox(height: Dimen.espacio4),
            ],

            const SizedBox(height: Dimen.espacio2),
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

/// A que cuenta va la plata: bancos y pasarelas activos, nunca una caja.
class _SelectorCuenta extends ConsumerWidget {
  const _SelectorCuenta({
    required this.valor,
    required this.error,
    required this.habilitado,
    required this.onCambio,
  });

  final int? valor;
  final String? error;
  final bool habilitado;
  final ValueChanged<int?> onCambio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuentas = ref.watch(cuentasElegiblesProvider);

    return cuentas.when(
      loading: () => const LinearProgressIndicator(),
      // Leer las cuentas pide permiso de Finanzas (cajas o bancos): sin el,
      // se dice claro en vez de mostrar un desplegable vacio.
      error: (e, _) => AppAlerta(
        e is ApiExcepcion
            ? e.texto
            : 'No pudimos cargar las cuentas financieras.',
      ),
      data: (lista) => lista.isEmpty
          ? const AppAlerta(
              'No hay cuentas de banco activas. Créala primero en el panel web, en Bancos.',
            )
          : AppSelector<int>(
              valor: lista.any((c) => c.id == valor) ? valor : null,
              etiqueta: 'Cuenta a la que va la plata',
              icono: Icons.account_balance_outlined,
              habilitado: habilitado,
              error: error,
              opciones: [for (final c in lista) Opcion(c.id, c.etiqueta)],
              onCambio: onCambio,
            ),
    );
  }
}
