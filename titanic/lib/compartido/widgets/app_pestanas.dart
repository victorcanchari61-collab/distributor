import 'package:flutter/material.dart';

import '../../core/tema/acento.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';

/// Una pestaña: su valor, el texto y, si se quiere, un ícono y cuántos
/// registros tiene.
class Pestana<T> {
  const Pestana(this.valor, this.texto, {this.icono, this.contador});

  final T valor;
  final String texto;
  final IconData? icono;

  /// El número al costado, como en el panel web: cuántos registros tiene.
  final int? contador;
}

/// Un nombre que llega TODO EN MAYÚSCULAS desde los datos ("TIENDA 1",
/// "SEGUNDO PISO") se muestra como "Tienda 1": en mayúsculas una fila de
/// pestañas se lee como un grito y cuesta distinguir una de otra. Solo se toca
/// lo que viene entero en mayúsculas; un nombre escrito a mano ("Por rol")
/// queda como está. Es el mismo `legible` del `Tabs` del panel web.
String textoLegible(String texto) {
  final letras = texto.replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚÜÑáéíóúüñ]'), '');
  if (letras.length < 2 || letras != letras.toUpperCase()) return texto;
  final bajo = texto.toLowerCase();
  return bajo.substring(0, 1).toUpperCase() + bajo.substring(1);
}

/// Las pestañas de una vista, iguales a las del panel web (`Tabs`).
///
/// Se usan cuando varias tablas pequeñas pertenecen al mismo tema y no merecen
/// entrada propia en el menú: las categorías, marcas y unidades viven dentro de
/// Productos; la Bóveda, dentro de Cajas. Se deslizan de lado cuando no entran
/// todas en el ancho del teléfono.
///
/// Van juntas dentro de un rectángulo con fondo gris y borde fino, que las
/// separa de lo que hay arriba y abajo. Cada pestaña es una tarjetita blanca
/// con borde; la activa se rellena con el color del módulo, igual que su
/// contador.
///
/// Van en el hueco `pestanas` de `AppListaPagina`, arriba de todo, en el mismo
/// lugar que en la web.
class AppPestanas<T> extends StatefulWidget {
  const AppPestanas({
    super.key,
    required this.pestanas,
    required this.activa,
    required this.onCambio,
  });

  final List<Pestana<T>> pestanas;
  final T activa;
  final ValueChanged<T> onCambio;

  @override
  State<AppPestanas<T>> createState() => _AppPestanasState<T>();
}

class _AppPestanasState<T> extends State<AppPestanas<T>> {
  /// La pestaña activa, para traerla a la vista.
  final _llaveActiva = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Al cambiar de pestaña la vista suele armarse de nuevo, y con ella esta
    // fila, que arrancaba desplazada al inicio: elegir "Unidades" dejaba la
    // activa fuera de la pantalla. Aquí aparece ya en su sitio, sin animar.
    _mostrarActiva(animado: false);
  }

  @override
  void didUpdateWidget(covariant AppPestanas<T> anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.activa != widget.activa) _mostrarActiva(animado: true);
  }

  /// Desliza la fila lo justo para que la pestaña activa se vea entera.
  void _mostrarActiva({required bool animado}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contexto = _llaveActiva.currentContext;
      if (!mounted || contexto == null) return;
      // Solo esta fila: `Scrollable.ensureVisible` movería también la lista
      // vertical de la página para centrar la pestaña.
      final fila = Scrollable.maybeOf(contexto);
      final caja = contexto.findRenderObject();
      if (fila == null || caja == null) return;
      fila.position.ensureVisible(
        caja,
        // 0.5: centrada cuando se puede, así se ven también sus vecinas.
        alignment: 0.5,
        duration: animado ? const Duration(milliseconds: 250) : Duration.zero,
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final acento = Acento.de(context);
    final pestanas = widget.pestanas;
    final activa = widget.activa;

    // Lo que se desliza es el envoltorio, no el rectángulo: así el borde
    // redondo no se recorta y el rectángulo mide lo que sus pestañas.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: Dimen.espacio3,
        vertical: 6,
      ),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0xB3E2E8F0),
          border: Border.all(color: Colores.linea),
          borderRadius: BorderRadius.circular(Dimen.radioCampo),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < pestanas.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              _Pestana(
                key: pestanas[i].valor == activa ? _llaveActiva : null,
                pestana: pestanas[i],
                activa: pestanas[i].valor == activa,
                acento: acento,
                onTap: () {
                  if (pestanas[i].valor != activa) {
                    widget.onCambio(pestanas[i].valor);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pestana<T> extends StatelessWidget {
  const _Pestana({
    super.key,
    required this.pestana,
    required this.activa,
    required this.acento,
    required this.onTap,
  });

  final Pestana<T> pestana;
  final bool activa;
  final Color acento;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // El texto de la activa va un poco más oscuro que el acento, para que se
    // lea sobre su propio tinte.
    final tinta = Color.lerp(acento, Colores.tinta, 0.25)!;
    final radio = BorderRadius.circular(9);

    return Material(
      color: activa
          ? Color.alphaBlend(acento.withValues(alpha: 0.12), Colores.superficie)
          : Colores.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: radio,
        // El borde más grueso hace de "anillo" de la activa.
        side: BorderSide(
          color: activa ? acento : Colores.linea,
          width: activa ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radio,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pestana.icono != null) ...[
                Icon(
                  pestana.icono,
                  size: 16,
                  color: activa ? acento : Colores.tintaTenue,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                textoLegible(pestana.texto),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
                  color: activa ? tinta : Colores.tintaSuave,
                ),
              ),
              if (pestana.contador != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: activa ? acento : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${pestana.contador}',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      color: activa ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
