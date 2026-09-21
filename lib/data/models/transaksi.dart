import 'transaksi_item.dart';

class Transaksi {
  final String id;
  final DateTime createdAt;
  final int total;
  final String metodeBayar;
  final String status;
  final DateTime? dibatalkanAt;
  final DateTime? dieditAt;
  final List<TransaksiItem> items;
  final bool isPending;

  Transaksi({
    required this.id,
    required this.createdAt,
    required this.total,
    required this.metodeBayar,
    required this.status,
    this.dibatalkanAt,
    this.dieditAt,
    required this.items,
    this.isPending = false,
  });

  factory Transaksi.fromJson(Map<String, dynamic> json, {bool isPending = false}) {
    return Transaksi(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      total: json['total'] as int,
      metodeBayar: json['metode_bayar'] as String,
      status: json['status'] as String,
      dibatalkanAt: json['dibatalkan_at'] != null ? DateTime.parse(json['dibatalkan_at'] as String) : null,
      dieditAt: json['diedit_at'] != null ? DateTime.parse(json['diedit_at'] as String) : null,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => TransaksiItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isPending: isPending,
    );
  }

  Transaksi copyWith({
    String? id,
    DateTime? createdAt,
    int? total,
    String? metodeBayar,
    String? status,
    DateTime? dibatalkanAt,
    DateTime? dieditAt,
    List<TransaksiItem>? items,
    bool? isPending,
  }) {
    return Transaksi(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      total: total ?? this.total,
      metodeBayar: metodeBayar ?? this.metodeBayar,
      status: status ?? this.status,
      dibatalkanAt: dibatalkanAt ?? this.dibatalkanAt,
      dieditAt: dieditAt ?? this.dieditAt,
      items: items ?? this.items,
      isPending: isPending ?? this.isPending,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'total': total,
      'metode_bayar': metodeBayar,
      'status': status,
      if (dibatalkanAt != null) 'dibatalkan_at': dibatalkanAt!.toIso8601String(),
      if (dieditAt != null) 'diedit_at': dieditAt!.toIso8601String(),
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}
