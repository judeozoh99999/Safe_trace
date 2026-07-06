import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';

class ContactModel {
  final String id;
  final String name;
  final String phoneNumber;
  final Color avatarColor;

  ContactModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.avatarColor,
  });
}

class ContactsNotifier extends StateNotifier<List<ContactModel>> {
  ContactsNotifier() : super([
    ContactModel(id: '1', name: 'Chioma', phoneNumber: '08123456789', avatarColor: AppColors.avatarPurple),
    ContactModel(id: '2', name: 'Tunde', phoneNumber: '09012345678', avatarColor: AppColors.avatarGreen),
    ContactModel(id: '3', name: 'Yusuf', phoneNumber: '07098765432', avatarColor: AppColors.avatarRed),
  ]);

  void addContact(String name, String phone) {
    if (state.length >= 5) return;
    
    // Choose avatar color sequentially
    final color = AppColors.avatarColors[state.length % AppColors.avatarColors.length];
    final newContact = ContactModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      phoneNumber: phone,
      avatarColor: color,
    );
    state = [...state, newContact];
  }

  void removeContact(String id) {
    state = state.where((contact) => contact.id != id).toList();
  }
}

final contactsProvider = StateNotifierProvider<ContactsNotifier, List<ContactModel>>((ref) {
  return ContactsNotifier();
});
