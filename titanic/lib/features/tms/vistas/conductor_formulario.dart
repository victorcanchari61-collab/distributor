import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/flota.dart';
import '../estado/tms_controlador.dart';
import 'campo_foto.dart';

/// Alta y edición de un conductor.
class ConductorFormulario extends ConsumerStatefulWidget {
  const ConductorFormulario({super.key, this.conductor});

  final Conductor? conductor;

  @override
  ConsumerState<ConductorFormulario> createState() => _ConductorFormularioState();
}

class _ConductorFormularioState extends ConsumerState<ConductorFormulario> {
  late final _nombre = TextEditingController(text: widget.conductor?.nombre ?? '');
  late final _documento = TextEditingController(text: widget.conductor?.documento ?? '');
  late final _telefono = TextEditingController(text: widget.conductor?.telefono ?? '');
  late final _direccion = TextEditingController(text: widget.conductor?.direccion ?? '');
  late final _licencia = TextEditingController(text: widget.conductor?.licenciaNumero ?? '');
  late final _categoria = TextEditingController(
    text: widget.conductor?.licenciaCategoria ?? '',
  );
  late final _observacion = TextEditingController(text: widget.conductor?.observacion ?? '');

  late DateTime? _licenciaVence = widget.conductor?.licenciaVence;
  late DateTime? _fechaIngreso = widget.conductor?.fechaIngreso;
  late String? _foto = widget.conductor?.foto;
  late bool _activo = widget.conductor?.activo ?? true;

  bool _guardando = false;
  bool _subiendoFoto = false;
  String? _error;
  String? _errorNombre;
  String? _errorDocumento;

  bool get _esNuevo => widget.conductor == null;

  @override
  void dispose() {
    _nombre.dispose();
    _documento.dispose();
    _telefono.dispose();
    _direccion.dispose();
    _licencia.dispose();
    _categoria.dispose();
    _observacion.dispose();
    super.dispose();
  }

  bool _validar() {
    setState(() {
      _errorNombre = _nombre.text.trim().isEmpty ? 'Escribe el nombre.' : null;
      _errorDocumento = _documento.text.trim().isEmpty ? 'Escribe el documento.' : null;
    });
    return _errorNombre == null && _errorDocumento == null;
  }

  /// Un texto vacío se manda como null: "" y "sin dato" no son lo mismo, y
  /// guardar cadenas vacías obliga a comprobar las dos cosas al leerlas.
  String? _texto(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_validar()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(conductoresProvider.notifier)
          .guardar(
            id: widget.conductor?.id,
            cuerpo: {
              'nombre': _nombre.text.trim(),
              'documento': _documento.text.trim(),
              'telefono': _texto(_telefono),
              'direccion': _texto(_direccion),
              'licenciaNumero': _texto(_licencia),
              'licenciaCategoria': _texto(_categoria),
              'licenciaVence': _licenciaVence?.toIso8601String(),
              'foto': _foto,
              'fechaIngreso': _fechaIngreso?.toIso8601String(),
              'observacion': _texto(_observacion),
              'activo': _activo,
            },
          );

      navegador.pop();
      mensajero.showSnackBar(
        SnackBar(content: Text(_esNuevo ? 'Conductor creado' : 'Conductor actualizado')),
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
    // Su propio Scaffold: no cuelga de AppShell, asi que declara aqui el acento
    // del modulo. Sin esto los componentes compartidos saldrian con el azul de
    // marca en vez del color de TMS.
    return Acento.modulo(
      'tms',
      (context) => Scaffold(
        appBar: AppBar(
          title: Text(
            _esNuevo ? 'Nuevo conductor' : 'Editar conductor',
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

            AppCampo(
              controlador: _nombre,
              etiqueta: 'Nombre',
              icono: Icons.person_outline,
              error: _errorNombre,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _documento,
              etiqueta: 'Documento',
              pista: 'DNI',
              icono: Icons.badge_outlined,
              tipoTeclado: TextInputType.number,
              maxLargo: 20,
              error: _errorDocumento,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _telefono,
              etiqueta: 'Teléfono',
              icono: Icons.phone_outlined,
              opcional: true,
              tipoTeclado: TextInputType.phone,
              maxLargo: 30,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _direccion,
              etiqueta: 'Dirección',
              icono: Icons.place_outlined,
              opcional: true,
              maxLargo: 250,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio5),

            const Text(
              'Licencia',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colores.tinta,
              ),
            ),
            const SizedBox(height: Dimen.espacio3),

            AppCampo(
              controlador: _licencia,
              etiqueta: 'Número de licencia',
              icono: Icons.credit_card_outlined,
              opcional: true,
              maxLargo: 40,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _categoria,
              etiqueta: 'Categoría',
              pista: 'A-I, A-IIa, A-IIIb...',
              icono: Icons.workspace_premium_outlined,
              opcional: true,
              maxLargo: 20,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            CampoFecha(
              etiqueta: 'La licencia vence',
              valor: _licenciaVence,
              habilitado: !_guardando,
              onCambio: (v) => setState(() => _licenciaVence = v),
            ),
            const SizedBox(height: Dimen.espacio5),

            CampoFoto(
              ruta: _foto,
              carpeta: 'conductores',
              habilitado: !_guardando,
              onCambio: (v) => setState(() => _foto = v),
              onSubiendo: (v) => setState(() => _subiendoFoto = v),
            ),
            const SizedBox(height: Dimen.espacio5),

            CampoFecha(
              etiqueta: 'Fecha de ingreso',
              valor: _fechaIngreso,
              habilitado: !_guardando,
              onCambio: (v) => setState(() => _fechaIngreso = v),
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _observacion,
              etiqueta: 'Observación',
              icono: Icons.notes_outlined,
              opcional: true,
              maxLargo: 300,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio2),

            CheckboxListTile(
              value: _activo,
              onChanged: _guardando ? null : (v) => setState(() => _activo = v ?? true),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('Activo', style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                'Un conductor inactivo no se ofrece al asignar vehículos ni entra en las alertas.',
                style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
              ),
            ),
            const SizedBox(height: Dimen.espacio5),

            AppBoton(
              texto: _esNuevo ? 'Crear conductor' : 'Guardar cambios',
              cargando: _guardando,
              // Mientras la foto sube no se guarda: se grabaría sin ella y
              // habría que volver a entrar a ponerla.
              onPressed: _subiendoFoto ? null : _guardar,
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
