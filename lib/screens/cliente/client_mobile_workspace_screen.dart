import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/reservation_provider.dart';
import '../reservation/reservation_screen.dart';
import 'views/client_booking_confirmation_screen.dart';
import 'views/client_contract_screen.dart';
import 'views/client_history_screen.dart';
import 'views/client_live_profile_screen.dart';
import 'views/client_payment_screen.dart';
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
  _TripsStage _tripsStage = _TripsStage.list;
  String? _selectedRequestId;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final reservation = context.watch<ReservationProvider>();
    final userInitial = _userInitial(auth.displayName);
    final activeRequest = _findRequestById(reservation, _selectedRequestId);

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
                    onReservationCreated: _openReservationConfirmation,
                  ),
            ),
          );
        },
      ),
      _buildTripsScreen(activeRequest),
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

  void _openReservationConfirmation(String? requestId) {
    setState(() {
      _selectedIndex = 1;
      _tripsStage = _TripsStage.confirmation;
      _selectedRequestId = requestId;
    });
    Navigator.of(context).pop();
  }

  Widget _buildTripsScreen(Map<String, dynamic>? activeRequest) {
    switch (_tripsStage) {
      case _TripsStage.contract:
        return ClientContractScreen(
          request: activeRequest ?? const {},
          showBackButton: false,
          onConfirm: () {
            setState(() {
              _tripsStage = _TripsStage.payment;
            });
          },
        );
      case _TripsStage.payment:
        return ClientPaymentScreen(
          request: activeRequest ?? const {},
          showBackButton: false,
          onPaymentComplete: () {
            setState(() {
              _tripsStage = _TripsStage.confirmation;
            });
          },
        );
      case _TripsStage.confirmation:
        return ClientBookingConfirmationScreen(
          request: activeRequest ?? const {},
          showBackButton: false,
          onOpenTrips: () {
            setState(() {
              _tripsStage = _TripsStage.list;
            });
          },
        );
      case _TripsStage.list:
        return ClientHistoryScreen(
          showBackButton: false,
          onOpenContract: (request) {
            setState(() {
              _selectedRequestId = request['id']?.toString();
              _tripsStage = _TripsStage.contract;
            });
          },
          onOpenPayment: (request) {
            setState(() {
              _selectedRequestId = request['id']?.toString();
              _tripsStage = _TripsStage.payment;
            });
          },
        );
    }
  }

  Map<String, dynamic>? _findRequestById(
    ReservationProvider reservation,
    String? requestId,
  ) {
    final requests = reservation.flightRequests;
    if (requests.isEmpty) return null;
    if (requestId == null || requestId.isEmpty) {
      return requests.first;
    }

    for (final request in requests) {
      if (request['id']?.toString() == requestId) {
        return request;
      }
    }

    return requests.first;
  }
}

enum _TripsStage { list, contract, payment, confirmation }
