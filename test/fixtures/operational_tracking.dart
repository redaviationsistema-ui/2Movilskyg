// Test-only data for native presentation checks; never used by the app entry point.
Map<String, dynamic> operationalTrackingFixture() => {
  'operation': {
    'id': 42,
    'status': 'en_vuelo',
    'timeline': [
      for (var index = 0; index < 4; index++)
        {
          'id': index + 1,
          'operation_id': 42,
          'status': 'en_vuelo',
          'title': 'Liberacion operativa del proveedor',
          'description':
              'Estado: operational_ready | Aeronave: LEARJET 31A | Workflow: tracking_live',
          'created_at': '2026-10-14T15:0$index:00Z',
        },
    ],
  },
};
Map<String, dynamic> operationalTrackingRequestFixture() => {
  'operation_id': 42,
  'passengers': 4,
  'legs': [
    {
      'origin_icao': 'MMTO',
      'destination_icao': 'MMVR',
      'departure_datetime': '2026-10-14T15:00:00',
    },
    {
      'origin_icao': 'MMVR',
      'destination_icao': 'MMUN',
      'departure_datetime': '2026-10-15T15:00:00',
    },
  ],
};
