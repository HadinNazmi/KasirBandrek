import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/admin_provider.dart';
import 'menu/menu_tab.dart';
import 'pengaturan/pengaturan_tab.dart';
import 'pin_gate.dart';
import 'riwayat/riwayat_tab.dart';

class AdminLayout extends ConsumerStatefulWidget {
  const AdminLayout({super.key});

  @override
  ConsumerState<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends ConsumerState<AdminLayout> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    RiwayatTab(),
    MenuTab(),
    PengaturanTab(),
  ];

  @override
  Widget build(BuildContext context) {
    // Monitor token
    ref.listen<String?>(adminTokenProvider, (previous, next) {
      if (next == null && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PinGateScreen()),
          (route) => route.isFirst,
        );
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C4A2D).withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              backgroundColor: Colors.white,
              selectedItemColor: AppTheme.secondary,
              unselectedItemColor: const Color(0xFF84746C),
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long),
                  label: 'Riwayat',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.restaurant_menu),
                  label: 'Menu',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Pengaturan',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
