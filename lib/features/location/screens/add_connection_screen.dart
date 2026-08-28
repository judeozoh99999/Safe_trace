import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/nearby_alert_provider.dart';
import '../../../shared/widgets/upgrade_bottom_sheet.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/theme/app_colors.dart';

class AddConnectionScreen extends ConsumerStatefulWidget {
  const AddConnectionScreen({super.key});

  @override
  ConsumerState<AddConnectionScreen> createState() => _AddConnectionScreenState();
}

class _AddConnectionScreenState extends ConsumerState<AddConnectionScreen> {
  bool _isEnterIdTab = true;
  final TextEditingController _idController = TextEditingController();
  String _selectedType = 'Personal'; // Personal, Venue, Responder
  String? _inlineError;
  bool _isLoading = false;

  // Scanner control
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanning = true;

  @override
  void dispose() {
    _idController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _sendRequest() async {
    final subInfo = ref.read(currentSubscriptionProvider);
    if (subInfo.isFree) {
      UpgradeBottomSheet.show(
        context,
        message: 'Upgrade to SafeTrace Plus to initiate nearby alert connections.',
      );
      return;
    }

    final targetId = _idController.text.trim().toUpperCase();
    setState(() {
      _inlineError = null;
    });

    if (targetId.isEmpty) {
      setState(() {
        _inlineError = "Please enter a Nearby Alert ID";
      });
      return;
    }

    final state = ref.read(nearbyAlertProvider).valueOrNull;
    if (state != null && targetId == state.nearbyAlertId) {
      setState(() {
        _inlineError = "You cannot connect with yourself.";
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(nearbyAlertProvider.notifier).sendConnectionRequest(targetId, _selectedType);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Connection request sent successfully!")),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _inlineError = e.toString().replaceAll("Exception: ", "");
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onQrCodeScanned(String scannedId) {
    if (!_isScanning) return;
    setState(() {
      _isScanning = false;
    });
    _scannerController.stop();

    // Show Confirmation Bottom Sheet
    _showConnectionConfirmationSheet(scannedId);
  }

  void _showConnectionConfirmationSheet(String scannedId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        String localSelectedType = 'Personal';
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Confirm Connection",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Select connection type to connect with ID: $scannedId",
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),

                  // Connection type selectable cards row
                  Row(
                    children: [
                      _buildModalTypeCard('Personal', Icons.person_outline_rounded, 'Friends', localSelectedType, (type) {
                        setModalState(() => localSelectedType = type);
                      }),
                      const SizedBox(width: 8),
                      _buildModalTypeCard('Venue', Icons.storefront_rounded, 'Venues', localSelectedType, (type) {
                        setModalState(() => localSelectedType = type);
                      }),
                      const SizedBox(width: 8),
                      _buildModalTypeCard('Responder', Icons.local_police_rounded, 'Services', localSelectedType, (type) {
                        setModalState(() => localSelectedType = type);
                      }),
                    ],
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF131522),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        Navigator.of(context).pop(); // close modal
                        setState(() => _isLoading = true);

                        try {
                          await ref.read(nearbyAlertProvider.notifier).sendConnectionRequest(scannedId, localSelectedType);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Connection request sent successfully!")),
                            );
                            Navigator.of(context).pop(); // pop screen
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: ${e.toString().replaceAll("Exception: ", "")}")),
                            );
                            // Resume scanning
                            setState(() {
                              _isScanning = true;
                            });
                            _scannerController.start();
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isLoading = false);
                          }
                        }
                      },
                      child: const Text("Confirm & Send Request", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      // If bottom sheet was dismissed without sending, resume scanning
      if (!_isScanning && mounted) {
        setState(() {
          _isScanning = true;
        });
        _scannerController.start();
      }
    });
  }

  Widget _buildModalTypeCard(String type, IconData icon, String label, String currentSelected, ValueChanged<String> onSelected) {
    final isSelected = type == currentSelected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelected(type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
            border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? const Color(0xFF4F46E5) : Colors.grey, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFF4F46E5) : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncVal = ref.watch(nearbyAlertProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : const Color(0xFF111827), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Add Connection",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF111827)),
            ),
            const SizedBox(height: 2),
            Text(
              "Enter an ID or scan a QR code",
              style: TextStyle(fontSize: 12, color: isDark ? AppColors.textDarkSecondary : const Color(0xFF6B7280), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: asyncVal.when(
          data: (state) => _buildTabsAndBody(state, isDark),
          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
          error: (e, st) => Center(child: Text("Error loading Nearby Alert: $e")),
        ),
      ),
    );
  }

  Widget _buildTabsAndBody(NearbyAlertState state, bool isDark) {
    return Column(
      children: [
        // Tab buttons header
        Container(
          color: isDark ? AppColors.cardDark : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Enter ID
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isEnterIdTab 
                          ? (isDark ? AppColors.primary : const Color(0xFF131522)) 
                          : (isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      setState(() {
                        _isEnterIdTab = true;
                      });
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.numbers_rounded, color: _isEnterIdTab ? Colors.white : const Color(0xFF6B7280), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          "Enter ID",
                          style: TextStyle(
                            color: _isEnterIdTab ? Colors.white : const Color(0xFF6B7280),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Scan QR
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_isEnterIdTab 
                          ? (isDark ? AppColors.primary : const Color(0xFF131522)) 
                          : (isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      setState(() {
                        _isEnterIdTab = false;
                      });
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner_rounded, color: !_isEnterIdTab ? Colors.white : const Color(0xFF6B7280), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          "Scan QR",
                          style: TextStyle(
                            color: !_isEnterIdTab ? Colors.white : const Color(0xFF6B7280),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Body content
        Expanded(
          child: _isEnterIdTab 
              ? _buildEnterIdTab(state, isDark)
              : _buildScanQrTab(state, isDark),
        ),
      ],
    );
  }

  Widget _buildEnterIdTab(NearbyAlertState state, bool isDark) {
    final displayId = state.nearbyAlertId.isNotEmpty ? state.nearbyAlertId : "NA00000000";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User's ID card
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: displayId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Nearby Alert ID copied to clipboard!")),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF131522), // Dark Navy
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "YOUR NEARBY ALERT ID",
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        displayId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Share this with others so they can connect with you",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            "Connect with someone",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Enter the Nearby Alert ID of a person, venue, or emergency responder.",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // Labelled input field
          const Text(
            "NEARBY ALERT ID",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _inlineError != null ? Colors.red : const Color(0xFFE5E7EB)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Text(
                  "#",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _idController,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: "NA12345678",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_inlineError != null) ...[
            const SizedBox(height: 6),
            Text(_inlineError!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 12),
          const Text(
            "After sending, the other party must approve before the connection becomes active.",
            style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.3),
          ),
          const SizedBox(height: 24),

          // Connection Type Row
          const Text(
            "CONNECTION TYPE",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildTypeSelectionCard('Personal', Icons.person_outline_rounded, 'Friends and family', isDark),
              const SizedBox(width: 8),
              _buildTypeSelectionCard('Venue', Icons.storefront_rounded, 'Hotels and malls', isDark),
              const SizedBox(width: 8),
              _buildTypeSelectionCard('Responder', Icons.local_police_rounded, 'Emergency services', isDark),
            ],
          ),

          const SizedBox(height: 32),

          // Send button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.primary : const Color(0xFF131522),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoading ? null : _sendRequest,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Send Connection Request", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelectionCard(String type, IconData icon, String subtitle, bool isDark) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected 
                ? (isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF)) 
                : (isDark ? AppColors.cardDark : Colors.white),
            border: Border.all(
              color: isSelected 
                  ? const Color(0xFF4F46E5) 
                  : (isDark ? AppColors.dividerDark : const Color(0xFFE5E7EB)),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF4F46E5) : Colors.grey,
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                type,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFF4F46E5) : (isDark ? Colors.white : const Color(0xFF1F2937)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Colors.grey, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanQrTab(NearbyAlertState state, bool isDark) {
    final displayId = state.nearbyAlertId.isNotEmpty ? state.nearbyAlertId : "NA00000000";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Camera viewfinder
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 250,
              width: double.infinity,
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isScanning)
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty) {
                          final code = barcodes.first.rawValue;
                          if (code != null && code.startsWith("NA")) {
                            _onQrCodeScanned(code);
                          }
                        }
                      },
                    ),
                  // Red corner brackets layout simulation
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red.withValues(alpha: 0.8), width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const Positioned(
                    bottom: 12,
                    child: Text(
                      "Point at a Nearby Alert QR code Tap to Scan",
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Scan the Nearby Alert QR code displayed by a venue, responder, or contact to connect instantly.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 20),

          // Divider
          Row(
            children: const [
              Expanded(child: Divider(color: Color(0xFFE5E7EB))),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text("Or show your QR code", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              Expanded(child: Divider(color: Color(0xFFE5E7EB))),
            ],
          ),
          const SizedBox(height: 20),

          // Own QR code
          GestureDetector(
            onTap: () {
              Share.share(
                "Connect with me on SafeTrace Nearby Alert!\nMy Nearby Alert ID is: $displayId",
                subject: "Nearby Alert Connection ID",
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: QrImageView(
                data: displayId,
                version: QrVersions.auto,
                size: 160.0,
                foregroundColor: const Color(0xFF131522),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            displayId,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF131522),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text("Tap QR code to share your ID", style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
