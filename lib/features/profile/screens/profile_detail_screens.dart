import 'dart:async';
import 'package:flutter/material.dart';

// --- ANIMATION TRANSITION HELPER ---
Route _createRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeInOutCubic;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      return SlideTransition(
        position: animation.drive(tween),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
  );
}

// ==========================================================
// 1. HELP & SUPPORT SCREEN (Mockup 2)
// ==========================================================
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final Map<int, bool> _expandedMap = {};

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> faqs = [
      {
        "q": "What is SafeTrace?",
        "a": "SafeTrace is a personal safety app built for Nigeria. It lets you share your location with trusted contacts, send emergency alerts instantly, and connect with a proximity-based safety network (Nearby Alert) — all from your phone."
      },
      {
        "q": "How does the Panic Button work?",
        "a": "Hold the red panic button on the Home screen for 2 seconds. SafeTrace immediately sends your live GPS location to all 5 of your trusted contacts via push notification, SMS, and the app. Your location continues to update in real-time until you end the alert."
      },
      {
        "q": "What is Nearby Alert?",
        "a": "Nearby Alert creates a local safety network within a 20-meter radius. You can connect with venues, trusted people, and emergency responders. If you trigger an emergency, they are notified instantly. Connections auto-disconnect when either party exits the 20m radius."
      },
      {
        "q": "How do Trusted Contacts work?",
        "a": "Add up to 5 trusted contacts (family, friends, colleagues). When you trigger a panic alert, they all receive your location instantly. Contacts with the app get a push notification; others receive an SMS. They can also monitor your check-in status."
      },
      {
        "q": "What happens to my location data?",
        "a": "Location logs are stored securely and automatically deleted after 7 days. You can clear your history at any time in Privacy & Data settings. SafeTrace never sells your personal data to third parties."
      },
      {
        "q": "Can SafeTrace work offline?",
        "a": "The panic button requires an active Internet connection to send alerts. However, your most recent location is cached locally and can be shared via SMS even without Internet. We recommend keeping mobile data on for full protection."
      },
      {
        "q": "How do I cancel my subscription?",
        "a": "SafeTrace uses a simple annual plan (₦1,000/year). To cancel, go to Wallet and contact our support team. Your access remains active until the end of your paid period."
      },
      {
        "q": "What is Watch Mode / Audio Sentinel?",
        "a": "Audio Sentinel continuously monitors your microphone for sudden loud sounds (shouting, breaking glass, gunshots). If danger is detected above 80dB, it automatically alerts your trusted contacts and Nearby Alert network."
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Help & Support",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
            ),
            SizedBox(height: 2),
            Text(
              "SafeTrace Support Centre",
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search field FAQ
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: const [
                  Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Search FAQs, topics...",
                        hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Enjoying SafeTrace card
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF131522),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Enjoying SafeTrace?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 2),
                        Text("Rate us on the App Store", style: TextStyle(color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E334D),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {},
                    child: const Text("Rate App", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              "FREQUENTLY ASKED QUESTIONS",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF6B7280), letterSpacing: 0.5),
            ),
            const SizedBox(height: 12),

            // FAQs List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: faqs.length,
              itemBuilder: (context, index) {
                final faq = faqs[index];
                final isExpanded = _expandedMap[index] ?? false;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        onTap: () {
                          setState(() {
                            _expandedMap[index] = !isExpanded;
                          });
                        },
                        title: Text(
                          faq["q"]!,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                        ),
                        trailing: Icon(
                          isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      if (isExpanded)
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                          child: Text(
                            faq["a"]!,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.45),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // CONTACT SUPPORT
            const Text(
              "CONTACT SUPPORT",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF6B7280), letterSpacing: 0.5),
            ),
            const SizedBox(height: 12),

            _buildSupportActionCard(
              icon: Icons.email_outlined,
              iconBg: const Color(0xFFE8F5E9),
              iconColor: const Color(0xFF2E7D32),
              title: "Email Support",
              sub: "support@safetrace.ng",
              btnLabel: "Send Email",
              onPressed: () {},
            ),
            const SizedBox(height: 12),

            _buildSupportActionCard(
              icon: Icons.phone_outlined,
              iconBg: const Color(0xFFEBF5FF),
              iconColor: const Color(0xFF2563EB),
              title: "Phone Support",
              sub: "Mon-Fri · 9 AM - 6 PM WAT",
              btnLabel: "Call Now",
              onPressed: () {},
            ),
            const SizedBox(height: 24),

            // SAFETY RESOURCES
            const Text(
              "SAFETY RESOURCES",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF6B7280), letterSpacing: 0.5),
            ),
            const SizedBox(height: 12),

            _buildResourceTile(Icons.shield_outlined, "Safety Guidelines", "Best practices for using SafeTrace"),
            const SizedBox(height: 12),
            _buildResourceTile(Icons.menu_book_outlined, "User Manual", "Full documentation and guides"),
            const SizedBox(height: 24),

            // APP INFORMATION
            const Text(
              "APP INFORMATION",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF6B7280), letterSpacing: 0.5),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  _buildAppInfoRow("App Version", "2.4.1 (Build 312)"),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  _buildAppInfoRow("Data Region", "Nigeria · West Africa"),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text("Terms of Service", style: TextStyle(color: Color(0xFF4F46E5), fontSize: 12, decoration: TextDecoration.underline)),
                SizedBox(width: 16),
                Text("Privacy Policy", style: TextStyle(color: Color(0xFF4F46E5), fontSize: 12, decoration: TextDecoration.underline)),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportActionCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String sub,
    required String btnLabel,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEEF2FF),
              foregroundColor: const Color(0xFF4F46E5),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: onPressed,
            child: Text(btnLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceTile(IconData icon, String title, String sub) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4F46E5)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(sub, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        trailing: const Icon(Icons.open_in_new_rounded, color: Color(0xFF9CA3AF), size: 16),
      ),
    );
  }

  Widget _buildAppInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Color(0xFF111827), fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ==========================================================
// 2. TRUSTED CIRCLE SCREEN (Trusted Circle.png)
// ==========================================================
class TrustedCircleScreen extends StatefulWidget {
  const TrustedCircleScreen({super.key});

  @override
  State<TrustedCircleScreen> createState() => _TrustedCircleScreenState();
}

class _TrustedCircleScreenState extends State<TrustedCircleScreen> {
  final List<Map<String, String>> _contacts = [
    {"name": "Chioma Obi", "phone": "+234 802 345 6789", "relation": "Emergency Circle"},
    {"name": "Yusuf Alabi", "phone": "+234 803 123 4567", "relation": "Emergency Circle"},
    {"name": "Ngozi Nwosu", "phone": "+234 805 987 6543", "relation": "Emergency Circle"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Trusted Circle",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 2),
            Text(
              "${_contacts.length} of 5 contacts added",
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // TRUSTED CONTACTS Header
                  const Text(
                    "TRUSTED CONTACTS",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF6B7280), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 12),

                  // Contacts List
                  ...List.generate(_contacts.length, (index) {
                    final c = _contacts[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFEEF2FF),
                          child: Text(c["name"]!.substring(0, 1), style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                        ),
                        title: Text(c["name"]!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(c["phone"]!, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(6)),
                              child: Text(c["relation"]!, style: const TextStyle(color: Color(0xFF4F46E5), fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                              onPressed: () {
                                setState(() {
                                  _contacts.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),
                  // INACTIVE USERS
                  const Text(
                    "WELFARE STATUS",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF6B7280), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFFFBEB),
                        child: Text("E", style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                      ),
                      title: const Text("Emeka Okafor", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text("3 days inactive", style: TextStyle(color: Color(0xFFD97706), fontSize: 12)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                        child: const Text("Welfare Check Active", style: TextStyle(color: Color(0xFFD97706), fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Add Contact Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(_createRoute(AddContactScreen(onContactAdded: (name, phone) {
                      setState(() {
                        _contacts.add({"name": name, "phone": phone, "relation": "Family"});
                      });
                    })));
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add, color: Colors.white),
                      SizedBox(width: 8),
                      Text("Add Contact", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// 3. ADD CONTACT SCREEN (Trusted Circle - Add Contact.png)
// ==========================================================
class AddContactScreen extends StatefulWidget {
  final Function(String, String) onContactAdded;
  const AddContactScreen({super.key, required this.onContactAdded});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _relationship = "Family";
  bool _welfareCheck = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Add Contact",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
            ),
            SizedBox(height: 2),
            Text(
              "Add to your trusted circle",
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name Field
                    const Text("FULL NAME", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(hintText: "Enter full name", border: InputBorder.none),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Phone Field
                    const Text("PHONE NUMBER", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(hintText: "+234 800 000 0000", border: InputBorder.none),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Relationship dropdown mock
                    const Text("RELATIONSHIP", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _relationship,
                          isExpanded: true,
                          items: ["Family", "Friend", "Colleague", "Neighbor"].map((val) {
                            return DropdownMenuItem(value: val, child: Text(val));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _relationship = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Welfare Check Option Toggle
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
                      child: SwitchListTile(
                        value: _welfareCheck,
                        onChanged: (val) => setState(() => _welfareCheck = val),
                        activeColor: const Color(0xFF4F46E5),
                        title: const Text("Enable Welfare Check", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text("Automatically send alert check-in if contact is inactive for 3 days.", style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Submit Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final name = _nameCtrl.text.trim();
                    final phone = _phoneCtrl.text.trim();
                    if (name.isNotEmpty && phone.isNotEmpty) {
                      widget.onContactAdded(name, phone);
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text("Add Contact", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// 4. WELFARE CHECK ALERT SCREEN (Welfare Check Alert.png)
// ==========================================================
class WelfareCheckAlertScreen extends StatefulWidget {
  const WelfareCheckAlertScreen({super.key});

  @override
  State<WelfareCheckAlertScreen> createState() => _WelfareCheckAlertScreenState();
}

class _WelfareCheckAlertScreenState extends State<WelfareCheckAlertScreen> {
  int _inactivityDays = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Welfare Check",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
            ),
            SizedBox(height: 2),
            Text(
              "Automated check-ins for inactive circle users",
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Welfare Check monitors inactivity metrics dynamically and notifies your emergency contacts if you are offline beyond the threshold period.",
                      style: TextStyle(color: Color(0xFF92400E), fontSize: 13, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              "INACTIVITY THRESHOLD",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF6B7280), letterSpacing: 0.5),
            ),
            const SizedBox(height: 12),

            // Inactivity days selection
            Column(
              children: [1, 2, 3, 5].map((day) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  color: Colors.white,
                  child: RadioListTile<int>(
                    value: day,
                    groupValue: _inactivityDays,
                    title: Text("$day Days Inactive"),
                    subtitle: Text("Alert if no app activity for $day days"),
                    activeColor: const Color(0xFF4F46E5),
                    onChanged: (val) {
                      if (val != null) setState(() => _inactivityDays = val);
                    },
                  ),
                );
              }).toList(),
            ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Welfare Check updated successfully")));
                  Navigator.of(context).pop();
                },
                child: const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// 5. NOTIFICATION PREFERENCES (Notification Preferences.png)
// ==========================================================
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  bool _dangerAlerts = true;
  bool _proximity = true;
  bool _welfare = true;
  bool _updates = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Notifications",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
            ),
            SizedBox(height: 2),
            Text(
              "Alerts, check-ins, updates",
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
            child: Column(
              children: [
                SwitchListTile(
                  value: _dangerAlerts,
                  activeColor: const Color(0xFF4F46E5),
                  onChanged: (val) => setState(() => _dangerAlerts = val),
                  title: const Text("Danger Alerts", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("High threat proximity safety reports"),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _proximity,
                  activeColor: const Color(0xFF4F46E5),
                  onChanged: (val) => setState(() => _proximity = val),
                  title: const Text("Proximity Connections", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("When a connection comes nearby"),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _welfare,
                  activeColor: const Color(0xFF4F46E5),
                  onChanged: (val) => setState(() => _welfare = val),
                  title: const Text("Welfare Check Alerts", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("Notifications for inactive circle contacts"),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _updates,
                  activeColor: const Color(0xFF4F46E5),
                  onChanged: (val) => setState(() => _updates = val),
                  title: const Text("SafeTrace Updates", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("App announcements and safety tips"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// 6. PRIVACY & DATA SCREEN (Privacy & Data.png)
// ==========================================================
class PrivacyDataScreen extends StatefulWidget {
  const PrivacyDataScreen({super.key});

  @override
  State<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends State<PrivacyDataScreen> {
  bool _historyLogging = true;
  bool _shareProximity = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Privacy & Data",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
            ),
            SizedBox(height: 2),
            Text(
              "Location sharing, data retention",
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
            child: Column(
              children: [
                SwitchListTile(
                  value: _historyLogging,
                  activeColor: const Color(0xFF4F46E5),
                  onChanged: (val) => setState(() => _historyLogging = val),
                  title: const Text("Location History Logging", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("Store location history logs locally"),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _shareProximity,
                  activeColor: const Color(0xFF4F46E5),
                  onChanged: (val) => setState(() => _shareProximity = val),
                  title: const Text("Share Proximity Beacon", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("Allow anonymous radar scan discovery"),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: true,
                  onChanged: null, // Always enabled
                  title: const Text("Auto-Delete Logs after 7 days", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                  subtitle: const Text("Always active to protect privacy"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFEF4444)),
                foregroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location history logs cleared")));
              },
              child: const Text("Clear Location History", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// 7. SIGN OUT (Sign Out.png)
// ==========================================================
class SignOutScreen extends StatelessWidget {
  const SignOutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                decoration: const BoxDecoration(color: Color(0xFFFEE2E2), shape: BoxShape.circle),
                padding: const EdgeInsets.all(24),
                child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 48),
              ),
              const SizedBox(height: 24),
              const Text(
                "Sign Out",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 12),
              const Text(
                "Are you sure you want to sign out? You will need to verify your phone number via SMS OTP to log back in.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 14, height: 1.45),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Signed out successfully")));
                  },
                  child: const Text("Sign Out", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel", style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// 8. DELETE ACCOUNT CONFIRMATION (Delete Account.png - Mockup 5)
// ==========================================================
class DeleteAccountConfirmScreen extends StatefulWidget {
  const DeleteAccountConfirmScreen({super.key});

  @override
  State<DeleteAccountConfirmScreen> createState() => _DeleteAccountConfirmScreenState();
}

class _DeleteAccountConfirmScreenState extends State<DeleteAccountConfirmScreen> {
  bool _understand = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              "Delete Account",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFD32F2F)),
            ),
            Row(
              children: [
                Icon(Icons.circle, size: 6, color: Color(0xFFD32F2F)),
                SizedBox(width: 4),
                Icon(Icons.circle, size: 6, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        decoration: const BoxDecoration(color: Color(0xFFFFEBEE), shape: BoxShape.circle),
                        padding: const EdgeInsets.all(20),
                        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFD32F2F), size: 40),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "This cannot be undone.",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFD32F2F)),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Deleting your account permanently removes all your data from SafeTrace. Please read carefully before continuing.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 14, height: 1.45),
                      ),
                      const SizedBox(height: 24),

                      // Warning Box
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFFCDD2)),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.warning_amber_rounded, color: Color(0xFFD32F2F), size: 18),
                                SizedBox(width: 8),
                                Text(
                                  "The following will be permanently deleted:",
                                  style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildWarningItem(Icons.shield_outlined, "Your trusted contacts will no longer receive alerts from you"),
                            _buildWarningItem(Icons.history_rounded, "All location history and safety notes will be permanently deleted"),
                            _buildWarningItem(Icons.nearby_off_outlined, "Your Nearby Alert connections will be immediately terminated"),
                            _buildWarningItem(Icons.account_balance_wallet_outlined, "Your ₦1,000 wallet balance will be forfeited — no refunds"),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Checkbox
                      InkWell(
                        onTap: () => setState(() => _understand = !_understand),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _understand ? const Color(0xFF4F46E5) : const Color(0xFFE5E7EB)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _understand,
                                activeColor: const Color(0xFF4F46E5),
                                onChanged: (val) {
                                  if (val != null) setState(() => _understand = val);
                                },
                              ),
                              const Expanded(
                                child: Text(
                                  "I understand that deleting my account is permanent and irreversible.",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF111827)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Keep / Continue buttons
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF131522),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Keep My Account", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _understand ? const Color(0xFFF3F4F6) : const Color(0xFFE5E7EB),
                    foregroundColor: _understand ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _understand
                      ? () {
                          Navigator.of(context).push(_createRoute(const VerifyIdentityScreen()));
                        }
                      : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.chevron_right),
                      SizedBox(width: 8),
                      Text("I Understand, Continue", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFC62828), size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Color(0xFFC62828), fontSize: 12, height: 1.35))),
        ],
      ),
    );
  }
}

// ==========================================================
// 9. VERIFY YOUR IDENTITY (Verify Your Identity.png - Mockup 4)
// ==========================================================
class VerifyIdentityScreen extends StatefulWidget {
  const VerifyIdentityScreen({super.key});

  @override
  State<VerifyIdentityScreen> createState() => _VerifyIdentityScreenState();
}

class _VerifyIdentityScreenState extends State<VerifyIdentityScreen> {
  final List<TextEditingController> _codeCtrls = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  int _timerSeconds = 27;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var ctrl in _codeCtrls) {
      ctrl.dispose();
    }
    for (var fn in _focusNodes) {
      fn.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              "Verify Your Identity",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFD32F2F)),
            ),
            Row(
              children: [
                Icon(Icons.circle, size: 6, color: Colors.grey),
                SizedBox(width: 4),
                Icon(Icons.circle, size: 6, color: Color(0xFFD32F2F)),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                decoration: const BoxDecoration(color: Color(0xFF131522), shape: BoxShape.circle),
                padding: const EdgeInsets.all(20),
                child: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              const Text(
                "Verify your identity",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 8),
              const Text(
                "We sent a 6-digit code to +234 802 345 **** to confirm this action.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 14, height: 1.45),
              ),
              const SizedBox(height: 24),

              // Code OTP Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 48,
                    height: 54,
                    child: TextField(
                      controller: _codeCtrls[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        counterText: "",
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5), borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (val) {
                        if (val.isNotEmpty && index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (val.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              Text(
                "Resend code in 00:${_timerSeconds.toString().padLeft(2, '0')}",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827), fontSize: 13),
              ),
              const SizedBox(height: 24),

              // Caution Banner
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFD32F2F), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Entering this code will immediately begin the deletion process. This action cannot be reversed.",
                        style: TextStyle(color: Color(0xFFC62828), fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5E7EB),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(_createRoute(const AccountDeletedScreen()));
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.delete_outline_rounded, color: Color(0xFF7F8C8D)),
                      SizedBox(width: 8),
                      Text("Delete My Account", style: TextStyle(color: Color(0xFF7F8C8D), fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel", style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// 10. ACCOUNT DELETED (Account Deleted.png - Mockup 3)
// ==========================================================
class AccountDeletedScreen extends StatelessWidget {
  const AccountDeletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          "Account Deleted",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),
              Container(
                decoration: const BoxDecoration(color: Color(0xFF131522), shape: BoxShape.circle),
                padding: const EdgeInsets.all(24),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 24),
              const Text(
                "Goodbye, Jude.",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 12),
              const Text(
                "Your account and all associated data have been permanently deleted from SafeTrace.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 14, height: 1.45),
              ),
              const SizedBox(height: 24),

              // Summary card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("WHAT WAS REMOVED:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    _buildCheckItem("Profile & personal information"),
                    _buildCheckItem("Location history (38 logs)"),
                    _buildCheckItem("Trusted contacts (3)"),
                    _buildCheckItem("Nearby Alert connections"),
                    _buildCheckItem("Wallet & transaction history"),
                    _buildCheckItem("Community reports"),
                  ],
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF131522),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    // Navigate all the way back to root welcome/onboarding
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text("Return to Welcome Screen", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Stay safe out there. You can always create a new account. Thank you for using SafeTrace.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 13)),
        ],
      ),
    );
  }
}
