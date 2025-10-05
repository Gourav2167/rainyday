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
            SizedBox(height: 16),
            _buildInfoCard(
              'Data Coverage',
              'NASA POWER provides data at 0.5° x 0.625° spatial resolution with global coverage. Historical data spans from 1981 to present, ensuring robust statistical analysis.',
            ),
            SizedBox(height: 16),
            _buildInfoCard(
              'Acknowledgments',
              'Special thanks to NASA\'s Earth Science Division for providing open access to satellite-derived meteorological data through the POWER project.',
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
