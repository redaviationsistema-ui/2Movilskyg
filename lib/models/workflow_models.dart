import 'package:flutter/material.dart';

class StaticAction {
  final IconData icon;
  final String label;
  final String message;

  const StaticAction({
    required this.icon,
    required this.label,
    required this.message,
  });
}

class StaticRecord {
  final String title;
  final String subtitle;
  final String status;
  final String amount;

  const StaticRecord({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.amount,
  });

  StaticRecord copyWith({
    String? title,
    String? subtitle,
    String? status,
    String? amount,
  }) {
    return StaticRecord(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      status: status ?? this.status,
      amount: amount ?? this.amount,
    );
  }
}

class WorkflowSnapshot {
  final List<StaticRecord> records;
  final bool onlyAttention;
  final int operationCount;
  final String lastAudit;

  const WorkflowSnapshot({
    required this.records,
    required this.onlyAttention,
    required this.operationCount,
    required this.lastAudit,
  });

  WorkflowSnapshot copyWith({
    List<StaticRecord>? records,
    bool? onlyAttention,
    int? operationCount,
    String? lastAudit,
  }) {
    return WorkflowSnapshot(
      records: records ?? this.records,
      onlyAttention: onlyAttention ?? this.onlyAttention,
      operationCount: operationCount ?? this.operationCount,
      lastAudit: lastAudit ?? this.lastAudit,
    );
  }
}
