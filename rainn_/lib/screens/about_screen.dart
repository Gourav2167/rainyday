import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('About'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Icon(Icons.cloud, size: 80, color: Colors.blue[600]),
                  SizedBox(height: 16),
                  Text(
                    'Rain Prediction App',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 2,
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'NASA Space Apps Challenge 2025',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),
            _buildInfoCard(
              'About the Challenge',
              '"Will It Rain On My Parade?" challenges participants to create innovative solutions for weather prediction using NASA\'s extensive Earth observation datasets.',
            ),
            SizedBox(height: 16),
            _buildInfoCard(
              'Data Source',
              'This app uses NASA POWER (Prediction of Worldwide Energy Resources) API, which provides global meteorological and solar energy data derived from satellite observations and atmospheric models.',
            ),
            SizedBox(height: 16),
            _buildInfoCard(
              'How It Works',
              'The app analyzes historical weather patterns from the past decade for your selected location and date, calculating rain probability based on NASA\'s precipitation data (PRECTOTCORR parameter).',
            ),

            _buildInfoCard(
              'How to Use',
              '1. Select your location using the location picker or enter coordinates manually.\n\n2. Choose the date you want to check for rain probability.\n\n3. Tap "Predict Weather" to get results.\n\n4. View the rain probability percentage and confidence level.\n\n5. Check detailed weather parameters including temperature, humidity, and precipitation data.\n\n6. Save predictions to history for future reference.',
            ),
            SizedBox(height: 16),
            _buildInfoCard(
              'Developer Team - Vishnu',
              'Team Members:\n• Mrityunjay Burman\n• Gourav Singh\n• Jagdish Das\n• Nirmala Khadka\n• Varun\n• Swarit\n\nFull Stack Developer - Gourav Singh:\n• Led backend API integration with NASA POWER service\n• Implemented location services and data processing algorithms\n• Designed and developed the app architecture and database structure\n• Coordinated with NASA APIs for weather data retrieval and analysis\n\nFrontend Developer - Jagdish Das:\n• Designed and implemented the user interface and user experience\n• Developed responsive mobile layouts for weather prediction screens\n• Created intuitive navigation and interactive elements\n• Optimized app performance and user interactions\n\nFrontend, UI & UX Developer - Nirmala Khadka:\n• Specialized in frontend development and user interface design\n• Created responsive and intuitive mobile layouts for weather prediction screens\n• Designed user experience flows and interactive elements\n• Implemented modern UI components with focus on usability and accessibility\n• Developed visual design systems and ensured consistent user experience across all app screens\n• Optimized app interface for better user engagement and interaction\n\nThis app was developed as part of the NASA Space Apps Challenge 2025, combining expertise in mobile app development, API integration, and data visualization to create an intuitive weather prediction tool.',
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String content) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              content,
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
