/// Modelos de dominio de Bel-Aaktun.
///
/// Son deliberadamente independientes de la interfaz: cuando conectes la API
/// real solo necesitas un `fromJson` por clase y un repositorio que devuelva
/// estas mismas entidades.
library;

class Artisan {
  const Artisan({
    required this.id,
    required this.name,
    required this.craft,
    required this.cave,
    required this.bio,
    required this.techniques,
    required this.yearsOfCraft,
    this.imagePath,
    this.coverPath,
    this.ownerUserId,
    this.phone,
    this.whatsapp,
    this.email,
    this.address,
    this.openDays = const [],
    this.openTime,
    this.closeTime,
    this.paymentMethods = const [],
    this.languages = const [],
    this.isPublished = true,
  });

  final String id;
  final String name;

  /// Oficio principal, por ejemplo "Tejedora de Jipi Japa".
  final String craft;

  /// Cueva o taller donde trabaja.
  final String cave;
  final String bio;

  /// Técnicas y materiales que domina.
  final List<String> techniques;
  final int yearsOfCraft;

  /// Foto de perfil: asset (`assets/images/...`), archivo local o data URI.
  /// Si es `null` se usa el marcador dibujado.
  final String? imagePath;

  /// Foto de portada del taller.
  final String? coverPath;

  /// Cuenta que administra el taller (`null` en talleres de demostración).
  final String? ownerUserId;

  final String? phone;
  final String? whatsapp;
  final String? email;

  /// Dirección o referencia para llegar.
  final String? address;

  /// Días abiertos: 1 = lunes … 7 = domingo.
  final List<int> openDays;

  /// Horario en formato `HH:mm`.
  final String? openTime;
  final String? closeTime;

  /// Efectivo, transferencia, tarjeta…
  final List<String> paymentMethods;

  /// Idiomas en los que atiende el taller.
  final List<String> languages;

  /// Un taller no publicado no aparece a los turistas.
  final bool isPublished;

  bool get hasSchedule =>
      openDays.isNotEmpty && openTime != null && closeTime != null;

  Artisan copyWith({
    String? name,
    String? craft,
    String? cave,
    String? bio,
    List<String>? techniques,
    int? yearsOfCraft,
    String? imagePath,
    bool clearImage = false,
    String? coverPath,
    bool clearCover = false,
    String? ownerUserId,
    String? phone,
    String? whatsapp,
    String? email,
    String? address,
    List<int>? openDays,
    String? openTime,
    String? closeTime,
    List<String>? paymentMethods,
    List<String>? languages,
    bool? isPublished,
  }) => Artisan(
    id: id,
    name: name ?? this.name,
    craft: craft ?? this.craft,
    cave: cave ?? this.cave,
    bio: bio ?? this.bio,
    techniques: techniques ?? this.techniques,
    yearsOfCraft: yearsOfCraft ?? this.yearsOfCraft,
    imagePath: clearImage ? null : (imagePath ?? this.imagePath),
    coverPath: clearCover ? null : (coverPath ?? this.coverPath),
    ownerUserId: ownerUserId ?? this.ownerUserId,
    phone: phone ?? this.phone,
    whatsapp: whatsapp ?? this.whatsapp,
    email: email ?? this.email,
    address: address ?? this.address,
    openDays: openDays ?? this.openDays,
    openTime: openTime ?? this.openTime,
    closeTime: closeTime ?? this.closeTime,
    paymentMethods: paymentMethods ?? this.paymentMethods,
    languages: languages ?? this.languages,
    isPublished: isPublished ?? this.isPublished,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'craft': craft,
    'cave': cave,
    'bio': bio,
    'techniques': techniques,
    'yearsOfCraft': yearsOfCraft,
    'imagePath': imagePath,
    'coverPath': coverPath,
    'ownerUserId': ownerUserId,
    'phone': phone,
    'whatsapp': whatsapp,
    'email': email,
    'address': address,
    'openDays': openDays,
    'openTime': openTime,
    'closeTime': closeTime,
    'paymentMethods': paymentMethods,
    'languages': languages,
    'isPublished': isPublished,
  };

  factory Artisan.fromJson(Map<String, dynamic> json) => Artisan(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    craft: json['craft'] as String? ?? '',
    cave: json['cave'] as String? ?? '',
    bio: json['bio'] as String? ?? '',
    techniques: _strings(json['techniques']),
    yearsOfCraft: json['yearsOfCraft'] as int? ?? 0,
    imagePath: json['imagePath'] as String?,
    coverPath: json['coverPath'] as String?,
    ownerUserId: json['ownerUserId'] as String?,
    phone: json['phone'] as String?,
    whatsapp: json['whatsapp'] as String?,
    email: json['email'] as String?,
    address: json['address'] as String?,
    openDays: [
      for (final day in (json['openDays'] as List<dynamic>? ?? const []))
        if (day is int) day,
    ],
    openTime: json['openTime'] as String?,
    closeTime: json['closeTime'] as String?,
    paymentMethods: _strings(json['paymentMethods']),
    languages: _strings(json['languages']),
    isPublished: json['isPublished'] as bool? ?? true,
  );
}

List<String> _strings(Object? value) => [
  for (final item in (value as List<dynamic>? ?? const []))
    if (item is String) item,
];

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.artisanId,
    required this.category,
    required this.description,
    required this.technique,
    this.price,
    this.imagePath,
    this.photos = const [],
    this.madeToOrder = false,
    this.isActive = true,
    this.stock,
    this.productionDays,
    this.dimensions,
    this.materials = const [],
  });

  final String id;
  final String name;
  final String artisanId;
  final String category;
  final String description;
  final String technique;

  /// Precio en pesos mexicanos. `null` significa "precio a consultar".
  final int? price;

  /// Imagen de catálogo (asset). Las fotos que sube el taller van en [photos].
  final String? imagePath;

  /// Fotografías subidas por el taller; la primera es la portada.
  final List<String> photos;

  /// Pieza hecha por encargo (no hay stock inmediato).
  final bool madeToOrder;

  /// Una pieza desactivada deja de mostrarse al turista sin borrarse.
  final bool isActive;

  /// Piezas disponibles. `null` = no se lleva inventario.
  final int? stock;

  /// Días de elaboración cuando es por encargo.
  final int? productionDays;

  /// Medidas o talla, texto libre ("Talla 57 · ala 9 cm").
  final String? dimensions;

  final List<String> materials;

  /// Imagen principal para tarjetas y fichas.
  String? get coverImage => photos.isNotEmpty ? photos.first : imagePath;

  /// Todas las imágenes de la pieza.
  List<String> get gallery => [
    ...photos,
    if (photos.isEmpty && imagePath != null) imagePath!,
  ];

  bool get isSoldOut => !madeToOrder && stock != null && stock! <= 0;

  Product copyWith({
    String? name,
    String? category,
    String? description,
    String? technique,
    int? price,
    List<String>? photos,
    bool? madeToOrder,
    bool? isActive,
    int? stock,
  }) => Product(
    id: id,
    name: name ?? this.name,
    artisanId: artisanId,
    category: category ?? this.category,
    description: description ?? this.description,
    technique: technique ?? this.technique,
    price: price ?? this.price,
    imagePath: imagePath,
    photos: photos ?? this.photos,
    madeToOrder: madeToOrder ?? this.madeToOrder,
    isActive: isActive ?? this.isActive,
    stock: stock ?? this.stock,
    productionDays: productionDays,
    dimensions: dimensions,
    materials: materials,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'artisanId': artisanId,
    'category': category,
    'description': description,
    'technique': technique,
    'price': price,
    'imagePath': imagePath,
    'photos': photos,
    'madeToOrder': madeToOrder,
    'isActive': isActive,
    'stock': stock,
    'productionDays': productionDays,
    'dimensions': dimensions,
    'materials': materials,
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    name: json['name'] as String,
    artisanId: json['artisanId'] as String,
    category: json['category'] as String,
    description: json['description'] as String,
    technique: json['technique'] as String,
    price: json['price'] as int?,
    imagePath: json['imagePath'] as String?,
    photos: _strings(json['photos']),
    madeToOrder: json['madeToOrder'] as bool? ?? false,
    isActive: json['isActive'] as bool? ?? true,
    stock: json['stock'] as int?,
    productionDays: json['productionDays'] as int?,
    dimensions: json['dimensions'] as String?,
    materials: _strings(json['materials']),
  );
}

enum CaveKind { cueva, taller, puntoDeEncuentro }

class CaveLocation {
  const CaveLocation({
    required this.id,
    required this.name,
    required this.kind,
    required this.description,
    required this.mapX,
    required this.mapY,
    this.artisanIds = const [],
    this.imagePath,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final CaveKind kind;
  final String description;

  /// Posición normalizada (0–1) sobre el mapa ilustrado de Bécal.
  ///
  /// Solo se usa como respaldo cuando la parada aún no tiene coordenadas
  /// reales ([latitude] / [longitude]).
  final double mapX;
  final double mapY;

  final List<String> artisanIds;
  final String? imagePath;

  /// Coordenadas reales de la parada (WGS84).
  final double? latitude;
  final double? longitude;

  /// `true` cuando la parada puede dibujarse en el mapa geográfico.
  bool get hasCoordinates => latitude != null && longitude != null;
}

class Experience {
  const Experience({
    required this.id,
    required this.title,
    required this.description,
    required this.durationMinutes,
    this.artisanId = 'art-01',
    this.pricePerPerson = 0,
    this.depositPercent = 30,
    this.maxParticipants = 12,
    this.isActive = true,
    this.imagePath,
    this.photos = const [],
    this.includes = const [],
    this.whatToBring,
    this.languages = const [],
    this.meetingPoint,
  });

  final String id;
  final String title;
  final String description;
  final int durationMinutes;

  /// Taller que ofrece la experiencia (dueño de las reservaciones).
  final String artisanId;

  /// Precio por persona en MXN.
  final int pricePerPerson;

  /// Anticipo que pide el taller, en porcentaje del total (0–100).
  final int depositPercent;

  final int maxParticipants;
  final bool isActive;
  final String? imagePath;

  /// Fotografías subidas por el taller; la primera es la portada.
  final List<String> photos;

  /// Qué incluye la experiencia ("Agua fresca", "Material de tejido"…).
  final List<String> includes;

  /// Recomendaciones para el visitante.
  final String? whatToBring;

  final List<String> languages;

  /// Punto de encuentro si es distinto al taller.
  final String? meetingPoint;

  String? get coverImage => photos.isNotEmpty ? photos.first : imagePath;

  List<String> get gallery => [
    ...photos,
    if (photos.isEmpty && imagePath != null) imagePath!,
  ];

  int totalFor(int people) => pricePerPerson * people;

  int depositFor(int people) {
    final total = totalFor(people);
    if (total <= 0 || depositPercent <= 0) return 0;
    return (total * depositPercent / 100).round();
  }

  Experience copyWith({
    String? title,
    String? description,
    int? durationMinutes,
    int? pricePerPerson,
    int? depositPercent,
    int? maxParticipants,
    bool? isActive,
    List<String>? photos,
  }) => Experience(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    artisanId: artisanId,
    pricePerPerson: pricePerPerson ?? this.pricePerPerson,
    depositPercent: depositPercent ?? this.depositPercent,
    maxParticipants: maxParticipants ?? this.maxParticipants,
    isActive: isActive ?? this.isActive,
    imagePath: imagePath,
    photos: photos ?? this.photos,
    includes: includes,
    whatToBring: whatToBring,
    languages: languages,
    meetingPoint: meetingPoint,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'durationMinutes': durationMinutes,
    'artisanId': artisanId,
    'pricePerPerson': pricePerPerson,
    'depositPercent': depositPercent,
    'maxParticipants': maxParticipants,
    'isActive': isActive,
    'imagePath': imagePath,
    'photos': photos,
    'includes': includes,
    'whatToBring': whatToBring,
    'languages': languages,
    'meetingPoint': meetingPoint,
  };

  factory Experience.fromJson(Map<String, dynamic> json) => Experience(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    durationMinutes: json['durationMinutes'] as int,
    artisanId: json['artisanId'] as String? ?? 'art-01',
    pricePerPerson: json['pricePerPerson'] as int? ?? 0,
    depositPercent: json['depositPercent'] as int? ?? 30,
    maxParticipants: json['maxParticipants'] as int? ?? 12,
    isActive: json['isActive'] as bool? ?? true,
    imagePath: json['imagePath'] as String?,
    photos: _strings(json['photos']),
    includes: _strings(json['includes']),
    whatToBring: json['whatToBring'] as String?,
    languages: _strings(json['languages']),
    meetingPoint: json['meetingPoint'] as String?,
  );
}

class BookingRequest {
  const BookingRequest({
    required this.experienceId,
    required this.date,
    required this.timeSlot,
    required this.people,
    required this.name,
    required this.phone,
    this.notes,
  });

  final String experienceId;
  final DateTime date;
  final String timeSlot;
  final int people;
  final String name;
  final String phone;
  final String? notes;
}
