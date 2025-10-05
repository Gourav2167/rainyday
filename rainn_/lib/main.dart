import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/prediction_screen.dart';
import 'screens/location_screen.dart';
import 'screens/history_screen.dart';
import 'screens/about_screen.dart';

// Custom theme extension for gradient background
class GradientTheme extends ThemeExtension<GradientTheme> {
  final LinearGradient gradient;
  const GradientTheme({required this.gradient});

  @override
  ThemeExtension<GradientTheme> copyWith({LinearGradient? gradient}) {
    return GradientTheme(gradient: gradient ?? this.gradient);
  }

  @override
  ThemeExtension<GradientTheme> lerp(ThemeExtension<GradientTheme>? other, double t) {
    if (other is! GradientTheme) return this;
    return GradientTheme(gradient: LinearGradient.lerp(gradient, other.gradient, t)!);
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rain Prediction App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.transparent, // Make scaffold transparent for gradient
        extensions: [
          const GradientTheme(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF001B48), // Deep blue
                Color(0xFF3AA0FF), // Light blue
              ],
            ),
          ),
        ],
      ),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    HomeScreen(),
    PredictionScreen(),
    LocationScreen(),
    HistoryScreen(),
    AboutScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gradientTheme = Theme.of(context).extension<GradientTheme>();
    return Container(
      decoration: BoxDecoration(
        gradient: gradientTheme?.gradient ?? const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF001B48), // Deep blue
            Color(0xFF3AA0FF), // Light blue
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Make scaffold transparent
        body: _screens[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          backgroundColor: Colors.black.withOpacity(0.3),
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.cloud), label: 'Predict'),
            BottomNavigationBarItem(icon: Icon(Icons.location_on), label: 'Location'),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
            BottomNavigationBarItem(icon: Icon(Icons.info), label: 'About'),
          ],
        ),
      ),
    );
  }
}
