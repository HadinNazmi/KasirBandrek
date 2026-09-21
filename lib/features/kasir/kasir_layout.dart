import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import 'kasir_screen.dart';
import 'hari_ini_tab.dart';

class KasirLayout extends ConsumerStatefulWidget {
  const KasirLayout({super.key});

  @override
  ConsumerState<KasirLayout> createState() => _KasirLayoutState();
}

class _KasirLayoutState extends ConsumerState<KasirLayout> {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;

  final List<Widget> _pages = const [
    KasirScreen(),
    HariIniTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // Jika sedang di tab selain Kasir, kembali ke tab Kasir dulu
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }

        // Cek double tap back dalam kurun waktu 2 detik
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tekan sekali lagi untuk keluar'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          SystemNavigator.pop();
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
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            selectedItemColor: AppTheme.primary,
            unselectedItemColor: AppTheme.outline,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.point_of_sale),
                label: 'Kasir',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long),
                label: 'Hari Ini',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
