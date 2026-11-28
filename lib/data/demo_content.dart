/// Contenido de demostración de Bel-Aaktun.
///
/// ⚠️ Estos textos, precios y nombres son de ejemplo: no son datos reales de
/// artesanos ni de talleres. Existen para que la interfaz se pueda revisar
/// completa. Sustituye este archivo por tu repositorio/API (`GET /artesanos`,
/// `GET /productos`, `GET /cuevas`) manteniendo las entidades de `models.dart`.
library;

import '../core/config/app_config.dart';
import 'models.dart';

abstract final class DemoContent {
  static const List<String> categories = [
    'Todo',
    'Sombreros',
    'Bolsos',
    'Decoración',
    'Miniaturas',
  ];

  static const List<Artisan> sampleArtisans = [
    Artisan(
      id: 'art-01',
      name: 'Doña Elena Chan',
      craft: 'Tejedora de Jipi Japa',
      cave: 'Cueva La Esperanza',
      bio:
          'Aprendió el tejido a los nueve años, sentada en el suelo de la cueva '
          'familiar. Hoy forma a las nuevas tejedoras de Bécal y firma cada '
          'sombrero con las iniciales de su madre.',
      techniques: ['Tejido fino', 'Remate a mano', 'Planchado con palma'],
      yearsOfCraft: 32,
    ),
    Artisan(
      id: 'art-02',
      name: 'Don Aurelio Poot',
      craft: 'Sombrerero tradicional',
      cave: 'Cueva El Rosario',
      bio:
          'Especialista en sombreros de ala ancha. Trabaja la palma húmeda al '
          'amanecer, cuando la fibra cede sin romperse, y deja secar cada pieza '
          'tres días en penumbra.',
      techniques: [
        'Tejido de ala ancha',
        'Bloqueado en madera',
        'Acabado natural',
      ],
      yearsOfCraft: 41,
    ),
    Artisan(
      id: 'art-03',
      name: 'Taller Ik’al',
      craft: 'Bolsos y fibras',
      cave: 'Cueva San Miguel',
      bio:
          'Un taller familiar de tres generaciones que combina la palma con '
          'tintes de corteza y semillas. Cada bolso lleva el nombre de la '
          'cueva donde fue tejido.',
      techniques: ['Tintes naturales', 'Tejido abierto', 'Forro en manta'],
      yearsOfCraft: 18,
    ),
    Artisan(
      id: 'art-04',
      name: 'María José Dzul',
      craft: 'Miniaturas y decoración',
      cave: 'Cueva La Palma',
      bio:
          'Convierte los recortes del tejido en piezas diminutas: nacimientos, '
          'fruteros y lámparas. Su trabajo mantiene vivo el oficio sin '
          'desperdiciar una sola hebra.',
      techniques: ['Miniatura', 'Recorte aprovechado', 'Luz cálida'],
      yearsOfCraft: 12,
    ),
  ];

  static const List<Product> sampleProducts = [
    Product(
      id: 'prod-01',
      name: 'Sombrero Brisa de Bécal',
      artisanId: 'art-01',
      category: 'Sombreros',
      description:
          'Ala media y copa suave, tejida en una sola pieza. Pensado para el '
          'calor de Campeche y para doblarse sin perder la forma.',
      technique: 'Tejido fino · 18 vueltas',
      price: 4200,
    ),
    Product(
      id: 'prod-02',
      name: 'Bolso U k’aax',
      artisanId: 'art-03',
      category: 'Bolsos',
      description:
          'Tejido abierto con tintes de corteza y asa de palma trenzada. '
          'Interior forrado en manta de algodón.',
      technique: 'Tinte natural · Tejido abierto',
      price: 2350,
    ),
    Product(
      id: 'prod-03',
      name: 'Lámpara Luz de cueva',
      artisanId: 'art-04',
      category: 'Decoración',
      description:
          'Pantalla tejida que dibuja sombras de palma sobre la pared. '
          'Cada pieza aprovecha recortes del taller.',
      technique: 'Miniatura · Recorte aprovechado',
      price: 1850,
    ),
    Product(
      id: 'prod-04',
      name: 'Sombrero Don Aurelio',
      artisanId: 'art-02',
      category: 'Sombreros',
      description:
          'Ala ancha y acabado natural, bloqueado a mano en madera. '
          'Se teje por encargo y se entrega en tres semanas.',
      technique: 'Ala ancha · Bloqueado en madera',
      price: 5600,
      madeToOrder: true,
    ),
    Product(
      id: 'prod-05',
      name: 'Cinturón de palma',
      artisanId: 'art-03',
      category: 'Bolsos',
      description:
          'Trenzado continuo con hebilla de madera de ébano. '
          'Se ajusta al cuerpo con el uso.',
      technique: 'Trenzado continuo',
      price: 890,
    ),
    Product(
      id: 'prod-06',
      name: 'Nacimiento en miniatura',
      artisanId: 'art-04',
      category: 'Miniaturas',
      description:
          'Doce figuras tejidas en hilo de palma sobre base de barro. '
          'Una pieza de colección hecha por encargo.',
      technique: 'Miniatura · Barro y palma',
      price: 1200,
      madeToOrder: true,
    ),
  ];

  static const List<CaveLocation> sampleCaves = [
    CaveLocation(
      id: 'cave-01',
      name: 'Cueva La Esperanza',
      kind: CaveKind.cueva,
      description:
          'Cueva de techos altos donde se teje el Jipi Japa más fino de Bécal.',
      mapX: 0.26,
      mapY: 0.33,
      latitude: 20.4456,
      longitude: -90.0317,
      artisanIds: ['art-01'],
    ),
    CaveLocation(
      id: 'cave-02',
      name: 'Cueva El Rosario',
      kind: CaveKind.cueva,
      description: 'Taller de sombreros de ala ancha con bloqueado en madera.',
      mapX: 0.62,
      mapY: 0.24,
      latitude: 20.4409,
      longitude: -90.0248,
      artisanIds: ['art-02'],
    ),
    CaveLocation(
      id: 'cave-03',
      name: 'Cueva San Miguel',
      kind: CaveKind.taller,
      description:
          'Taller familiar de bolsos y tintes naturales, abierto a visitas.',
      mapX: 0.47,
      mapY: 0.60,
      latitude: 20.4442,
      longitude: -90.0242,
      artisanIds: ['art-03'],
    ),
    CaveLocation(
      id: 'cave-04',
      name: 'Cueva La Palma',
      kind: CaveKind.taller,
      description:
          'Espacio de miniaturas y decoración tejida con recortes de palma.',
      mapX: 0.76,
      mapY: 0.71,
      latitude: 20.4393,
      longitude: -90.0309,
      artisanIds: ['art-04'],
    ),
    CaveLocation(
      id: 'cave-05',
      name: 'Plaza de Bécal',
      kind: CaveKind.puntoDeEncuentro,
      description:
          'Punto de encuentro para iniciar el recorrido guiado por las cuevas.',
      mapX: 0.19,
      mapY: 0.71,
      latitude: 20.4426,
      longitude: -90.0282,
    ),
  ];

  static const List<Experience> sampleExperiences = [
    Experience(
      id: 'exp-01',
      title: 'Recorrido por las cuevas',
      description:
          'Caminata guiada por tres cuevas artesanales, del tejido al acabado.',
      durationMinutes: 90,
      artisanId: 'art-01',
      pricePerPerson: 350,
      depositPercent: 30,
      maxParticipants: 12,
    ),
    Experience(
      id: 'exp-02',
      title: 'Teje tu propia palma',
      description:
          'Taller de una tarde con una tejedora: sales con tu propia pieza.',
      durationMinutes: 120,
      artisanId: 'art-02',
      pricePerPerson: 480,
      depositPercent: 30,
      maxParticipants: 8,
    ),
    Experience(
      id: 'exp-03',
      title: 'Encuentro con artesanos',
      description:
          'Conversación y demostración en el taller, con degustación local.',
      durationMinutes: 60,
      artisanId: 'art-03',
      pricePerPerson: 250,
      depositPercent: 20,
      maxParticipants: 15,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Talleres de muestra del piloto
  //
  // Dos ejemplos para enseñar a turistas y artesanos cómo funciona la
  // mensualidad: uno al día (activo) y otro sin pagar (fuera de servicio). Se
  // marcan como «Ejemplo» y no reciben pedidos ni reservas reales.
  // ---------------------------------------------------------------------------

  static const String showcaseActiveId = 'art-muestra-activo';
  static const String showcaseInactiveId = 'art-muestra-fuera';

  static final List<Artisan> showcaseArtisans = [
    Artisan(
      id: showcaseActiveId,
      name: 'Taller de muestra · Activo',
      craft: 'Ejemplo de taller con mensualidad al día',
      cave: 'Bécal, Campeche',
      bio:
          'Así se ve un taller con su mensualidad pagada: aparece activo, '
          'muestra sus piezas y experiencias y puede recibir pedidos y '
          'reservas. Es un ejemplo: no recibe pedidos reales.',
      techniques: const ['Tejido de jipi japa'],
      yearsOfCraft: 0,
      openDays: const [1, 2, 3, 4, 5, 6],
      openTime: '09:00',
      closeTime: '17:00',
      paymentMethods: const ['Efectivo', 'Transferencia'],
      languages: const ['Español'],
      subscriptionUntil: DateTime(2099, 12, 31),
      isShowcase: true,
    ),
    const Artisan(
      id: showcaseInactiveId,
      name: 'Taller de muestra · Fuera de servicio',
      craft: 'Ejemplo de taller sin mensualidad',
      cave: 'Bécal, Campeche',
      bio:
          'Así se ve un taller sin su mensualidad al día: sigue visible, pero '
          'aparece «fuera de servicio» y no puede recibir pedidos ni reservas '
          'hasta que pague. Es un ejemplo.',
      techniques: ['Tejido de jipi japa'],
      yearsOfCraft: 0,
      isShowcase: true,
    ),
  ];

  static const List<Product> showcaseProducts = [
    Product(
      id: 'prod-muestra-activo',
      name: 'Sombrero de muestra',
      artisanId: showcaseActiveId,
      category: 'Sombreros',
      description:
          'Pieza de ejemplo de un taller activo: se puede ver su precio y el '
          'botón para agregarla al carrito.',
      technique: 'Ejemplo',
      price: 800,
      stock: 5,
    ),
    Product(
      id: 'prod-muestra-fuera',
      name: 'Bolso de muestra',
      artisanId: showcaseInactiveId,
      category: 'Bolsos',
      description:
          'Pieza de ejemplo de un taller fuera de servicio: se ve, pero no se '
          'puede comprar hasta que el taller pague su mensualidad.',
      technique: 'Ejemplo',
      price: 450,
      stock: 3,
    ),
  ];

  static const List<Experience> showcaseExperiences = [
    Experience(
      id: 'exp-muestra-activo',
      title: 'Visita de muestra',
      description:
          'Experiencia de ejemplo de un taller activo: muestra horarios y cupo '
          'como lo verá el turista.',
      durationMinutes: 60,
      artisanId: showcaseActiveId,
      pricePerPerson: 200,
      depositPercent: 0,
      maxParticipants: 8,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Datos visibles en la app
  //
  // Con `AppConfig.seedSampleData = false` (versión para el piloto) la app
  // arranca vacía: sin talleres, piezas ni experiencias de ejemplo. Del mapa
  // solo queda la plaza del pueblo como punto de encuentro.
  // ---------------------------------------------------------------------------

  static List<Artisan> get artisans =>
      AppConfig.seedSampleData ? sampleArtisans : const [];

  static List<Product> get products =>
      AppConfig.seedSampleData ? sampleProducts : const [];

  static List<Experience> get experiences =>
      AppConfig.seedSampleData ? sampleExperiences : const [];

  static List<CaveLocation> get caves => AppConfig.seedSampleData
      ? sampleCaves
      : [
          for (final cave in sampleCaves)
            if (cave.artisanIds.isEmpty) cave,
        ];

  /// Ids de todo el contenido de ejemplo (para limpiarlo de instalaciones
  /// anteriores).
  static Set<String> get sampleArtisanIds =>
      {for (final artisan in sampleArtisans) artisan.id};

  static Set<String> get sampleProductIds =>
      {for (final product in sampleProducts) product.id};

  static Set<String> get sampleExperienceIds =>
      {for (final experience in sampleExperiences) experience.id};

  static Artisan? artisanById(String id) {
    for (final artisan in artisans) {
      if (artisan.id == id) return artisan;
    }
    return null;
  }

  static Product? productById(String id) {
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  static List<Product> productsOf(String artisanId) {
    return products.where((p) => p.artisanId == artisanId).toList();
  }

  static List<CaveLocation> cavesOf(String artisanId) {
    return caves.where((c) => c.artisanIds.contains(artisanId)).toList();
  }

  static List<Product> byCategory(String category) {
    if (category == categories.first) return products;
    return products.where((p) => p.category == category).toList();
  }

  /// Treinta días de disponibilidad a partir de hoy (demostración).
  static List<DateTime> nextDays([int count = 21]) {
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    return List<DateTime>.generate(
      count,
      (index) => base.add(Duration(days: index)),
    );
  }
}
