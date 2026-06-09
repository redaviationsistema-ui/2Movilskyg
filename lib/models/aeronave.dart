class Aircraft {
  final String id;
  final String name;
  final String aircraftType;
  final int capacityPassengers;
  final double rentalPriceUsd;
  final double cruiseSpeedKnots;
  final double nationalExpensesUsd;
  final double internationalExpensesUsd;
  final String homeBase;
  final String city;
  final double crewOvernightUsd;
  final double minimumHours;
  final String imageUrl;

  Aircraft({
    required this.id,
    required this.name,
    required this.aircraftType,
    required this.capacityPassengers,
    required this.rentalPriceUsd,
    required this.cruiseSpeedKnots,
    required this.nationalExpensesUsd,
    required this.internationalExpensesUsd,
    required this.homeBase,
    required this.city,
    required this.crewOvernightUsd,
    required this.minimumHours,
    this.imageUrl = '',
  });

  double get cruiseSpeed => cruiseSpeedKnots;

  factory Aircraft.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0;
      return 0;
    }

    String firstText(List<dynamic> values) {
      for (final value in values) {
        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
      }
      return '';
    }

    String firstImageFromCollection(dynamic value) {
      final items =
          value is List
              ? value
              : value == null
              ? const []
              : [value];
      for (final item in items) {
        if (item is String && item.trim().isNotEmpty) return item.trim();
        if (item is Map) {
          final image = firstText([
            item['main_image'],
            item['mainImage'],
            item['image_url'],
            item['imageUrl'],
            item['image'],
            item['url'],
            item['path'],
            item['file_url'],
            item['fileUrl'],
            item['public_url'],
            item['publicUrl'],
            item['src'],
            item['photo_url'],
          ]);
          if (image.isNotEmpty) return image;
        }
      }
      return '';
    }

    final galleryImage = firstImageFromCollection(
      json['images'] ??
          json['aircraft_images'] ??
          json['aircraftImages'] ??
          json['gallery_images'] ??
          json['galleryImages'] ??
          json['gallery'] ??
          json['photos'] ??
          json['media'] ??
          json['multimedia'] ??
          json['pictures'] ??
          json['files'],
    );

    return Aircraft(
      id: json["id"].toString(),
      name: json["name"] ?? json["model"] ?? "",
      aircraftType: json["aircraft_type"] ?? json["model"] ?? "",
      capacityPassengers: json["capacity_passengers"] ?? json["capacity"] ?? 0,
      rentalPriceUsd: parseDouble(
        json["rental_price_usd"] ?? json["hourly_rate"],
      ),
      cruiseSpeedKnots:
          json["cruise_speed_knots"] != null
              ? parseDouble(json["cruise_speed_knots"])
              : (json["speed_kmh"] != null
                  ? parseDouble(json["speed_kmh"]) / 1.852
                  : 350),
      nationalExpensesUsd: parseDouble(json["national_expenses_usd"] ?? 0),
      internationalExpensesUsd: parseDouble(
        json["international_expenses_usd"] ?? 0,
      ),
      homeBase: json["home_base"] ?? json["base_airport"] ?? "",
      city: json["city"] ?? json["base_airport"] ?? "",
      minimumHours: parseDouble(json['minimum_hours'] ?? 1),
      crewOvernightUsd: parseDouble(json['crew_overnight_usd'] ?? 0),
      imageUrl: firstText([
        json['image_url'],
        json['imageUrl'],
        json['main_image'],
        json['mainImage'],
        json['aircraft_image'],
        json['aircraft_photo'],
        json['aircraft_photo_url'],
        json['photo_url'],
        json['thumbnail_url'],
        json['cover_image'],
        galleryImage,
      ]),
    );
  }

  Map<String, dynamic> toCacheMap() {
    return {
      'id': id,
      'name': name,
      'aircraft_type': aircraftType,
      'capacity_passengers': capacityPassengers,
      'rental_price_usd': rentalPriceUsd,
      'cruise_speed_knots': cruiseSpeedKnots,
      'national_expenses_usd': nationalExpensesUsd,
      'international_expenses_usd': internationalExpensesUsd,
      'home_base': homeBase,
      'city': city,
      'crew_overnight_usd': crewOvernightUsd,
      'minimum_hours': minimumHours,
      'image_url': imageUrl,
      'is_active': 1,
    };
  }
}
