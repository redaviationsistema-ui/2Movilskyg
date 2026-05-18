import '../core/api_client.dart';
import '../models/aircraft.dart';

class AircraftService {
  static Future<List<Aircraft>> getFleet() async {
    final response = await ApiClient.instance.getAircraftPreview();

    return response.map<Aircraft>((json) => Aircraft.fromJson(json)).toList();
  }

  static Future<Aircraft?> getAircraftById(String id) async {
    final fleet = await ApiClient.instance.getAircraftPreview();
    final matches = fleet.where((item) => item['id'].toString() == id);

    return matches.isEmpty ? null : Aircraft.fromJson(matches.first);
  }
}
