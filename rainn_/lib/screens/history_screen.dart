import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/nasa_api_service.dart';

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _predictionHistory = [];
  Map<String, dynamic> _historyStats = {};
  bool _isLoading = true;
  bool _showStats = true;

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
  }

  Future<void> _loadHistoryData() async {
    setState(() => _isLoading = true);

    try {
      // Load prediction history and statistics
      List<Map<String, dynamic>> history = await NasaApiService.getPredictionHistory();
      Map<String, dynamic> stats = await NasaApiService.getHistoryStatistics();

      setState(() {
        _predictionHistory = history;
        _historyStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading history data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearHistory() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Clear History'),
          content: Text('Are you sure you want to clear all prediction history? This action cannot be undone.'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Clear'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await NasaApiService.clearPredictionHistory();
      await _loadHistoryData(); // Reload the empty history
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Prediction History'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.analytics),
            onPressed: () => setState(() => _showStats = !_showStats),
            tooltip: 'Toggle Statistics',
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _predictionHistory.isNotEmpty ? _clearHistory : null,
            tooltip: 'Clear History',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadHistoryData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView()
          : _predictionHistory.isEmpty
              ? _buildEmptyView()
              : _buildHistoryView(),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading prediction history...'),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No Prediction History',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Your rain predictions will appear here once you start using the app',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.cloud),
            label: Text('Make a Prediction'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryView() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_showStats) ...[
            _buildStatisticsCard(),
            SizedBox(height: 16),
          ],
          Text(
            'Recent Predictions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            '${_predictionHistory.length} predictions saved',
            style: TextStyle(color: Colors.grey[600]),
          ),
          SizedBox(height: 16),
          ..._predictionHistory.map((prediction) => _buildPredictionCard(prediction)).toList(),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    int totalPredictions = _historyStats['total_predictions'] ?? 0;
    int uniqueLocations = _historyStats['unique_locations'] ?? 0;
    String? dateRange = _historyStats['date_range'];
    double avgRainProbability = _historyStats['avg_rain_probability'] ?? 0.0;

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue, size: 24),
                SizedBox(width: 8),
                Text(
                  'Prediction Statistics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    Icons.assignment,
                    'Total Predictions',
                    totalPredictions.toString(),
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    Icons.location_on,
                    'Locations',
                    uniqueLocations.toString(),
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    Icons.opacity,
                    'Avg Rain Chance',
                    '${avgRainProbability.toStringAsFixed(1)}%',
                    _getProbabilityColor(avgRainProbability),
                  ),
                ),
              ],
            ),
            if (dateRange != null) ...[
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.date_range, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Date Range: $dateRange',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPredictionCard(Map<String, dynamic> prediction) {
    DateTime timestamp = DateTime.parse(prediction['timestamp']);
    String location = prediction['location']['address'] ?? 'Unknown Location';
    String date = prediction['date']['formatted'] ?? 'Unknown Date';
    String time = prediction['time']['formatted'] ?? 'Unknown Time';

    double rainProbability = prediction['prediction']['rainProbability'] ?? 0.0;
    double avgTemperature = prediction['prediction']['avgTemperature'] ?? 0.0;
    double avgHumidity = prediction['prediction']['avgHumidity'] ?? 0.0;

    Color probabilityColor = _getProbabilityColor(rainProbability);
    IconData weatherIcon = _getWeatherIcon(rainProbability);

    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with timestamp and location
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: probabilityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: probabilityColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(weatherIcon, size: 14, color: probabilityColor),
                      SizedBox(width: 4),
                      Text(
                        '${rainProbability.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: probabilityColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),

            // Location and date/time info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.blue[600]),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text(
                            '$date • $time',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Weather details
            Row(
              children: [
                Expanded(
                  child: _buildMiniWeatherCard(
                    'Temperature',
                    '${avgTemperature.toStringAsFixed(1)}°C',
                    Icons.thermostat,
                    _getTemperatureColor(avgTemperature),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildMiniWeatherCard(
                    'Humidity',
                    '${avgHumidity.toStringAsFixed(1)}%',
                    Icons.water_drop,
                    _getHumidityColor(avgHumidity),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildMiniWeatherCard(
                    'Wind Speed',
                    '${(prediction['prediction']['avgWindSpeed'] ?? 0.0).toStringAsFixed(1)} m/s',
                    Icons.air,
                    _getWindSpeedColor(prediction['prediction']['avgWindSpeed'] ?? 0.0),
                  ),
                ),
              ],
            ),

            // Rain probability bar
            SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rain Probability',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                SizedBox(height: 4),
                LinearProgressIndicator(
                  value: rainProbability / 100,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(probabilityColor),
                ),
                SizedBox(height: 2),
                Text(
                  '${rainProbability.toStringAsFixed(0)}% - ${_getRainComment(rainProbability)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: probabilityColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniWeatherCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 14),
          SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Color _getProbabilityColor(double probability) {
    if (probability >= 70) return Colors.red;
    if (probability >= 40) return Colors.orange;
    if (probability >= 20) return Colors.yellow.shade700;
    return Colors.green;
  }

  Color _getTemperatureColor(double temp) {
    if (temp < 10) return Colors.blue;
    if (temp < 20) return Colors.green;
    if (temp < 30) return Colors.orange;
    return Colors.red;
  }

  Color _getHumidityColor(double humidity) {
    if (humidity < 30) return Colors.orange;
    if (humidity < 60) return Colors.green;
    return Colors.blue;
  }

  Color _getWindSpeedColor(double windSpeed) {
    if (windSpeed < 2) return Colors.green;
    if (windSpeed < 5) return Colors.yellow.shade700;
    if (windSpeed < 10) return Colors.orange;
    return Colors.red;
  }

  String _getRainComment(double probability) {
    if (probability > 80) return "Heavy Rain";
    if (probability > 60) return "High Chance";
    if (probability > 40) return "Moderate";
    if (probability > 20) return "Low Chance";
    return "Clear";
  }

  IconData _getWeatherIcon(double probability) {
    if (probability > 70) return Icons.thunderstorm;
    if (probability > 40) return Icons.grain;
    if (probability > 20) return Icons.wb_cloudy;
    return Icons.wb_sunny;
  }
}
