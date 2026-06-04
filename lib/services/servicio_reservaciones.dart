import '../core/cliente_api.dart';
import '../models/aeropuerto.dart';
import '../models/aeronave.dart';

class ReservationService {
  final _api = ApiClient.instance;

  /// AIRPORTS MEXICO
  Future<List<Airport>> getNationalAirports() async {
    final response = await _api.getAirports();

    return (response as List).map((json) => Airport.fromJson(json)).toList();
  }

  /// INTERNATIONAL AIRPORTS
  Future<List<Airport>> getInternationalAirports() async {
    final response = await _api.getAirports();

    return (response as List).map((json) => Airport.fromJson(json)).toList();
  }

  /// AIRCRAFT FLEET
  Future<List<Aircraft>> getFleet() async {
    final response = await _api.getAircraftPreview();

    return (response as List).map((json) => Aircraft.fromJson(json)).toList();
  }

  Future<bool> checkAvailability(
    String aircraftId,
    String startISO,
    String endISO,
  ) async {
    final response = await _api.getReservations();

    return response.where((reservation) {
      if ((reservation['aircraft_id'] ?? reservation['aircraft']?['id'])
              .toString() !=
          aircraftId) {
        return false;
      }

      final start = DateTime.tryParse(
        reservation['start_datetime']?.toString() ?? '',
      );
      final end = DateTime.tryParse(
        reservation['end_datetime']?.toString() ?? '',
      );
      if (start == null || end == null) return false;

      return start.isBefore(DateTime.parse(endISO)) &&
          end.isAfter(DateTime.parse(startISO));
    }).isEmpty;
  }
}
