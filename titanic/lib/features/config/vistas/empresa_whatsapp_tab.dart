import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/config_modelos.dart';
import '../estado/config_controlador.dart';

/// El mensaje de siempre; la empresa lo puede cambiar. Las {llaves} se reemplazan al enviar.
const plantillaWhatsAppPorDefecto =
    'Hola {cliente} 👋\nTe enviamos tu {tipo} {numero} por {total}.\n\nDescárgala aquí:\n{url}\n\nGracias por tu compra. — {empresa}';

const _variables = [
  '{cliente}',
  '{tipo}',
  '{numero}',
  '{total}',
  '{empresa}',
  '{url}',
];

/// El envío de comprobantes por WhatsApp: si el celular de la empresa está vinculado (con su QR), si cada comprobante
/// aceptado por SUNAT se manda solo, y el mensaje con su vista previa. El enlace del mensaje baja el PDF directo.
///
/// El interruptor y el mensaje se guardan con el botón «Guardar cambios» de la pantalla; vincular y desvincular el
/// celular se hacen aquí mismo.
class EmpresaWhatsAppTab extends ConsumerStatefulWidget {
  const EmpresaWhatsAppTab({
    super.key,
    required this.puedeEditar,
    required this.automatico,
    required this.plantilla,
    required this.onAutomatico,
    required this.onGuardar,
    required this.guardando,
  });

  final bool puedeEditar;
  final bool automatico;
  final TextEditingController plantilla;
  final ValueChanged<bool> onAutomatico;
  final VoidCallback onGuardar;
  final bool guardando;

  @override
  ConsumerState<EmpresaWhatsAppTab> createState() => _EmpresaWhatsAppTabState();
}

class _EmpresaWhatsAppTabState extends ConsumerState<EmpresaWhatsAppTab> {
  EstadoWhatsApp? _estado;
  bool _cargando = true;
  Timer? _vigia;

  @override
  void initState() {
    super.initState();
    widget.plantilla.addListener(_alCambiarTexto);
    _cargar();
  }

  @override
  void dispose() {
    widget.plantilla.removeListener(_alCambiarTexto);
    _vigia?.cancel();
    super.dispose();
  }

  void _alCambiarTexto() => setState(() {});

  Future<void> _cargar() async {
    try {
      final estado = await ref.read(configApiProvider).estadoWhatsApp();
      if (!mounted) return;
      setState(() {
        _estado = estado;
        _cargando = false;
      });
      // Mientras espera el QR se vuelve a mirar cada pocos segundos: al escanearlo pasa solo a "conectado".
      if (estado.estado == 'esperando-qr') {
        _vigia ??= Timer.periodic(
          const Duration(seconds: 4),
          (_) => _cargar(),
        );
      } else {
        _vigia?.cancel();
        _vigia = null;
      }
    } on ApiExcepcion catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      Aviso.de(context).error(e.texto);
    }
  }

  Future<void> _desvincular() async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Cambiar el celular de WhatsApp',
      mensaje:
          'Se cierra la sesión actual y aparece un QR nuevo para vincular otro celular. Mientras tanto no se envía nada.',
      textoConfirmar: 'Desvincular',
      tono: ConfirmTono.aviso,
    );
    if (!ok || !mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(configApiProvider).desvincularWhatsApp();
      mensajero.mostrar('Sesión cerrada. Escanea el QR nuevo.');
      // El servicio tarda un momento en sacar el QR nuevo.
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) _cargar();
      });
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  /// Mete la variable donde está el cursor, en vez de obligar a escribirla.
  void _insertar(String clave) {
    final c = widget.plantilla;
    final texto = c.text.trim().isEmpty ? plantillaWhatsAppPorDefecto : c.text;
    final sel = c.selection;
    final ini = sel.isValid && c.text.isNotEmpty ? sel.start : texto.length;
    final fin = sel.isValid && c.text.isNotEmpty ? sel.end : texto.length;
    final nuevo = texto.replaceRange(ini, fin, clave);
    c.value = TextEditingValue(
      text: nuevo,
      selection: TextSelection.collapsed(offset: ini + clave.length),
    );
  }

  String get _vistaPrevia =>
      (widget.plantilla.text.trim().isEmpty
              ? plantillaWhatsAppPorDefecto
              : widget.plantilla.text)
          .replaceAll('{cliente}', 'JUAN PÉREZ')
          .replaceAll('{tipo}', 'boleta')
          .replaceAll('{numero}', 'B001-00000012')
          .replaceAll('{total}', 'S/ 157.00')
          .replaceAll('{empresa}', 'Titanic D')
          .replaceAll('{url}', 'http://tu-servidor/api/publico/comprobante/3f9a…');

  @override
  Widget build(BuildContext context) {
    final estado = _estado;
    final conectado = estado?.estado == 'conectado';
    final esperando = estado?.estado == 'esperando-qr';
    final apagado = estado?.estado == 'sin-servicio';

    final (colorEstado, textoEstado, detalle) = switch (estado?.estado) {
      'conectado' => (Colores.exito, 'Conectado', 'Listo para enviar comprobantes'),
      'esperando-qr' => (
        Colores.advertencia,
        'Esperando vinculación',
        'Escanea el código con el celular de la empresa',
      ),
      'sin-servicio' => (
        Colores.peligro,
        'Servicio apagado',
        'No se pudo hablar con el servicio de WhatsApp',
      ),
      null => (Colores.tintaSuave, 'Consultando…', ''),
      _ => (Colores.peligro, 'Desconectado', 'Se está reconectando…'),
    };

    return ListView(
      padding: const EdgeInsets.all(Dimen.espacio4),
      children: [
        // El celular
        Container(
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
                  const Icon(Icons.smartphone, color: Colores.exito),
                  const SizedBox(width: Dimen.espacio2),
                  const Expanded(
                    child: Text(
                      'Celular de la empresa',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualizar estado',
                    onPressed: _cargando ? null : _cargar,
                    icon: const Icon(Icons.refresh, size: 20),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(Dimen.espacio3),
                decoration: BoxDecoration(
                  color: Colores.fondo,
                  borderRadius: BorderRadius.circular(Dimen.radioCampo),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colorEstado,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: Dimen.espacio3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            textoEstado,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (detalle.isNotEmpty)
                            Text(
                              detalle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colores.tintaSuave,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (estado?.faltaToken ?? false) ...[
                const SizedBox(height: Dimen.espacio3),
                const AppAlerta(
                  'Falta el token de WhatsApp en la configuración del servidor (WhatsApp:Token). Sin él no se puede enviar.',
                  tono: AlertaTono.aviso,
                ),
              ],
              if (apagado) ...[
                const SizedBox(height: Dimen.espacio3),
                const AppAlerta(
                  'Revisa que distributor-whatsapp esté corriendo en el servidor y toca actualizar.',
                ),
              ],
              if (esperando) ...[
                const SizedBox(height: Dimen.espacio4),
                Center(
                  child: estado?.qrImagen != null
                      ? Container(
                          padding: const EdgeInsets.all(Dimen.espacio2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colores.linea),
                            borderRadius: BorderRadius.circular(Dimen.radioCampo),
                          ),
                          child: Image.memory(
                            base64Decode(estado!.qrImagen!.split(',').last),
                            width: 220,
                            height: 220,
                            gaplessPlayback: true,
                            filterQuality: FilterQuality.none,
                          ),
                        )
                      : const Padding(
                          padding: EdgeInsets.all(Dimen.espacio5),
                          child: CircularProgressIndicator(),
                        ),
                ),
                const SizedBox(height: Dimen.espacio3),
                const Text(
                  '1. Abre WhatsApp en el celular de la empresa\n2. Entra a Dispositivos vinculados\n3. Toca «Vincular un dispositivo» y escanea este código',
                  style: TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
                ),
              ],
              if (conectado) ...[
                if ((estado?.enCola ?? 0) > 0) ...[
                  const SizedBox(height: Dimen.espacio3),
                  Text(
                    '${estado!.enCola} ${estado.enCola == 1 ? 'mensaje esperando' : 'mensajes esperando'} su turno: salen con una pausa entre uno y otro.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colores.tintaSuave,
                    ),
                  ),
                ],
                if (widget.puedeEditar) ...[
                  const SizedBox(height: Dimen.espacio3),
                  AppBoton(
                    texto: 'Cambiar celular',
                    variante: BotonVariante.secundario,
                    onPressed: _desvincular,
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: Dimen.espacio4),

        // El envío automático
        Container(
          padding: const EdgeInsets.all(Dimen.espacio3),
          decoration: BoxDecoration(
            border: Border.all(color: Colores.linea),
            borderRadius: BorderRadius.circular(Dimen.radioCampo),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Enviar cada comprobante automáticamente',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Cuando SUNAT acepta una factura, boleta o nota, se manda una sola vez al teléfono del cliente. Si no tiene teléfono o falla, queda anotado en el comprobante y se puede enviar a mano.',
                  style: TextStyle(fontSize: 12),
                ),
                value: widget.automatico,
                onChanged: widget.puedeEditar ? widget.onAutomatico : null,
              ),
              const SizedBox(height: Dimen.espacio3),
              const Text(
                'Mensaje',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: Dimen.espacio2),
              TextField(
                controller: widget.plantilla,
                enabled: widget.puedeEditar,
                minLines: 5,
                maxLines: 9,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: plantillaWhatsAppPorDefecto,
                  hintStyle: const TextStyle(color: Colores.tintaTenue),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Dimen.radioCampo),
                  ),
                ),
              ),
              const Text(
                'Toca una variable para insertarla:',
                style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
              ),
              const SizedBox(height: Dimen.espacio2),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final v in _variables)
                    ActionChip(
                      label: Text(v, style: const TextStyle(fontSize: 12)),
                      onPressed: widget.puedeEditar ? () => _insertar(v) : null,
                    ),
                ],
              ),
              const SizedBox(height: Dimen.espacio2),
              const Text(
                'El enlace siempre se agrega, aunque lo quites del texto.',
                style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
              ),
            ],
          ),
        ),
        const SizedBox(height: Dimen.espacio4),

        // Como lo recibe el cliente
        const Text(
          'Así lo recibe el cliente',
          style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
        ),
        const SizedBox(height: Dimen.espacio2),
        Container(
          padding: const EdgeInsets.all(Dimen.espacio3),
          decoration: BoxDecoration(
            color: const Color(0xFFEFEAE2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFD9FDD3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _vistaPrevia,
                style: const TextStyle(fontSize: 13, color: Color(0xFF27272A)),
              ),
            ),
          ),
        ),
        const SizedBox(height: Dimen.espacio2),
        const Text(
          'El enlace descarga el PDF directo al abrirlo: no abre ninguna página.',
          style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
        ),

        if (widget.puedeEditar) ...[
          const SizedBox(height: Dimen.espacio4),
          AppBoton(
            texto: 'Guardar cambios',
            cargando: widget.guardando,
            onPressed: widget.onGuardar,
          ),
        ],
      ],
    );
  }
}
