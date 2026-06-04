class MarketplaceMetric {
  final String label;
  final String value;
  final String helper;

  const MarketplaceMetric({
    required this.label,
    required this.value,
    required this.helper,
  });
}

class MarketplaceModule {
  final String title;
  final String description;

  const MarketplaceModule({required this.title, required this.description});
}

class AvailabilityBadgeData {
  final String label;
  final String helper;

  const AvailabilityBadgeData({required this.label, required this.helper});
}

class OperatorRequest {
  final String route;
  final String aircraftCategory;
  final String etaResponse;
  final String status;
  final String notes;

  const OperatorRequest({
    required this.route,
    required this.aircraftCategory,
    required this.etaResponse,
    required this.status,
    required this.notes,
  });
}

class CancellationRule {
  final String window;
  final String penalty;
  final String action;

  const CancellationRule({
    required this.window,
    required this.penalty,
    required this.action,
  });
}

class RoadmapPhase {
  final String title;
  final String description;

  const RoadmapPhase({required this.title, required this.description});
}
