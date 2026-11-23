# Fotografías de Bel-Aaktun

Esta carpeta está vacía a propósito: no se incluyeron imágenes de stock ni
fotografías inventadas.

La interfaz usa `BelArtwork`, un marcador visual dibujado en código (arco de
cueva + tejido de jipi) que respeta la paleta de la marca.

## Cómo colocar las fotografías reales

1. Copia aquí los archivos, por ejemplo:

   ```
   assets/images/cueva_portada.jpg
   assets/images/sombrero_jipi.jpg
   assets/images/artesano_01.jpg
   ```

2. Asigna la ruta en `lib/data/demo_content.dart` (campo `imagePath` de cada
   `Product`, `Artisan` o `CaveLocation`).

3. No hace falta tocar `pubspec.yaml`: la carpeta completa ya está declarada
   como asset.

En cuanto un elemento tenga `imagePath`, `BelArtwork` muestra la fotografía en
lugar del marcador dibujado, con el mismo recorte y los mismos degradados.
