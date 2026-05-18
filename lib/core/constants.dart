class AppConstants {
  /* ===============================
     SUPABASE
  =============================== */

  static const String supabaseUrl = "https://antkusroysbehyliqvti.supabase.co";

  static const String supabaseAnonKey =
      "sb_publishable_RZWNYqYb0-TL6vYSTBZozg_Qk465M4b";

  /* ===============================
     TAX
  =============================== */

  /* ===============================
     FLIGHT TYPES
  =============================== */

  static const List<String> flightTypes = [
    "Private Jet",
    "Helicopter",
    "Air Ambulance",
    "Cargo",
  ];

  /* ===============================
     ROUTE TYPES
  =============================== */

  static const List<String> routeTypes = [
    "NATIONAL",
    // "INTERNATIONAL"
  ];

  /* ===============================
     AIRCRAFT CATEGORY MAP
     (igual que tu sistema Vue)
  =============================== */

  /* ===============================
     AIRPORT TYPES
  =============================== */

  static const Map<String, List<String>> flightTypeAirportTypes = {
    "Private Jet": ["AIRPORT"],

    "Helicopter": ["Helicóptero", "HELIPLATAFORMA", "AIRPORT"],

    "Air Ambulance": ["AIRPORT", "HELIPUERTO", "HELIPLATAFORMA"],

    "Cargo": ["AIRPORT"],
  };

  /* ===============================
     DEFAULT VALUES
  =============================== */

  static const int defaultPassengers = 1;

  static const double defaultCruiseSpeed = 350;

  /* ===============================
     UI
  =============================== */

  static const double padding = 20.0;

  static const double borderRadius = 12.0;
}
