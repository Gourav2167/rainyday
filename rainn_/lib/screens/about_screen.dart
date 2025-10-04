// ...existing code...
import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  static const Color primaryDefault = Color(0xFFF97316);
  static const Color cardLight = Color(0xFFFFEDD5);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color cardSecondaryLight = Color(0xFF3B82F6);
  static const Color cardSecondaryDark = Color(0xFF2563EB);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? cardDark : cardLight;
    final Color cardSecondaryBg = isDark ? cardSecondaryDark : cardSecondaryLight;
    final Color textSecondary = isDark ? textSecondaryDark : textSecondaryLight;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('About & Help'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Intro card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Will It Rain In My Parade?',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Your personal parade planner, powered by government's open data. We help you find the perfect rain-free day for your celebration.",
                      style: TextStyle(color: textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Secondary card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardSecondaryBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Government International Space Apps Challenge',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "This project is a proud entry for the world's largest global hackathon. Inspired by space, for life on Earth.",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // FAQ section
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Frequently Asked Questions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: ExpansionTile(
                  title: const Text("How does it work?"),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        'Details about how it works.',
                        style: TextStyle(color: textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: ExpansionTile(
                  title: const Text("What's the 'Parade' theme about?"),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        "Details about the 'Parade' theme.",
                        style: TextStyle(color: textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: ExpansionTile(
                  title: const Text("How can I contribute?"),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        'Details on how to contribute.',
                        style: TextStyle(color: textSecondary),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Footer
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryDefault,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 6,
                      ),
                      onPressed: () {
                        // TODO: implement share action
                      },
                      icon: const Icon(Icons.favorite_border),
                      label: const Text('Share the Sunshine'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Made with ❤️ for the love of science and clear skies.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ...existing code...