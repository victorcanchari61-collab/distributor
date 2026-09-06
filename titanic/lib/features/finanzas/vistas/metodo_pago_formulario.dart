import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/metodo_pago.dart';
import '../estado/finanzas_controlador.dart';

/// Alta y edicion de un metodo de pago.
class MetodoPagoFormulario extends ConsumerStatefulWidget {
  const MetodoPagoFormulario({super.key, this.metodo});

  /// Null cuando es un metodo nuevo.
  final MetodoPago? metodo;

  @override
  ConsumerState<MetodoPagoFormulario> createState() => _MetodoPagoFormularioState();
}

class _MetodoPagoFormularioState extends ConsumerState<MetodoPagoFormulario> {
  late final _nombre = TextEditingController(text: widget.metodo?.nombre ?? '');
  late final _banco = TextEditingController(text: widget.metodo?.banco ?? '');
  late final _numeroCuenta = TextEditingController(text: widget.metodo?.numeroCuenta ?? '');
  late final _cci = TextEditingController(text: widget.metodo?.cci ?? '');
  late final _titular = TextEditingController(text: widget.metodo?.titular ?? '');

  late String _tipo = widget.metodo?.tipo ?? TipoMetodoPago.efectivo;

  bool _guardando = false;
  String? _error;
  String? _errorNombre;
  String? _errorBanco;
  String? _errorNumeroCuenta;

  bool get _esNuevo => widget.metodo == null;
  bool get _esTransferencia => _tipo == TipoMetodoPago.transferencia;
  bool get _tieneCuenta => _tipo != TipoMetodoPago.efectivo;

  @override
  void dispose() {
    for (final c in [_nombre, _banco, _numeroCuenta, _cci, _titular]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validar() {
    setState(() {
      _errorNombre = _nombre.text.trim().isEmpty ? 'Ingresa el nombre.' : null;
      _errorBanco = _esTransferencia && _banco.text.trim().isEmpty ? 'Indica el banco.' : null;
      _errorNumeroCuenta = _tieneCuenta && _numeroCuenta.text.trim().isEmpty
          ? (_esTransferencia ? 'Indica el número de cuenta.' : 'Indica el número de celular.')
          : null;
    });
    return _errorNombre == null && _errorBanco == null && _errorNumeroCuenta == null;
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_validar()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.of(context);

    final cuerpo = <String, dynamic>{
      'nombre': _nombre.text.trim(),
      'tipo': _tipo,
      'banco': _esTransferencia && _banco.text.trim().isNotEmpty ? _banco.text.trim() : null,
      'numeroCuenta': _tieneCuenta && _numeroCuenta.text.trim().isNotEmpty
          ? _numeroCuenta.text.trim()
          : null,
      'cci': _esTransferencia && _cci.text.trim().isNotEmpty ? _cci.text.trim() : null,
      'titular': _tieneCuenta && _titular.text.trim().isNotEmpty ? _titular.text.trim() : null,
      if (!_esNuevo) 'activo': widget.metodo!.activo,
    };

    try {
      await ref.read(metodosPagoProvider.notifier).guardar(id: widget.metodo?.id, cuerpo: cuerpo);

      navegador.pop();
      mensajero.showSnackBar(
        SnackBar(content: Text(_esNuevo ? 'Método de pago creado' : 'Método de pago actualizado')),
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
          bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(Dimen.espacio4),
          children: [
            if (_error != null) ...[AppAlerta(_error!), const SizedBox(height: Dimen.espacio4)],

            AppSelector<String>(
              valor: _tipo,
              etiqueta: 'Tipo',
              icono: Icons.category_outlined,
              habilitado: !_guardando,
              opciones: [
                for (final t in TipoMetodoPago.todos) Opcion(t, TipoMetodoPago.etiqueta(t)),
              ],
              onCambio: (v) => setState(() => _tipo = v ?? TipoMetodoPago.efectivo),
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

            if (_esTransferencia) ...[
              AppCampo(
                controlador: _banco,
                etiqueta: 'Banco',
                pista: 'BCP, Interbank, BBVA...',
                icono: Icons.account_balance_outlined,
                error: _errorBanco,
                habilitado: !_guardando,
              ),
              const SizedBox(height: Dimen.espacio4),
            ],

            if (_tieneCuenta) ...[
              AppCampo(
                controlador: _numeroCuenta,
                etiqueta: _esTransferencia ? 'Número de cuenta' : 'Número de celular',
                icono: Icons.numbers_outlined,
                error: _errorNumeroCuenta,
                habilitado: !_guardando,
              ),
              const SizedBox(height: Dimen.espacio4),
            ],

            if (_esTransferencia) ...[
              AppCampo(
                controlador: _cci,
                etiqueta: 'CCI',
                pista: 'Código de cuenta interbancario',
                icono: Icons.tag,
                opcional: true,
                habilitado: !_guardando,
              ),
              const SizedBox(height: Dimen.espacio4),
            ],

            if (_tieneCuenta) ...[
              AppCampo(
                controlador: _titular,
                etiqueta: 'Titular',
                pista: 'A nombre de quién está',
                icono: Icons.person_outline,
                opcional: true,
                habilitado: !_guardando,
              ),
              const SizedBox(height: Dimen.espacio4),
            ],

            const SizedBox(height: Dimen.espacio2),
            AppBoton(
              texto: _esNuevo ? 'Crear método' : 'Guardar cambios',
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
        ),
      ),
    );
  }
}
