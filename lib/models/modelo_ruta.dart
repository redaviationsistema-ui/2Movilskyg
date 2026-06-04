import 'aeropuerto.dart';

class RouteModel {
  Airport? fromAirport;
  Airport? toAirport;

  String? fromCity;
  String? fromState;

  String? toCity;
  String? toState;

  DateTime? startDate;
  DateTime? endDate;

  int passengers;

  String? aircraftId;

  RouteModel({
    this.fromAirport,
    this.toAirport,
    this.fromCity,
    this.fromState,
    this.toCity,
    this.toState,
    this.startDate,
    this.endDate,
    this.passengers = 1,
    this.aircraftId,
  });
}
