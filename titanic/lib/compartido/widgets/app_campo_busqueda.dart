import 'package:flutter/material.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';
import 'app_filtros_en_linea.dart';

/// Un filtro del buscador, descrito por de dónde sale su valor.
///
/// Se declara el extractor y no la lista de opciones porque las opciones son
/// las que de verdad hay entre los registros cargados: una lista escrita a mano
/// ofrecería mercados sin un solo cliente, y "sin resultados" es lo peor que
/// puede devolver un filtro.
class FiltroBusqueda<T> {
  const FiltroBusqueda(this.etiqueta, this.valor);

  final String etiqueta;
  final String? Function(T) valor;
}

/// Campo para elegir un registro escribiendo, con búsqueda ampliada aparte.
///
/// Antes esto era un botón que abría una hoja: tocar el campo tapaba la
/// pantalla con un modal aunque la persona solo quisiera teclear tres letras
/// del nombre que ya conoce, que es el caso normal cuando el vendedor está
/// frente al cliente. Ahora se escribe en el sitio y las coincidencias caen
/// debajo.
///
/// La lupa sigue ahí para lo otro: cuando no se sabe el nombre y hay que mirar
/// la lista entera con sus filtros. Son dos maneras distintas de buscar y por
/// eso son dos gestos distintos, no uno solo que sirva a medias para ambas.
class AppCampoBusqueda<T> extends StatefulWidget {
  const AppCampoBusqueda({
    super.key,
    required this.etiqueta,
    required this.icono,
    required this.pista,
    required this.items,
    required this.titulo,
    required this.buscable,
    required this.onElegir,
    this.subtitulo,
    this.filtros = const [],
    this.textoElegido,
    this.error,
    this.habilitado = true,
    this.maximoSugerencias = 8,
  });

  final String etiqueta;
  final IconData icono;
  final String pista;

  final List<T> items;
  final String Function(T) titulo;
  final String? Function(T)? subtitulo;

  /// Todo lo que hace encontrable a un registro, ya en minúsculas.
  final String Function(T) buscable;

  final List<FiltroBusqueda<T>> filtros;
  final void Function(T) onElegir;

  /// Lo que hay elegido ahora, para pintarlo al abrir el formulario.
  final String? textoElegido;

  final String? error;
  final bool habilitado;

  /// Cuántas coincidencias caen bajo el campo. Más no caben en el teclado
  /// abierto, y a partir de ahí lo que hace falta es afinar la búsqueda.
  final int maximoSugerencias;

  @override
  State<AppCampoBusqueda<T>> createState() => _AppCampoBusquedaState<T>();
}

/// Lo que ocupa la etiqueta flotante encima de la caja del campo.
const double _altoEtiqueta = 18;

class _AppCampoBusquedaState<T> extends State<AppCampoBusqueda<T>> {
  late final TextEditingController _controlador =
      TextEditingController(text: widget.textoElegido ?? '');
  final FocusNode _foco = FocusNode();

  String _texto = '';
  bool _filtrosAbiertos = false;
  final Map<String, String?> _filtros = {};

  /// Lo elegido, para no proponer coincidencias de algo ya resuelto.
  bool _resuelto = false;

  @override
  void initState() {
    super.initState();
    _resuelto = widget.textoElegido != null;
    _foco.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant AppCampoBusqueda<T> viejo) {
    super.didUpdateWidget(viejo);

    // El formulario puede cambiar la selección por su cuenta — al elegir desde
    // la hoja ampliada, por ejemplo. Si no se reflejara aquí, el campo seguiría
    // mostrando lo anterior.
    if (widget.textoElegido != viejo.textoElegido && widget.textoElegido != null) {
      _controlador.text = widget.textoElegido!;
      _resuelto = true;
      _texto = '';
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    _foco.dispose();
    super.dispose();
  }

  /// Las opciones reales de un filtro: lo que aparece entre los registros.
  List<String> _opcionesDe(FiltroBusqueda<T> filtro) {
    final vistos = <String>{};
    for (final item in widget.items) {
      final v = filtro.valor(item);
      if (v != null && v.trim().isNotEmpty) vistos.add(v);
    }
    final lista = vistos.toList()..sort();
    return lista;
  }

  List<T> get _coincidencias {
    final texto = _texto.trim().toLowerCase();

    return widget.items.where((item) {
      for (final f in widget.filtros) {
        final elegido = _filtros[f.etiqueta];
        if (elegido != null && f.valor(item) != elegido) return false;
      }
      return texto.isEmpty || widget.buscable(item).contains(texto);
    }).toList();
  }

  void _elegir(T item) {
    _controlador.text = widget.titulo(item);
    _foco.unfocus();
    setState(() {
      _texto = '';
      _resuelto = true;
    });
    widget.onElegir(item);
  }

  /// Si hay algo que proponer debajo del campo ahora mismo.
  ///
  /// Solo con algo escrito o con un filtro puesto: al entrar al formulario,
  /// soltar la lista entera de clientes bajo el campo empujaría el resto de la
  /// pantalla fuera de la vista sin que nadie lo haya pedido.
  ///
  /// NO se exige que el campo tenga el foco: abrir un desplegable de filtro se
  /// lo quita, así que la lista se esfumaría justo mientras se filtra, que es
  /// cuando más falta hace verla.
  bool get _sugiriendo =>
      !_resuelto && (_texto.trim().isNotEmpty || _filtros.values.any((v) => v != null));

  @override
  Widget build(BuildContext context) {
    final coincidencias = _coincidencias;
    final hayFiltro = _filtros.values.any((v) => v != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _controlador,
                focusNode: _foco,
                enabled: widget.habilitado,
                onChanged: (v) => setState(() {
                  _texto = v;
                  // Volver a escribir deshace la elección: si no, el campo
                  // mostraría un nombre que ya no es el que se guardaría.
                  _resuelto = false;
                }),
                style: const TextStyle(fontSize: 15, color: Colores.tinta),
                decoration: InputDecoration(
                  labelText: widget.etiqueta,
                  hintText: widget.pista,
                  errorText: widget.error,
                  prefixIcon: Icon(widget.icono, size: 19, color: Colores.tintaTenue),
                  suffixIcon: IconButton(
                    onPressed: widget.habilitado ? () => _abrirHoja(context) : null,
                    icon: const Icon(Icons.search, size: 18, color: Colores.tintaTenue),
                    tooltip: 'Ver la lista completa',
                  ),
                  constraints: const BoxConstraints(minHeight: Dimen.campoLg),
                ),
              ),
            ),
            if (widget.filtros.isNotEmpty) ...[
              const SizedBox(width: Dimen.espacio2),
              Padding(
                /*
                 * Centrado con la CAJA del campo, no con el campo entero: la
                 * etiqueta flotante ("Cliente") ocupa arriba y el mensaje de
                 * error puede aparecer abajo, así que alinear por el centro o
                 * por el borde dejaría el botón bailando según el estado.
                 * Medido desde arriba queda quieto: alto de la etiqueta más lo
                 * que sobra entre la caja y el botón.
                 */
                padding: const EdgeInsets.only(top: _altoEtiqueta + (Dimen.campoLg - Dimen.campoMd) / 2),
                child: BotonFiltrosEnLinea(
                  activo: _filtrosAbiertos || hayFiltro,
                  onTap: () => setState(() => _filtrosAbiertos = !_filtrosAbiertos),
                ),
              ),
            ],
          ],
        ),

        if (_filtrosAbiertos && widget.filtros.isNotEmpty) ...[
          const SizedBox(height: Dimen.espacio2),
          Wrap(
            spacing: Dimen.espacio2,
            runSpacing: Dimen.espacio2,
            children: [
              for (final f in widget.filtros)
                FiltroEnLinea(
                  etiqueta: f.etiqueta,
                  valor: _filtros[f.etiqueta],
                  opciones: _opcionesDe(f),
                  onChanged: (v) => setState(() {
                    _filtros[f.etiqueta] = v;
                    _resuelto = false;
                  }),
                ),
            ],
          ),
        ],

        if (_sugiriendo) ...[
          const SizedBox(height: Dimen.espacio2),
          _Sugerencias<T>(
            items: coincidencias.take(widget.maximoSugerencias).toList(),
            restantes: coincidencias.length - widget.maximoSugerencias,
            titulo: widget.titulo,
            subtitulo: widget.subtitulo,
            onElegir: _elegir,
            onVerTodos: () => _abrirHoja(context),
          ),
        ],
      ],
    );
  }

  Future<void> _abrirHoja(BuildContext context) async {
    _foco.unfocus();

    final elegido = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HojaBusqueda<T>(
        titulo: widget.etiqueta,
        pista: widget.pista,
        items: widget.items,
        titulos: widget.titulo,
        subtitulos: widget.subtitulo,
        buscable: widget.buscable,
        filtros: widget.filtros,
        // Se abre con lo que ya se había escrito y filtrado: pasar a la lista
        // completa no debe obligar a repetir la búsqueda.
        textoInicial: _texto,
        filtrosIniciales: Map.of(_filtros),
      ),
    );

    if (elegido != null && mounted) _elegir(elegido);
  }
}

/// Las coincidencias que caen bajo el campo mientras se escribe.
class _Sugerencias<T> extends StatelessWidget {
  const _Sugerencias({
    required this.items,
    required this.restantes,
    required this.titulo,
    required this.subtitulo,
    required this.onElegir,
    required this.onVerTodos,
  });

  final List<T> items;
  final int restantes;
  final String Function(T) titulo;
  final String? Function(T)? subtitulo;
  final void Function(T) onElegir;
  final VoidCallback onVerTodos;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(Dimen.espacio4),
              child: Text(
                'Nada coincide con lo que escribiste.',
                style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in items)
                  _Fila<T>(
                    item: item,
                    titulo: titulo,
                    subtitulo: subtitulo,
                    onElegir: onElegir,
                  ),
                if (restantes > 0)
                  InkWell(
                    onTap: onVerTodos,
                    child: Padding(
                      padding: const EdgeInsets.all(Dimen.espacio3),
                      child: Text(
                        'y $restantes más — ver la lista completa',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colores.marca,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Fila<T> extends StatelessWidget {
  const _Fila({
    required this.item,
    required this.titulo,
    required this.subtitulo,
    required this.onElegir,
  });

  final T item;
  final String Function(T) titulo;
  final String? Function(T)? subtitulo;
  final void Function(T) onElegir;

  @override
  Widget build(BuildContext context) {
    final sub = subtitulo?.call(item);

    return InkWell(
      onTap: () => onElegir(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimen.espacio3,
          vertical: Dimen.espacio3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo(item),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colores.tinta,
              ),
            ),
            if (sub != null && sub.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  sub,
                  style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// La lista completa, con su buscador y sus filtros.
class _HojaBusqueda<T> extends StatefulWidget {
  const _HojaBusqueda({
    required this.titulo,
    required this.pista,
    required this.items,
    required this.titulos,
    required this.subtitulos,
    required this.buscable,
    required this.filtros,
    required this.textoInicial,
    required this.filtrosIniciales,
  });

  final String titulo;
  final String pista;
  final List<T> items;
  final String Function(T) titulos;
  final String? Function(T)? subtitulos;
  final String Function(T) buscable;
  final List<FiltroBusqueda<T>> filtros;
  final String textoInicial;
  final Map<String, String?> filtrosIniciales;

  @override
  State<_HojaBusqueda<T>> createState() => _HojaBusquedaState<T>();
}

class _HojaBusquedaState<T> extends State<_HojaBusqueda<T>> {
  late String _texto = widget.textoInicial;
  late final TextEditingController _controlador =
      TextEditingController(text: widget.textoInicial);
  late final Map<String, String?> _filtros = Map.of(widget.filtrosIniciales);
  late bool _filtrosAbiertos = _filtros.values.any((v) => v != null);

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  List<String> _opcionesDe(FiltroBusqueda<T> filtro) {
    final vistos = <String>{};
    for (final item in widget.items) {
      final v = filtro.valor(item);
      if (v != null && v.trim().isNotEmpty) vistos.add(v);
    }
    return vistos.toList()..sort();
  }

  List<T> get _visibles {
    final texto = _texto.trim().toLowerCase();

    return widget.items.where((item) {
      for (final f in widget.filtros) {
        final elegido = _filtros[f.etiqueta];
        if (elegido != null && f.valor(item) != elegido) return false;
      }
      return texto.isEmpty || widget.buscable(item).contains(texto);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _visibles;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colores.fondo,
          borderRadius: BorderRadius.vertical(top: Radius.circular(Dimen.radioPanel)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimen.espacio4,
                Dimen.espacio3,
                Dimen.espacio4,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colores.linea,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: Dimen.espacio3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.titulo,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colores.tinta,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colores.tintaSuave),
                        tooltip: 'Cerrar',
                      ),
                    ],
                  ),
                  const SizedBox(height: Dimen.espacio2),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controlador,
                          autofocus: true,
                          onChanged: (v) => setState(() => _texto = v),
                          style: const TextStyle(fontSize: 15, color: Colores.tinta),
                          decoration: InputDecoration(
                            hintText: widget.pista,
                            prefixIcon: const Icon(
                              Icons.search,
                              size: 19,
                              color: Colores.tintaTenue,
                            ),
                            constraints: const BoxConstraints(minHeight: Dimen.campoMd),
                          ),
                        ),
                      ),
                      if (widget.filtros.isNotEmpty) ...[
                        const SizedBox(width: Dimen.espacio2),
                        BotonFiltrosEnLinea(
                          activo: _filtrosAbiertos || _filtros.values.any((v) => v != null),
                          onTap: () => setState(() => _filtrosAbiertos = !_filtrosAbiertos),
                        ),
                      ],
                    ],
                  ),
                  if (_filtrosAbiertos && widget.filtros.isNotEmpty) ...[
                    const SizedBox(height: Dimen.espacio3),
                    Wrap(
                      spacing: Dimen.espacio2,
                      runSpacing: Dimen.espacio2,
                      children: [
                        for (final f in widget.filtros)
                          FiltroEnLinea(
                            etiqueta: f.etiqueta,
                            valor: _filtros[f.etiqueta],
                            opciones: _opcionesDe(f),
                            onChanged: (v) => setState(() => _filtros[f.etiqueta] = v),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: Dimen.espacio3),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${visibles.length} resultado${visibles.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
                    ),
                  ),
                  const SizedBox(height: Dimen.espacio2),
                ],
              ),
            ),
            Expanded(
              child: visibles.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(Dimen.espacio6),
                        child: Text(
                          'Nada coincide con lo que buscaste.',
                          style: TextStyle(fontSize: 14, color: Colores.tintaSuave),
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(
                        Dimen.espacio4,
                        0,
                        Dimen.espacio4,
                        Dimen.espacio6,
                      ),
                      itemCount: visibles.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: Colores.linea),
                      itemBuilder: (_, i) => _Fila<T>(
                        item: visibles[i],
                        titulo: widget.titulos,
                        subtitulo: widget.subtitulos,
                        onElegir: (item) => Navigator.of(context).pop(item),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
