import 'package:flutter/foundation.dart';

import '../models/workflow_models.dart';

class WorkflowProvider extends ChangeNotifier {
  final Map<String, WorkflowSnapshot> _states = {};

  WorkflowSnapshot watch({
    required String flowId,
    required List<StaticRecord> initialRecords,
  }) {
    _states.putIfAbsent(
      flowId,
      () => WorkflowSnapshot(
        records: List<StaticRecord>.from(initialRecords),
        onlyAttention: false,
        operationCount: 0,
        lastAudit: 'Sin operaciones recientes',
      ),
    );
    return _states[flowId]!;
  }

  List<StaticRecord> visibleRecords(String flowId) {
    final state = _states[flowId];
    if (state == null) return const [];
    if (!state.onlyAttention) return state.records;
    return state.records.where(_needsAttention).toList();
  }

  void createRecord(String flowId, StaticRecord record) {
    final state = _states[flowId];
    if (state == null) return;
    _states[flowId] = state.copyWith(
      records: [record, ...state.records],
      operationCount: state.operationCount + 1,
      lastAudit: '${record.title} creado correctamente',
    );
    notifyListeners();
  }

  void updateRecord(
    String flowId,
    StaticRecord original,
    StaticRecord updated,
  ) {
    final state = _states[flowId];
    if (state == null) return;
    final records = List<StaticRecord>.from(state.records);
    final index = records.indexOf(original);
    if (index == -1) return;
    records[index] = updated;
    _states[flowId] = state.copyWith(
      records: records,
      operationCount: state.operationCount + 1,
      lastAudit: '${updated.title} actualizado correctamente',
    );
    notifyListeners();
  }

  void deleteRecord(String flowId, StaticRecord record) {
    final state = _states[flowId];
    if (state == null) return;
    final records = List<StaticRecord>.from(state.records)..remove(record);
    _states[flowId] = state.copyWith(
      records: records,
      operationCount: state.operationCount + 1,
      lastAudit: '${record.title} eliminado correctamente',
    );
    notifyListeners();
  }

  StaticRecord? applyStatusToFirstActionable(
    String flowId, {
    required String status,
    required String suffix,
  }) {
    final state = _states[flowId];
    if (state == null || state.records.isEmpty) return null;
    final records = List<StaticRecord>.from(state.records);
    final updated = _updateFirstActionable(
      records,
      status: status,
      suffix: suffix,
    );
    _states[flowId] = state.copyWith(
      records: records,
      operationCount: state.operationCount + 1,
      lastAudit: '${updated?.title ?? 'Registro'} cambio a $status',
    );
    notifyListeners();
    return updated;
  }

  void toggleAttentionFilter(String flowId) {
    final state = _states[flowId];
    if (state == null) return;
    final onlyAttention = !state.onlyAttention;
    _states[flowId] = state.copyWith(
      onlyAttention: onlyAttention,
      operationCount: state.operationCount + 1,
      lastAudit:
          onlyAttention
              ? 'Filtro de pendientes activado'
              : 'Vista completa restaurada',
    );
    notifyListeners();
  }

  void applyAction(String flowId, StaticAction action) {
    final state = _states[flowId];
    if (state == null) return;

    final records = List<StaticRecord>.from(state.records);
    final label = action.label.toLowerCase();
    var onlyAttention = state.onlyAttention;
    var audit = '${action.label} ejecutado correctamente';

    if (label.contains('filtrar') || label.contains('ver')) {
      onlyAttention = !onlyAttention;
      audit =
          onlyAttention
              ? 'Filtro de pendientes activado'
              : 'Vista completa restaurada';
    } else if (label.contains('buscar')) {
      records.insert(
        0,
        const StaticRecord(
          title: 'Nueva busqueda generada',
          subtitle: 'Ruta capturada desde app movil | pendiente de cotizar',
          status: 'Pendiente',
          amount: 'Ahora',
        ),
      );
    } else if (label.contains('crear') ||
        label.contains('nueva') ||
        label.contains('alta') ||
        label.contains('subir') ||
        label.contains('invitar')) {
      records.insert(
        0,
        StaticRecord(
          title: '${action.label} registrado',
          subtitle: 'Registro creado y guardado como si viniera del backend.',
          status: 'Pendiente',
          amount: 'Nuevo',
        ),
      );
    } else if (label.contains('exportar') || label.contains('reporte')) {
      records.insert(
        0,
        StaticRecord(
          title: 'Reporte generado',
          subtitle: 'Archivo simulado creado con ${records.length} registros.',
          status: 'Confirmado',
          amount: 'PDF',
        ),
      );
    } else if (label.contains('rechazar')) {
      _updateFirstActionable(records, status: 'Rechazado', suffix: 'rechazado');
    } else if (label.contains('bloquear')) {
      _updateFirstActionable(records, status: 'Bloqueado', suffix: 'bloqueado');
    } else if (label.contains('aceptar') ||
        label.contains('aprobar') ||
        label.contains('activar') ||
        label.contains('confirmar') ||
        label.contains('liberar') ||
        label.contains('finalizar') ||
        label.contains('marcar aceptada')) {
      _updateFirstActionable(
        records,
        status: 'Confirmado',
        suffix: 'confirmado',
      );
    } else if (label.contains('iniciar')) {
      _updateFirstActionable(records, status: 'En curso', suffix: 'iniciado');
    } else if (label.contains('contraofertar')) {
      _updateFirstActionable(
        records,
        status: 'Contraoferta',
        suffix: 'contraofertado',
      );
    } else if (label.contains('editar') ||
        label.contains('actualizar') ||
        label.contains('cambiar') ||
        label.contains('mejorar') ||
        label.contains('metodo') ||
        label.contains('membresia') ||
        label.contains('plan')) {
      _updateFirstActionable(
        records,
        status: 'Actualizado',
        suffix: 'actualizado',
      );
    } else {
      _updateFirstActionable(records, status: 'Procesado', suffix: 'procesado');
    }

    _states[flowId] = state.copyWith(
      records: records,
      onlyAttention: onlyAttention,
      operationCount: state.operationCount + 1,
      lastAudit: audit,
    );
    notifyListeners();
  }

  void advanceRecord(String flowId, StaticRecord record) {
    final state = _states[flowId];
    if (state == null) return;
    final records = List<StaticRecord>.from(state.records);
    final index = records.indexOf(record);
    if (index == -1) return;

    final status = _nextStatus(record.status);
    records[index] = record.copyWith(
      status: status,
      subtitle: '${record.subtitle} | cambio manual guardado',
    );

    _states[flowId] = state.copyWith(
      records: records,
      operationCount: state.operationCount + 1,
      lastAudit: '${record.title} cambio a $status',
    );
    notifyListeners();
  }

  StaticRecord? _updateFirstActionable(
    List<StaticRecord> records, {
    required String status,
    required String suffix,
  }) {
    if (records.isEmpty) return null;
    final index = records.indexWhere(_needsAttention);
    final targetIndex = index == -1 ? 0 : index;
    final record = records[targetIndex];
    final updated = record.copyWith(
      status: status,
      subtitle: '${record.subtitle} | $suffix en app movil',
    );
    records[targetIndex] = updated;
    return updated;
  }

  bool _needsAttention(StaticRecord record) {
    final value = record.status.toLowerCase();
    return value.contains('pendiente') ||
        value.contains('revision') ||
        value.contains('nueva') ||
        value.contains('critica') ||
        value.contains('vencida') ||
        value.contains('bloqueado');
  }

  String _nextStatus(String status) {
    final value = status.toLowerCase();
    if (value.contains('pendiente') || value.contains('nueva')) {
      return 'En revision';
    }
    if (value.contains('revision') || value.contains('critica')) {
      return 'Confirmado';
    }
    if (value.contains('confirmado') || value.contains('activo')) {
      return 'Finalizado';
    }
    if (value.contains('bloqueado')) return 'Activo';
    return 'Actualizado';
  }
}
