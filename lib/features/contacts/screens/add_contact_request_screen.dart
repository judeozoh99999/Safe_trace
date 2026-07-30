import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../../../shared/widgets/safetrace_app_bar.dart';
import '../../auth/providers/auth_provider.dart';

class AddContactRequestScreen extends ConsumerStatefulWidget {
  const AddContactRequestScreen({super.key});

  @override
  ConsumerState<AddContactRequestScreen> createState() => _AddContactRequestScreenState();
}

class _AddContactRequestScreenState extends ConsumerState<AddContactRequestScreen> {
  final _phoneController = TextEditingController();
  String _selectedRelationship = 'Friend';
  bool _welfareCheckEnabled = false;

  bool _isLoading = false;
  String? _phoneError;

  final List<String> _relationships = [
    'Family',
    'Friend',
    'Colleague',
    'Neighbour',
    'Other',
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _normalizePhone(String raw) {
    String clean = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.startsWith('+234')) {
      return clean;
    }
    if (clean.startsWith('234')) {
      return '+$clean';
    }
    if (clean.startsWith('0')) {
      return '+234${clean.substring(1)}';
    }
    if (clean.length == 10) {
      return '+234$clean';
    }
    return '+234$clean';
  }

  Future<void> _sendRequest() async {
    setState(() {
      _phoneError = null;
    });

    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty) {
      setState(() {
        _phoneError = "Please enter a phone number.";
      });
      return;
    }

    final normalizedPhone = _normalizePhone(rawPhone);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Query Firestore users collection for matching phone number
      final usersQuery = await FirebaseFirestore.instance.collection('users').get();
      DocumentSnapshot? targetUserDoc;
      final cleanTargetSuffix = normalizedPhone.replaceAll(RegExp(r'[^\d]'), '');

      for (final doc in usersQuery.docs) {
        final data = doc.data();
        final p1 = (data['phoneNumber'] ?? '').toString().replaceAll(RegExp(r'[^\d]'), '');
        final p2 = (data['phone_number'] ?? '').toString().replaceAll(RegExp(r'[^\d]'), '');
        if (p1.endsWith(cleanTargetSuffix.substring(cleanTargetSuffix.length >= 10 ? cleanTargetSuffix.length - 10 : 0)) ||
            p2.endsWith(cleanTargetSuffix.substring(cleanTargetSuffix.length >= 10 ? cleanTargetSuffix.length - 10 : 0))) {
          targetUserDoc = doc;
          break;
        }
      }

      if (targetUserDoc == null) {
        setState(() {
          _phoneError = "this number is not registered on SafeTrace";
          _isLoading = false;
        });
        return;
      }

      final recipientUid = targetUserDoc.id;

      // 2. Check if trying to add self
      if (recipientUid == currentUser.uid) {
        setState(() {
          _phoneError = "you cannot add yourself to your trusted circle";
          _isLoading = false;
        });
        return;
      }

      // Fetch current user details from Firestore / Auth
      final authState = ref.read(authNotifierProvider);
      final requesterFirstName = authState.firstName.isNotEmpty ? authState.firstName : "User";
      final requesterLastName = authState.lastName.isNotEmpty ? authState.lastName : "";
      final requesterPhone = currentUser.phoneNumber ?? authState.phoneNumber;

      final recipientData = targetUserDoc.data() as Map<String, dynamic>;
      final recipientFirstName = recipientData['firstName'] ?? recipientData['first_name'] ?? 'User';
      final recipientLastName = recipientData['lastName'] ?? recipientData['last_name'] ?? '';

      // 3. Check if request or active circle already exists in trusted_circle_requests
      final existingQuery = await FirebaseFirestore.instance
          .collection('trusted_circle_requests')
          .where('requester_uid', whereIn: [currentUser.uid, recipientUid])
          .get();

      for (final doc in existingQuery.docs) {
        final data = doc.data();
        final r1 = data['requester_uid'];
        final r2 = data['recipient_uid'];
        final status = data['status'];

        if ((r1 == currentUser.uid && r2 == recipientUid) || (r1 == recipientUid && r2 == currentUser.uid)) {
          if (status == 'accepted') {
            setState(() {
              _phoneError = "this person is already in your trusted circle";
              _isLoading = false;
            });
            return;
          } else if (status == 'pending') {
            setState(() {
              _phoneError = "a request has already been sent to this person";
              _isLoading = false;
            });
            return;
          }
        }
      }

      // 4. Create document in trusted_circle_requests
      await FirebaseFirestore.instance.collection('trusted_circle_requests').add({
        'requester_uid': currentUser.uid,
        'requester_first_name': requesterFirstName,
        'requester_last_name': requesterLastName,
        'requester_phone': requesterPhone,
        'recipient_uid': recipientUid,
        'recipient_first_name': recipientFirstName,
        'recipient_last_name': recipientLastName,
        'recipient_phone': normalizedPhone,
        'relationship': _selectedRelationship,
        'welfare_check_enabled': true,
        'status': 'pending',
        'sent_at': FieldValue.serverTimestamp(),
        'responded_at': null,
      });

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _phoneError = "Failed to send request: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF9FAFB),
      appBar: const SafeTraceAppBar(
        title: "Add Contact",
        showBackButton: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Add to Trusted Circle",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Send a trusted contact request to a registered SafeTrace user.",
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textDarkSecondary : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),

              // 1. Phone Number Input
              Text(
                "PHONE NUMBER",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.textDarkSecondary : const Color(0xFF4B5563),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1D27) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _phoneError != null
                        ? const Color(0xFFEF4444)
                        : (isDark ? const Color(0xFF2E3347) : const Color(0xFFE5E7EB)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: isDark ? const Color(0xFF2E3347) : const Color(0xFFE5E7EB),
                          ),
                        ),
                      ),
                      child: Text(
                        "+234",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                        decoration: InputDecoration(
                          hintText: "8012345678",
                          hintStyle: TextStyle(
                            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_phoneError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _phoneError!,
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // 2. Relationship Dropdown
              Text(
                "RELATIONSHIP",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.textDarkSecondary : const Color(0xFF4B5563),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1D27) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E3347) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRelationship,
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF1A1D27) : Colors.white,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                    items: _relationships.map((rel) {
                      return DropdownMenuItem<String>(
                        value: rel,
                        child: Text(rel),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedRelationship = val;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Send Request Button
              SafeTraceButton(
                text: "Send Request",
                isLoading: _isLoading,
                onPressed: _sendRequest,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
