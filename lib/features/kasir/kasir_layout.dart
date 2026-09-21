import 'package:flutter/material.dart';
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

  final List<Widget> _pages = const [
    KasirScreen(),
    HariIniTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
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
    );
  }
}
