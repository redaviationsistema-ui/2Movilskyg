import 'package:flutter/material.dart';

import '../../../models/workflow_models.dart';

class WorkflowActionPanel extends StatelessWidget {
  const WorkflowActionPanel({
    super.key,
    required this.actions,
    required this.onAction,
  });

  final List<StaticAction> actions;
  final Future<void> Function(StaticAction action) onAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 720;
        final buttons =
            actions
                .map(
                  (action) => _WorkflowButton(
                    action: action,
                    compact: narrow,
                    onPressed: () => onAction(action),
                  ),
                )
                .toList();

        if (narrow) {
          return Column(
            children:
                buttons
                    .map(
                      (child) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: child,
                      ),
                    )
                    .toList(),
          );
        }

        return Row(
          children:
              buttons
                  .map(
                    (child) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: child,
                      ),
                    ),
                  )
                  .toList(),
        );
      },
    );
  }
}

class WorkflowHeroActions {
  static Future<void> run(
    BuildContext context, {
    required StaticAction action,
    required Future<void> Function(StaticAction action) onAction,
    required String operation,
  }) async {
    await onAction(action);
  }
}

class _WorkflowButton extends StatelessWidget {
  const _WorkflowButton({
    required this.action,
    required this.compact,
    required this.onPressed,
  });

  final StaticAction action;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(action.icon),
      label: Text(action.label),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF10253A),
        foregroundColor: Colors.white,
        minimumSize: Size(double.infinity, compact ? 48 : 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
