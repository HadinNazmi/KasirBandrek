import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network_info.dart';
import '../../providers/admin_provider.dart';
import '../../providers/supabase_provider.dart';
import '../kasir/kasir_layout.dart';
import 'admin_layout.dart';

class PinGateScreen extends ConsumerStatefulWidget {
  const PinGateScreen({super.key});

  @override
  ConsumerState<PinGateScreen> createState() => _PinGateScreenState();
}

class _PinGateScreenState extends ConsumerState<PinGateScreen> {
  String _pin = '';
  bool _isLoading = false;
  String? _errorMessage;
  bool _isLocked = false;
  int _lockCountdown = 0;
  Timer? _lockTimer;

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  void _onDigitPress(String digit) {
    if (_isLoading || _isLocked) return;
    if (_pin.length < 6) {
      setState(() {
        _errorMessage = null;
        _pin += digit;
      });

      if (_pin.length == 6) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_isLoading || _isLocked) return;
    if (_pin.isNotEmpty) {
      setState(() {
        _errorMessage = null;
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void _onClear() {
    if (_isLoading || _isLocked) return;
    setState(() {
      _errorMessage = null;
      _pin = '';
    });
  }

  Future<void> _verifyPin() async {
    final hasInternet = await NetworkInfo.isConnected();
    if (!hasInternet) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(NetworkInfo.offlineMessage),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _pin = '');
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final svc = ref.read(supabaseServiceProvider);
      final res = await svc.verifikasiPin(_pin);

      final isOk = res['ok'] as bool? ?? false;
      if (isOk) {
        final token = res['token'] as String;
        ref.read(adminTokenProvider.notifier).setToken(token);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminLayout()),
          );
        }
      } else {
        final isTerkunci = res['terkunci'] as bool? ?? false;
        if (isTerkunci) {
          final sisaDetik = (res['sisa_detik'] as num?)?.toInt() ?? 30;
          _startLockCountdown(sisaDetik);
        } else {
          final sisa = (res['sisa_percobaan'] as num?)?.toInt();
          setState(() {
            _errorMessage = sisa != null
                ? 'PIN salah. Percobaan tersisa: $sisa kali'
                : 'PIN salah. Silakan coba lagi.';
            _pin = '';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _pin = '';
          _isLoading = false;
        });
      }
    }
  }

  void _startLockCountdown(int seconds) {
    _lockTimer?.cancel();
    setState(() {
      _isLocked = true;
      _lockCountdown = seconds;
      _pin = '';
      _isLoading = false;
      _errorMessage = 'Terlalu banyak percobaan salah. Numpad terkunci.';
    });

    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockCountdown <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isLocked = false;
            _lockCountdown = 0;
            _errorMessage = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _lockCountdown--;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4EBE3),
      body: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const KasirLayout()),
            );
          }
        },
        child: SafeArea(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              color: const Color(0xFFFAF1E8),
              child: Column(
                children: [
                  // Top Navigation Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back Button
                        InkWell(
                          onTap: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => const KasirLayout()),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFEBDCD0)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF5C351E).withValues(alpha: 0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF2D1F17)),
                          ),
                        ),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFEBDCD0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE28743),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Kedai Bandrek • Mode Admin',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6E5A4F),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Help Button
                      TextButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (dCtx) => AlertDialog(
                              title: const Text('Bantuan PIN Admin'),
                              content: const Text(
                                'Masukkan 6 digit PIN Admin yang sudah dikonfigurasi pada sistem.\n\n'
                                'Jika salah 5 kali berturut-turut, sistem akan terkunci sementara selama 30 detik untuk keamanan.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dCtx),
                                  child: const Text('Tutup'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text(
                          'Bantuan',
                          style: TextStyle(
                            color: Color(0xFFE28743),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Lock Hero Section
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 12),
                          // Padlock Icon Badge with warm glow
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFFDFB), Color(0xFFFCEFE5)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE28743).withValues(alpha: 0.25),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFAECE0),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.lock_rounded,
                                  color: Color(0xFFE28743),
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Masukkan PIN Admin',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D1F17),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Khusus pemilik kedai untuk akses laporan pendapatan, pengaturan menu & harga',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6E5A4F),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // PIN Dots Indicator (6 digits)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(6, (index) {
                              final isFilled = index < _pin.length;
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 7),
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isFilled ? const Color(0xFFE28743) : Colors.white.withValues(alpha: 0.7),
                                  border: Border.all(
                                    color: isFilled ? const Color(0xFFC86D2B) : const Color(0xFFD8C5B6),
                                    width: isFilled ? 1.5 : 2,
                                  ),
                                  boxShadow: isFilled
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFFE28743).withValues(alpha: 0.35),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                              );
                            }),
                          ),

                          const SizedBox(height: 18),

                          // Error / Lock Alert Banner
                          if (_isLocked)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDF0E9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFF6C9BA)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFC84C32)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Numpad terkunci. Coba lagi dalam $_lockCountdown detik',
                                    style: const TextStyle(
                                      color: Color(0xFFC84C32),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDF0E9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFF6C9BA)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFC84C32)),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: Color(0xFFC84C32),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (_isLoading)
                            const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          else
                            const SizedBox(height: 32),

                          const SizedBox(height: 12),

                          // Numeric Keypad (Tactile Stitch Style)
                          Container(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    _buildKey('1', ''),
                                    const SizedBox(width: 12),
                                    _buildKey('2', 'ABC'),
                                    const SizedBox(width: 12),
                                    _buildKey('3', 'DEF'),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildKey('4', 'GHI'),
                                    const SizedBox(width: 12),
                                    _buildKey('5', 'JKL'),
                                    const SizedBox(width: 12),
                                    _buildKey('6', 'MNO'),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildKey('7', 'PQRS'),
                                    const SizedBox(width: 12),
                                    _buildKey('8', 'TUV'),
                                    const SizedBox(width: 12),
                                    _buildKey('9', 'WXYZ'),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    // Clear All
                                    Expanded(
                                      child: SizedBox(
                                        height: 62,
                                        child: InkWell(
                                          onTap: (_isLoading || _isLocked) ? null : _onClear,
                                          borderRadius: BorderRadius.circular(16),
                                          child: const Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Hapus',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF957F71),
                                                  ),
                                                ),
                                                Text(
                                                  'Semua',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: Color(0xFFAFA197),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _buildKey('0', '+'),
                                    const SizedBox(width: 12),
                                    // Backspace
                                    Expanded(
                                      child: SizedBox(
                                        height: 62,
                                        child: InkWell(
                                          onTap: (_isLoading || _isLocked) ? null : _onBackspace,
                                          borderRadius: BorderRadius.circular(16),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: const Color(0xFFEBDCD0)),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF542E15).withValues(alpha: 0.06),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.backspace_outlined,
                                                color: Color(0xFFE28743),
                                                size: 22,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Security Footer
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.lock_clock_outlined, size: 13, color: Color(0xFFA69488)),
                              SizedBox(width: 4),
                              Text(
                                'Terenkripsi secara lokal di perangkat POS Kedai Bandrek',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFFA69488),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildKey(String digit, String sub) {
    final disabled = _isLoading || _isLocked;

    return Expanded(
      child: SizedBox(
        height: 62,
        child: Material(
          color: disabled ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: disabled ? null : () => _onDigitPress(digit),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEBDCD0)),
                boxShadow: disabled
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFF542E15).withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    digit,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: disabled ? Colors.grey : const Color(0xFF2D1F17),
                      height: 1.1,
                    ),
                  ),
                  if (sub.isNotEmpty)
                    Text(
                      sub,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: disabled ? Colors.grey : const Color(0xFF9A8578),
                      ),
                    )
                  else
                    const SizedBox(height: 11),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
