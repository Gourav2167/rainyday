import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../services/nasa_api_service.dart';
import '../widgets/loading_screen.dart';

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _predictionHistory = [];
  Map<String, dynamic> _historyStats = {};
  bool _isLoading = true;
  bool _showStats = true;
  DateTime _lastUpdated = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    // Auto-refresh every 30 seconds
    Future.delayed(Duration(seconds: 30), () {
      if (mounted) {
        _loadHistoryData();
        _startAutoRefresh(); // Schedule next refresh
      }
    });
  }

  Future<void> _loadHistoryData() async {
    print('HistoryScreen: Starting to load history data...');
    setState(() => _isLoading = true);

    try {
      // Load prediction history and statistics
      print('HistoryScreen: Calling NasaApiService.getPredictionHistory()');
      List<Map<String, dynamic>> history = await NasaApiService.getPredictionHistory();

      print('HistoryScreen: Got ${history.length} history items');
      for (int i = 0; i < min(3, history.length); i++) {
        var item = history[i];
        print('HistoryScreen: Item ${i + 1}: ${item['location']['address']} - ${item['prediction']['rainProbability']}%');
      }

      print('HistoryScreen: Calling NasaApiService.getHistoryStatistics()');
      Map<String, dynamic> stats = await NasaApiService.getHistoryStatistics();

      print('HistoryScreen: Statistics - Total: ${stats['total_predictions']}, Locations: ${stats['unique_locations']}');

      setState(() {
        _predictionHistory = history;
        _historyStats = stats;
        _lastUpdated = DateTime.now();
        _isLoading = false;
      });

      print('HistoryScreen: Successfully loaded and set state with ${history.length} items');
    } catch (e) {
      print('HistoryScreen: Error loading history data: $e');
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

  Future<void> _testSharedPreferences() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.storage, color: Colors.blue),
              SizedBox(width: 8),
              Text('Testing Storage...'),
            ],
          ),
          content: Container(
            height: 100,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Testing SharedPreferences functionality...'),
                SizedBox(height: 8),
                Text('Check console for detailed results', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );

    try {
      await NasaApiService.testSharedPreferences();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Show results dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Storage Test Results'),
                ],
              ),
              content: Text(
                'SharedPreferences storage test completed successfully!\n\n'
                'Check the console logs for detailed results including:\n'
                '• Save/Retrieve operations\n'
                '• Data integrity verification\n'
                '• Storage capacity checks\n\n'
                'If predictions still aren\'t showing, the issue may be in the save process during prediction creation.'
              ),
              actions: [
                TextButton(
                  child: Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Show error dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.error, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Storage Test Failed'),
                ],
              ),
              content: Text('Storage test failed: $e'),
              actions: [
                TextButton(
                  child: Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    }
  }

  Future<void> _saveTestPrediction() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.add, color: Colors.blue),
              SizedBox(width: 8),
              Text('Saving Test Prediction...'),
            ],
          ),
          content: Container(
            height: 100,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Creating and saving a test prediction...'),
                SizedBox(height: 8),
                Text('Check console for detailed results', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );

    try {
      bool success = await NasaApiService.saveTestPrediction();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Show results dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(success ? Icons.check_circle : Icons.error, color: success ? Colors.green : Colors.red),
                  SizedBox(width: 8),
                  Text('Test Prediction Results'),
                ],
              ),
              content: Text(
                success
                  ? 'Test prediction saved successfully!\n\n'
                    'The history should now show 1 prediction.\n'
                    'Check the console logs for detailed information about the save process.'
                  : 'Failed to save test prediction.\n\n'
                    'Check the console logs for error details.\n'
                    'This indicates an issue with SharedPreferences storage.'
              ),
              actions: [
                TextButton(
                  child: Text('Refresh History'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _loadHistoryData(); // Refresh to show the test prediction
                  },
                ),
                TextButton(
                  child: Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Show error dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.error, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Test Save Failed'),
                ],
              ),
              content: Text('Failed to save test prediction: $e'),
              actions: [
                TextButton(
                  child: Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Prediction History'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadHistoryData,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'test_storage') {
                _testSharedPreferences();
              } else if (value == 'save_test') {
                _saveTestPrediction();
              } else if (value == 'clear_history') {
                _clearHistory();
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'test_storage',
                child: Row(
                  children: [
                    Icon(Icons.storage, size: 20),
                    SizedBox(width: 8),
                    Text('Test Storage'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'save_test',
                child: Row(
                  children: [
                    Icon(Icons.add, size: 20),
                    SizedBox(width: 8),
                    Text('Save Test Prediction'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'clear_history',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20),
                    SizedBox(width: 8),
                    Text('Clear History'),
                  ],
                ),
              ),
            ],
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
          _buildAutoRefreshIndicator(),
          SizedBox(height: 16),
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

  Widget _buildAutoRefreshIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.autorenew, size: 16, color: Colors.green[600]),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Auto-refresh active • Last updated: ${DateFormat('MMM dd, hh:mm a').format(_lastUpdated)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.green[400],
              shape: BoxShape.circle,
            ),
          ),
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
    double latitude = prediction['location']['latitude'];
    double longitude = prediction['location']['longitude'];
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
            // Header with timestamp and rain probability
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
            SizedBox(height: 12),

            // Location coordinates (compact view)
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.blue[600]),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Lat: ${latitude.toStringAsFixed(4)}, Long: ${longitude.toStringAsFixed(4)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),

            // Details button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showPredictionDetails(prediction),
                icon: Icon(Icons.visibility, size: 16),
                label: Text('View Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[50],
                  foregroundColor: Colors.blue[700],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.blue[200]!),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPredictionDetails(Map<String, dynamic> prediction) {
    DateTime timestamp = DateTime.parse(prediction['timestamp']);
    String location = prediction['location']['address'] ?? 'Unknown Location';
    String date = prediction['date']['formatted'] ?? 'Unknown Date';
    String time = prediction['time']['formatted'] ?? 'Unknown Time';

    double rainProbability = prediction['prediction']['rainProbability'] ?? 0.0;
    double avgTemperature = prediction['prediction']['avgTemperature'] ?? 0.0;
    double avgHumidity = prediction['prediction']['avgHumidity'] ?? 0.0;
    double avgWindSpeed = prediction['prediction']['avgWindSpeed'] ?? 0.0;

    Color probabilityColor = _getProbabilityColor(rainProbability);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.cloud, color: probabilityColor),
              SizedBox(width: 8),
              Text('Prediction Details'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location info
                _buildDetailRow('Location', location),
                _buildDetailRow('Coordinates', '${prediction['location']['latitude'].toStringAsFixed(4)}, ${prediction['location']['longitude'].toStringAsFixed(4)}'),
                _buildDetailRow('Date & Time', '$date • $time'),
                _buildDetailRow('Timestamp', DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp)),

                SizedBox(height: 16),
                Divider(),

                // Weather details
                SizedBox(height: 8),
                Text(
                  'Weather Conditions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                ),
                SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildDetailWeatherCard(
                        'Temperature',
                        '${avgTemperature.toStringAsFixed(1)}°C',
                        Icons.thermostat,
                        _getTemperatureColor(avgTemperature),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _buildDetailWeatherCard(
                        'Humidity',
                        '${avgHumidity.toStringAsFixed(1)}%',
                        Icons.water_drop,
                        _getHumidityColor(avgHumidity),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailWeatherCard(
                        'Wind Speed',
                        '${avgWindSpeed.toStringAsFixed(1)} m/s',
                        Icons.air,
                        _getWindSpeedColor(avgWindSpeed),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _buildDetailWeatherCard(
                        'Rain Probability',
                        '${rainProbability.toStringAsFixed(0)}%',
                        Icons.opacity,
                        probabilityColor,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16),
                Divider(),

                // Rain probability bar
                SizedBox(height: 8),
                Text(
                  'Rain Prediction',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                ),
                SizedBox(height: 8),
                LinearProgressIndicator(
                  value: rainProbability / 100,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(probabilityColor),
                ),
                SizedBox(height: 4),
                Text(
                  '${rainProbability.toStringAsFixed(0)}% - ${_getRainComment(rainProbability)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: probabilityColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailWeatherCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
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
