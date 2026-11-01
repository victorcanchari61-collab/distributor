import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_botones_formulario.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_hoja.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/comprobante.dart';
import '../estado/comprobantes_controlador.dart';

/// Solo los dígitos de un teléfono: sin espacios, guiones ni el "+".
String soloDigitos(String? telefono) =>
    (telefono ?? '').replaceAll(RegExp(r'\D'), '');

/// Un número sirve para WhatsApp si tiene al menos 9 dígitos (un celular peruano sin el 51).
bool telefonoValido(String? telefono) => soloDigitos(telefono).length >= 9;

/// "Enviar documento": abre la hoja que manda por WhatsApp el enlace que descarga el PDF del comprobante.
///
/// Muestra el número al que va —el del cliente, o el último al que se mandó— y se puede cambiar ahí mismo, solo para
/// este envío: el cliente sigue con el suyo.
Future<void> abrirEnvioWhatsApp(
  BuildContext context,
  Comprobante comprobante,
) => abrirHoja<void>(
  context,
  (_) => EnviarWhatsAppHoja(comprobante: comprobante),
);

class EnviarWhatsAppHoja extends ConsumerStatefulWidget {
  const EnviarWhatsAppHoja({super.key, required this.comprobante});

  final Comprobante comprobante;

  @override
  ConsumerState<EnviarWhatsAppHoja> createState() => _EnviarWhatsAppHojaState();
}

class _EnviarWhatsAppHojaState extends ConsumerState<EnviarWhatsAppHoja> {
  late final TextEditingController _telefono = TextEditingController(
    text:
        widget.comprobante.clienteTelefono ??
        widget.comprobante.whatsAppTelefono ??
        '',
  );
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _telefono.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _telefono.dispose();
    super.dispose();
  }

  Comprobante get _c => widget.comprobante;

  Future<void> _enviar() async {
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
          .enviarWhatsApp(_c.id, telefono: _telefono.text.trim());
      ref.read(comprobantesProvider(_c.tipo).notifier).reemplazar(nuevo);
      navegador.pop();
      mensajero.mostrar('${_c.numeroCompleto} enviado a la cola de WhatsApp');
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
    final delCliente = _c.clienteTelefono ?? '';
    final cambiado =
        soloDigitos(_telefono.text).isNotEmpty &&
        delCliente.isNotEmpty &&
        soloDigitos(_telefono.text) != soloDigitos(delCliente);
    final valido = telefonoValido(_telefono.text);
    final yaEnviado =
        _c.whatsAppEstado == EstadoWhatsAppCpe.encolado &&
        _c.whatsAppTelefono != null &&
        _c.whatsAppEnviadoEn != null;

    return HojaBase(
      titulo: 'Enviar documento',
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AppAlerta(_error!),
            const SizedBox(height: Dimen.espacio3),
          ],
          Container(
            padding: const EdgeInsets.all(Dimen.espacio3),
            decoration: BoxDecoration(
              color: Colores.fondo,
              borderRadius: BorderRadius.circular(Dimen.radioCampo),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _c.clienteNombre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${TipoCpe.corto(_c.tipo)} ${_c.numeroCompleto} · S/ ${_c.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colores.tintaSuave,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Dimen.espacio4),
          AppCampo(
            controlador: _telefono,
            etiqueta: 'Número de WhatsApp',
            icono: Icons.phone_outlined,
            pista: '987654321',
            tipoTeclado: TextInputType.phone,
            formateadores: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9 +\-]')),
            ],
            maxLargo: 20,
            error: _telefono.text.isNotEmpty && !valido
                ? 'Escribe un número de al menos 9 dígitos'
                : null,
          ),
          const SizedBox(height: Dimen.espacio2),
          Text(
            delCliente.isEmpty
                ? 'El cliente no tiene teléfono guardado: escríbelo para enviarlo.'
                : cambiado
                ? 'Solo para este envío: el cliente sigue con $delCliente.'
                : 'Es el número del cliente. Puedes cambiarlo aquí mismo.',
            style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
          ),
          if (yaEnviado) ...[
            const SizedBox(height: Dimen.espacio3),
            Text(
              'Ya se envió a ${_c.whatsAppTelefono} el ${_fechaHora(_c.whatsAppEnviadoEn!)}. '
              'Si lo envías otra vez, le llega de nuevo.',
              style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
            ),
          ],
          const SizedBox(height: Dimen.espacio3),
          const Text(
            'El cliente recibe un enlace que descarga el PDF directamente.',
            style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
          ),
        ],
      ),
      pie: AppBotonesFormulario(
        textoGuardar: 'Enviar',
        cargando: _enviando,
        onCancelar: () => Navigator.of(context).pop(),
        onGuardar: valido ? _enviar : null,
      ),
    );
  }
}

String _fechaHora(DateTime f) =>
    '${diaCorto(f)} ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

String diaCorto(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
