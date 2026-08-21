part of 'pantalla_espacio_sobrecargo.dart';

class _CrewNotificationButton extends StatelessWidget {
  const _CrewNotificationButton({
    required this.unread,
    required this.onPressed,
  });

  final int unread;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip:
          unread == 0 ? 'Notificaciones' : '$unread notificaciones sin leer',
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(
          Icons.notifications_none_rounded,
          color: Color(0xFFE2BD79),
        ),
      ),
    );
  }
}

class _CrewCompactHomeView extends StatelessWidget {
  const _CrewCompactHomeView({
    required this.assignments,
    required this.incidents,
    required this.documents,
    required this.currentStatus,
    required this.baseLabel,
    required this.profileState,
    required this.workflow,
    required this.onOpenMissions,
    required this.onOpenAvailability,
    required this.onOpenDocuments,
    required this.onOpenIncidents,
  });

  final List<CrewAssignment> assignments;
  final List<CrewIncident> incidents;
  final List<CrewDocument> documents;
  final String currentStatus;
  final String baseLabel;
  final String profileState;
  final Map<String, dynamic> workflow;
  final VoidCallback onOpenMissions;
  final VoidCallback onOpenAvailability;
  final VoidCallback onOpenDocuments;
  final VoidCallback onOpenIncidents;

  @override
  Widget build(BuildContext context) {
    final active =
        assignments.where((item) => !item.isFinalized).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final operation = active.firstOrNull;
    if (operation == null) {
      return _InfoTile(
        icon: Icons.flight_takeoff_rounded,
        title: 'No tienes vuelos asignados por ahora',
        subtitle: 'Te avisaremos cuando tengas una nueva operación.',
        action: FilledButton.icon(
          onPressed: onOpenAvailability,
          icon: const Icon(Icons.event_available_rounded),
          label: const Text('Ver disponibilidad'),
        ),
      );
    }

    final hasWorkflow = workflow.isNotEmpty;
    final flow = CrewOperationFlowSnapshot.fromPayload(
      workflow: workflow,
      canRespondToAssignment: operation.canRespondToAssignment,
    );
    final totalChecklistItems =
        flow.preparationSummary.total +
        flow.preflightSummary.total +
        flow.postflightSummary.total;
    final resolvedChecklistItems =
        flow.preparationSummary.resolved +
        flow.preflightSummary.resolved +
        flow.postflightSummary.resolved;
    final progress =
        hasWorkflow && totalChecklistItems > 0
            ? ((resolvedChecklistItems / totalChecklistItems) * 100).round()
            : operation.persistedChecklistProgress;
    final cta =
        hasWorkflow
            ? _friendlyHomeWorkflowAction(flow.primaryAction)
            : operation.canRespondToAssignment
            ? 'Confirmar mi vuelo'
            : progress < 100
            ? 'Continuar preparación'
            : 'Ver mi vuelo';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OperationalStrip(
          title: operation.route,
          subtitle:
              '${operation.code} · ${_compactCrewDate(operation.date)} · ${operation.showTime}',
          status: operation.status,
        ),
        const SizedBox(height: 14),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  operation.aircraft,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Presentación: ${operation.showTime} · Pasajeros: ${operation.passengers}',
                ),
                const SizedBox(height: 14),
                Semantics(
                  label: 'Tareas completadas: $progress por ciento',
                  child: LinearProgressIndicator(value: progress / 100),
                ),
                const SizedBox(height: 8),
                Text('$progress% completado'),
                const SizedBox(height: 16),
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: onOpenMissions,
                    style: FilledButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(cta),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _friendlyHomeWorkflowAction(CrewOperationPrimaryAction action) {
  switch (action.kind) {
    case 'confirm_assignment':
      return 'Confirmar mi vuelo';
    case 'open_checklist':
      return 'Completar checklist pre-vuelo';
    case 'open_tracking':
      return 'Abrir seguimiento';
    case 'open_closure':
      return 'Completar checklist post-vuelo';
    case 'submit_report':
      return 'Enviar reporte final';
    case 'workflow_action':
      final value = action.cta.toLowerCase().replaceAll('_', ' ');
      if (value.contains('llegada') || value.contains('check in')) {
        return 'Confirmar llegada';
      }
      if (value.contains('prepar') || value.contains('cabina')) {
        return 'Preparar cabina';
      }
      if (value.contains('pasaj')) {
        return 'Recibir pasajeros';
      }
      if (value.contains('despeg')) {
        return 'Registrar despegue';
      }
      if (value.contains('aterriz')) {
        return 'Registrar aterrizaje';
      }
      if (value.contains('desembar')) {
        return 'Registrar desembarque';
      }
      return action.cta.isEmpty ? 'Ver mi vuelo' : action.cta;
    default:
      return 'Ver mi vuelo';
  }
}

String _compactCrewDate(DateTime value) {
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

class _CrewAccountView extends StatelessWidget {
  const _CrewAccountView({
    required this.profileForm,
    required this.configForm,
    required this.documents,
    required this.assignments,
    required this.incidents,
    required this.activeSection,
    required this.onProfileChanged,
    required this.onSaveProfile,
    required this.onConfigChanged,
    required this.onSaveConfig,
    required this.onCreateDocument,
    required this.onDocumentStatusChanged,
    required this.onOpenOperation,
    required this.onOpenSection,
  });

  final Map<String, dynamic> profileForm;
  final Map<String, dynamic> configForm;
  final List<CrewDocument> documents;
  final List<CrewAssignment> assignments;
  final List<CrewIncident> incidents;
  final CrewPortalTab activeSection;
  final void Function(String, dynamic) onProfileChanged;
  final VoidCallback onSaveProfile;
  final void Function(String, dynamic) onConfigChanged;
  final VoidCallback onSaveConfig;
  final void Function(CrewDocument, File?) onCreateDocument;
  final void Function(CrewDocument, String) onDocumentStatusChanged;
  final ValueChanged<CrewAssignment> onOpenOperation;
  final ValueChanged<CrewPortalTab> onOpenSection;

  @override
  Widget build(BuildContext context) {
    if (activeSection == CrewPortalTab.account) {
      return _CrewAccountHome(
        onOpenSection: onOpenSection,
        onLogout: () => context.read<AuthProvider>().signOut(),
      );
    }

    Widget child;
    switch (activeSection) {
      case CrewPortalTab.profile:
        child = _ProfileView(
          form: profileForm,
          onChanged: onProfileChanged,
          onSave: onSaveProfile,
        );
        break;
      case CrewPortalTab.documents:
        child = _DocumentsView(
          documents: documents,
          onCreate: onCreateDocument,
          onStatusChanged: onDocumentStatusChanged,
        );
        break;
      case CrewPortalTab.history:
        child = _HistoryView(
          assignments: assignments,
          incidents: incidents,
          onOpenOperation: onOpenOperation,
        );
        break;
      case CrewPortalTab.payments:
        child = _PaymentsView(payments: const [], assignments: assignments);
        break;
      case CrewPortalTab.settings:
        child = _SettingsView(
          form: configForm,
          onChanged: onConfigChanged,
          onSave: onSaveConfig,
        );
        break;
      default:
        child = const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          onPressed: () => onOpenSection(CrewPortalTab.account),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Volver a Cuenta'),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _CrewAccountHome extends StatelessWidget {
  const _CrewAccountHome({required this.onOpenSection, required this.onLogout});

  final ValueChanged<CrewPortalTab> onOpenSection;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.person_rounded,
        'Mi perfil',
        'Datos personales',
        CrewPortalTab.profile,
      ),
      (
        Icons.folder_copy_rounded,
        'Mis documentos',
        'Documentos y vigencias',
        CrewPortalTab.documents,
      ),
      (
        Icons.history_rounded,
        'Historial de operaciones',
        'Ver operaciones anteriores',
        CrewPortalTab.history,
      ),
      (
        Icons.payments_rounded,
        'Pagos',
        'Consultar información',
        CrewPortalTab.payments,
      ),
      (
        Icons.tune_rounded,
        'Configuración',
        'Preferencias',
        CrewPortalTab.settings,
      ),
    ];

    return Column(
      children: [
        ...items.map(
          (item) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(item.$1),
              title: Text(
                item.$2,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(item.$3),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onOpenSection(item.$4),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text(
              'Cerrar sesión',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            onTap: onLogout,
          ),
        ),
      ],
    );
  }
}

class _CrewCommandHero extends StatelessWidget {
  const _CrewCommandHero({
    required this.status,
    required this.readiness,
    required this.readinessLabel,
    required this.nextMission,
    required this.alertCount,
    required this.pendingAssignments,
    required this.onOpenMissions,
    required this.onOpenAvailability,
    required this.onOpenIncidents,
  });

  final String status;
  final int readiness;
  final String readinessLabel;
  final CrewAssignment? nextMission;
  final int alertCount;
  final int pendingAssignments;
  final VoidCallback onOpenMissions;
  final VoidCallback onOpenAvailability;
  final VoidCallback onOpenIncidents;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 430;
    final route = nextMission?.route.trim();
    final missionLabel =
        route == null || route.isEmpty ? 'Sin mision asignada' : route;
    final showTime = nextMission?.showTime.trim() ?? '';

    return _AnimatedEntry(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 16 : 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF071827), Color(0xFF123A56)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0x44E0B86E)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0x55E0B86E)),
                  ),
                  child: const Icon(
                    Icons.airline_seat_recline_extra_rounded,
                    color: Color(0xFFE0B86E),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cabin Command',
                        style: TextStyle(
                          color: Color(0xFFE0B86E),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        readinessLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 22 : 26,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                _CrewHeroScore(value: readiness),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              missionLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 16 : 18,
                fontWeight: FontWeight.w900,
                height: 1.15,
              ),
            ),
            if (showTime.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                showTime,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFC9D7E2),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CrewHeroChip(
                  icon: Icons.verified_user_rounded,
                  label: status.isEmpty ? 'Estado pendiente' : status,
                ),
                _CrewHeroChip(
                  icon: Icons.notifications_active_outlined,
                  label: alertCount == 1 ? '1 alerta' : '$alertCount alertas',
                  highlighted: alertCount > 0,
                ),
                _CrewHeroChip(
                  icon: Icons.assignment_turned_in_rounded,
                  label:
                      pendingAssignments == 1
                          ? '1 respuesta pendiente'
                          : '$pendingAssignments respuestas pendientes',
                  highlighted: pendingAssignments > 0,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _CrewHeroButton(
                    icon: Icons.assignment_rounded,
                    label: 'Misiones',
                    onTap: onOpenMissions,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CrewHeroButton(
                    icon: Icons.event_available_rounded,
                    label: 'Disponible',
                    onTap: onOpenAvailability,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CrewHeroButton(
                    icon: Icons.report_problem_rounded,
                    label: 'Alertas',
                    onTap: onOpenIncidents,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CrewHeroScore extends StatelessWidget {
  const _CrewHeroScore({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE0B86E),
        border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
      ),
      child: Text(
        '$value',
        style: const TextStyle(
          color: Color(0xFF071827),
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _CrewHeroChip extends StatelessWidget {
  const _CrewHeroChip({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color:
            highlighted
                ? const Color(0xFFE0B86E)
                : Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x44E0B86E)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: highlighted ? const Color(0xFF071827) : Colors.white,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: highlighted ? const Color(0xFF071827) : Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrewHeroButton extends StatelessWidget {
  const _CrewHeroButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: Color(0x55E0B86E)),
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}

// Kept temporarily as the legacy composition reference while Crew rolls out.
// ignore: unused_element
class _DashboardView extends StatelessWidget {
  const _DashboardView({
    required this.assignments,
    required this.incidents,
    required this.documents,
    required this.currentStatus,
    required this.baseLabel,
    required this.profileState,
    required this.onOpenMissions,
    required this.onOpenAvailability,
    required this.onOpenDocuments,
    required this.onOpenIncidents,
  });

  final List<CrewAssignment> assignments;
  final List<CrewIncident> incidents;
  final List<CrewDocument> documents;
  final String currentStatus;
  final String baseLabel;
  final String profileState;
  final VoidCallback onOpenMissions;
  final VoidCallback onOpenAvailability;
  final VoidCallback onOpenDocuments;
  final VoidCallback onOpenIncidents;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 430;
    final sortedAssignments = [...assignments]..sort((left, right) {
      final leftRank = _missionRank(left.status);
      final rightRank = _missionRank(right.status);
      if (leftRank != rightRank) return leftRank.compareTo(rightRank);
      return left.date.compareTo(right.date);
    });
    final active = assignments.where((item) => !item.isFinalized).length;
    final nextMission = sortedAssignments.firstOrNull;
    final pendingAssignments =
        assignments.where((item) => item.canRespondToAssignment).length;
    final openIncidents = _openIncidentCount(incidents);
    final approvedDocuments = documents.where(_isDocumentApproved).length;
    final documentsValidity =
        documents.isEmpty
            ? 0
            : ((approvedDocuments / documents.length) * 100).round();
    final checklistProgress = nextMission?.persistedChecklistProgress ?? 0;
    final operationalStatus = _operationalStatus(currentStatus, nextMission);
    final readiness = _readinessScore(
      documentsValidity: documentsValidity,
      checklistProgress: checklistProgress,
      operationalStatus: operationalStatus,
      profileState: profileState,
    );
    final readinessLabel = _readinessLabel(readiness);
    final expiringDocuments = _expiringDocuments(documents);
    final criticalDocuments =
        expiringDocuments
            .where(
              (item) => item.daysRemaining != null && item.daysRemaining! <= 15,
            )
            .length;
    final alerts = _buildPremiumAlerts(
      nextMission: nextMission,
      operationalStatus: operationalStatus,
      documentsValidity: documentsValidity,
      expiringDocuments: expiringDocuments,
      openIncidents: openIncidents,
      pendingAssignments: pendingAssignments,
    );
    final missionTimeline = _buildMissionTimeline(
      nextMission,
      documentsValidity: documentsValidity,
    );
    final readinessBreakdown = [
      _BreakdownItem(
        label: 'Documentos',
        value: '$documentsValidity%',
        tone:
            documentsValidity >= 90
                ? const Color(0xFF0F8A5F)
                : const Color(0xFFB7791F),
      ),
      _BreakdownItem(
        label: 'Checklist',
        value: '$checklistProgress%',
        tone:
            checklistProgress >= 80
                ? const Color(0xFF0F8A5F)
                : const Color(0xFFB7791F),
      ),
      _BreakdownItem(
        label: 'Estado',
        value: operationalStatus,
        tone: _statusTone(operationalStatus),
      ),
      _BreakdownItem(
        label: 'Perfil',
        value: profileState,
        tone:
            profileState.toLowerCase().contains('valid') ||
                    profileState.toLowerCase().contains('aprobad')
                ? const Color(0xFF0F8A5F)
                : const Color(0xFFB7791F),
      ),
    ];
    final dayOfFlightDetails = _dayOfFlightDetails(nextMission, openIncidents);
    final coordinationLabel =
        nextMission?.provider.trim().isNotEmpty == true
            ? nextMission!.provider.trim()
            : 'Operaciones';

    return Column(
      children: [
        _CrewCommandHero(
          status: operationalStatus,
          readiness: readiness,
          readinessLabel: readinessLabel,
          nextMission: nextMission,
          alertCount: alerts.length,
          pendingAssignments: pendingAssignments,
          onOpenMissions: onOpenMissions,
          onOpenAvailability: onOpenAvailability,
          onOpenIncidents: onOpenIncidents,
        ),
        SizedBox(height: compact ? 12 : 14),
        _OperationalStrip(
          title: 'Centro operativo de cabina',
          subtitle:
              'Checklist, documentos, mision activa y contexto operativo sincronizados para vuelo seguro.',
          status: operationalStatus,
        ),
        SizedBox(height: compact ? 12 : 14),
        _MissionHeroCard(
          assignment: nextMission,
          operationalStatus: operationalStatus,
          checklistProgress: checklistProgress,
          onOpenMissions: onOpenMissions,
        ),
        SizedBox(height: compact ? 12 : 14),
        _MetricGrid(
          metrics: [
            _Metric('Servicios', '$active', Icons.flight_rounded),
            _Metric(
              'Checklist',
              '$checklistProgress%',
              Icons.checklist_rounded,
            ),

            _Metric('Alertas', '${alerts.length}', Icons.warning_rounded),
            _Metric('Estado', operationalStatus, Icons.verified_user_rounded),
          ],
        ),
        SizedBox(height: compact ? 12 : 14),
        _TimelineCard(items: missionTimeline),
        SizedBox(height: compact ? 12 : 14),
        _ReadinessCard(
          score: readiness,
          label: readinessLabel,
          pendingAssignments: pendingAssignments,
          expiredDocs: criticalDocuments,
          openIncidents: openIncidents,
        ),
        SizedBox(height: compact ? 12 : 14),
        _SummaryGrid(
          items: [
            _SummaryItem(
              title: 'Servicios completados',
              value:
                  '${assignments.where((item) => item.status == 'Finalizada').length}',
              detail:
                  nextMission == null
                      ? 'Sin mision activa en este momento.'
                      : '1 mision activa o en preparacion.',
            ),
            _SummaryItem(
              title: 'Puntualidad',
              value:
                  assignments.isEmpty
                      ? 'Sin dato'
                      : '${(100 - openIncidents).clamp(0, 100)}%',
              detail:
                  assignments.isEmpty
                      ? 'Sin actividad suficiente para calcularla.'
                      : 'Calculado con la actividad registrada.',
            ),
            _SummaryItem(
              title: 'Base operativa',
              value: baseLabel.isNotEmpty ? baseLabel : 'Pendiente',
              detail: 'Coordinacion $coordinationLabel.',
            ),
            _SummaryItem(
              title: 'Documentos por vencer',
              value: '${expiringDocuments.length}',
              detail:
                  expiringDocuments.isEmpty
                      ? 'Sin vencimientos proximos.'
                      : expiringDocuments.first.summary,
            ),
          ],
        ),
        SizedBox(height: compact ? 12 : 14),
        _BreakdownCard(items: readinessBreakdown),
        if (dayOfFlightDetails.isNotEmpty) ...[
          SizedBox(height: compact ? 12 : 14),
          _DayOfFlightCard(items: dayOfFlightDetails),
        ],
        if (alerts.isNotEmpty) ...[
          SizedBox(height: compact ? 12 : 14),
          _AlertStack(alerts: alerts),
        ],
        if (expiringDocuments.isNotEmpty) ...[
          SizedBox(height: compact ? 12 : 14),
          _ExpiringDocumentsCard(items: expiringDocuments),
        ],
      ],
    );
  }

  int _readinessScore({
    required int documentsValidity,
    required int checklistProgress,
    required String operationalStatus,
    required String profileState,
  }) {
    final documentWeight = documentsValidity * 0.45;
    final checklistWeight = checklistProgress * 0.25;
    final availabilityWeight =
        operationalStatus == 'Disponible'
            ? 20
            : operationalStatus == 'Asignado'
            ? 14
            : operationalStatus == 'En mision'
            ? 14
            : operationalStatus.isEmpty
            ? 0
            : 8;
    final normalizedProfile = profileState.toLowerCase();
    final profileWeight =
        normalizedProfile.isEmpty
            ? 0
            : normalizedProfile.contains('valid') ||
                normalizedProfile.contains('aprobad')
            ? 10
            : normalizedProfile.contains('revision')
            ? 6
            : 4;
    return (documentWeight +
            checklistWeight +
            availabilityWeight +
            profileWeight)
        .round()
        .clamp(0, 100);
  }

  String _readinessLabel(int score) {
    if (score >= 90) return 'Listo para volar';
    if (score >= 75) return 'Listo con seguimiento';
    return 'Requiere atencion';
  }

  int _missionRank(String status) {
    switch (status) {
      case 'En servicio':
        return 0;
      case 'Pasajeros recibidos':
        return 1;
      case 'Cabina revisada':
        return 2;
      case 'En aeropuerto/base':
        return 3;
      case 'Preparacion':
        return 4;
      case 'Confirmado':
        return 5;
      case 'Pendiente':
        return 6;
      case 'Solicitar revision':
        return 7;
      case 'Finalizada':
        return 8;
      default:
        return 9;
    }
  }

  String _operationalStatus(String currentStatus, CrewAssignment? assignment) {
    if (assignment == null) {
      return currentStatus.trim().isNotEmpty
          ? currentStatus.trim()
          : 'Sin mision activa';
    }
    if (assignment.status == 'En servicio') return 'En mision';
    if (assignment.status == 'Incidencia') return 'Incidencia';
    if (const [
      'Confirmado',
      'Preparacion',
      'En aeropuerto/base',
      'Cabina revisada',
      'Pasajeros recibidos',
    ].contains(assignment.status)) {
      return 'Asignado';
    }
    if (currentStatus.trim().isNotEmpty) return currentStatus.trim();
    if (assignment.status == 'Finalizada') return 'Cierre operativo';
    if (assignment.status == 'Pendiente') return 'Por confirmar';
    return 'Disponible';
  }

  int _openIncidentCount(List<CrewIncident> incidents) {
    return incidents.where((item) {
      final normalized = item.status.toLowerCase();
      return !normalized.contains('cerr') &&
          !normalized.contains('resuelt') &&
          !normalized.contains('atendid');
    }).length;
  }

  bool _isDocumentApproved(CrewDocument document) {
    final normalized = document.status.toLowerCase();
    return normalized.contains('vigente') ||
        normalized.contains('aprobado') ||
        normalized.contains('valid');
  }

  List<_ExpiringDocument> _expiringDocuments(List<CrewDocument> documents) {
    final now = DateTime.now();
    final items = <_ExpiringDocument>[];
    for (final document in documents) {
      final expiration = DateTime.tryParse(document.expiration);
      if (expiration == null) continue;
      final daysRemaining = expiration.difference(now).inDays;
      if (daysRemaining > 60) continue;
      items.add(
        _ExpiringDocument(
          title: document.title,
          category: document.category,
          daysRemaining: daysRemaining,
        ),
      );
    }
    items.sort((left, right) => left.sortValue.compareTo(right.sortValue));
    return items.take(3).toList();
  }

  List<String> _buildPremiumAlerts({
    required CrewAssignment? nextMission,
    required String operationalStatus,
    required int documentsValidity,
    required List<_ExpiringDocument> expiringDocuments,
    required int openIncidents,
    required int pendingAssignments,
  }) {
    final alerts = <String>[];

    if (expiringDocuments.any(
      (item) => item.daysRemaining != null && item.daysRemaining! <= 15,
    )) {
      alerts.add('Tienes documentos criticos por vencer en menos de 15 dias.');
    }
    if (pendingAssignments > 0) {
      final channel =
          nextMission?.provider.trim().isNotEmpty == true
              ? nextMission!.provider.trim()
              : 'operaciones';
      alerts.add('Tienes asignaciones pendientes de confirmar con $channel.');
    }
    if (openIncidents > 0) {
      alerts.add(
        'Hay incidencias abiertas que requieren seguimiento operativo.',
      );
    }

    return alerts.take(4).toList();
  }

  List<_TimelineItem> _buildMissionTimeline(
    CrewAssignment? assignment, {
    required int documentsValidity,
  }) {
    return [
      _TimelineItem(label: 'Asignada', done: assignment != null),
      _TimelineItem(
        label: 'Preparacion',
        done: assignment?.isChecklistCompleted('preparation') == true,
      ),
      _TimelineItem(label: 'Documentacion', done: documentsValidity >= 100),
      _TimelineItem(
        label: 'Pre-vuelo',
        done: assignment?.isChecklistCompleted('preflight') == true,
      ),
      _TimelineItem(
        label: 'Post-vuelo',
        done: assignment?.isChecklistCompleted('postflight') == true,
      ),
    ];
  }

  List<_DetailItem> _dayOfFlightDetails(
    CrewAssignment? assignment,
    int openIncidents,
  ) {
    if (assignment == null) return const [];
    return [
      _DetailItem(label: 'Hora reporte', value: assignment.showTime),
      _DetailItem(
        label: 'FBO',
        value:
            assignment.origin.isEmpty
                ? 'Pendiente por admin'
                : assignment.origin,
      ),
      _DetailItem(
        label: 'Catering',
        value:
            assignment.catering.isEmpty
                ? 'Sin detalle cargado'
                : assignment.catering,
      ),
      _DetailItem(
        label: 'Pasajeros especiales',
        value:
            assignment.passengers > 0
                ? '${assignment.passengers} pasajeros autorizados'
                : 'Sin dato de pasajeros',
      ),
      _DetailItem(
        label: 'Servicio',
        value:
            assignment.serviceLevel.isEmpty
                ? 'Sin nivel cargado'
                : assignment.serviceLevel,
      ),
      _DetailItem(
        label: 'Incidencias',
        value:
            openIncidents > 0
                ? '$openIncidents abiertas'
                : 'Sin alertas criticas',
      ),
    ];
  }

  Color _statusTone(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('disponible') || normalized.contains('mision')) {
      return const Color(0xFF0F8A5F);
    }
    if (normalized.contains('confirm')) return const Color(0xFF2563EB);
    if (normalized.contains('sin') || normalized.contains('por')) {
      return const Color(0xFFB7791F);
    }
    return const Color(0xFF64748B);
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({
    required this.score,
    required this.label,
    required this.pendingAssignments,
    required this.expiredDocs,
    required this.openIncidents,
  });

  final int score;
  final String label;
  final int pendingAssignments;
  final int expiredDocs;
  final int openIncidents;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 430;

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: _panelDecoration().copyWith(
        gradient: const LinearGradient(
          colors: [Color(0xFF07121D), Color(0xFF173B55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 18 : 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$score%',
                style: TextStyle(
                  color: Color(0xFFE0B86E),
                  fontSize: compact ? 24 : 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 10,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFE0B86E)),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _DarkAlertPill(label: '$pendingAssignments por confirmar'),
              _DarkAlertPill(label: '$expiredDocs docs alerta'),
              _DarkAlertPill(label: '$openIncidents incidencias'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MissionHeroCard extends StatelessWidget {
  const _MissionHeroCard({
    required this.assignment,
    required this.operationalStatus,
    required this.checklistProgress,
    required this.onOpenMissions,
  });

  final CrewAssignment? assignment;
  final String operationalStatus;
  final int checklistProgress;
  final VoidCallback onOpenMissions;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 430;
    final hasAssignment = assignment != null;

    return _AnimatedEntry(
      child: Container(
        padding: EdgeInsets.all(compact ? 16 : 18),
        decoration: _panelDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: compact ? 54 : 58,
                  height: compact ? 54 : 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2F8),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.flight_takeoff_rounded,
                    color: Color(0xFF0E2338),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasAssignment ? assignment!.code : 'OPS',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFFB7791F),
                          fontSize: compact ? 12 : 13,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        assignment == null
                            ? 'Sin vuelo asignado'
                            : assignment!.route,
                        maxLines: compact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0E2338),
                          height: 1.08,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        assignment == null
                            ? 'Mantente disponible para recibir una nueva mision.'
                            : '${assignment!.provider} · ${assignment!.aircraft}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF5F6975),
                          height: 1.25,
                          fontSize: compact ? 13 : 14,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(operationalStatus),
              ],
            ),
            SizedBox(height: compact ? 10 : 14),
            if (assignment != null)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _DarkMetricPill(label: assignment!.showTime),
                  _DarkMetricPill(
                    label:
                        assignment!.origin.isEmpty
                            ? 'Origen por definir'
                            : assignment!.origin,
                  ),
                  _DarkMetricPill(
                    label:
                        assignment!.passengers > 0
                            ? '${assignment!.passengers} pasajeros'
                            : 'Pax por confirmar',
                  ),
                ],
              ),
            SizedBox(height: compact ? 10 : 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: checklistProgress / 100,
                minHeight: 9,
                backgroundColor: const Color(0xFFE8EDF2),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF0E2338)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              assignment == null
                  ? 'Sin checklist activo.'
                  : 'Checklist operativo al $checklistProgress%.',
              style: TextStyle(
                color: const Color(0xFF41566A),
                fontWeight: FontWeight.w500,
                fontSize: compact ? 12 : 13,
                decoration: TextDecoration.none,
              ),
            ),
            SizedBox(height: compact ? 10 : 14),
            Align(
              alignment: compact ? Alignment.centerLeft : Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onOpenMissions,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  assignment == null ? 'Ver misiones' : 'Abrir mision',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkMetricPill extends StatelessWidget {
  const _DarkMetricPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 430;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 10,
        vertical: compact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6F8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.black,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _SummaryItem {
  const _SummaryItem({
    required this.title,
    required this.value,
    required this.detail,
  });

  final String title;
  final String value;
  final String detail;
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.items});

  final List<_SummaryItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 430) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.02,
            ),
            itemBuilder:
                (context, index) =>
                    _SummaryGridCard(item: items[index], delay: index * 60),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: constraints.maxWidth < 520 ? 200 : 240,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: constraints.maxWidth < 520 ? 1.0 : 1.18,
          ),
          itemBuilder:
              (context, index) =>
                  _SummaryGridCard(item: items[index], delay: index * 60),
        );
      },
    );
  }
}

class _SummaryGridCard extends StatelessWidget {
  const _SummaryGridCard({required this.item, required this.delay});

  final _SummaryItem item;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 430;

    return _AnimatedEntry(
      delay: delay,
      child: Container(
        padding: EdgeInsets.all(compact ? 14 : 16),
        decoration: _panelDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF5F6975),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: compact ? 10 : 18),
            Text(
              item.value,
              maxLines: compact ? 2 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF0E2338),
                fontSize: compact ? 18 : 24,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            SizedBox(height: compact ? 6 : 6),
            Text(
              item.detail,
              maxLines: compact ? 3 : 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF41566A),
                height: 1.25,
                fontSize: compact ? 12 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineItem {
  const _TimelineItem({required this.label, required this.done});

  final String label;
  final bool done;
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.items});

  final List<_TimelineItem> items;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 430;

    return _AnimatedEntry(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 14 : 16),
        decoration: _panelDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Timeline operativo',
              style: TextStyle(
                fontSize: compact ? 16 : 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: compact ? 10 : 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  items
                      .map(
                        (item) => Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 10 : 12,
                            vertical: compact ? 8 : 9,
                          ),
                          decoration: BoxDecoration(
                            color:
                                item.done
                                    ? const Color(0xFFEAF6F0)
                                    : const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color:
                                  item.done
                                      ? const Color(0xFFB8E3CA)
                                      : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.done
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                size: 16,
                                color:
                                    item.done
                                        ? const Color(0xFF0F8A5F)
                                        : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                item.label,
                                style: TextStyle(
                                  color:
                                      item.done
                                          ? const Color(0xFF0F8A5F)
                                          : const Color(0xFF475569),
                                  fontWeight: FontWeight.w800,
                                  fontSize: compact ? 12 : 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownItem {
  const _BreakdownItem({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.items});

  final List<_BreakdownItem> items;

  @override
  Widget build(BuildContext context) {
    return _AnimatedEntry(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: _panelDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Breakdown de readiness',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: item.tone,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.label,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      item.value,
                      style: TextStyle(
                        color: item.tone,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailItem {
  const _DetailItem({required this.label, required this.value});

  final String label;
  final String value;
}

class _DayOfFlightCard extends StatelessWidget {
  const _DayOfFlightCard({required this.items});

  final List<_DetailItem> items;

  @override
  Widget build(BuildContext context) {
    return _AnimatedEntry(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: _panelDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detalle del servicio',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 116,
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          color: Color(0xFF5F6975),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.value,
                        style: const TextStyle(
                          color: Color(0xFF0E2338),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertStack extends StatelessWidget {
  const _AlertStack({required this.alerts});

  final List<String> alerts;

  @override
  Widget build(BuildContext context) {
    return Column(
      children:
          alerts
              .asMap()
              .entries
              .map(
                (entry) => _AnimatedEntry(
                  delay: entry.key * 50,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: _panelDecoration().copyWith(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFFBEB), Colors.white],
                      ),
                      border: Border.all(color: const Color(0xFFF2D184)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFFB7791F),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: const TextStyle(
                              color: Color(0xFF7A5A18),
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }
}

class _ExpiringDocument {
  const _ExpiringDocument({
    required this.title,
    required this.category,
    required this.daysRemaining,
  });

  final String title;
  final String category;
  final int? daysRemaining;

  int get sortValue => daysRemaining ?? 99999;

  String get summary {
    if (daysRemaining == null) return '$category sin fecha registrada';
    if (daysRemaining! < 0) return '$category vencido';
    return '$category vence en $daysRemaining dias';
  }
}

class _ExpiringDocumentsCard extends StatelessWidget {
  const _ExpiringDocumentsCard({required this.items});

  final List<_ExpiringDocument> items;

  @override
  Widget build(BuildContext context) {
    return _AnimatedEntry(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: _panelDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Documentos por vencer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.description_rounded,
                      color: Color(0xFFB7791F),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            item.summary,
                            style: const TextStyle(color: Color(0xFF5F6975)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkAlertPill extends StatelessWidget {
  const _DarkAlertPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _OperationalStrip extends StatelessWidget {
  const _OperationalStrip({
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 430;

    return _AnimatedEntry(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 16 : 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF07121D), Color(0xFF12304A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0x33E0B86E)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 22,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: compact ? 44 : 50,
              height: compact ? 44 : 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE0B86E), Color(0xFFF2D39C)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.airlines_rounded,
                color: Color(0xFF07121D),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status,
                    style: TextStyle(
                      color: Color(0xFFE0B86E),
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 14 : 17,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFFD8E2EA),
                      fontSize: compact ? 12 : 13,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionList extends StatefulWidget {
  const _MissionList({
    required this.assignments,
    required this.coordinationLabel,
    required this.onAccept,
    required this.onReject,
    required this.onRequestChange,
    required this.onOpenOperation,
    required this.isSaving,
  });

  final List<CrewAssignment> assignments;
  final String coordinationLabel;
  final ValueChanged<CrewAssignment> onAccept;
  final ValueChanged<CrewAssignment> onReject;
  final ValueChanged<CrewAssignment> onRequestChange;
  final ValueChanged<CrewAssignment> onOpenOperation;
  final bool isSaving;

  @override
  State<_MissionList> createState() => _MissionListState();
}

class _MissionListState extends State<_MissionList> {
  String? _selectedAssignmentId;

  @override
  Widget build(BuildContext context) {
    final activeAssignments =
        widget.assignments.where((item) => !item.isFinalized).toList();

    if (activeAssignments.isEmpty) {
      return const _InfoTile(
        icon: Icons.assignment_turned_in_rounded,
        title: 'Sin misiones activas',
        subtitle: 'Cuando admin publique una operacion activa aparecera aqui.',
      );
    }

    final selected = _selectedAssignment(activeAssignments);
    final primaryAction = _primaryActionFor(selected);
    final secondaryActions = _secondaryActionsFor(selected);
    final actionTitle =
        selected == null
            ? 'Acciones principales'
            : selected.canRespondToAssignment
            ? 'Confirma disponibilidad'
            : 'Siguiente paso operativo';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MissionSelectorStrip(
          assignments: activeAssignments,
          selectedId: selected?.id,
          onSelected:
              (assignment) =>
                  setState(() => _selectedAssignmentId = assignment.id),
        ),
        if (selected != null) ...[
          const SizedBox(height: 14),
          _MissionHero(assignment: selected),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => widget.onOpenOperation(selected),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF17324A),
              side: const BorderSide(color: Color(0xFF17324A)),
            ),
            icon: const Icon(Icons.route_rounded),
            label: const Text('Continuar con mi vuelo'),
          ),
          const SizedBox(height: 14),
          if (primaryAction != null)
            _ActionCard(
              title: actionTitle,
              subtitle: _primaryDetail(selected),
              icon: Icons.assignment_turned_in_rounded,
              button: primaryAction.label,
              titleColor: const Color(0xFFFF3B30),
              titleFontSize: selected.canRespondToAssignment ? 24 : 22,
              titleFontWeight: FontWeight.bold,
              subtitleStyle: TextStyle(
                color: const Color(0xFF4B5563),
                fontSize: selected.canRespondToAssignment ? 16 : 15,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
              buttonHeight: 56,
              buttonRadius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              onPressed:
                  widget.isSaving
                      ? null
                      : () => _runPrimaryAction(selected, primaryAction),
            ),
          if (secondaryActions.isNotEmpty) ...[
            const SizedBox(height: 14),
            _MissionSecondaryActions(
              actions: secondaryActions,
              onTap: (action) => _runSecondaryAction(selected, action),
            ),
          ],
          const SizedBox(height: 14),
          const _InfoTile(
            icon: Icons.verified_rounded,
            title: 'Progreso del vuelo',
            subtitle:
                'Consulta tus tareas, fotografías y los pasos que tienes pendientes.',
          ),
        ],
      ],
    );
  }

  CrewAssignment? _selectedAssignment(List<CrewAssignment> assignments) {
    if (assignments.isEmpty) return null;
    final selected = assignments.where(
      (item) => item.id == _selectedAssignmentId,
    );
    if (selected.isNotEmpty) return selected.first;
    _selectedAssignmentId = assignments.first.id;
    return assignments.first;
  }

  _MissionPrimaryAction? _primaryActionFor(CrewAssignment? assignment) {
    if (assignment == null) return null;
    if (assignment.canRespondToAssignment) {
      return const _MissionPrimaryAction(
        label: 'Confirmar disponibilidad',
        kind: _MissionActionKind.accept,
      );
    }
    return null;
  }

  List<_MissionSecondaryAction> _secondaryActionsFor(
    CrewAssignment? assignment,
  ) {
    if (assignment == null || !assignment.canRespondToAssignment) {
      return const [];
    }
    return const [
      _MissionSecondaryAction(
        label: 'Solicitar cambio',
        icon: Icons.edit_note_rounded,
        kind: _MissionActionKind.requestChange,
      ),
      _MissionSecondaryAction(
        label: 'Rechazar',
        icon: Icons.close_rounded,
        kind: _MissionActionKind.reject,
      ),
    ];
  }

  String _primaryDetail(CrewAssignment assignment) {
    if (assignment.canRespondToAssignment) {
      return 'Revisa ruta, horario de presentacion y briefing con operaciones.';
    }
    if (assignment.canCheckin) {
      return 'Presentate en aeropuerto/base. Hora limite: ${assignment.showTime} · Lugar: ${assignment.origin.isEmpty ? 'Pendiente por admin' : assignment.origin}.';
    }
    if (assignment.canMarkCabinReady) {
      return 'Revisa cabina, catering, limpieza e insumos antes del abordaje.';
    }
    if (assignment.canReceivePassengers) {
      return 'Recibe pasajeros, valida necesidades especiales y confirma lista de abordaje.';
    }
    if (assignment.canStartService) {
      return 'Inicia el servicio a bordo y mantente en coordinacion con ${widget.coordinationLabel} si surge una incidencia.';
    }
    if (assignment.canFinalizeService) {
      return 'Cierra el servicio, registra observaciones y deja trazabilidad del vuelo.';
    }
    return 'La operacion ya completo su flujo principal. Solo queda consulta y seguimiento administrativo.';
  }

  void _runPrimaryAction(
    CrewAssignment assignment,
    _MissionPrimaryAction action,
  ) {
    switch (action.kind) {
      case _MissionActionKind.accept:
        widget.onAccept(assignment);
        break;
      case _MissionActionKind.reject:
        widget.onReject(assignment);
        break;
      case _MissionActionKind.requestChange:
        widget.onRequestChange(assignment);
        break;
    }
  }

  void _runSecondaryAction(
    CrewAssignment assignment,
    _MissionSecondaryAction action,
  ) {
    switch (action.kind) {
      case _MissionActionKind.accept:
        widget.onAccept(assignment);
        break;
      case _MissionActionKind.reject:
        widget.onReject(assignment);
        break;
      case _MissionActionKind.requestChange:
        widget.onRequestChange(assignment);
        break;
    }
  }

  // Legacy presentation helper kept temporarily for binary-compatible hot reload;
  // it is no longer rendered or used as a source of operational truth.
  // ignore: unused_element
  List<_MissionStage> _buildStages(CrewAssignment assignment) {
    final missionState = assignment.status.trim();
    return [
      _MissionStage(
        id: 'availability',
        label: 'Disponibilidad',
        state: assignment.canRespondToAssignment ? 'Pendiente' : 'Confirmado',
        points: const [
          'Confirmar disponibilidad con operaciones',
          'Revisar fecha, hora y ruta asignada',
          'Confirmar horario de presentacion',
        ],
      ),
      _MissionStage(
        id: 'itinerary',
        label: 'Itinerario',
        state: assignment.route.isNotEmpty ? 'Recibido' : 'Pendiente de carga',
        points: [
          assignment.route.isEmpty
              ? 'Ruta pendiente de carga'
              : 'Ruta asignada: ${assignment.route}',
          assignment.origin.isEmpty
              ? 'Confirmar aeropuerto/base de salida'
              : 'Salida registrada: ${assignment.origin}',
          assignment.aircraft.isEmpty
              ? 'Validar aeronave asignada'
              : 'Aeronave asignada: ${assignment.aircraft}',
        ],
      ),
      _MissionStage(
        id: 'presentation',
        label: 'Presentacion',
        state:
            assignment.canCheckin
                ? 'Pendiente'
                : [
                  'En aeropuerto/base',
                  'Cabina revisada',
                  'Pasajeros recibidos',
                  'En servicio',
                  'Finalizada',
                ].contains(missionState)
                ? 'Completado'
                : 'Pendiente',
        points: [
          'Llegar a aeropuerto/base',
          'Presentarse con personal operativo',
          'Briefing: ${assignment.showTime}',
        ],
      ),
      _MissionStage(
        id: 'cabin',
        label: 'Cabina y catering',
        state:
            assignment.canMarkCabinReady
                ? 'Pendiente'
                : [
                  'Cabina revisada',
                  'Pasajeros recibidos',
                  'En servicio',
                  'Finalizada',
                ].contains(missionState)
                ? 'Completado'
                : 'Pendiente',
        points: [
          'Revisar limpieza de cabina',
          assignment.catering.isEmpty
              ? 'Verificar catering y bebidas'
              : 'Catering asignado: ${assignment.catering}',
          assignment.serviceLevel.isEmpty
              ? 'Confirmar insumos y amenidades'
              : 'Servicio previsto: ${assignment.serviceLevel}',
          'Reportar faltantes a ${widget.coordinationLabel}, si aplica',
        ],
      ),
      _MissionStage(
        id: 'passengers',
        label: 'Pasajeros',
        state:
            assignment.canReceivePassengers
                ? 'Pendiente'
                : [
                  'Pasajeros recibidos',
                  'En servicio',
                  'Finalizada',
                ].contains(missionState)
                ? 'Completado'
                : 'Pendiente',
        points: [
          'Recibir pasajeros',
          assignment.passengers > 0
              ? 'Validar ${assignment.passengers} pasajeros autorizados'
              : 'Validar cantidad contra lista',
          assignment.specialRequirements.isEmpty
              ? 'Confirmar necesidades especiales'
              : 'Necesidades especiales: ${assignment.specialRequirements}',
          'Dar indicaciones basicas de seguridad',
        ],
      ),
      _MissionStage(
        id: 'service',
        label: 'Servicio en vuelo',
        state:
            assignment.canStartService
                ? 'Pendiente'
                : ['En servicio', 'Finalizada'].contains(missionState)
                ? 'Completado'
                : 'Pendiente',
        points: [
          'Atender servicio durante el vuelo',
          'Mantener cabina limpia y ordenada',
          assignment.client.isEmpty
              ? 'Atender solicitudes del cliente'
              : 'Cliente asignado: ${assignment.client}',
          'Supervisar seguridad y cinturones',
        ],
      ),
      _MissionStage(
        id: 'layover',
        label: 'Escala / siguiente tramo',
        state: missionState == 'Finalizada' ? 'Completado' : 'Pendiente',
        points: [
          'Apoya en desembarque / escala / siguiente tramo',
          assignment.destination.isEmpty
              ? 'Verificar pasajeros que bajan o suben'
              : 'Destino actual: ${assignment.destination}',
          'Revisar cabina despues del tramo',
          'Reponer insumos, si aplica',
          'Confirmar catering del siguiente tramo',
        ],
      ),
      _MissionStage(
        id: 'closing',
        label: 'Cierre',
        state:
            assignment.canFinalizeService
                ? 'Pendiente'
                : missionState == 'Finalizada'
                ? 'Completado'
                : 'Pendiente',
        points: [
          'Apoyar en desembarque',
          'Revisar objetos olvidados',
          'Registrar faltantes o danos',
          'Reporta incidencias y cierre a ${widget.coordinationLabel}',
        ],
      ),
      _MissionStage(
        id: 'admin-closing',
        label: 'Cierre administrativo',
        state: missionState == 'Finalizada' ? 'Completado' : 'Pendiente admin',
        points: [
          '${widget.coordinationLabel} cierra la operacion',
          'Se resguarda la trazabilidad final del servicio',
          'La asignacion queda lista para consulta e historial',
        ],
      ),
    ];
  }

  // ignore: unused_element
  List<_MissionProgressItem> _buildProgress(List<_MissionStage> stages) {
    const baseSteps = [
      ('availability', 'Disponibilidad'),
      ('itinerary', 'Itinerario'),
      ('presentation', 'Presentacion'),
      ('cabin', 'Cabina'),
      ('passengers', 'Pasajeros'),
      ('service', 'Servicio'),
      ('layover', 'Escala / tramo'),
      ('closing', 'Cierre'),
      ('admin-closing', 'Cierre admin'),
    ];
    return baseSteps.map((step) {
      final stage = stages.where((item) => item.id == step.$1).firstOrNull;
      return _MissionProgressItem(
        label: step.$2,
        state: stage?.state ?? 'Pendiente',
        tone: _stageTone(stage?.state ?? 'Pendiente'),
      );
    }).toList();
  }

  _MissionStageTone _stageTone(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('completado') ||
        normalized.contains('confirmado') ||
        normalized.contains('recibido')) {
      return _MissionStageTone.done;
    }
    if (normalized.contains('admin')) return _MissionStageTone.neutral;
    return _MissionStageTone.pending;
  }
}

enum _MissionActionKind { accept, reject, requestChange }

class _MissionPrimaryAction {
  const _MissionPrimaryAction({required this.label, required this.kind});

  final String label;
  final _MissionActionKind kind;
}

class _MissionSecondaryAction {
  const _MissionSecondaryAction({
    required this.label,
    required this.icon,
    required this.kind,
  });

  final String label;
  final IconData icon;
  final _MissionActionKind kind;
}

class _MissionStage {
  const _MissionStage({
    required this.id,
    required this.label,
    required this.state,
    required this.points,
  });

  final String id;
  final String label;
  final String state;
  final List<String> points;
}

enum _MissionStageTone { done, pending, neutral }

class _MissionProgressItem {
  const _MissionProgressItem({
    required this.label,
    required this.state,
    required this.tone,
  });

  final String label;
  final String state;
  final _MissionStageTone tone;
}

class _MissionSelectorStrip extends StatelessWidget {
  const _MissionSelectorStrip({
    required this.assignments,
    required this.selectedId,
    required this.onSelected,
  });

  final List<CrewAssignment> assignments;
  final String? selectedId;
  final ValueChanged<CrewAssignment> onSelected;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 430;

    return SizedBox(
      height: compact ? 128 : 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: assignments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = assignments[index];
          final isSelected = item.id == selectedId;
          return GestureDetector(
            onTap: () => onSelected(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: compact ? 208 : 220,
              padding: EdgeInsets.all(compact ? 12 : 14),
              decoration: _panelDecoration().copyWith(
                gradient:
                    isSelected
                        ? const LinearGradient(
                          colors: [Color(0xFF0E2235), Color(0xFF173B55)],
                        )
                        : const LinearGradient(
                          colors: [Colors.white, Color(0xFFF8FBFD)],
                        ),
                border: Border.all(
                  color:
                      isSelected
                          ? const Color(0x33E0B86E)
                          : const Color(0xFFE5EAF0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.route,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          isSelected ? Colors.white : const Color(0xFF0E2338),
                      fontSize: compact ? 13 : 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      '${item.aircraft} · ${item.showTime}',
                      maxLines: compact ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            isSelected
                                ? const Color(0xFFD8E2EA)
                                : const Color(0xFF5F6975),
                        height: 1.25,
                        fontSize: compact ? 12 : 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _StatusPill(item.status),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MissionHero extends StatelessWidget {
  const _MissionHero({required this.assignment});

  final CrewAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 430;

    return _AnimatedEntry(
      child: Container(
        padding: EdgeInsets.all(compact ? 14 : 18),
        decoration: _panelDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: compact ? 42 : 48,
                  height: compact ? 42 : 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2F8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.flight_takeoff_rounded,
                    color: Color(0xFF0E2338),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (assignment.code != 'OPS')
                        Text(
                          'Folio: ${assignment.code}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFFB7791F),
                            fontSize: compact ? 11 : 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      if (assignment.code != 'OPS') const SizedBox(height: 4),
                      Text(
                        assignment.route,
                        maxLines: compact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0E2338),
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        assignment.provider,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF5F6975),
                          height: 1.3,
                          fontSize: compact ? 12 : 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        assignment.aircraft,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF41566A),
                          height: 1.25,
                          fontSize: compact ? 12 : 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: _StatusPill(
                    assignment.status,
                    textColor: Colors.black,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 12 : 14),
            Wrap(
              spacing: compact ? 6 : 8,
              runSpacing: compact ? 6 : 8,
              children: [
                _DarkMetricPill(label: assignment.showTime),
                _DarkMetricPill(
                  label:
                      assignment.origin.isEmpty
                          ? 'Origen por definir'
                          : assignment.origin,
                ),
                _DarkMetricPill(
                  label:
                      assignment.passengers > 0
                          ? '${assignment.passengers} pasajeros'
                          : 'Pasajeros sin dato',
                ),
                if (assignment.serviceLevel.isNotEmpty)
                  _DarkMetricPill(label: assignment.serviceLevel),
              ],
            ),
            const SizedBox(height: 12),
            _MissionInfoList(assignment: assignment),
            if (assignment.rejectReason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Motivo registrado: ${assignment.rejectReason}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF8D1F1A),
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MissionInfoList extends StatelessWidget {
  const _MissionInfoList({required this.assignment});

  final CrewAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 430;
    final rows = [
      ('Folio', assignment.code),
      ('Ruta', assignment.route),
      ('Empresa', assignment.provider),
      ('Aeronave', assignment.aircraft),
      ('Presentacion', assignment.showTime),
      (
        'Pasajeros',
        assignment.passengers > 0 ? '${assignment.passengers} pax' : 'Sin dato',
      ),
      ('Estado', assignment.status),
    ];

    return Column(
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          _MissionInfoRow(
            label: rows[index].$1,
            value:
                rows[index].$2.isEmpty ? 'Pendiente por admin' : rows[index].$2,
            compact: compact,
          ),
          if (index != rows.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MissionInfoRow extends StatelessWidget {
  const _MissionInfoRow({
    required this.label,
    required this.value,
    required this.compact,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: compact ? 88 : 96,
          child: Text(
            '$label:',
            style: TextStyle(
              color: const Color(0xFF5F6975),
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF0E2338),
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _MissionProgressCard extends StatelessWidget {
  const _MissionProgressCard({required this.items});

  final List<_MissionProgressItem> items;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 430;

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progreso de la mision',
            style: TextStyle(
              fontSize: compact ? 16 : 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(items.length, (index) {
            final item = items[index];
            final colors = _colorsFor(item.tone);
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == items.length - 1 ? 0 : 10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.$1,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.$2),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: colors.$3,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF0E2338),
                            fontSize: compact ? 14 : 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.state,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.$3,
                            fontSize: compact ? 12 : 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  (Color, Color, Color) _colorsFor(_MissionStageTone tone) {
    return switch (tone) {
      _MissionStageTone.done => (
        const Color(0xFFEAF6F0),
        const Color(0xFFB8E3CA),
        const Color(0xFF0F8A5F),
      ),
      _MissionStageTone.neutral => (
        const Color(0xFFEAF2F8),
        const Color(0xFFBFDBFE),
        const Color(0xFF1D4ED8),
      ),
      _MissionStageTone.pending => (
        const Color(0xFFFFF8E7),
        const Color(0xFFF2D184),
        const Color(0xFFB7791F),
      ),
    };
  }
}

class _MissionSecondaryActions extends StatelessWidget {
  const _MissionSecondaryActions({required this.actions, required this.onTap});

  final List<_MissionSecondaryAction> actions;
  final ValueChanged<_MissionSecondaryAction> onTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 430;

    return Wrap(
      spacing: compact ? 8 : 10,
      runSpacing: 8,
      children:
          actions
              .map(
                (action) => ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: 48,
                    minWidth: compact ? 0 : 170,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: () => onTap(action),
                    icon: Icon(action.icon, size: 20),
                    label: Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 14 : 18,
                        vertical: 12,
                      ),
                      side: const BorderSide(color: Color(0xFFD4DCE6)),
                      foregroundColor: const Color(0xFF22364A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }
}

// ignore: unused_element
class _MissionChecklistCard extends StatelessWidget {
  const _MissionChecklistCard({
    required this.stages,
    required this.expandedStageId,
    required this.onToggle,
  });

  final List<_MissionStage> stages;
  final String expandedStageId;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 430;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Checklist operativo',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF3B30),
            ),
          ),
          const SizedBox(height: 10),
          ...stages.map((stage) {
            final expanded = stage.id == expandedStageId;
            final colors = _pillColors(stage.state);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onToggle(stage.id),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 14 : 16,
                          vertical: compact ? 12 : 14,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stage.label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: const Color(0xFF0E2338),
                                      fontWeight: FontWeight.w600,
                                      fontSize: compact ? 15 : 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _stageSupportText(stage),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: const Color(0xFF667085),
                                      fontSize: compact ? 13 : 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.$1,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      stage.state,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.$2,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    expanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: const Color(0xFF4B5563),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (expanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            stage.points
                                .map(
                                  (point) => Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 3),
                                          child: Icon(
                                            Icons.check_circle_outline_rounded,
                                            size: 16,
                                            color: Color(0xFF173B55),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            point,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: const Color(0xFF374151),
                                              height: 1.3,
                                              fontSize: compact ? 15 : 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  (Color, Color) _pillColors(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('completado') ||
        normalized.contains('confirmado') ||
        normalized.contains('recibido')) {
      return (const Color(0xFFEAF6F0), const Color(0xFF0F8A5F));
    }
    if (normalized.contains('admin')) {
      return (const Color(0xFFEAF2F8), const Color(0xFF173B55));
    }
    return (const Color(0xFFFFF5DE), const Color(0xFFB7791F));
  }

  String _stageSupportText(_MissionStage stage) {
    if (stage.points.isEmpty) return stage.state;
    return stage.points.first;
  }
}

class _CalendarView extends StatefulWidget {
  const _CalendarView({
    required this.selectedDate,
    required this.assignments,
    required this.blocks,
    required this.blockForm,
    required this.statuses,
    required this.coordinationLabel,
    required this.onDateSelected,
    required this.onBlockFormChanged,
    required this.onBlock,
    required this.onOpenOperation,
    required this.onAccept,
    required this.isSaving,
  });

  final DateTime selectedDate;
  final List<CrewAssignment> assignments;
  final List<CrewBlock> blocks;
  final Map<String, dynamic> blockForm;
  final List<CrewAvailabilityStatus> statuses;
  final String coordinationLabel;
  final ValueChanged<DateTime> onDateSelected;
  final void Function(String, dynamic) onBlockFormChanged;
  final VoidCallback onBlock;
  final ValueChanged<CrewAssignment> onOpenOperation;
  final ValueChanged<CrewAssignment> onAccept;
  final bool isSaving;

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  late final TextEditingController _reasonController;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController(
      text: widget.blockForm['reason']?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _CalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentReason = widget.blockForm['reason']?.toString() ?? '';
    if (_reasonController.text != currentReason) {
      _reasonController.value = TextEditingValue(
        text: currentReason,
        selection: TextSelection.collapsed(offset: currentReason.length),
      );
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dayItems =
        widget.assignments
            .where((item) => isSameDay(item.date, widget.selectedDate))
            .toList();
    final dayBlocks =
        widget.blocks
            .where((item) => isSameDay(item.date, widget.selectedDate))
            .toList();
    final hasConfirmedConflict = widget.assignments.any(
      (item) =>
          isSameDay(item.date, widget.selectedDate) &&
          [
            'Confirmado',
            'En aeropuerto/base',
            'Cabina revisada',
            'Pasajeros recibidos',
            'En servicio',
          ].contains(item.status),
    );
    final selectableStates =
        widget.statuses.where((item) => item.selectable).toList();
    final fallbackState =
        selectableStates.isEmpty ? 'NO_DISPONIBLE' : selectableStates.first.key;
    final stateValue = widget.blockForm['state']?.toString() ?? fallbackState;
    final blockTypeValue = widget.blockForm['blockType']?.toString() ?? '';
    final agendaErrors = <String>[];
    final normalizedState = stateValue.toUpperCase();
    if (normalizedState == 'NO_DISPONIBLE' &&
        _reasonController.text.trim().isEmpty) {
      agendaErrors.add(
        'Describe el motivo del bloqueo para que ${widget.coordinationLabel} lo audite.',
      );
    }
    if (blockTypeValue.trim().isEmpty) {
      agendaErrors.add('Selecciona el tipo de bloqueo.');
    }
    if (hasConfirmedConflict && normalizedState == 'NO_DISPONIBLE') {
      agendaErrors.add(
        'Ya tienes una mision confirmada ese dia; el bloqueo debe revisarlo ${widget.coordinationLabel}.',
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: _panelDecoration(),
          child: TableCalendar<CrewAssignment>(
            firstDay: DateTime.now().subtract(const Duration(days: 90)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: widget.selectedDate,
            selectedDayPredicate: (day) => isSameDay(day, widget.selectedDate),
            onDaySelected: (selected, _) => widget.onDateSelected(selected),
            eventLoader:
                (day) =>
                    widget.assignments
                        .where((item) => isSameDay(item.date, day))
                        .toList(),
            calendarStyle: const CalendarStyle(
              markerDecoration: BoxDecoration(
                color: Color(0xFFE0B86E),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: _panelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bloqueo de disponibilidad',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Puedes bloquear agenda propia para descanso, capacitacion o restriccion, pero no eliminar vuelos asignados.',
                style: TextStyle(color: Color(0xFF5F6975), height: 1.35),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: stateValue,
                decoration: const InputDecoration(
                  labelText: 'Estado de agenda',
                ),
                items:
                    selectableStates
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.key,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                onChanged:
                    (value) =>
                        widget.onBlockFormChanged('state', value ?? stateValue),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: blockTypeValue.isEmpty ? null : blockTypeValue,
                decoration: const InputDecoration(labelText: 'Tipo de bloqueo'),
                items:
                    const [
                          'Descanso',
                          'Capacitacion',
                          'Medico',
                          'Personal',
                          'Restriccion operativa',
                        ]
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                onChanged:
                    (value) =>
                        widget.onBlockFormChanged('blockType', value ?? ''),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Motivo',
                  hintText: 'Describe el motivo del bloqueo',
                ),
                onChanged:
                    (value) => widget.onBlockFormChanged('reason', value),
              ),
              if (agendaErrors.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...agendaErrors.map(
                  (error) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      error,
                      style: const TextStyle(
                        color: Color(0xFF8D1F1A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: agendaErrors.isEmpty ? widget.onBlock : null,
                  icon: const Icon(Icons.event_busy_rounded),
                  label: const Text('Solicitar bloqueo'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...dayBlocks.map(
          (item) => _InfoTile(
            icon: Icons.block_rounded,
            title: '${item.blockType} | ${item.state}',
            subtitle: item.reason,
          ),
        ),
        ...dayItems.map((item) {
          return _CalendarFlightCard(
            item: item,
            actions:
                item.canRespondToAssignment
                    ? [
                      FilledButton.icon(
                        onPressed:
                            widget.isSaving
                                ? null
                                : () => widget.onAccept(item),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Confirmar vuelo'),
                      ),
                    ]
                    : [
                      OutlinedButton.icon(
                        onPressed: () => widget.onOpenOperation(item),
                        icon: const Icon(Icons.route_rounded),
                        label: const Text('Abrir operación'),
                      ),
                    ],
          );
        }),
      ],
    );
  }
}

class _CalendarFlightCard extends StatelessWidget {
  const _CalendarFlightCard({required this.item, required this.actions});

  final CrewAssignment item;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final steps = _flowSteps(item.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.code} - ${item.route}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0E2338),
                  ),
                ),
              ),
              _StatusPill(item.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${item.showTime} | ${item.aircraft}',
            style: const TextStyle(color: Color(0xFF5F6975)),
          ),
          const SizedBox(height: 4),
          Text(
            '${item.provider}${item.serviceLevel.isEmpty ? '' : ' | ${item.serviceLevel}'}',
            style: const TextStyle(color: Color(0xFF5F6975)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                steps
                    .map(
                      (step) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color:
                              step.$2
                                  ? const Color(0xFFEAF6F0)
                                  : step.$3
                                  ? const Color(0xFFFFF8E7)
                                  : const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color:
                                step.$2
                                    ? const Color(0xFFB8E3CA)
                                    : step.$3
                                    ? const Color(0xFFF2D184)
                                    : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          step.$1,
                          style: TextStyle(
                            color:
                                step.$2
                                    ? const Color(0xFF0F8A5F)
                                    : step.$3
                                    ? const Color(0xFFB7791F)
                                    : const Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        ],
      ),
    );
  }

  List<(String, bool, bool)> _flowSteps(String status) {
    final labels = [
      'Asignada',
      'Confirmada por sobrecargo',
      'En aeropuerto/base',
      'Cabina revisada',
      'Pasajeros recibidos',
      'En vuelo',
      'Cierre operativo',
    ];
    final index = switch (status) {
      'Pendiente' => 0,
      'Confirmado' => 1,
      'Preparacion' => 2,
      'En aeropuerto/base' => 2,
      'Cabina revisada' => 3,
      'Pasajeros recibidos' => 4,
      'En servicio' => 5,
      'Finalizada' => 6,
      _ => 0,
    };
    return labels.asMap().entries.map((entry) {
      final done = entry.key < index;
      final active = entry.key == index;
      return (entry.value, done, active);
    }).toList();
  }
}

enum _AvailabilityFocusSection { status, register }

class _AvailabilityView extends StatefulWidget {
  const _AvailabilityView({
    required this.focusSection,
    required this.selectedDate,
    required this.assignments,
    required this.records,
    required this.statuses,
    required this.baseLabel,
    required this.coverageLabel,
    required this.isLoading,
    required this.onDateSelected,
    required this.onMonthChanged,
    required this.onSave,
    required this.onRequestChange,
  });

  final _AvailabilityFocusSection focusSection;
  final DateTime selectedDate;
  final List<CrewAssignment> assignments;
  final List<CrewAvailabilityRecord> records;
  final List<CrewAvailabilityStatus> statuses;
  final String baseLabel;
  final String coverageLabel;
  final bool isLoading;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onMonthChanged;
  final Future<void> Function(DateTime, String, String) onSave;
  final Future<void> Function(DateTime) onRequestChange;

  @override
  State<_AvailabilityView> createState() => _AvailabilityViewState();
}

class _AvailabilityViewState extends State<_AvailabilityView> {
  late final TextEditingController _commentController;
  final GlobalKey _summaryKey = GlobalKey();
  final GlobalKey _editorKey = GlobalKey();
  String _selectedStatus = 'DISPONIBLE';

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _syncEditor();
  }

  @override
  void didUpdateWidget(covariant _AvailabilityView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldRecord = _recordFor(oldWidget.records, oldWidget.selectedDate);
    final newRecord = _selectedRecord;
    if (!isSameDay(oldWidget.selectedDate, widget.selectedDate) ||
        oldRecord?.statusKey != newRecord?.statusKey ||
        oldRecord?.comment != newRecord?.comment) {
      _syncEditor();
    }
    if (oldWidget.focusSection != widget.focusSection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToFocusSection();
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  CrewAvailabilityRecord? get _selectedRecord =>
      _recordFor(widget.records, widget.selectedDate);

  CrewAvailabilityRecord? _recordFor(
    List<CrewAvailabilityRecord> records,
    DateTime day,
  ) {
    for (final record in records) {
      if (isSameDay(record.date, day)) return record;
    }
    return null;
  }

  void _syncEditor() {
    final record = _selectedRecord;
    final selectableKeys = widget.statuses.map((item) => item.key).toSet();
    final candidate = record?.statusKey ?? 'DISPONIBLE';
    _selectedStatus =
        selectableKeys.contains(candidate)
            ? candidate
            : (widget.statuses.isEmpty
                ? 'DISPONIBLE'
                : widget.statuses.first.key);
    _commentController.text = record?.comment ?? '';
  }

  Future<void> _scrollToFocusSection() async {
    final targetContext =
        widget.focusSection == _AvailabilityFocusSection.register
            ? _editorKey.currentContext
            : _summaryKey.currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 430;
    final selectedRecord = _selectedRecord;
    final operation = _operationFor(widget.selectedDate);
    final locked = selectedRecord?.isOperation == true;
    final activity =
        widget.records
            .where(
              (item) =>
                  item.isStored &&
                  item.statusKey != 'POR_CONFIRMAR' &&
                  item.statusKey != 'EN_OPERACION',
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OperationalStrip(
          title: 'Calendario mensual',
          subtitle:
              'Marca tus dias disponibles, descanso o restricciones para que admin pueda planear operaciones.',
          status: widget.isLoading ? 'Actualizando...' : 'Sincronizado',
        ),
        const SizedBox(height: 14),
        KeyedSubtree(key: _summaryKey, child: _availabilitySummary()),
        const SizedBox(height: 14),
        _availabilityQuickActions(locked),
        const SizedBox(height: 14),
        Container(
          padding: EdgeInsets.all(compact ? 12 : 14),
          decoration: _panelDecoration(),
          child: TableCalendar<CrewAvailabilityRecord>(
            locale: 'es_MX',
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 730)),
            focusedDay: widget.selectedDate,
            selectedDayPredicate: (day) => isSameDay(day, widget.selectedDate),
            onDaySelected: (selected, _) => widget.onDateSelected(selected),
            onPageChanged: widget.onMonthChanged,
            eventLoader: (day) {
              final record = _recordFor(widget.records, day);
              return record == null ? [] : [record];
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder:
                  (context, day, focusedDay) => _dayCell(day, false),
              todayBuilder: (context, day, focusedDay) => _dayCell(day, false),
              selectedBuilder:
                  (context, day, focusedDay) => _dayCell(day, true),
              outsideBuilder:
                  (context, day, focusedDay) =>
                      _dayCell(day, false, isOutsideMonth: true),
              markerBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            rowHeight: compact ? 78 : 90,
            daysOfWeekHeight: 28,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),
        ),
        const SizedBox(height: 14),
        KeyedSubtree(
          key: _editorKey,
          child:
              locked
                  ? _operationEditor(operation, selectedRecord)
                  : _availabilityEditor(selectedRecord),
        ),
        if (activity.isNotEmpty) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _panelDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mi bitacora',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ultimos movimientos de disponibilidad',
                  style: TextStyle(color: Color(0xFF5F6975)),
                ),
                const SizedBox(height: 12),
                ...activity
                    .take(6)
                    .map(
                      (item) => _InfoTile(
                        icon: Icons.history_rounded,
                        title: '${_dateLabel(item.date)} | ${item.label}',
                        subtitle:
                            item.comment.isEmpty
                                ? 'Actualizado desde ${item.origin.toLowerCase()}.'
                                : item.comment,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _availabilitySummary() {
    final keys = [
      'DISPONIBLE',
      'NO_DISPONIBLE',
      'DESCANSO',
      'EN_OPERACION',
      'BLOQUEO_SOLICITADO',
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        final cardWidth = compact ? (constraints.maxWidth - 10) / 2 : 155.0;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children:
              keys.map((key) {
                final status = _statusFor(key);
                final count =
                    widget.records
                        .where((item) => item.statusKey == key)
                        .length;
                return Container(
                  width: cardWidth,
                  padding: const EdgeInsets.all(13),
                  decoration: _panelDecoration(),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 7, backgroundColor: status.color),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$count dias',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              _summaryLabelForKey(key),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF5F6975),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  Widget _availabilityQuickActions(bool locked) {
    final actions = [
      ('DISPONIBLE', 'Marcar disponible'),
      ('DESCANSO', 'Marcar descanso'),
      ('NO_DISPONIBLE', 'Marcar no disponible'),
      ('BLOQUEO_SOLICITADO', 'Solicitar bloqueo'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acciones rapidas',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                actions.map((item) {
                  final enabled =
                      !locked &&
                      widget.statuses.any(
                        (status) => status.selectable && status.key == item.$1,
                      );
                  return OutlinedButton(
                    onPressed:
                        enabled
                            ? () => setState(() => _selectedStatus = item.$1)
                            : null,
                    child: Text(item.$2),
                  );
                }).toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  locked || widget.isLoading
                      ? null
                      : () => widget.onSave(
                        widget.selectedDate,
                        _selectedStatus,
                        _commentController.text.trim(),
                      ),
              icon: const Icon(Icons.save_rounded),
              label: const Text('Guardar disponibilidad'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime day, bool selected, {bool isOutsideMonth = false}) {
    final record = _recordFor(widget.records, day);
    final operation = _operationFor(day);
    final displayStatus = _displayStatusForDay(day, record, operation);
    final status = _statusFor(displayStatus.$1);
    final color =
        displayStatus.$1 == 'POR_CONFIRMAR'
            ? const Color(0xFFF8E2BD)
            : status.color;
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 44,
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color:
              isOutsideMonth
                  ? const Color(0xFFF8F4EC)
                  : color.withValues(
                    alpha: displayStatus.$1 == 'POR_CONFIRMAR' ? 0.9 : 0.18,
                  ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF0E2338) : const Color(0xFFE8EDF2),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color:
                    isOutsideMonth
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF15293A),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                displayStatus.$2,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      isOutsideMonth
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF41566A),
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 10,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, String) _displayStatusForDay(
    DateTime day,
    CrewAvailabilityRecord? record,
    CrewAssignment? operation,
  ) {
    if (operation != null) {
      return ('EN_OPERACION', 'En\noperacion');
    }
    if (record == null) return ('POR_CONFIRMAR', 'Por\nconfirmar');
    return switch (record.statusKey) {
      'DISPONIBLE' => ('DISPONIBLE', 'Disponible'),
      'DESCANSO' => ('DESCANSO', 'Descanso'),
      'NO_DISPONIBLE' => ('NO_DISPONIBLE', 'No\ndisponible'),
      'BLOQUEO_SOLICITADO' => ('BLOQUEO_SOLICITADO', 'Bloqueo'),
      'EN_OPERACION' => ('EN_OPERACION', 'En\noperacion'),
      _ => (record.statusKey, record.label),
    };
  }

  String _summaryLabelForKey(String key) {
    return switch (key) {
      'DISPONIBLE' => 'Disponible este mes',
      'NO_DISPONIBLE' => 'No disponible',
      'DESCANSO' => 'Descanso',
      'EN_OPERACION' => 'En operacion',
      'BLOQUEO_SOLICITADO' => 'Bloqueos pendientes',
      _ => _statusFor(key).label,
    };
  }

  Widget _availabilityMeta() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Base: ${widget.baseLabel.isEmpty ? 'Sin base' : widget.baseLabel}',
          style: const TextStyle(color: Color(0xFF41566A), height: 1.35),
        ),
        Text(
          'Cobertura: ${widget.coverageLabel.isEmpty ? 'Sin cobertura' : widget.coverageLabel}',
          style: const TextStyle(color: Color(0xFF41566A), height: 1.35),
        ),
      ],
    );
  }

  Widget _availabilityStatusBadge(String key) {
    final status = _statusFor(key);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: status.color, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _availabilityEditor(CrewAvailabilityRecord? record) {
    final selectable =
        widget.statuses.where((item) => item.selectable).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detalle del dia',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            _dateLabel(widget.selectedDate),
            style: const TextStyle(
              color: Color(0xFF0E2338),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  record?.label ?? 'Sin estado registrado',
                  style: TextStyle(
                    color: record?.color ?? const Color(0xFF5F6975),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _availabilityStatusBadge(_selectedStatus),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Estado',
              border: OutlineInputBorder(),
            ),
            items:
                selectable
                    .map(
                      (status) => DropdownMenuItem(
                        value: status.key,
                        child: Text(status.label),
                      ),
                    )
                    .toList(),
            onChanged:
                widget.isLoading
                    ? null
                    : (value) {
                      if (value == null) return;
                      setState(() => _selectedStatus = value);
                    },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _commentController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Comentario',
              hintText: 'Escribe un comentario para Admin / Red Sky',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          _availabilityMeta(),
          const SizedBox(height: 12),
          Text(
            'Origen: ${record?.origin ?? 'SISTEMA'}',
            style: const TextStyle(color: Color(0xFF5F6975)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  widget.isLoading
                      ? null
                      : () => widget.onSave(
                        widget.selectedDate,
                        _selectedStatus,
                        _commentController.text.trim(),
                      ),
              icon: const Icon(Icons.save_rounded),
              label: const Text('Guardar disponibilidad'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _operationEditor(
    CrewAssignment? operation,
    CrewAvailabilityRecord? record,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration().copyWith(
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detalle del dia',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            _dateLabel(widget.selectedDate),
            style: const TextStyle(
              color: Color(0xFF0E2338),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            operation == null
                ? record?.comment ?? 'La operacion fue asignada por admin.'
                : '${operation.code} | ${operation.route} | ${operation.showTime}',
            style: const TextStyle(color: Color(0xFF41566A), height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'En operacion',
              style: TextStyle(
                color: Color(0xFF1D4ED8),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _availabilityMeta(),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  widget.isLoading
                      ? null
                      : () => widget.onRequestChange(widget.selectedDate),
              icon: const Icon(Icons.edit_calendar_rounded),
              label: const Text('Solicitar cambio'),
            ),
          ),
        ],
      ),
    );
  }

  CrewAssignment? _operationFor(DateTime day) {
    for (final assignment in widget.assignments) {
      if (isSameDay(assignment.date, day) &&
          !assignment.status.toLowerCase().contains('rechaz')) {
        return assignment;
      }
    }
    return null;
  }

  CrewAvailabilityStatus _statusFor(String key) {
    for (final status in widget.statuses) {
      if (status.key == key) return status;
    }
    for (final status in CrewAvailabilityStatus.defaults) {
      if (status.key == key) return status;
    }
    return CrewAvailabilityStatus(
      key: key,
      label: key.replaceAll('_', ' '),
      description: '',
      color: const Color(0xFF94A3B8),
    );
  }

  String _dateLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({
    required this.form,
    required this.onChanged,
    required this.onSave,
  });

  final Map<String, dynamic> form;
  final void Function(String, dynamic) onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    const profileStates = ['Pendiente', 'Validado', 'En revision', 'Rechazado'];
    final rawProfileState = form['profileState']?.toString().trim() ?? '';
    final selectedProfileState =
        profileStates.contains(rawProfileState) ? rawProfileState : null;

    return Column(
      children: [
        const _InfoTile(
          icon: Icons.person_pin_rounded,
          title: 'Perfil de vuelo',
          subtitle: 'Edita base, idiomas, experiencia y cobertura operativa.',
        ),
        _FormPanel(
          title: 'Datos operativos',
          children: [
            _TextFormLine(
              label: 'Nombre',
              value: form['name']?.toString() ?? '',
              onChanged: (value) => onChanged('name', value),
            ),
            _TextFormLine(
              label: 'Base',
              value: form['base']?.toString() ?? '',
              onChanged: (value) => onChanged('base', value),
            ),
            _TextFormLine(
              label: 'Idiomas',
              value: form['languages']?.toString() ?? '',
              onChanged: (value) => onChanged('languages', value),
            ),
            _TextFormLine(
              label: 'Experiencia',
              value: form['experience']?.toString() ?? '',
              onChanged: (value) => onChanged('experience', value),
              maxLines: 3,
            ),
            _TextFormLine(
              label: 'Cobertura',
              value: form['coverage']?.toString() ?? '',
              onChanged: (value) => onChanged('coverage', value),
            ),
            DropdownButtonFormField<String>(
              initialValue: selectedProfileState,
              decoration: const InputDecoration(labelText: 'Estado perfil'),
              items:
                  profileStates
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
              onChanged: (value) => onChanged('profileState', value ?? ''),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Guardar perfil'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DocumentsView extends StatelessWidget {
  const _DocumentsView({
    required this.documents,
    required this.onCreate,
    required this.onStatusChanged,
  });

  final List<CrewDocument> documents;
  final void Function(CrewDocument, File?) onCreate;
  final void Function(CrewDocument, String) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _InfoTile(
          icon: Icons.info_outline_rounded,
          title: 'Mis documentos',
          subtitle: 'Consulta y actualiza la información de tus documentos.',
        ),
        const SizedBox(height: 14),
        _DocumentComposer(onCreate: onCreate),
        const SizedBox(height: 14),
        ...documents.map(
          (item) => _DocumentTile(
            document: item,
            onStatusChanged: (status) => onStatusChanged(item, status),
          ),
        ),
      ],
    );
  }
}

class _IncidentsView extends StatelessWidget {
  const _IncidentsView({
    required this.assignments,
    required this.incidents,
    required this.onCreate,
  });

  final List<CrewAssignment> assignments;
  final List<CrewIncident> incidents;
  final ValueChanged<CrewAssignment> onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionCard(
          title: 'Crear incidencia operativa',
          subtitle:
              assignments.isEmpty
                  ? 'Necesitas una mision asignada para levantar incidencia.'
                  : 'Registra retrasos, catering, documento, FBO o servicio.',
          icon: Icons.add_alert_rounded,
          button: 'Nueva incidencia',
          onPressed:
              assignments.isEmpty ? null : () => onCreate(assignments.first),
        ),
        const SizedBox(height: 14),
        ...incidents.map((item) => _IncidentTile(incident: item)),
      ],
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView({
    required this.assignments,
    required this.incidents,
    required this.onOpenOperation,
  });

  final List<CrewAssignment> assignments;
  final List<CrewIncident> incidents;
  final ValueChanged<CrewAssignment> onOpenOperation;

  @override
  Widget build(BuildContext context) {
    final completed =
        assignments.where((item) => item.status == 'Finalizada').toList();
    return Column(
      children: [
        _MetricGrid(
          metrics: [
            _Metric('Vuelos completados', '${completed.length}', Icons.flight),
            _Metric('Incidencias', '${incidents.length}', Icons.report),
          ],
        ),
        const SizedBox(height: 14),
        if (completed.isEmpty)
          const _InfoTile(
            icon: Icons.history_rounded,
            title: 'Sin vuelos finalizados',
            subtitle: 'El historial se generara automaticamente.',
          )
        else
          ...completed.map(
            (item) => Column(
              children: [
                _AssignmentCard(item: item),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => onOpenOperation(item),
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('Ver tareas y reporte del vuelo'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PaymentsView extends StatelessWidget {
  const _PaymentsView({required this.payments, required this.assignments});

  final List<CrewPaymentRecord> payments;
  final List<CrewAssignment> assignments;

  @override
  Widget build(BuildContext context) {
    final completed =
        assignments.where((item) => item.status == 'Finalizada').length;
    return Column(
      children: [
        _MetricGrid(
          metrics: [
            _Metric('Servicios', '$completed', Icons.room_service_rounded),
            _Metric(
              'Pagos registrados',
              '${payments.length}',
              Icons.receipt_long_rounded,
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...payments.map(
          (item) => _InfoTile(
            icon: Icons.receipt_long_rounded,
            title: item.concept,
            subtitle: '${item.assignment} | ${item.amount} | ${item.status}',
          ),
        ),
      ],
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView({
    required this.form,
    required this.onChanged,
    required this.onSave,
  });

  final Map<String, dynamic> form;
  final void Function(String, dynamic) onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FormPanel(
          title: 'Preferencias del portal',
          children: [
            SwitchListTile(
              value: form['notifyAssignments'] == true,
              onChanged: (value) => onChanged('notifyAssignments', value),
              title: const Text('Notificar nuevas asignaciones'),
            ),
            SwitchListTile(
              value: form['notifyIncidents'] == true,
              onChanged: (value) => onChanged('notifyIncidents', value),
              title: const Text('Notificar incidencias'),
            ),
            SwitchListTile(
              value: form['notifyScheduleChanges'] == true,
              onChanged: (value) => onChanged('notifyScheduleChanges', value),
              title: const Text('Cambios de agenda'),
            ),
            _TextFormLine(
              label: 'Cobertura personal',
              value: form['personalCoverage']?.toString() ?? '',
              onChanged: (value) => onChanged('personalCoverage', value),
            ),
            DropdownButtonFormField<String>(
              initialValue:
                  form['escalationMode']?.toString() ?? 'Admin primero',
              decoration: const InputDecoration(labelText: 'Escalamiento'),
              items:
                  const [
                        'Admin primero',
                        'Admin y operador',
                        'Solo admin en criticas',
                      ]
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
              onChanged: (value) => onChanged('escalationMode', value ?? ''),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Guardar configuracion'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0E2338),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _TextFormLine extends StatelessWidget {
  const _TextFormLine({
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      ),
    );
  }
}

class _DocumentComposer extends StatefulWidget {
  const _DocumentComposer({required this.onCreate});

  final void Function(CrewDocument, File?) onCreate;

  @override
  State<_DocumentComposer> createState() => _DocumentComposerState();
}

class _DocumentComposerState extends State<_DocumentComposer> {
  final _name = TextEditingController();
  final _expiration = TextEditingController();
  final _note = TextEditingController();
  String _category = 'Certificacion';

  @override
  void dispose() {
    _name.dispose();
    _expiration.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FormPanel(
      title: 'Alta documental',
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: const InputDecoration(labelText: 'Categoria'),
          items:
              const ['Certificacion', 'Identidad', 'Idioma', 'Experiencia']
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
          onChanged: (value) => setState(() => _category = value ?? _category),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _expiration,
          decoration: const InputDecoration(
            labelText: 'Vencimiento',
            hintText: '2027-12-31',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Nota'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Se registrará únicamente la referencia y sus metadatos.',
          style: TextStyle(color: Color(0xFF5F6975)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar documento'),
          ),
        ),
      ],
    );
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    widget.onCreate(
      CrewDocument(
        title: name,
        status: 'Pendiente',
        expiration:
            _expiration.text.trim().isEmpty
                ? 'Sin vigencia'
                : _expiration.text.trim(),
        category: _category,
        note: _note.text.trim(),
        localPath: '',
      ),
      null,
    );
    _name.clear();
    _expiration.clear();
    _note.clear();
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document, required this.onStatusChanged});

  final CrewDocument document;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    const statusOptions = [
      'Pendiente',
      'En revision',
      'Aprobado',
      'Rechazado',
      'Vence pronto',
      'Vigente',
    ];
    final selectedStatus =
        statusOptions.contains(document.status) ? document.status : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            document.title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${document.category} | Vence: ${document.expiration}',
            style: const TextStyle(color: Color(0xFF5F6975)),
          ),
          if (document.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(document.note),
          ],
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: selectedStatus,
            decoration: const InputDecoration(labelText: 'Estado'),
            items:
                statusOptions
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
            onChanged: (value) {
              if (value != null) onStatusChanged(value);
            },
          ),
        ],
      ),
    );
  }
}

class _IncidentTile extends StatelessWidget {
  const _IncidentTile({required this.incident});

  final CrewIncident incident;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _incidentDisplayTitle(incident);
    final statusLabel = _incidentStatusLabel(incident.status);
    final priorityLabel = _incidentPriorityLabel(incident.priority);
    final evidenceLabel = _incidentEvidenceLabel(incident);
    final hasEvidence = evidenceLabel.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F223A),
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _IncidentBadge.status(
                status: incident.status,
                label: statusLabel,
              ),
            ],
          ),
          const SizedBox(height: 6),
          _IncidentBadge.priority(
            priority: incident.priority,
            label: priorityLabel,
          ),
          const SizedBox(height: 10),
          if (incident.description.isNotEmpty) ...[
            Text(
              incident.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF4D5B6A),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (hasEvidence) ...[
            _IncidentEvidenceRow(incident: incident),
            const SizedBox(height: 12),
          ],
          if (incident.comments.isNotEmpty) ...[
            ...incident.comments
                .take(2)
                .map(
                  (comment) => Text(
                    'Comentario: $comment',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF344054),
                    ),
                  ),
                ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showIncidentDetailModal(context, incident),
              icon: const Icon(Icons.visibility_rounded),
              label: const Text('Ver detalle'),
            ),
          ),
        ],
      ),
    );
  }
}

String _incidentDisplayTitle(CrewIncident incident) {
  final raw = [
    incident.title,
    incident.category,
    incident.type,
  ].firstWhere((item) => item.trim().isNotEmpty, orElse: () => 'Incidencia');
  final normalized = raw.trim();
  if (normalized.toLowerCase().contains('cabina')) return 'Cabina';
  return normalized[0].toUpperCase() + normalized.substring(1);
}

String _incidentStatusLabel(String status) {
  final value = status.trim().toLowerCase();
  if (value == 'open' || value.contains('abiert')) return 'Abierta';
  if (value == 'closed' || value.contains('cerr')) return 'Cerrada';
  if (value == 'resolved' || value.contains('resuelt')) return 'Resuelta';
  if (value == 'pending' || value.contains('pend')) return 'Pendiente';
  if (value.isEmpty) return 'Abierta';
  return status.trim();
}

String _incidentPriorityLabel(String priority) {
  final value = priority.trim().toLowerCase();
  if (value == 'high' || value.contains('alta')) return 'Prioridad alta';
  if (value == 'medium' || value.contains('media')) return 'Prioridad media';
  if (value == 'low' || value.contains('baja')) return 'Prioridad baja';
  return priority.trim().isEmpty ? 'Prioridad media' : priority.trim();
}

String _incidentOperationType(CrewIncident incident) {
  final candidates = [incident.category, incident.type, incident.assignment];
  for (final candidate in candidates) {
    final value = candidate.trim();
    if (value.isEmpty) continue;
    if (value.toLowerCase() == 'operacion') return 'Operación';
    if (value.toLowerCase() == 'operation') return 'Operación';
    return value.replaceAll('Operacion', 'Operación');
  }
  return 'Operación';
}

String _incidentEvidenceLabel(CrewIncident incident) {
  final evidence = incident.evidence.trim();
  if (evidence.isEmpty || evidence.toLowerCase() == 'sin evidencia') return '';
  if (evidence.contains(',')) {
    return evidence
        .split(',')
        .map((item) => item.trim())
        .firstWhere((item) => item.isNotEmpty, orElse: () => evidence);
  }
  return evidence;
}

bool _isImageEvidence(CrewIncident incident) {
  final mimeType = incident.evidenceMimeType.trim().toLowerCase();
  if (mimeType.startsWith('image/')) return true;

  bool matchesImageExtension(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return false;
    final parsed = Uri.tryParse(raw);
    final candidate =
        parsed != null && parsed.path.isNotEmpty ? parsed.path : raw;
    final lower = candidate.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  return matchesImageExtension(incident.evidenceUrl) ||
      matchesImageExtension(_incidentEvidenceLabel(incident));
}

Future<void> _showIncidentDetailModal(
  BuildContext context,
  CrewIncident incident,
) {
  final media = MediaQuery.of(context);
  final theme = Theme.of(context);
  final statusLabel = _incidentStatusLabel(incident.status);
  final priorityLabel = _incidentPriorityLabel(incident.priority);
  final operationType = _incidentOperationType(incident);
  final evidenceLabel = _incidentEvidenceLabel(incident);
  final hasEvidence = evidenceLabel.isNotEmpty;
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder:
        (dialogContext) => Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: media.size.width * 0.9,
              maxHeight: media.size.height * 0.82,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFDFEFF),
                borderRadius: BorderRadius.circular(26),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Incidencia de cabina',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF10243E),
                              fontSize: 24,
                              height: 1.05,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF2F5F8),
                            foregroundColor: const Color(0xFF10243E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _IncidentBadge.priority(
                          priority: incident.priority,
                          label: priorityLabel,
                        ),
                        _IncidentBadge.status(
                          status: incident.status,
                          label: statusLabel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Tipo de operación',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF24384D),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _IncidentInfoBlock(
                      child: Text(
                        operationType,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF10243E),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Descripción',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF24384D),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _IncidentInfoBlock(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        incident.description.trim().isEmpty
                            ? 'Sin descripción disponible.'
                            : incident.description.trim(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF435567),
                          height: 1.35,
                        ),
                      ),
                    ),
                    if (hasEvidence) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Evidencia',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF24384D),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _IncidentEvidenceRow(incident: incident),
                    ],
                    if (!hasEvidence) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Sin evidencia adjunta',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6B7886),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (incident.comments.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Comentarios',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF24384D),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _IncidentInfoBlock(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children:
                              incident.comments
                                  .take(2)
                                  .map(
                                    (comment) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        comment,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: const Color(0xFF435567),
                                              height: 1.35,
                                            ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10243E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Cerrar',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
  );
}

Future<void> _showIncidentEvidencePreview(
  BuildContext context,
  CrewIncident incident,
) {
  final url = resolveMediaUrl(incident.evidenceUrl);
  final label = _incidentEvidenceLabel(incident);
  final isImage = _isImageEvidence(incident);
  if (url.isEmpty || !isImage) {
    return showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Evidencia'),
            content: Text(
              label.isEmpty
                  ? 'No hay una imagen disponible para esta evidencia.'
                  : label,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cerrar'),
              ),
            ],
          ),
    );
  }
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder:
        (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          backgroundColor: const Color(0xFFFDFEFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Evidencia',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10243E),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(
                      minHeight: 180,
                      maxHeight: 400,
                    ),
                    color: const Color(0xFFF3F5F8),
                    child: InteractiveViewer(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const SizedBox(
                            height: 220,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder:
                            (context, error, stackTrace) => const SizedBox(
                              height: 220,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.broken_image_outlined,
                                      size: 42,
                                      color: Color(0xFF6B7886),
                                    ),
                                    SizedBox(height: 8),
                                    Text('No fue posible cargar la imagen'),
                                  ],
                                ),
                              ),
                            ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  label.isEmpty ? 'Archivo adjunto' : label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF10243E),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10243E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Cerrar',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
  );
}

Future<CrewIncident> _resolveIncidentForEvidence(CrewIncident incident) async {
  if (incident.evidenceUrl.trim().isNotEmpty || incident.id.trim().isEmpty) {
    return incident;
  }
  try {
    final response = await ApiClient.instance.get(
      '/crew-operation-incidents/${incident.id}',
      authenticated: true,
    );
    final source = _asMap(response['incident'] ?? response['data'] ?? response);
    if (source.isEmpty) return incident;
    final resolved = CrewIncident.fromJson(source);
    if (resolved.evidenceUrl.trim().isEmpty) return incident;
    return resolved;
  } catch (_) {
    return incident;
  }
}

class _IncidentBadge extends StatelessWidget {
  const _IncidentBadge._({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
  });

  factory _IncidentBadge.priority({
    required String priority,
    required String label,
  }) {
    final value = priority.trim().toLowerCase();
    if (value == 'high' || value.contains('alta')) {
      return _IncidentBadge._(
        label: '⚠ $label',
        backgroundColor: Color(0xFFFFECE8),
        foregroundColor: Color(0xFFC2412D),
        icon: null,
      );
    }
    if (value == 'low' || value.contains('baja')) {
      return _IncidentBadge._(
        label: '⚠ $label',
        backgroundColor: Color(0xFFEFF4FB),
        foregroundColor: Color(0xFF355B8C),
        icon: null,
      );
    }
    return _IncidentBadge._(
      label: '⚠ $label',
      backgroundColor: Color(0xFFFFF4DE),
      foregroundColor: Color(0xFF9D6B10),
      icon: null,
    );
  }

  factory _IncidentBadge.status({
    required String status,
    required String label,
  }) {
    final value = status.trim().toLowerCase();
    if (value == 'closed' || value.contains('cerr')) {
      return _IncidentBadge._(
        label: '● $label',
        backgroundColor: const Color(0xFFF0F2F5),
        foregroundColor: const Color(0xFF667085),
        icon: null,
      );
    }
    if (value == 'resolved' || value.contains('resuelt')) {
      return _IncidentBadge._(
        label: '● $label',
        backgroundColor: const Color(0xFFE7F8EE),
        foregroundColor: const Color(0xFF137A4B),
        icon: null,
      );
    }
    if (value == 'pending' || value.contains('pend')) {
      return _IncidentBadge._(
        label: '● $label',
        backgroundColor: const Color(0xFFFFF4DE),
        foregroundColor: const Color(0xFF9D6B10),
        icon: null,
      );
    }
    return _IncidentBadge._(
      label: '● $label',
      backgroundColor: const Color(0xFFEAF8EF),
      foregroundColor: const Color(0xFF1F7A4F),
      icon: null,
    );
  }

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foregroundColor),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncidentInfoBlock extends StatelessWidget {
  const _IncidentInfoBlock({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _IncidentEvidenceRow extends StatelessWidget {
  const _IncidentEvidenceRow({required this.incident});

  final CrewIncident incident;

  @override
  Widget build(BuildContext context) {
    final label = _incidentEvidenceLabel(incident);
    final resolvedUrl = resolveMediaUrl(incident.evidenceUrl);
    final clickable = resolvedUrl.isNotEmpty || _isImageEvidence(incident);
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(_evidenceIcon(label), color: const Color(0xFF435567), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF10243E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (clickable)
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF7A8794)),
        ],
      ),
    );
    if (!clickable) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final resolvedIncident = await _resolveIncidentForEvidence(incident);
        if (!context.mounted) return;
        await _showIncidentEvidencePreview(context, resolvedIncident);
      },
      child: card,
    );
  }

  IconData _evidenceIcon(String value) {
    final lower = value.toLowerCase();
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif')) {
      return Icons.image_outlined;
    }
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    return Icons.attach_file_rounded;
  }
}
