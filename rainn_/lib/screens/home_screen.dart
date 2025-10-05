import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/location_service.dart';
import '../services/nasa_api_service.dart';
import '../widgets/loading_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

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

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
      // Auto-refresh prediction whenever date changes (or even if same date is selected again)
      _getPrediction();
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedTime = picked;
      });
      // Auto-refresh prediction whenever time changes (or even if same time is selected again)
      _getPrediction();
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
      // Use enhanced prediction method that combines historical data with current year live data
      Map<String, dynamic> result = await NasaApiService.getEnhancedWeatherData(
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
        actions: [
          IconButton(
            icon: Icon(Icons.bug_report),
            onPressed: _runDebugTest,
            tooltip: 'Debug NASA API (20 years)',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.transparent, // Use transparent to show main gradient
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
                          mainAxisSize: MainAxisSize.min,
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
                            SizedBox(height: 28),
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
                              Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Getting location...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
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
                          mainAxisSize: MainAxisSize.min,
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
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildCompactPredictionWidget(),
                        if (_predictionResult!.containsKey('yesterdaysPrecipitation') && _predictionResult!['yesterdaysPrecipitation'] != null)
                          Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: _buildYesterdaysDataCard(_predictionResult!['yesterdaysPrecipitation']),
                          ),
                      ],
                    ),
                  ),
                ),
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

    Color probabilityColor = _getProbabilityColor(rainProbability);
    String predictionLevel = _getPredictionLevel(rainProbability);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Card(
        elevation: 12,
        shadowColor: probabilityColor.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white,
                probabilityColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: probabilityColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getWeatherIcon(rainProbability),
                      color: probabilityColor,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rain Prediction',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          predictionLevel,
                          style: TextStyle(
                            fontSize: 14,
                            color: probabilityColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24),

              // Main circular progress indicator
              Center(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        probabilityColor.withOpacity(0.1),
                        probabilityColor.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: StaticCircularProgressIndicator(
                    percentage: rainProbability,
                    color: probabilityColor,
                    size: 140,
                    strokeWidth: 10,
                  ),
                ),
              ),

              SizedBox(height: 24),

              // Prediction details
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: probabilityColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: probabilityColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _getRainComment(rainProbability),
                      style: TextStyle(
                        fontSize: 16,
                        color: probabilityColor,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoChip(
                            Icons.thermostat,
                            'Temp',
                            '${avgTemperature.toStringAsFixed(1)}°C',
                            _getTemperatureColor(avgTemperature),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoChip(
                            Icons.water_drop,
                            'Humidity',
                            '${avgHumidity.toStringAsFixed(1)}%',
                            _getHumidityColor(avgHumidity),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Data source info
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.satellite, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Powered by NASA Earth Data (20+ years)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Color _getProbabilityColor(double probability) {
    if (probability >= 70) return Colors.red.shade600;
    if (probability >= 50) return Colors.orange.shade600;
    if (probability >= 30) return Colors.amber.shade600;
    return Colors.green.shade600;
  }

  String _getPredictionLevel(double probability) {
    if (probability >= 80) return 'Very High Risk';
    if (probability >= 60) return 'High Risk';
    if (probability >= 40) return 'Moderate Risk';
    if (probability >= 20) return 'Low Risk';
    return 'Very Low Risk';
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

  static Color _getProgressColor(double percentage) {
    if (percentage >= 70) return Colors.red.shade600;
    if (percentage >= 50) return Colors.orange.shade600;
    if (percentage >= 30) return Colors.amber.shade600;
    return Colors.green.shade600;
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

  String _getAnimationType(double probability) {
    if (probability > 70) {
      return 'thunder';
    } else if (probability > 40) {
      return 'rain';
    } else if (probability > 20) {
      return 'cloudy';
    } else {
      return 'sunny';
    }
  }

  String _getDetailedWeatherDescription(double probability) {
    if (probability > 80) {
      return "Heavy precipitation expected with potential thunderstorms. Stay indoors and avoid travel if possible.";
    } else if (probability > 60) {
      return "Significant chance of rainfall. Plan outdoor activities accordingly and keep rain protection handy.";
    } else if (probability > 40) {
      return "Moderate possibility of showers. Light rain gear recommended for extended outdoor time.";
    } else if (probability > 20) {
      return "Low likelihood of precipitation. Generally good conditions for outdoor activities.";
    } else {
      return "Clear conditions expected. Perfect weather for any outdoor plans or activities.";
    }
  }

  IconData _getWeatherActionIcon(double probability) {
    if (probability > 80) {
      return Icons.umbrella;
    } else if (probability > 60) {
      return Icons.beach_access;
    } else if (probability > 40) {
      return Icons.explore;
    } else if (probability > 20) {
      return Icons.wb_sunny;
    } else {
      return Icons.celebration;
    }
  }

  Widget _buildYesterdaysDataCard(double yesterdaysPrecipitation) {
    Color rainColor = yesterdaysPrecipitation > 3.0
        ? Colors.red.shade600
        : yesterdaysPrecipitation > 1.0
            ? Colors.orange.shade600
            : Colors.green.shade600;

    IconData rainIcon = yesterdaysPrecipitation > 3.0
        ? Icons.thunderstorm
        : yesterdaysPrecipitation > 1.0
            ? Icons.grain
            : Icons.wb_sunny;

    return Card(
      elevation: 4,
      child: Container(
        padding: EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              rainColor.withOpacity(0.1),
              rainColor.withOpacity(0.05),
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
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: rainColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(rainIcon, color: rainColor, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yesterday\'s Weather Impact',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        'Recent data heavily influencing prediction',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: rainColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: rainColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${yesterdaysPrecipitation.toStringAsFixed(1)} mm',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: rainColor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Yesterday\'s Rain',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '20x',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Data Weight',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.star, size: 16, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Yesterday\'s weather has maximum influence on today\'s prediction accuracy',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber[800],
                        fontWeight: FontWeight.w500,
                      ),
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
}

// Animated Weather Icon Widget
class AnimatedWeatherIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final String animationType;

  const AnimatedWeatherIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.size,
    required this.animationType,
  });

  @override
  State<AnimatedWeatherIcon> createState() => _AnimatedWeatherIconState();
}

class _AnimatedWeatherIconState extends State<AnimatedWeatherIcon>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: _getAnimationDuration()),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 1.0,
      end: _getAnimationEnd(),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 70) return Colors.red.shade600;
    if (percentage >= 50) return Colors.orange.shade600;
    if (percentage >= 30) return Colors.amber.shade600;
    return Colors.green.shade600;
  }



  double _getAnimationEnd() {
    switch (widget.animationType) {
      case 'thunder':
        return 1.3;
      case 'rain':
        return 1.2;
      case 'cloudy':
        return 1.1;
      case 'sunny':
        return 1.15;
      default:
        return 1.1;
    }
  }



  int _getAnimationDuration() {
    switch (widget.animationType) {
      case 'thunder':
        return 800;
      case 'rain':
        return 1200;
      case 'cloudy':
        return 2000;
      case 'sunny':
        return 3000;
      default:
        return 1500;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Icon(
            widget.icon,
            color: widget.color,
            size: widget.size,
          ),
        );
      },
    );
  }
}

// Animated Counter Widget
class AnimatedCounter extends StatefulWidget {
  final double value;
  final Color color;
  final double fontSize;
  final String suffix;

  const AnimatedCounter({
    super.key,
    required this.value,
    required this.color,
    required this.fontSize,
    required this.suffix,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0,
      end: widget.value,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: oldWidget.value,
        end: widget.value,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${_animation.value.toStringAsFixed(0)}${widget.suffix}',
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.bold,
            color: widget.color,
          ),
        );
      },
    );
  }
}

// Animated Progress Bar Widget
class AnimatedProgressBar extends StatefulWidget {
  final double value;
  final Color color;
  final double height;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    required this.color,
    required this.height,
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0,
      end: widget.value,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    ));

    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: oldWidget.value,
        end: widget.value,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuart,
      ));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(widget.height / 2),
      ),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _animation.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.color.withOpacity(0.8),
                    widget.color,
                  ],
                ),
                borderRadius: BorderRadius.circular(widget.height / 2),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.3),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Animated Weather Detail Card Widget
class AnimatedWeatherDetailCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Duration delay;

  const AnimatedWeatherDetailCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.delay,
  });

  @override
  State<AnimatedWeatherDetailCard> createState() => _AnimatedWeatherDetailCardState();
}

class _AnimatedWeatherDetailCardState extends State<AnimatedWeatherDetailCard>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.color.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.1),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    widget.icon,
                    color: widget.color,
                    size: 20,
                  ),
                  SizedBox(height: 4),
                  Text(
                    widget.value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: widget.color,
                    ),
                  ),
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Static Circular Progress Indicator Widget
class StaticCircularProgressIndicator extends StatefulWidget {
  final double percentage;
  final Color color;
  final double size;
  final double strokeWidth;

  const StaticCircularProgressIndicator({
    super.key,
    required this.percentage,
    required this.color,
    required this.size,
    required this.strokeWidth,
  });

  @override
  State<StaticCircularProgressIndicator> createState() => _StaticCircularProgressIndicatorState();
}

class _StaticCircularProgressIndicatorState extends State<StaticCircularProgressIndicator> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: widget.color.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          // Background reference (full faint circle)
          CustomPaint(
            size: Size(widget.size, widget.size),
            painter: CircularProgressPainter(
              percentage: 1.0,
              color: widget.color.withOpacity(0.1),
              strokeWidth: widget.strokeWidth,
              isBackground: true,
            ),
          ),
          // Progress arc (visible colored arc - static, no animation)
          CustomPaint(
            size: Size(widget.size, widget.size),
            painter: CircularProgressPainter(
              percentage: widget.percentage / 100.0, // Convert percentage to decimal for arc calculation
              color: widget.color, // Use the passed color parameter directly
              strokeWidth: widget.strokeWidth,
              isBackground: false,
            ),
          ),
          // Center content
          Center(
            child: Container(
              width: widget.size - widget.strokeWidth * 2 - 20,
              height: widget.size - widget.strokeWidth * 2 - 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Center(
                child: Text(
                  '${widget.percentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: widget.color,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for Circular Progress
class CircularProgressPainter extends CustomPainter {
  final double percentage;
  final Color color;
  final double strokeWidth;
  final bool isBackground;

  CircularProgressPainter({
    required this.percentage,
    required this.color,
    required this.strokeWidth,
    this.isBackground = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    if (isBackground) {
      // Draw white background track (full circle)
      final backgroundPaint = Paint()
        ..color = Colors.white.withOpacity(0.9) // White track
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawCircle(center, radius, backgroundPaint);
    } else if (percentage > 0) {
      // Draw progress arc with dynamic color
      final progressPaint = Paint()
        ..color = color // Use the dynamic color passed in
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // Calculate the angle for the progress arc (starts from top, goes clockwise)
      final sweepAngle = 2 * math.pi * percentage;

      // Draw the red progress arc
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // Start from top (12 o'clock position)
        sweepAngle,   // Sweep angle based on percentage
        false,        // Don't use center point
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
           oldDelegate.color != color ||
           oldDelegate.strokeWidth != strokeWidth;
  }
}
