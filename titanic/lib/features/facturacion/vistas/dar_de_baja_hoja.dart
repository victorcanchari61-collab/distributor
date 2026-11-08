import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_botones_formulario.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_hoja.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../ventas/estado/ventas_controlador.dart';
import '../datos/comprobante.dart';
import '../estado/comprobantes_controlador.dart';

/// Lo que se le dice a quien pidió la baja o la consultó, según lo que respondió SUNAT. Devuelve el texto y si es un
/// error: una baja pendiente no lo es, solo hay que esperar.
({String texto, bool esError}) mensajeDeBaja(
  Comprobante c, {
  bool consulta = false,
}) => switch (c.bajaEstado) {
  EstadoBajaCpe.aceptada => (
    texto: '${c.numeroCompleto} dada de baja',
    esError: false,
  ),
  EstadoBajaCpe.pendiente => (
    texto: consulta
        ? 'SUNAT todavía procesa la baja'
        : 'SUNAT todavía procesa la baja: consúltala en unos minutos',
    esError: false,
  ),
  _ => (texto: c.bajaMensaje ?? 'SUNAT no aceptó la baja', esError: true),
};

/// Pide la baja de una factura: se anula ante SUNAT sin emitir una nota de crédito, solo dentro de los 7 días de emitida.
Future<void> abrirDarDeBaja(BuildContext context, Comprobante comprobante) =>
    abrirHoja<void>(context, (_) => DarDeBajaHoja(comprobante: comprobante));

class DarDeBajaHoja extends ConsumerStatefulWidget {
  const DarDeBajaHoja({super.key, required this.comprobante});

  final Comprobante comprobante;

  @override
  ConsumerState<DarDeBajaHoja> createState() => _DarDeBajaHojaState();
}

class _DarDeBajaHojaState extends ConsumerState<DarDeBajaHoja> {
  final _motivo = TextEditingController();
  bool _enviando = false;
  String? _error;

  Comprobante get _c => widget.comprobante;

  @override
  void initState() {
    super.initState();
    // El botón se habilita al llegar a los 3 caracteres que pide SUNAT.
    _motivo.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  bool get _valido => _motivo.text.trim().length >= 3;

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    // El mensajero se toma antes de esperar: después de cerrar la hoja ya no hay contexto.
    final mensajero = Aviso.de(context);
    final navegador = Navigator.of(context);

    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final nuevo = await ref
          .read(comprobantesApiProvider)
          .darDeBaja(_c.id, _motivo.text.trim());
      ref.read(comprobantesProvider(_c.tipo).notifier).reemplazar(nuevo);
      // Una baja aceptada anula la venta: su nota (si la tiene) cambia de estado.
      if (nuevo.bajaEstado == EstadoBajaCpe.aceptada) {
        ref.invalidate(notasVentaProvider);
      }

      navegador.pop();
      final r = mensajeDeBaja(nuevo);
      if (r.esError) {
        mensajero.error(r.texto);
      } else {
        mensajero.mostrar(r.texto);
      }
    } on ApiExcepcion catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return HojaBase(
      titulo: 'Dar de baja ${_c.numeroCompleto}',
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AppAlerta(_error!),
            const SizedBox(height: Dimen.espacio3),
          ],
          Text(
            _c.clienteNombre,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Colores.tinta,
            ),
          ),
          const SizedBox(height: Dimen.espacio3),
          AppAlerta(_c.avisoBaja, tono: AlertaTono.aviso),
          const SizedBox(height: Dimen.espacio4),
          AppCampo(
            controlador: _motivo,
            etiqueta: 'Motivo de la baja',
            icono: Icons.edit_note,
            pista: 'Ej.: Error en los productos facturados',
            maxLargo: 100,
            habilitado: !_enviando,
          ),
        ],
      ),
      pie: AppBotonesFormulario(
        textoGuardar: 'Dar de baja',
        cargando: _enviando,
        onCancelar: () => Navigator.of(context).pop(),
        onGuardar: _valido ? _enviar : null,
      ),
    );
  }
}
