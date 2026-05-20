import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/reservation_provider.dart';
import '../reservation/reservation_screen.dart';
import 'views/client_history_screen.dart';
import 'views/client_live_profile_screen.dart';
import 'views/client_results_screen.dart';
import 'widgets/client_mobile_flow_widgets.dart';

class ClientMobileWorkspaceScreen extends StatefulWidget {
  const ClientMobileWorkspaceScreen({super.key});

  @override
  State<ClientMobileWorkspaceScreen> createState() =>
      _ClientMobileWorkspaceScreenState();
}

class _ClientMobileWorkspaceScreenState
    extends State<ClientMobileWorkspaceScreen> {
  int _selectedIndex = 0;
  int _searchSession = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userInitial = _userInitial(auth.displayName);

    final screens = [
      ReservationScreen(
        key: ValueKey('reservation-$_searchSession'),
        userInitial: userInitial,
        onQuoteReady: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (_) => ClientResultsScreen(
                    userInitial: userInitial,
                    onBackToSearch: _resetSearchFlow,
                    onReservationCreated: _openFlightsFromResults,
                  ),
            ),
          );
        },
      ),
      const ClientHistoryScreen(showBackButton: false),
      const ClientLiveProfileScreen(showBackButton: false),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F1E8),
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: ClientMobileBottomNav(
        currentIndex: _selectedIndex,
        onSelect: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  String _userInitial(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return 'C';
    return trimmed.substring(0, 1).toUpperCase();
  }

  void _resetSearchFlow() {
    context.read<ReservationProvider>().resetForm();
    setState(() {
      _searchSession++;
      _selectedIndex = 0;
    });
    Navigator.of(context).pop();
  }

  void _openFlightsFromResults() {
    context.read<ReservationProvider>().resetForm();
    setState(() {
      _searchSession++;
      _selectedIndex = 1;
    });
    Navigator.of(context).pop();
  }
}
