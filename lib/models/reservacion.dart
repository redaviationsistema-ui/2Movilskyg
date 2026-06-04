class Reservation {
  final String id;

  final String aircraftId;

  final DateTime startDatetime;
  final DateTime endDatetime;

  final String status;

  Reservation({
    required this.id,
    required this.aircraftId,
    required this.startDatetime,
    required this.endDatetime,
    required this.status,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: json["id"].toString(),

      aircraftId: json["aircraft_id"].toString(),

      startDatetime: DateTime.parse(json["start_datetime"]),

      endDatetime: DateTime.parse(json["end_datetime"]),

      status: json["status"] ?? "pending",
    );
  }
}
