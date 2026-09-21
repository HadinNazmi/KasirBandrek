import 'package:flutter/material.dart';
import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../data/models/transaksi.dart';

class _ProdukRow {
  final String namaMenu;
  int qty;
  int total;

  _ProdukRow({required this.namaMenu, required this.qty, required this.total});
}

class ProdukTerjualCard extends StatelessWidget {
  final List<Transaksi> transaksi;
  final String? judulPeriode;

  const ProdukTerjualCard({
    super.key,
    required this.transaksi,
    this.judulPeriode,
  });

  List<_ProdukRow> _aggregate() {
    final Map<String, _ProdukRow> map = {};

    for (final t in transaksi) {
      if (t.status != 'selesai') continue;
      for (final item in t.items) {
        final existing = map[item.namaMenu];
        if (existing != null) {
          existing.qty += item.qty;
          existing.total += item.subtotal;
        } else {
          map[item.namaMenu] = _ProdukRow(
            namaMenu: item.namaMenu,
            qty: item.qty,
            total: item.subtotal,
          );
        }
      }
    }

    final list = map.values.toList();
    list.sort((a, b) => b.qty.compareTo(a.qty));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _aggregate();

    final totalQty = rows.fold(0, (sum, r) => sum + r.qty);
    final totalNilai = rows.fold(0, (sum, r) => sum + r.total);
    final maxQty = rows.isNotEmpty ? rows.first.qty : 1;

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.surfaceDim.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Produk Terjual',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F1B16),
                      ),
                    ),
                    if (judulPeriode != null)
                      Text(
                        judulPeriode!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.outline,
                        ),
                      ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE5D4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$totalQty porsi',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),

            if (rows.isEmpty) ...[
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.restaurant_menu,
                        size: 36, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    const Text(
                      'Belum ada produk terjual pada periode ini',
                      style: TextStyle(fontSize: 12, color: AppTheme.outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ] else ...[
              const SizedBox(height: 12),

              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.namaMenu,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F1B16),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '×${row.qty}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 90,
                            child: Text(
                              AppFormat.currency(row.total),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF5D4A3E),
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: row.qty / maxQty,
                          minHeight: 4,
                          backgroundColor: const Color(0xFFF9EFE6),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const Divider(height: 16),

              // Footer total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Nilai Produk',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F1B16),
                    ),
                  ),
                  Text(
                    AppFormat.currency(totalNilai),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
