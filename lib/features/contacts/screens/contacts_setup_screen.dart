import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/safetrace_app_bar.dart';
import '../providers/contacts_provider.dart';
import '../../home_shell.dart';

class ContactsSetupScreen extends ConsumerWidget {
  const ContactsSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider);
    final notifier = ref.read(contactsProvider.notifier);

    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: const SafeTraceAppBar(
          title: "Emergency Circle",
          showBackButton: false,
        ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text(
                "Who keeps you safe?",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Add up to 5 people to your emergency circle. SafeTrace alerts them instantly if a threat is detected.",
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textLightSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Contact input form
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppBorderRadius.mdBorder,
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                ),
                child: Column(
                  children: [
                    SafeTraceTextField(
                      hintText: "Contact Name",
                      controller: nameController,
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SafeTraceTextField(
                      hintText: "Phone Number (e.g. 08123456789)",
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_android_rounded,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SafeTraceButton(
                      text: "Add to Circle",
                      type: ButtonType.ghost,
                      onPressed: () {
                        final name = nameController.text.trim();
                        final phone = phoneController.text.trim();
                        if (name.isEmpty || phone.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Name and phone number are required")),
                          );
                          return;
                        }
                        if (contacts.length >= 5) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("You can only add up to 5 contacts")),
                          );
                          return;
                        }
                        notifier.addContact(name, phone);
                        nameController.clear();
                        phoneController.clear();
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Contact list heading
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "YOUR EMERGENCY CIRCLE",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textLightSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    "${contacts.length}/5 ADDED",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Contact items list
              Expanded(
                child: contacts.isEmpty
                    ? const Center(
                        child: Text(
                          "No contacts added yet.",
                          style: TextStyle(color: AppColors.textLightSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: contacts.length,
                        itemBuilder: (context, index) {
                          final contact = contacts[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: AppBorderRadius.mdBorder,
                              border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: contact.avatarColor,
                                child: Text(
                                  contact.name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                contact.name,
                                style: const TextStyle(
                                  color: Color(0xFF111827),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                contact.phoneNumber,
                                style: const TextStyle(color: AppColors.textLightSecondary),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                onPressed: () => notifier.removeContact(contact.id),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Save & Proceed
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: SafeTraceButton(
                  text: "Complete Setup",
                  onPressed: contacts.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const HomeShell()),
                          );
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    ),);
  }
}
