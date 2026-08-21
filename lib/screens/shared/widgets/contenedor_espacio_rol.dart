import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/proveedor_autenticacion.dart';

class RoleWorkspaceShellScope extends InheritedWidget {
  const RoleWorkspaceShellScope({
    super.key,
    required super.child,
    required this.openDrawer,
    required this.selectIndex,
  });

  final VoidCallback openDrawer;
  final ValueChanged<int> selectIndex;

  static RoleWorkspaceShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RoleWorkspaceShellScope>();
  }

  @override
  bool updateShouldNotify(RoleWorkspaceShellScope oldWidget) {
    return openDrawer != oldWidget.openDrawer ||
        selectIndex != oldWidget.selectIndex;
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

class RoleWorkspaceShell extends StatefulWidget {
  const RoleWorkspaceShell({
    super.key,
    required this.branchLabel,
    required this.roleLabel,
    required this.title,
    required this.items,
    this.initialIndex = 0,
  });

  final String branchLabel;
  final String roleLabel;
  final String title;
  final List<RoleWorkspaceItem> items;
  final int initialIndex;

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
    final userEmail = auth.user?.email ?? 'sin correo';

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
                items: widget.items,
                selectedIndex: _selectedIndex,
                onSelect: _selectIndex,
                onLogout: auth.signOut,
              ),
      body: Builder(
        builder: (scaffoldContext) {
          return RoleWorkspaceShellScope(
            openDrawer: () => Scaffold.of(scaffoldContext).openDrawer(),
            selectIndex: _selectIndex,
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
                              child: KeyedSubtree(
                                key: ValueKey(currentItem.label),
                                child: currentItem.screen,
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
                              child: KeyedSubtree(
                                key: ValueKey(currentItem.label),
                                child: currentItem.screen,
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
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
  });

  final String branchLabel;
  final String roleLabel;
  final String title;
  final String userEmail;
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

class _WorkspaceDrawer extends StatelessWidget {
  const _WorkspaceDrawer({
    required this.branchLabel,
    required this.roleLabel,
    required this.title,
    required this.userEmail,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
  });

  final String branchLabel;
  final String roleLabel;
  final String title;
  final String userEmail;
  final List<RoleWorkspaceItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0C1B2A),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _WorkspaceIdentityCard(
                branchLabel: branchLabel,
                roleLabel: roleLabel,
                title: title,
                userEmail: userEmail,
              ),
              const SizedBox(height: 18),
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
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Cerrar sesion'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
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

class _WorkspaceIdentityCard extends StatelessWidget {
  const _WorkspaceIdentityCard({
    required this.branchLabel,
    required this.roleLabel,
    required this.title,
    required this.userEmail,
  });

  final String branchLabel;
  final String roleLabel;
  final String title;
  final String userEmail;

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
