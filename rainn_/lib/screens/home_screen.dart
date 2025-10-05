import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/location_service.dart';
import '../services/nasa_api_service.dart';
import '../widgets/loading_screen.dart';
import 'package:geolocator/geolocator.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Position? _currentPosition;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isLoading = false;
  Map<String, dynamic>? _predictionResult;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-load prediction when location is available
    if (_currentPosition != null && _predictionResult == null && !_isLoading) {
      _getPrediction();
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    Position? position = await LocationService.getCurrentLocation();

    if (!mounted) return;

    setState(() {
      _currentPosition = position;
      _isLoading = false;
    });

    // Automatically get prediction once location is available
    if (_currentPosition != null && _predictionResult == null) {
      _getPrediction();
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );

    if (picked != null && picked != _selectedDate && mounted) {
      setState(() {
        _selectedDate = picked;
      });
      _getPrediction(); // Refresh prediction with new date
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (picked != null && picked != _selectedTime && mounted) {
      setState(() {
        _selectedTime = picked;
      });
      _getPrediction(); // Refresh prediction with new time
    }
  }

  Future<void> _getPrediction() async {
    if (_currentPosition == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location not available')),
        );
      }
      return;
    }

    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Use selected time for more accurate predictions
      Map<String, dynamic> result = await NasaApiService.getHistoricalData(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        year: _selectedDate.year,
        month: _selectedDate.month,
        day: _selectedDate.day,
        selectedTime: _selectedTime,
      );

      if (!mounted) return;

      setState(() {
        _predictionResult = result;
        _isLoading = false;
      });


    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting prediction: $e')),
      );
    }
  }

  Future<void> _runDebugTest() async {
    if (!mounted) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.bug_report, color: Colors.blue),
              SizedBox(width: 8),
              Text('NASA API Debug Test'),
            ],
          ),
          content: Container(
            height: 120,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Testing NASA API with 20 years of historical data...'),
                SizedBox(height: 8),
                Text('This may take a few moments...', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );

    try {
      Map<String, dynamic> debugResult = await NasaApiService.debugApiWithHistoricalData(
        latitude: _currentPosition?.latitude ?? 28.7041,
        longitude: _currentPosition?.longitude ?? 77.1025,
      );

      if (!mounted) return;

      Navigator.of(context).pop(); // Close loading dialog

      // Show results dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  debugResult['success'] == true ? Icons.check_circle : Icons.error,
                  color: debugResult['success'] == true ? Colors.green : Colors.red,
                ),
                SizedBox(width: 8),
                Text('Debug Test Results'),
              ],
            ),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    debugResult['success'] == true ? '✓ Test completed successfully!' : '✗ Test failed',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: debugResult['success'] == true ? Colors.green : Colors.red,
                    ),
                  ),
                  SizedBox(height: 12),
                  if (debugResult['success'] == true) ...[
                    Text('• Years tested: ${debugResult['years_tested']}'),
                    Text('• Data points collected: ${debugResult['total_data_points']}'),
                    Text('• Execution time: ${debugResult['execution_time_ms']}ms'),
                    if (debugResult.containsKey('data') && debugResult['data'].containsKey('rainProbability'))
                      Text('• Rain probability: ${debugResult['data']['rainProbability'].toStringAsFixed(1)}%'),
                  ] else ...[
                    Text('• Error: ${debugResult['error']}'),
                    if (debugResult.containsKey('step'))
                      Text('• Failed at step: ${debugResult['step']}'),
                  ],
                  SizedBox(height: 16),
                  Text(
                    'Check the console/logs for detailed debug information.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
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
    } catch (e) {
      if (!mounted) return;

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
                Text('Debug Test Failed'),
              ],
            ),
            content: Text('An unexpected error occurred: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.cloud_queue, size: 28),
            SizedBox(width: 12),
            Text('Rain Prediction'),
          ],
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.bug_report, color: Colors.white),
            onPressed: _runDebugTest,
            tooltip: 'Debug NASA API (20 years)',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue[50]!,
              Colors.white,
              Colors.blue[50]!,
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Location and Date cards in same row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Card(
                      elevation: 8,
                      shadowColor: Colors.blue.withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on, color: Colors.blue[600], size: 20),
                                SizedBox(width: 6),
                                Text(
                                  'Location',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            if (_currentPosition != null)
                              Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  LocationService.getLocationString(
                                    _currentPosition!.latitude,
                                    _currentPosition!.longitude,
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            else
                              Text(
                                'Getting location...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _getCurrentLocation,
                                icon: Icon(Icons.refresh, size: 16),
                                label: Text('Refresh', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[600],
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Card(
                      elevation: 8,
                      shadowColor: Colors.blue.withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.calendar_today, color: Colors.blue[600], size: 20),
                                SizedBox(width: 6),
                                Text(
                                  'Date & Time',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(_selectedDate),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.blue[800],
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    _selectedTime.format(context),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _selectDate,
                                    icon: Icon(Icons.calendar_today, size: 16),
                                    label: Text('Date', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[600],
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _selectTime,
                                    icon: Icon(Icons.access_time, size: 16),
                                    label: Text('Time', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[600],
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              // Loading indicator or prediction widget
              if (_isLoading && _currentPosition != null) ...[
                Expanded(
                  child: LoadingScreen(
                    loadingText: "Analyzing weather patterns...",
                    duration: Duration(seconds: 8),
                  ),
                ),
              ] else if (_predictionResult != null) ...[
                Expanded(child: _buildCompactPredictionWidget()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionCard() {
    double rainProbability = _predictionResult!['rainProbability'];
    double avgTemp = _predictionResult!['avgTemperature'];
    double avgHumidity = _predictionResult!['avgHumidity'];

    Color probabilityColor = rainProbability > 70 
        ? Colors.red 
        : rainProbability > 40 
            ? Colors.orange 
            : Colors.green;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: probabilityColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: probabilityColor),
          ),
          child: Column(
            children: [
              Text(
                '${rainProbability.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: probabilityColor,
                ),
              ),
              Text(
                'Chance of Rain',
                style: TextStyle(fontSize: 16, color: probabilityColor),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard('Temperature', '${avgTemp.toStringAsFixed(1)}°C', Icons.thermostat),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildStatCard('Humidity', '${avgHumidity.toStringAsFixed(1)}%', Icons.water_drop),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.blue[600]),
          SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCompactPredictionWidget() {
    double rainProbability = _predictionResult!['rainProbability'];
    double avgTemperature = _predictionResult!['avgTemperature'] ?? 0.0;
    double avgHumidity = _predictionResult!['avgHumidity'] ?? 0.0;
    double avgWindSpeed = _predictionResult!['avgWindSpeed'] ?? 0.0;

    String comment = _getRainComment(rainProbability);
    IconData weatherIcon = _getWeatherIcon(rainProbability);

    Color probabilityColor = rainProbability > 70
        ? Colors.red
        : rainProbability > 40
            ? Colors.orange
            : Colors.green;

    return Card(
      elevation: 6,
      child: Container(
        padding: EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              probabilityColor.withOpacity(0.1),
              probabilityColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(weatherIcon, color: probabilityColor, size: 28),
                SizedBox(width: 12),
                Text(
                  'Today\'s Rain Prediction',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${rainProbability.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: probabilityColor,
                        ),
                      ),
                      Text(
                        'Chance of Rain',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: probabilityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: probabilityColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    comment,
                    style: TextStyle(
                      color: probabilityColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // Enhanced weather details
            Row(
              children: [
                Expanded(
                  child: _buildWeatherDetailCard(
                    'Temperature',
                    '${avgTemperature.toStringAsFixed(1)}°C',
                    Icons.thermostat,
                    _getTemperatureColor(avgTemperature),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildWeatherDetailCard(
                    'Humidity',
                    '${avgHumidity.toStringAsFixed(1)}%',
                    Icons.water_drop,
                    _getHumidityColor(avgHumidity),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildWeatherDetailCard(
                    'Wind Speed',
                    '${avgWindSpeed.toStringAsFixed(1)} m/s',
                    Icons.air,
                    _getWindSpeedColor(avgWindSpeed),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            // Data quality indicator
            if (_predictionResult!.containsKey('dataQuality'))
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.analytics, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      'Enhanced prediction using 20+ years of NASA data',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherDetailCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(height: 2),
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
    if (probability > 80) {
      return "Heavy rain expected! Don't step out without raincoat";
    } else if (probability > 60) {
      return "High chance of rain. Carry your raincoat";
    } else if (probability > 40) {
      return "Moderate rain chance. Be prepared";
    } else if (probability > 20) {
      return "Low rain chance. Should be fine";
    } else {
      return "No rain expected. Clear skies ahead!";
    }
  }

  IconData _getWeatherIcon(double probability) {
    if (probability > 70) {
      return Icons.thunderstorm;
    } else if (probability > 40) {
      return Icons.grain;
    } else if (probability > 20) {
      return Icons.wb_cloudy;
    } else {
      return Icons.wb_sunny;
    }
  }
}
