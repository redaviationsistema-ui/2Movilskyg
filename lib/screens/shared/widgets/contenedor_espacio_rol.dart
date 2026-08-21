import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/proveedor_autenticacion.dart';

class RoleWorkspaceShellScope extends InheritedWidget {
  const RoleWorkspaceShellScope({
    super.key,
    required super.child,
    required this.openDrawer,
    required this.selectIndex,
    required this.selectSection,
  });

  final VoidCallback openDrawer;
  final ValueChanged<int> selectIndex;
  final void Function(int workspaceIndex, {Object? section}) selectSection;

  static RoleWorkspaceShellScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<RoleWorkspaceShellScope>();
  }

  @override
  bool updateShouldNotify(RoleWorkspaceShellScope oldWidget) {
    return openDrawer != oldWidget.openDrawer ||
        selectIndex != oldWidget.selectIndex ||
        selectSection != oldWidget.selectSection;
  }
}

class RoleWorkspaceItem {
  final String label;
  final String shortLabel;
  final IconData icon;
  final Widget screen;

  const RoleWorkspaceItem({
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.screen,
  });
}

class RoleWorkspaceDrawerItem {
  const RoleWorkspaceDrawerItem({
    required this.label,
    required this.section,
    this.enabled = true,
    this.status = RoleWorkspaceDrawerItemStatus.pending,
  });

  final String label;
  final Object section;
  final bool enabled;
  final RoleWorkspaceDrawerItemStatus status;
}

class RoleWorkspaceDrawerGroup {
  const RoleWorkspaceDrawerGroup({
    required this.workspaceIndex,
    required this.items,
  });

  final int workspaceIndex;
  final List<RoleWorkspaceDrawerItem> items;
}

enum RoleWorkspaceDrawerItemStatus { pending, completed, blocked }

class RoleWorkspaceShell extends StatefulWidget {
  const RoleWorkspaceShell({
    super.key,
    required this.branchLabel,
    required this.roleLabel,
    required this.title,
    required this.items,
    this.initialIndex = 0,
    this.bodyBuilder,
    this.drawerGroups = const [],
    this.activeSection,
    this.onSelectSection,
    this.userPhone,
  });

  final String branchLabel;
  final String roleLabel;
  final String title;
  final List<RoleWorkspaceItem> items;
  final int initialIndex;
  final Widget Function(int selectedIndex)? bodyBuilder;
  final List<RoleWorkspaceDrawerGroup> drawerGroups;
  final Object? activeSection;
  final void Function(int workspaceIndex, {Object? section})? onSelectSection;
  final String? userPhone;

  @override
  State<RoleWorkspaceShell> createState() => _RoleWorkspaceShellState();
}

class _RoleWorkspaceShellState extends State<RoleWorkspaceShell> {
  late int _selectedIndex;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isWide = MediaQuery.of(context).size.width >= 960;
    final currentItem = widget.items[_selectedIndex];
    final currentBody =
        widget.bodyBuilder?.call(_selectedIndex) ?? currentItem.screen;
    final userEmail = auth.user?.email ?? 'sin correo';
    final userPhone = auth.user?.phone.trim();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF06111D),
      drawer:
          isWide
              ? null
              : _WorkspaceDrawer(
                branchLabel: widget.branchLabel,
                roleLabel: widget.roleLabel,
                title: widget.title,
                userEmail: userEmail,
                userPhone: userPhone,
                items: widget.items,
                groups: widget.drawerGroups,
                selectedIndex: _selectedIndex,
                activeSection: widget.activeSection,
                onSelect: _selectIndex,
                onSelectSection: _selectSection,
                onLogout: auth.signOut,
              ),
      body: Builder(
        builder: (scaffoldContext) {
          return RoleWorkspaceShellScope(
            openDrawer: () => Scaffold.of(scaffoldContext).openDrawer(),
            selectIndex: _selectIndex,
            selectSection: _selectSection,
            child: SafeArea(
              child:
                  isWide
                      ? Row(
                        children: [
                          _WorkspaceSidebar(
                            branchLabel: widget.branchLabel,
                            roleLabel: widget.roleLabel,
                            title: widget.title,
                            userEmail: userEmail,
                            userPhone: userPhone,
                            items: widget.items,
                            selectedIndex: _selectedIndex,
                            onSelect: _selectIndex,
                            onLogout: auth.signOut,
                          ),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                final slide = Tween<Offset>(
                                  begin: const Offset(0.03, 0),
                                  end: Offset.zero,
                                ).animate(animation);

                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: slide,
                                    child: child,
                                  ),
                                );
                              },
                              child:
                                  widget.bodyBuilder != null
                                      ? currentBody
                                      : KeyedSubtree(
                                        key: ValueKey(currentItem.label),
                                        child: currentBody,
                                      ),
                            ),
                          ),
                        ],
                      )
                      : Column(
                        children: [
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                final slide = Tween<Offset>(
                                  begin: const Offset(0, 0.02),
                                  end: Offset.zero,
                                ).animate(animation);

                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: slide,
                                    child: child,
                                  ),
                                );
                              },
                              child:
                                  widget.bodyBuilder != null
                                      ? currentBody
                                      : KeyedSubtree(
                                        key: ValueKey(currentItem.label),
                                        child: currentBody,
                                      ),
                            ),
                          ),
                          _WorkspaceBottomNav(
                            items: widget.items,
                            selectedIndex: _selectedIndex,
                            onSelect: _selectIndex,
                          ),
                        ],
                      ),
            ),
          );
        },
      ),
    );
  }

  void _selectIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _selectSection(int workspaceIndex, {Object? section}) {
    setState(() {
      _selectedIndex = workspaceIndex;
    });
    widget.onSelectSection?.call(workspaceIndex, section: section);
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }
}

class _WorkspaceBottomNav extends StatelessWidget {
  const _WorkspaceBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<RoleWorkspaceItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final visibleEntries =
        items.length <= 5
            ? items.asMap().entries.toList()
            : [
              ...items.asMap().entries.take(4),
              MapEntry(
                selectedIndex >= 4 ? selectedIndex : 4,
                items[selectedIndex >= 4 ? selectedIndex : 4],
              ),
            ];
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF0E2235),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x33E0B86E)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children:
              visibleEntries.map((entry) {
                final item = entry.value;
                final originalIndex = entry.key;
                final isSelected = originalIndex == selectedIndex;
                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => onSelect(originalIndex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? const Color(0xFFE0B86E)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            size: 19,
                            color:
                                isSelected
                                    ? const Color(0xFF10253A)
                                    : Colors.white.withValues(alpha: 0.82),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.shortLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                                  isSelected
                                      ? const Color(0xFF10253A)
                                      : Colors.white.withValues(alpha: 0.74),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }
}

class _WorkspaceSidebar extends StatelessWidget {
  const _WorkspaceSidebar({
    required this.branchLabel,
    required this.roleLabel,
    required this.title,
    required this.userEmail,
    required this.userPhone,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
  });

  final String branchLabel;
  final String roleLabel;
  final String title;
  final String userEmail;
  final String? userPhone;
  final List<RoleWorkspaceItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF07121D), Color(0xFF0E2238), Color(0xFF14324B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WorkspaceIdentityCard(
            branchLabel: branchLabel,
            roleLabel: roleLabel,
            title: title,
            userEmail: userEmail,
            userPhone: userPhone,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _WorkspaceNavTile(
                    label: item.label,
                    icon: item.icon,
                    isSelected: index == selectedIndex,
                    onTap: () => onSelect(index),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Cerrar sesion'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceDrawer extends StatefulWidget {
  const _WorkspaceDrawer({
    required this.branchLabel,
    required this.roleLabel,
    required this.title,
    required this.userEmail,
    required this.userPhone,
    required this.items,
    required this.groups,
    required this.selectedIndex,
    required this.activeSection,
    required this.onSelect,
    required this.onSelectSection,
    required this.onLogout,
  });

  final String branchLabel;
  final String roleLabel;
  final String title;
  final String userEmail;
  final String? userPhone;
  final List<RoleWorkspaceItem> items;
  final List<RoleWorkspaceDrawerGroup> groups;
  final int selectedIndex;
  final Object? activeSection;
  final ValueChanged<int> onSelect;
  final void Function(int workspaceIndex, {Object? section}) onSelectSection;
  final VoidCallback onLogout;

  @override
  State<_WorkspaceDrawer> createState() => _WorkspaceDrawerState();
}

class _WorkspaceDrawerState extends State<_WorkspaceDrawer> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0C1B2A),
      child: SafeArea(
        child: RoleWorkspaceDrawerContent(
          branchLabel: widget.branchLabel,
          roleLabel: widget.roleLabel,
          title: widget.title,
          userEmail: widget.userEmail,
          userPhone: widget.userPhone,
          items: widget.items,
          groups: widget.groups,
          selectedIndex: widget.selectedIndex,
          activeSection: widget.activeSection,
          onSelect: widget.onSelect,
          onSelectSection: widget.onSelectSection,
          onLogout: widget.onLogout,
        ),
      ),
    );
  }
}

class RoleWorkspaceDrawerContent extends StatefulWidget {
  const RoleWorkspaceDrawerContent({
    super.key,
    required this.branchLabel,
    required this.roleLabel,
    required this.title,
    required this.userEmail,
    required this.userPhone,
    required this.items,
    required this.groups,
    required this.selectedIndex,
    required this.activeSection,
    required this.onSelect,
    required this.onSelectSection,
    required this.onLogout,
  });

  final String branchLabel;
  final String roleLabel;
  final String title;
  final String userEmail;
  final String? userPhone;
  final List<RoleWorkspaceItem> items;
  final List<RoleWorkspaceDrawerGroup> groups;
  final int selectedIndex;
  final Object? activeSection;
  final ValueChanged<int> onSelect;
  final void Function(int workspaceIndex, {Object? section}) onSelectSection;
  final VoidCallback onLogout;

  @override
  State<RoleWorkspaceDrawerContent> createState() =>
      _RoleWorkspaceDrawerContentState();
}

class _RoleWorkspaceDrawerContentState
    extends State<RoleWorkspaceDrawerContent> {
  int? _expandedGroupIndex;

  @override
  void initState() {
    super.initState();
    _expandedGroupIndex = _initialExpandedGroup();
  }

  @override
  void didUpdateWidget(covariant RoleWorkspaceDrawerContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final preferred = _initialExpandedGroup();
    if (preferred != null && preferred != _expandedGroupIndex) {
      _expandedGroupIndex = preferred;
    }
  }

  int? _initialExpandedGroup() {
    for (final group in widget.groups) {
      if (group.items.any((item) => item.section == widget.activeSection)) {
        return group.workspaceIndex;
      }
    }
    return widget.groups.any(
          (group) => group.workspaceIndex == widget.selectedIndex,
        )
        ? widget.selectedIndex
        : null;
  }

  RoleWorkspaceDrawerGroup? _groupFor(int workspaceIndex) {
    for (final group in widget.groups) {
      if (group.workspaceIndex == workspaceIndex) return group;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _WorkspaceIdentityCard(
            branchLabel: widget.branchLabel,
            roleLabel: widget.roleLabel,
            title: widget.title,
            userEmail: widget.userEmail,
            userPhone: widget.userPhone,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView(
              children:
                  widget.items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final group = _groupFor(index);
                    if (group == null) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _WorkspaceNavTile(
                          label: item.label,
                          icon: item.icon,
                          isSelected: index == widget.selectedIndex,
                          onTap: () => widget.onSelect(index),
                        ),
                      );
                    }

                    final hasActiveChild = group.items.any(
                      (child) => child.section == widget.activeSection,
                    );
                    final isExpanded = _expandedGroupIndex == index;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _WorkspaceNavGroup(
                        label: item.label,
                        icon: item.icon,
                        isSelected:
                            index == widget.selectedIndex || hasActiveChild,
                        isExpanded: isExpanded,
                        items: group.items,
                        activeSection: widget.activeSection,
                        onToggle: () {
                          setState(() {
                            _expandedGroupIndex = isExpanded ? null : index;
                          });
                        },
                        onSelectItem:
                            (child) => widget.onSelectSection(
                              index,
                              section: child.section,
                            ),
                      ),
                    );
                  }).toList(),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Cerrar sesion'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceIdentityCard extends StatelessWidget {
  const _WorkspaceIdentityCard({
    required this.branchLabel,
    required this.roleLabel,
    required this.title,
    required this.userEmail,
    required this.userPhone,
  });

  final String branchLabel;
  final String roleLabel;
  final String title;
  final String userEmail;
  final String? userPhone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF11283D), Color(0xFF173D57)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0x33E0B86E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PERFIL SOBRECARGO',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFFE0B86E), Color(0xFFF2D39C)],
              ),
            ),
            child: const Icon(
              Icons.flight_takeoff_rounded,
              color: Color(0xFF10253A),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            branchLabel,
            style: const TextStyle(
              color: Color(0xFFE0B86E),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            roleLabel,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            userEmail,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              height: 1.35,
            ),
          ),
          if ((userPhone ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              userPhone!.trim(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.66),
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkspaceNavTile extends StatelessWidget {
  const _WorkspaceNavTile({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected ? const Color(0xFF10253A) : Colors.white;
    final background =
        isSelected ? const Color(0xFFE0B86E) : Colors.transparent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                isSelected
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceNavGroup extends StatelessWidget {
  const _WorkspaceNavGroup({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isExpanded,
    required this.items,
    required this.activeSection,
    required this.onToggle,
    required this.onSelectItem,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isExpanded;
  final List<RoleWorkspaceDrawerItem> items;
  final Object? activeSection;
  final VoidCallback onToggle;
  final ValueChanged<RoleWorkspaceDrawerItem> onSelectItem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE0B86E) : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color:
                    isSelected
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? const Color(0xFF10253A) : Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color:
                          isSelected ? const Color(0xFF10253A) : Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  isExpanded ? '˅' : '>',
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF10253A) : Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 12, 8),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 2,
                    margin: const EdgeInsets.only(top: 4, bottom: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8FA7BC).withValues(alpha: 0.34),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children:
                          items.map((item) {
                            final isActive = item.section == activeSection;
                            return _WorkspaceNavSubtile(
                              label: item.label,
                              isActive: isActive,
                              enabled: item.enabled,
                              status: item.status,
                              onTap:
                                  item.enabled
                                      ? () => onSelectItem(item)
                                      : null,
                            );
                          }).toList(),
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

class _WorkspaceNavSubtile extends StatelessWidget {
  const _WorkspaceNavSubtile({
    required this.label,
    required this.isActive,
    required this.enabled,
    required this.status,
    this.onTap,
  });

  final String label;
  final bool isActive;
  final bool enabled;
  final RoleWorkspaceDrawerItemStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textColor =
        status == RoleWorkspaceDrawerItemStatus.blocked
            ? Colors.white.withValues(alpha: 0.34)
            : isActive
            ? const Color(0xFFE0B86E)
            : status == RoleWorkspaceDrawerItemStatus.completed
            ? Colors.white.withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.88);
    final indicatorColor =
        status == RoleWorkspaceDrawerItemStatus.blocked
            ? Colors.white.withValues(alpha: 0.28)
            : isActive
            ? const Color(0xFFE0B86E)
            : status == RoleWorkspaceDrawerItemStatus.completed
            ? const Color(0xFFE7EEF6)
            : Colors.white.withValues(alpha: 0.72);
    final indicatorLabel =
        status == RoleWorkspaceDrawerItemStatus.blocked
            ? '🔒'
            : isActive
            ? '●'
            : status == RoleWorkspaceDrawerItemStatus.completed
            ? '✓'
            : '○';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                child: Text(
                  indicatorLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: indicatorColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
