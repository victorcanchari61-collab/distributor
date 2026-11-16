import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/csv.dart';
import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_buscador.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_hoja.dart';
import '../../../compartido/widgets/app_pestanas.dart';
import '../../../compartido/widgets/app_shell.dart';
import '../../../compartido/widgets/app_vacio.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/almacen.dart';
import '../estado/inventario_controlador.dart';

// El amarillo de lo que coincide con la busqueda: el mismo de la web
// (amber-100/500/700).
const _ambarFondo = Color(0xFFFEF3C7);
const _ambarBorde = Color(0xFFF59E0B);
const _ambarTinta = Color(0xFFB45309);

/// La clave del plano de los lugares que no cuelgan de ningun piso: el unico
/// plano de un almacen sin pisos.
const _sinPiso = 0;

/// Lo que se le dice a quien encuentra un plano vacio: aqui solo se mira.
const _dondeSeDibuja =
    'El plano se dibuja desde el panel web, en Inventario → Plano del almacén.';

/// Cuantas coincidencias se listan bajo el buscador antes de pedir que se
/// escriba algo mas.
const _maximoResultados = 6;

/// Plano del almacen: cada piso dibujado como se ve desde arriba, con sus
/// lugares, pasillos y escaleras.
///
/// Es de consulta: sirve para que el almacenero o el repartidor encuentre un
/// producto sin saberse las rutas de memoria. Se busca el producto y se
/// iluminan los lugares donde esta. El plano se dibuja desde el panel web.
class PlanoAlmacenPagina extends ConsumerStatefulWidget {
  const PlanoAlmacenPagina({super.key});

  static const ruta = '/inv/plano';

  @override
  ConsumerState<PlanoAlmacenPagina> createState() => _PlanoAlmacenPaginaState();
}

class _PlanoAlmacenPaginaState extends ConsumerState<PlanoAlmacenPagina> {
  /// El plano que esta acercado ("almacen-piso"). Mientras lo esta, la pagina
  /// no se desliza: arrastrar el dedo mueve el plano y no la lista.
  String? _claveAmpliada;

  @override
  Widget build(BuildContext context) {
    final grupo = resolverRuta(PlanoAlmacenPagina.ruta).grupo;
    final color = grupo?.color ?? Colores.marca;

    return AppShell(
      titulo: 'Plano del almacén',
      subtitulo: grupo?.titulo,
      acentado: color,
      rutaActual: PlanoAlmacenPagina.ruta,
      child: _contenido(context),
    );
  }

  Widget _contenido(BuildContext context) {
    final almacenes = ref.watch(almacenesActivosProvider);
    final opciones = ref.watch(almacenesOpcionesProvider);

    // Sin elegir, el principal (o el primero que haya).
    final elegido = ref.watch(almacenPlanoProvider);
    final almacenId =
        elegido ??
        (almacenes.isEmpty
            ? null
            : (almacenes.where((a) => a.esPrincipal).firstOrNull ??
                      almacenes.first)
                  .id);

    if (almacenId == null) {
      return _Desplazable(
        onRecargar: () async {
          ref.invalidate(almacenesOpcionesProvider);
          await _esperar([ref.read(almacenesOpcionesProvider.future)]);
        },
        hijos: [
          if (opciones.isLoading)
            const _Cargando()
          else if (opciones.hasError)
            _Error(
              opciones.error!,
              titulo: 'No se pudieron cargar los almacenes',
            )
          else
            const AppVacio(
              icono: Icons.warehouse_outlined,
              titulo: 'No hay almacenes',
            ),
        ],
      );
    }

    final ubicaciones = ref.watch(ubicacionesProvider(almacenId));
    final plano = ref.watch(planoAlmacenProvider(almacenId));
    final productos = ref.watch(productosUbicadosProvider(almacenId));
    final busqueda = ref.watch(busquedaPlanoProvider);

    Future<void> recargar() async {
      ref.invalidate(ubicacionesProvider(almacenId));
      ref.invalidate(planoAlmacenProvider(almacenId));
      ref.invalidate(productosUbicadosProvider(almacenId));
      await _esperar([
        ref.read(ubicacionesProvider(almacenId).future),
        ref.read(planoAlmacenProvider(almacenId).future),
        ref.read(productosUbicadosProvider(almacenId).future),
      ]);
    }

    final pestanasAlmacen = almacenes.length < 2
        ? null
        : AppPestanas<int>(
            activa: almacenId,
            onCambio: (v) {
              ref.read(almacenPlanoProvider.notifier).state = v;
              // Un piso es de un almacen: en otro se arranca por el primero.
              ref.read(pisoPlanoProvider.notifier).state = null;
            },
            pestanas: [
              for (final a in almacenes)
                Pestana<int>(a.id, a.nombre, icono: Icons.warehouse_outlined),
            ],
          );

    final lista = ubicaciones.valueOrNull;
    final cuadricula = plano.valueOrNull;
    final error = ubicaciones.error ?? plano.error;

    if (lista == null || cuadricula == null) {
      return _Desplazable(
        onRecargar: recargar,
        hijos: [
          ?pestanasAlmacen,
          if (error != null && !ubicaciones.isLoading && !plano.isLoading)
            _Error(error, titulo: 'No se pudo cargar el plano')
          else
            const _Cargando(),
        ],
      );
    }

    if (!lista.any((u) => !u.esPiso)) {
      return _Desplazable(
        onRecargar: recargar,
        hijos: [
          ?pestanasAlmacen,
          const AppVacio(
            icono: Icons.layers_outlined,
            titulo: 'Este almacén todavía no tiene lugares',
            detalle: _dondeSeDibuja,
          ),
        ],
      );
    }

    final mapa = _MapaAlmacen(lista, cuadricula);

    // El piso elegido, si es de este almacen; si no, el primero.
    final pisoElegido = ref.watch(pisoPlanoProvider);
    final piso = mapa.claves.contains(pisoElegido)
        ? pisoElegido!
        : mapa.claves.first;

    // La busqueda: que productos coinciden y en que lugares estan.
    final texto = normalizarTitulo(busqueda);
    final items = productos.valueOrNull?.items ?? const <ProductoUbicado>[];
    final coincidencias = texto.isEmpty
        ? const <ProductoUbicado>[]
        : [
            for (final p in items)
              if (normalizarTitulo('${p.codigo} ${p.producto}').contains(texto))
                p,
          ];
    final resaltados = {
      for (final p in coincidencias)
        for (final l in p.lugares) l.ubicacionId,
    };

    void irALugar(int ubicacionId) {
      final lugar = mapa.porId[ubicacionId];
      if (lugar == null) return;
      FocusScope.of(context).unfocus();
      ref.read(pisoPlanoProvider.notifier).state = mapa.pisoDe(lugar);
      _verLugar(context, almacenId, lugar, coincidencias);
    }

    final clave = '$almacenId-$piso';
    final dibujados = mapa.dibujados(piso);
    final elementos = mapa.elementos(piso);
    final sinDibujar = mapa.sinDibujar(piso);

    return _Desplazable(
      onRecargar: recargar,
      fijo: _claveAmpliada == clave,
      hijos: [
        ?pestanasAlmacen,
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimen.espacio4,
            Dimen.espacio2,
            Dimen.espacio4,
            0,
          ),
          child: AppBuscador(
            valor: busqueda,
            onCambio: (t) => ref.read(busquedaPlanoProvider.notifier).state = t,
            pista: 'Buscar producto…',
          ),
        ),
        if (texto.isNotEmpty)
          _Resultados(
            coincidencias: coincidencias,
            cargando: productos.isLoading && productos.valueOrNull == null,
            error: productos.error,
            mapa: mapa,
            onLugar: irALugar,
          ),
        if (mapa.claves.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: Dimen.espacio2),
            child: AppPestanas<int>(
              activa: piso,
              onCambio: (v) => ref.read(pisoPlanoProvider.notifier).state = v,
              pestanas: [
                for (final k in mapa.claves)
                  Pestana<int>(
                    k,
                    mapa.titulo(k),
                    icono: Icons.layers_outlined,
                    // Buscando, cuantos lugares de ese piso tienen lo buscado.
                    contador: texto.isEmpty
                        ? null
                        : mapa
                              .lugaresDe(k)
                              .where((u) => resaltados.contains(u.id))
                              .length,
                  ),
              ],
            ),
          ),
        const SizedBox(height: Dimen.espacio2),
        if (dibujados.isEmpty && elementos.isEmpty)
          const AppVacio(
            icono: Icons.grid_off_outlined,
            titulo: 'Este piso todavía no está dibujado',
            detalle: _dondeSeDibuja,
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
            child: _Plano(
              key: ValueKey(clave),
              columnas: math.max(1, cuadricula.columnas),
              filas: math.max(1, cuadricula.filas),
              lugares: dibujados,
              elementos: elementos,
              destinos: {
                for (final e in elementos) e.id: mapa.destino(e, piso),
              },
              resaltados: resaltados,
              onTocar: (l) => _verLugar(context, almacenId, l, coincidencias),
              onAmpliado: (ampliado) =>
                  setState(() => _claveAmpliada = ampliado ? clave : null),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              Dimen.espacio4,
              Dimen.espacio2,
              Dimen.espacio4,
              0,
            ),
            child: Text(
              'Pellizca para acercar · toca un lugar para ver qué hay',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colores.tintaTenue),
            ),
          ),
        ],
        if (sinDibujar.isNotEmpty)
          _SinDibujar(
            lugares: sinDibujar,
            resaltados: resaltados,
            onTocar: (l) => _verLugar(context, almacenId, l, coincidencias),
          ),
        const SizedBox(height: Dimen.espacio6),
      ],
    );
  }

  void _verLugar(
    BuildContext context,
    int almacenId,
    Ubicacion lugar,
    List<ProductoUbicado> coincidencias,
  ) {
    abrirHoja<void>(
      context,
      (_) => _HojaLugar(
        almacenId: almacenId,
        lugar: lugar,
        buscados: {for (final p in coincidencias) p.productoId},
      ),
    );
  }
}

/// Espera a que terminen de recargar. Si alguna falla, el error ya lo pinta
/// la pantalla: aqui no hay nada mas que hacer con el.
Future<void> _esperar(List<Future<Object?>> cargas) async {
  try {
    await Future.wait(cargas);
  } on Object {
    return;
  }
}

/// Como se reparten los lugares del almacen entre los planos: uno por piso, y
/// uno aparte para lo que no cuelga de ningun piso (el unico, si no hay pisos).
class _MapaAlmacen {
  _MapaAlmacen(this.lista, this.plano)
    : porId = {for (final u in lista) u.id: u} {
    final pisos = [
      for (final u in lista)
        if (u.esPiso && u.padreId == null) u,
    ];
    claves = [
      for (final p in pisos) p.id,
      if (pisos.isEmpty || lista.any((u) => !u.esPiso && pisoDe(u) == _sinPiso))
        _sinPiso,
    ];
  }

  final List<Ubicacion> lista;
  final PlanoAlmacen plano;
  final Map<int, Ubicacion> porId;

  /// Los planos que hay, en orden: el id de cada piso o [_sinPiso].
  late final List<int> claves;

  /// El piso del que cuelga un lugar, subiendo por el arbol.
  int pisoDe(Ubicacion u) {
    if (u.esPiso) return u.id;
    var padreId = u.padreId;
    // Tope por si el arbol viniera con un ciclo: nunca debe colgar la pantalla.
    for (var i = 0; padreId != null && i < 32; i++) {
      final padre = porId[padreId];
      if (padre == null) break;
      if (padre.esPiso) return padre.id;
      padreId = padre.padreId;
    }
    return _sinPiso;
  }

  String titulo(int clave) {
    if (clave == _sinPiso) return 'Sin piso';
    final piso = porId[clave]!;
    final nombre = piso.nombre?.trim() ?? '';
    return nombre.isEmpty ? piso.codigo : '${piso.codigo} · $nombre';
  }

  /// Todos los lugares (no pisos) de un plano, dibujados o no.
  Iterable<Ubicacion> lugaresDe(int clave) =>
      lista.where((u) => !u.esPiso && pisoDe(u) == clave);

  /// Los que estan dibujados en ese plano: los que cuelgan directo del piso.
  List<Ubicacion> dibujados(int clave) => [
    for (final u in lista)
      if (!u.esPiso &&
          u.dibujado &&
          (clave == _sinPiso ? u.padreId == null : u.padreId == clave))
        u,
  ];

  /// Los pasillos y escaleras de un plano: los suyos y las escaleras que lo
  /// cruzan aunque arranquen en otro piso.
  List<ElementoPlano> elementos(int clave) => [
    for (final e in plano.elementos)
      if (clave == _sinPiso
          ? e.pisoId == null && e.pisos.isEmpty
          : e.pisoId == clave || e.pisos.contains(clave))
        e,
  ];

  /// A donde lleva una escalera desde el piso que se mira: "Sube a P2 · P3",
  /// "Baja a P1" o, en un piso del medio, las dos cosas. Los pisos van en el
  /// orden de [ElementoPlano.pisos] (de abajo hacia arriba); los de abajo, del
  /// mas cercano al mas lejano. Vacio si no es escalera o no cruza ese piso.
  String destino(ElementoPlano e, int clave) {
    if (!e.esEscalera) return '';
    final i = e.pisos.indexOf(clave);
    if (i < 0) return '';
    String codigos(Iterable<int> ids) => [
      for (final id in ids)
        if (porId[id] case final piso?) piso.codigo,
    ].join(' · ');
    final sube = codigos(e.pisos.skip(i + 1));
    final baja = codigos(e.pisos.take(i).toList().reversed);
    return [
      if (sube.isNotEmpty) 'Sube a $sube',
      if (baja.isNotEmpty) 'Baja a $baja',
    ].join(' — ');
  }

  /// Los lugares del plano que nadie dibujo todavia: se listan para que nada
  /// quede escondido.
  List<Ubicacion> sinDibujar(int clave) {
    final dibujadosIds = {for (final u in dibujados(clave)) u.id};
    return [
      for (final u in lugaresDe(clave))
        if (!dibujadosIds.contains(u.id)) u,
    ];
  }
}

/// La pagina deslizable, con jalar para recargar.
class _Desplazable extends StatelessWidget {
  const _Desplazable({
    required this.onRecargar,
    required this.hijos,
    this.fijo = false,
  });

  final Future<void> Function() onRecargar;
  final List<Widget> hijos;

  /// No se desliza: el plano esta acercado y el dedo lo mueve a el.
  final bool fijo;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRecargar,
      child: ListView(
        physics: fijo
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: Dimen.espacio2),
        children: hijos,
      ),
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(Dimen.espacio6),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _Error extends StatelessWidget {
  const _Error(this.error, {required this.titulo});

  final Object error;
  final String titulo;

  @override
  Widget build(BuildContext context) => AppVacio(
    icono: Icons.wifi_off_outlined,
    titulo: titulo,
    detalle: error is ApiExcepcion ? (error as ApiExcepcion).texto : null,
  );
}

// ------------------------------------------------------------------ Busqueda

/// Lo que coincide con lo buscado: cada producto con los lugares donde esta.
/// Tocar un lugar lleva a su piso y abre lo que hay ahi.
class _Resultados extends StatelessWidget {
  const _Resultados({
    required this.coincidencias,
    required this.cargando,
    required this.error,
    required this.mapa,
    required this.onLugar,
  });

  final List<ProductoUbicado> coincidencias;
  final bool cargando;
  final Object? error;
  final _MapaAlmacen mapa;
  final ValueChanged<int> onLugar;

  @override
  Widget build(BuildContext context) {
    final Widget cuerpo;
    if (cargando) {
      cuerpo = const Padding(
        padding: EdgeInsets.all(Dimen.espacio3),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (error != null) {
      cuerpo = _Mensaje(
        error is ApiExcepcion
            ? (error as ApiExcepcion).texto
            : 'No se pudieron cargar los productos.',
      );
    } else if (coincidencias.isEmpty) {
      cuerpo = const _Mensaje('Ningún producto coincide con lo que buscaste.');
    } else {
      final lugares = {
        for (final p in coincidencias)
          for (final l in p.lugares) l.ubicacionId,
      };
      final visibles = coincidencias.take(_maximoResultados).toList();
      final resto = coincidencias.length - visibles.length;
      cuerpo = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimen.espacio3,
              Dimen.espacio2,
              Dimen.espacio3,
              Dimen.espacio1,
            ),
            child: Text(
              '${coincidencias.length} '
              '${coincidencias.length == 1 ? 'producto' : 'productos'} · '
              '${lugares.length} ${lugares.length == 1 ? 'lugar' : 'lugares'}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colores.tintaSuave,
              ),
            ),
          ),
          for (var i = 0; i < visibles.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _FilaResultado(producto: visibles[i], mapa: mapa, onLugar: onLugar),
          ],
          if (resto > 0)
            _Mensaje('y $resto más: sigue escribiendo para acotar.'),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimen.espacio4,
        Dimen.espacio2,
        Dimen.espacio4,
        0,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colores.superficie,
          border: Border.all(color: Colores.linea),
          borderRadius: BorderRadius.circular(Dimen.radioCampo),
        ),
        child: cuerpo,
      ),
    );
  }
}

class _FilaResultado extends StatelessWidget {
  const _FilaResultado({
    required this.producto,
    required this.mapa,
    required this.onLugar,
  });

  final ProductoUbicado producto;
  final _MapaAlmacen mapa;
  final ValueChanged<int> onLugar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimen.espacio3,
        vertical: Dimen.espacio2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            producto.producto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
          Text(
            producto.codigo,
            style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
          ),
          const SizedBox(height: 6),
          if (producto.sinLugar)
            const AppEtiqueta('Sin lugar', tono: EtiquetaTono.aviso)
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final l in producto.lugares)
                  _ChipLugar(
                    lugar: l,
                    // Si el lugar no esta en este almacen (no deberia), no lleva a nada.
                    onTap: mapa.porId.containsKey(l.ubicacionId)
                        ? () => onLugar(l.ubicacionId)
                        : null,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ChipLugar extends StatelessWidget {
  const _ChipLugar({required this.lugar, this.onTap});

  final LugarDeProducto lugar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ambarFondo,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: _ambarBorde),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.place_outlined, size: 14, color: _ambarTinta),
              const SizedBox(width: 4),
              Text(
                lugar.nombre == null
                    ? lugar.ruta
                    : '${lugar.ruta} · ${lugar.nombre}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _ambarTinta,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(Dimen.espacio3),
    child: Text(
      texto,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
    ),
  );
}

// --------------------------------------------------------------------- Plano

/// El plano de un piso: la cuadricula con sus lugares, pasillos y escaleras.
///
/// Ocupa el ancho de la pantalla y se acerca pellizcando. Mientras esta
/// acercado avisa con [onAmpliado], para que la pagina deje de deslizarse.
class _Plano extends StatefulWidget {
  const _Plano({
    super.key,
    required this.columnas,
    required this.filas,
    required this.lugares,
    required this.elementos,
    this.destinos = const {},
    required this.resaltados,
    required this.onTocar,
    required this.onAmpliado,
  });

  final int columnas;
  final int filas;
  final List<Ubicacion> lugares;
  final List<ElementoPlano> elementos;

  /// Por id de escalera, a donde lleva desde este piso ("Sube a P2").
  final Map<int, String> destinos;

  /// Los ids de los lugares que tienen lo que se busca.
  final Set<int> resaltados;
  final ValueChanged<Ubicacion> onTocar;
  final ValueChanged<bool> onAmpliado;

  @override
  State<_Plano> createState() => _PlanoState();
}

class _PlanoState extends State<_Plano> {
  final _transformacion = TransformationController();
  bool _ampliado = false;

  @override
  void initState() {
    super.initState();
    _transformacion.addListener(_alMover);
  }

  @override
  void dispose() {
    _transformacion
      ..removeListener(_alMover)
      ..dispose();
    super.dispose();
  }

  void _alMover() {
    final ampliado = _transformacion.value.getMaxScaleOnAxis() > 1.01;
    if (ampliado == _ampliado) return;
    setState(() => _ampliado = ampliado);
    widget.onAmpliado(ampliado);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, caja) {
        final ancho = caja.maxWidth;
        final celda = ancho / widget.columnas;
        final alto = celda * widget.filas;

        Widget rectangulo(int x, int y, int an, int al, Widget hijo) =>
            Positioned(
              left: x * celda,
              top: y * celda,
              width: math.max(1, an) * celda,
              height: math.max(1, al) * celda,
              child: Padding(padding: const EdgeInsets.all(1), child: hijo),
            );

        return Container(
          decoration: BoxDecoration(
            color: Colores.fondo,
            border: Border.all(color: Colores.lineaFuerte),
            borderRadius: BorderRadius.circular(Dimen.radioCampo),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              SizedBox(
                width: ancho,
                height: alto,
                child: InteractiveViewer(
                  transformationController: _transformacion,
                  minScale: 1,
                  maxScale: 6,
                  child: SizedBox(
                    width: ancho,
                    height: alto,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _PintorCuadricula(
                              columnas: widget.columnas,
                              filas: widget.filas,
                            ),
                          ),
                        ),
                        for (final e in widget.elementos)
                          rectangulo(
                            e.x,
                            e.y,
                            e.ancho,
                            e.alto,
                            _CajaElemento(
                              elemento: e,
                              destino: widget.destinos[e.id] ?? '',
                            ),
                          ),
                        for (final l in widget.lugares)
                          if (l.planoPartes.isEmpty)
                            rectangulo(
                              l.planoX!,
                              l.planoY!,
                              l.planoAncho!,
                              l.planoAlto!,
                              _CajaLugar(
                                lugar: l,
                                resaltado: widget.resaltados.contains(l.id),
                                onTap: () => widget.onTocar(l),
                              ),
                            )
                          else
                            _figura(l, celda),
                      ],
                    ),
                  ),
                ),
              ),
              if (_ampliado)
                Positioned(
                  top: 6,
                  right: 6,
                  child: IconButton.filledTonal(
                    tooltip: 'Ver el plano entero',
                    icon: const Icon(Icons.zoom_out_map, size: 18),
                    onPressed: () => _transformacion.value = Matrix4.identity(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Un lugar con partes de mas (en forma de L): una sola figura del tamaño
  /// de la caja que lo encierra, que solo pinta y responde en sus celdas.
  Widget _figura(Ubicacion l, double celda) {
    final forma = _FormaLugar.de(l);
    final caja = forma.caja;
    return Positioned(
      left: caja.left * celda,
      top: caja.top * celda,
      width: caja.width * celda,
      height: caja.height * celda,
      child: _FiguraLugar(
        lugar: l,
        forma: forma,
        celda: celda,
        resaltado: widget.resaltados.contains(l.id),
        onTap: () => widget.onTocar(l),
      ),
    );
  }
}

/// Las celdas que ocupa un lugar con partes: la union de su rectangulo
/// principal y sus partes, en celdas de la cuadricula.
class _FormaLugar {
  _FormaLugar._(this.celdas, this.caja, this.principal);

  factory _FormaLugar.de(Ubicacion l) {
    Rect rect(int x, int y, int ancho, int alto) => Rect.fromLTWH(
      x.toDouble(),
      y.toDouble(),
      math.max(1, ancho).toDouble(),
      math.max(1, alto).toDouble(),
    );
    final principal = rect(l.planoX!, l.planoY!, l.planoAncho!, l.planoAlto!);
    final rects = [
      principal,
      for (final p in l.planoPartes) rect(p.x, p.y, p.ancho, p.alto),
    ];
    final celdas = <(int, int)>{
      for (final r in rects)
        for (var x = r.left.toInt(); x < r.right.toInt(); x++)
          for (var y = r.top.toInt(); y < r.bottom.toInt(); y++) (x, y),
    };
    return _FormaLugar._(
      celdas,
      rects.reduce((a, b) => a.expandToInclude(b)),
      principal,
    );
  }

  final Set<(int, int)> celdas;

  /// El rectangulo que encierra toda la figura.
  final Rect caja;

  /// El rectangulo principal: ahi van el codigo, el nombre y el contador.
  final Rect principal;

  /// El contorno de la figura en pixeles, relativo a [caja]. Se arma celda
  /// por celda: el borde de cada una queda solo donde no sigue el lugar.
  Path contorno(double celda) {
    var camino = Path();
    for (final (x, y) in celdas) {
      camino = Path.combine(
        PathOperation.union,
        camino,
        Path()..addRect(
          Rect.fromLTWH(
            (x - caja.left) * celda,
            (y - caja.top) * celda,
            celda,
            celda,
          ),
        ),
      );
    }
    return camino;
  }
}

/// Recorta la figura, y lo que se puede tocar, a las celdas del lugar.
class _RecorteForma extends CustomClipper<Path> {
  const _RecorteForma(this.forma, this.celda);

  final _FormaLugar forma;
  final double celda;

  @override
  Path getClip(Size size) => forma.contorno(celda);

  @override
  bool shouldReclip(_RecorteForma anterior) =>
      anterior.forma != forma || anterior.celda != celda;
}

/// El relleno y el borde de una figura de varias partes. El borde va solo por
/// fuera: no hay linea donde se tocan sus rectangulos.
class _PintorForma extends CustomPainter {
  const _PintorForma({
    required this.forma,
    required this.celda,
    required this.relleno,
    required this.borde,
    required this.grosor,
  });

  final _FormaLugar forma;
  final double celda;
  final Color relleno;
  final Color borde;
  final double grosor;

  /// El hueco con lo de al lado: el mismo que deja cada caja suelta.
  static const _hueco = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final contorno = forma.contorno(celda);
    canvas.save();
    canvas.clipPath(contorno);
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawPath(contorno, Paint()..color = relleno);
    // El recorte se come la mitad de afuera del trazo: lo que queda es el
    // hueco mas el borde, por dentro.
    canvas.drawPath(
      contorno,
      Paint()
        ..color = borde
        ..style = PaintingStyle.stroke
        ..strokeWidth = (_hueco + grosor) * 2,
    );
    // El hueco se borra para que se vea la cuadricula de abajo.
    canvas.drawPath(
      contorno,
      Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.stroke
        ..strokeWidth = _hueco * 2,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorForma anterior) =>
      anterior.forma != forma ||
      anterior.celda != celda ||
      anterior.relleno != relleno ||
      anterior.borde != borde ||
      anterior.grosor != grosor;
}

/// Un lugar con partes de mas, dibujado como una sola figura. El codigo, el
/// nombre y el contador van una vez, en el rectangulo principal; tocar
/// cualquier parte abre el lugar.
class _FiguraLugar extends StatelessWidget {
  const _FiguraLugar({
    required this.lugar,
    required this.forma,
    required this.celda,
    required this.resaltado,
    required this.onTap,
  });

  final Ubicacion lugar;
  final _FormaLugar forma;
  final double celda;
  final bool resaltado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final principal = forma.principal;
    final caja = forma.caja;
    return Opacity(
      opacity: lugar.activo ? 1 : 0.45,
      child: ClipPath(
        clipper: _RecorteForma(forma, celda),
        child: CustomPaint(
          painter: _PintorForma(
            forma: forma,
            celda: celda,
            relleno: resaltado ? _ambarFondo : Colores.superficie,
            borde: resaltado ? _ambarBorde : Colores.tinta,
            grosor: resaltado ? 2 : 1.2,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                children: [
                  // Como en una caja suelta: el hueco de 1 y el rotulo adentro.
                  Positioned(
                    left: (principal.left - caja.left) * celda + 1,
                    top: (principal.top - caja.top) * celda + 1,
                    width: math.max(1, principal.width * celda - 2),
                    height: math.max(1, principal.height * celda - 2),
                    child: _RotuloLugar(lugar: lugar, resaltado: resaltado),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Un lugar del plano: su codigo, su nombre y cuantos productos tiene.
class _CajaLugar extends StatelessWidget {
  const _CajaLugar({
    required this.lugar,
    required this.resaltado,
    required this.onTap,
  });

  final Ubicacion lugar;
  final bool resaltado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final forma = RoundedRectangleBorder(
      side: BorderSide(
        color: resaltado ? _ambarBorde : Colores.tinta,
        width: resaltado ? 2 : 1.2,
      ),
      borderRadius: BorderRadius.circular(3),
    );

    return Opacity(
      opacity: lugar.activo ? 1 : 0.45,
      child: Material(
        color: resaltado ? _ambarFondo : Colores.superficie,
        shape: forma,
        child: InkWell(
          customBorder: forma,
          onTap: onTap,
          child: _RotuloLugar(lugar: lugar, resaltado: resaltado),
        ),
      ),
    );
  }
}

/// Lo que se lee dentro de un lugar: codigo y nombre arriba a la izquierda y,
/// si tiene, cuantos productos abajo a la derecha.
class _RotuloLugar extends StatelessWidget {
  const _RotuloLugar({required this.lugar, required this.resaltado});

  final Ubicacion lugar;
  final bool resaltado;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, caja) {
        // La letra crece con la caja: en un lugar chico no se desborda,
        // y al acercar el plano se lee igual de nitida.
        final letra = (math.min(caja.maxWidth, caja.maxHeight) / 3.2).clamp(
          5.0,
          12.0,
        );
        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: math.max(1, caja.maxWidth - 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lugar.codigo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: letra,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: resaltado ? _ambarTinta : Colores.tinta,
                        ),
                      ),
                      if (lugar.nombre != null &&
                          lugar.nombre!.trim().isNotEmpty)
                        Text(
                          lugar.nombre!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: letra * 0.85,
                            height: 1.1,
                            color: Colores.tintaSuave,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (lugar.productos > 0)
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: letra * 0.4,
                    vertical: letra * 0.1,
                  ),
                  decoration: BoxDecoration(
                    color: resaltado ? _ambarBorde : Acento.de(context),
                    borderRadius: BorderRadius.circular(letra),
                  ),
                  child: Text(
                    '${lugar.productos}',
                    style: TextStyle(
                      fontSize: letra * 0.8,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Un pasillo o una escalera: se dibujan pero no guardan mercaderia.
class _CajaElemento extends StatelessWidget {
  const _CajaElemento({required this.elemento, this.destino = ''});

  final ElementoPlano elemento;

  /// Solo escaleras: a donde lleva desde el piso que se mira. Vacio, nada.
  final String destino;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PintorElemento(escalera: elemento.esEscalera),
      child: LayoutBuilder(
        builder: (context, caja) {
          final letra = (math.min(caja.maxWidth, caja.maxHeight) / 3).clamp(
            5.0,
            11.0,
          );
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      color: const Color(0xD9FFFFFF),
                      child: Text(
                        elemento.nombre,
                        style: TextStyle(
                          fontSize: letra,
                          fontWeight: FontWeight.w600,
                          color: Colores.tintaSuave,
                        ),
                      ),
                    ),
                    if (destino.isNotEmpty) ...[
                      SizedBox(height: letra * 0.2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: Acento.de(context),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          destino,
                          style: TextStyle(
                            fontSize: letra * 0.85,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Las lineas tenues de la cuadricula, una por celda.
class _PintorCuadricula extends CustomPainter {
  const _PintorCuadricula({required this.columnas, required this.filas});

  final int columnas;
  final int filas;

  @override
  void paint(Canvas canvas, Size size) {
    final lapiz = Paint()
      ..color = Colores.linea
      ..strokeWidth = 0.5;
    final ancho = size.width / columnas;
    final alto = size.height / filas;
    for (var c = 1; c < columnas; c++) {
      canvas.drawLine(
        Offset(c * ancho, 0),
        Offset(c * ancho, size.height),
        lapiz,
      );
    }
    for (var f = 1; f < filas; f++) {
      canvas.drawLine(Offset(0, f * alto), Offset(size.width, f * alto), lapiz);
    }
  }

  @override
  bool shouldRepaint(_PintorCuadricula anterior) =>
      anterior.columnas != columnas || anterior.filas != filas;
}

/// El relleno de un pasillo (rayas en diagonal y borde punteado) o de una
/// escalera (peldaños horizontales), como en el panel web.
class _PintorElemento extends CustomPainter {
  const _PintorElemento({required this.escalera});

  final bool escalera;

  static const _separacion = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final caja = Offset.zero & size;
    canvas.drawRect(
      caja,
      Paint()..color = escalera ? Colores.fondo : const Color(0xFFF1F5F9),
    );

    final rayas = Paint()
      ..color = Colores.lineaFuerte
      ..strokeWidth = 1;
    canvas.save();
    canvas.clipRect(caja);
    if (escalera) {
      for (var y = _separacion; y < size.height; y += _separacion) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), rayas);
      }
    } else {
      for (var d = -size.height; d < size.width; d += _separacion) {
        canvas.drawLine(
          Offset(d, size.height),
          Offset(d + size.height, 0),
          rayas,
        );
      }
    }
    canvas.restore();

    final borde = Paint()
      ..color = Colores.tintaTenue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (escalera) {
      canvas.drawRect(caja.deflate(0.5), borde);
    } else {
      _punteado(canvas, caja.deflate(0.5), borde);
    }
  }

  /// Un rectangulo con borde de guiones.
  void _punteado(Canvas canvas, Rect r, Paint lapiz) {
    const guion = 3.0;
    const hueco = 2.0;
    void linea(Offset a, Offset b) {
      final largo = (b - a).distance;
      if (largo == 0) return;
      final paso = (b - a) / largo;
      for (var t = 0.0; t < largo; t += guion + hueco) {
        canvas.drawLine(
          a + paso * t,
          a + paso * math.min(t + guion, largo),
          lapiz,
        );
      }
    }

    linea(r.topLeft, r.topRight);
    linea(r.topRight, r.bottomRight);
    linea(r.bottomRight, r.bottomLeft);
    linea(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(_PintorElemento anterior) => anterior.escalera != escalera;
}

// ------------------------------------------------------------- Sin dibujar

/// Los lugares de este piso que todavia no estan en el plano: igual se ven y
/// se puede mirar que tienen.
class _SinDibujar extends StatelessWidget {
  const _SinDibujar({
    required this.lugares,
    required this.resaltados,
    required this.onTocar,
  });

  final List<Ubicacion> lugares;
  final Set<int> resaltados;
  final ValueChanged<Ubicacion> onTocar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimen.espacio4,
        Dimen.espacio5,
        Dimen.espacio4,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sin dibujar en el plano (${lugares.length})',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colores.tintaSuave,
            ),
          ),
          const SizedBox(height: Dimen.espacio2),
          for (final l in lugares) ...[
            _FilaSinDibujar(
              lugar: l,
              resaltado: resaltados.contains(l.id),
              onTap: () => onTocar(l),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _FilaSinDibujar extends StatelessWidget {
  const _FilaSinDibujar({
    required this.lugar,
    required this.resaltado,
    required this.onTap,
  });

  final Ubicacion lugar;
  final bool resaltado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: lugar.activo ? 1 : 0.6,
      child: Material(
        color: resaltado ? _ambarFondo : Colores.superficie,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: resaltado ? _ambarBorde : Colores.linea),
          borderRadius: BorderRadius.circular(Dimen.radioCampo),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Dimen.radioCampo),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimen.espacio3,
              vertical: 10,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 20,
                  color: resaltado ? _ambarTinta : Acento.de(context),
                ),
                const SizedBox(width: Dimen.espacio3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lugar.ruta,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        lugar.nombre ?? lugar.tipoEtiqueta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colores.tintaSuave,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!lugar.activo)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: AppEtiqueta('Inactivo'),
                  ),
                if (lugar.productos > 0)
                  AppEtiqueta(
                    '${lugar.productos} '
                    '${lugar.productos == 1 ? 'producto' : 'productos'}',
                    tono: EtiquetaTono.modulo,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- Hoja

/// Lo que esta puesto en un lugar, con el stock de cada producto.
///
/// Sale de la lista de productos ubicados del almacen, que ya trae stock y
/// unidad: el detalle por lugar pide el permiso de Almacenes y quien solo mira
/// el plano no lo tiene.
class _HojaLugar extends ConsumerWidget {
  const _HojaLugar({
    required this.almacenId,
    required this.lugar,
    required this.buscados,
  });

  final int almacenId;
  final Ubicacion lugar;

  /// Los productos que coinciden con la busqueda: van primero y resaltados.
  final Set<int> buscados;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(productosUbicadosProvider(almacenId));

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoHoja(
              lugar.ruta,
              subtitulo: [
                lugar.tipoEtiqueta,
                if (lugar.nombre != null) lugar.nombre!,
                if (!lugar.activo) 'Inactivo',
              ].join(' · '),
            ),
            Flexible(
              child: datos.when(
                loading: () => const _Cargando(),
                error: (e, _) => _Mensaje(
                  e is ApiExcepcion ? e.texto : 'No se pudo cargar.',
                ),
                data: (d) {
                  final aqui = [
                    for (final p in d.items)
                      if (p.lugares.any((l) => l.ubicacionId == lugar.id)) p,
                  ];
                  // Lo buscado arriba; el resto, por nombre.
                  aqui.sort((a, b) {
                    final ba = buscados.contains(a.productoId) ? 0 : 1;
                    final bb = buscados.contains(b.productoId) ? 0 : 1;
                    return ba != bb
                        ? ba - bb
                        : a.producto.compareTo(b.producto);
                  });

                  if (aqui.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: Dimen.espacio5),
                      child: _Mensaje(
                        'No hay productos puestos en este lugar.',
                      ),
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Dimen.espacio4,
                          Dimen.espacio3,
                          Dimen.espacio4,
                          0,
                        ),
                        child: Text(
                          '${aqui.length} '
                          '${aqui.length == 1 ? 'producto' : 'productos'} · '
                          'stock del almacén',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colores.tintaSuave,
                          ),
                        ),
                      ),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(
                            Dimen.espacio4,
                            Dimen.espacio1,
                            Dimen.espacio4,
                            Dimen.espacio4,
                          ),
                          itemCount: aqui.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final p = aqui[i];
                            final buscado = buscados.contains(p.productoId);
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: buscado
                                  ? const Icon(
                                      Icons.search,
                                      size: 18,
                                      color: _ambarTinta,
                                    )
                                  : null,
                              minLeadingWidth: 0,
                              title: Text(
                                p.producto,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  p.codigo,
                                  if (p.categoria != null) p.categoria!,
                                ].join(' · '),
                              ),
                              trailing: Text(
                                '${formatoNumero(p.stock)} ${p.unidadBase}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: p.stock > 0
                                      ? Colores.tinta
                                      : Colores.tintaTenue,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
