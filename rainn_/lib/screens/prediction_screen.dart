import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/nasa_api_service.dart';
import '../services/location_service.dart';
import 'dart:math';

class PredictionScreen extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;

  const PredictionScreen({
    Key? key,
    this.latitude,
    this.longitude,
    this.selectedDate,
    this.selectedTime,
  }) : super(key: key);

  @override
  _PredictionScreenState createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  Map<String, dynamic>? _predictionData;
  bool _isLoading = false;
  String? _error;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  double? _selectedLatitude;
  double? _selectedLongitude;
  List<double> precipitationData = [];
  List<double> temperatureData = [];

  @override
  void initState() {
    super.initState();
    // Initialize with passed values or defaults
    _selectedLatitude = widget.latitude;
    _selectedLongitude = widget.longitude;
    _selectedDate = widget.selectedDate ?? DateTime.now();
    _selectedTime = widget.selectedTime ?? TimeOfDay.now();
    _loadPredictionData();
  }

  Future<void> _loadPredictionData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      double latitude, longitude;

      // Use selected location if available, otherwise get current location
      if (_selectedLatitude != null && _selectedLongitude != null) {
        latitude = _selectedLatitude!;
        longitude = _selectedLongitude!;
      } else {
        var position = await LocationService.getCurrentLocation();
        if (position == null) {
          throw Exception('Unable to get current location');
        }
        latitude = position.latitude;
        longitude = position.longitude;
      }

      print('Loading prediction for location: $latitude, $longitude');
      print('Selected date: ${_selectedDate.toString().split(' ')[0]}');

      // Get prediction for selected date, time, and location
      var data = await NasaApiService.getHistoricalData(
        latitude: latitude,
        longitude: longitude,
        year: _selectedDate.year,
        month: _selectedDate.month,
        day: _selectedDate.day,
        selectedTime: _selectedTime,
      );

      setState(() {
        _predictionData = data;
        precipitationData = List<double>.from(_predictionData!['precipitationData'] ?? []);
        temperatureData = List<double>.from(_predictionData!['temperatureData'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      print('Error in prediction screen: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(Duration(days: 365)), // Allow up to 1 year in the future
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadPredictionData();
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
      // Note: Time doesn't affect the data loading since NASA API is daily-based
      // But we can use it for more precise predictions in the future
    }
  }

  Future<void> _testApiConnection() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      bool isConnected = await NasaApiService.testApiConnection();

      setState(() {
        _isLoading = false;
        if (isConnected) {
          _error = 'API connection successful! The service is working correctly.';
        } else {
          _error = 'API connection failed. Please check your internet connection and try again.';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'API test failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rain Prediction'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.access_time),
            onPressed: () => _selectTime(context),
            tooltip: 'Select time',
          ),
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
            tooltip: 'Select date',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadPredictionData,
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView()
          : _error != null
              ? _buildErrorView()
              : _buildPredictionView(),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading prediction data...'),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text(
            'Error loading prediction data',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPredictionData,
            child: Text('Retry'),
          ),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: _testApiConnection,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: Text('Test API Connection'),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionView() {
    if (_predictionData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No prediction data available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Tap refresh to load prediction data'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPredictionData,
              child: Text('Load Prediction'),
            ),
          ],
        ),
      );
    }

    double rainProbability = (_predictionData!['rainProbability'] ?? 0).toDouble();
    double avgPrecipitation = (_predictionData!['avgPrecipitation'] ?? 0).toDouble();
    double avgTemperature = (_predictionData!['avgTemperature'] ?? 0).toDouble();
    double avgHumidity = (_predictionData!['avgHumidity'] ?? 0).toDouble();
    double avgWindSpeed = (_predictionData!['avgWindSpeed'] ?? 0).toDouble();

    print('Enhanced Prediction Screen - Rain Probability: $rainProbability%');
    print('Enhanced Prediction Screen - Avg Precipitation: $avgPrecipitation mm');
    print('Enhanced Prediction Screen - Avg Temperature: $avgTemperature°C');
    print('Enhanced Prediction Screen - Avg Humidity: $avgHumidity%');
    print('Enhanced Prediction Screen - Avg Wind Speed: $avgWindSpeed m/s');

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateSelector(),
          SizedBox(height: 16),
          _buildEnhancedPredictionCard(rainProbability, avgPrecipitation, avgTemperature, avgHumidity, avgWindSpeed),
          SizedBox(height: 16),
          _buildHistoricalChart(precipitationData, temperatureData),
          SizedBox(height: 16),
          _buildPredictionConfidence(rainProbability),
          SizedBox(height: 16),
          _buildDebugInfo(),
        ],
      ),
    );
  }

  Widget _buildEnhancedPredictionCard(double rainProbability, double avgPrecipitation, double avgTemperature, double avgHumidity, double avgWindSpeed) {
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
                  'Enhanced Rain Prediction',
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

  Widget _buildDateSelector() {
    bool isFutureDate = _selectedDate.isAfter(DateTime.now().subtract(Duration(days: 1)));

    return Card(
      elevation: 2,
      color: isFutureDate ? Colors.orange[50] : Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: isFutureDate ? Colors.orange : Colors.blue,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected Date: ${_selectedDate.toString().split(' ')[0]}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isFutureDate ? Colors.orange[800] : Colors.black,
                        ),
                      ),
                      if (isFutureDate)
                        Text(
                          'Future dates use trend-based predictions',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildMainPredictionCard(double rainProbability, double avgPrecipitation) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rain Prediction',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPredictionIndicator(
                    'Rain Probability',
                    rainProbability,
                    _getRainProbabilityColor(rainProbability),
                    '${rainProbability.toStringAsFixed(1)}%',
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildPredictionIndicator(
                    'Avg Precipitation',
                    (avgPrecipitation / 25.4) * 100, // Convert mm to inches for percentage
                    Colors.blue,
                    '${avgPrecipitation.toStringAsFixed(2)} mm',
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getRainProbabilityColor(rainProbability).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getRainProbabilityColor(rainProbability),
                  width: 1,
                ),
              ),
              child: Text(
                _getRainPredictionText(rainProbability),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _getRainProbabilityColor(rainProbability),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherConditionsCard(double avgTemperature, double avgHumidity) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weather Conditions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildConditionItem(
                    Icons.thermostat,
                    'Temperature',
                    '${avgTemperature.toStringAsFixed(1)}°C',
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildConditionItem(
                    Icons.water_drop,
                    'Humidity',
                    '${avgHumidity.toStringAsFixed(1)}%',
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoricalChart(List<double> precipitationData, List<double> temperatureData) {
    bool isFutureDate = _selectedDate.isAfter(DateTime.now().subtract(Duration(days: 1)));

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  isFutureDate ? 'Prediction Based on Historical Trends' : 'Historical Trends (Last 10 Years)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (isFutureDate)
                  Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(
                      Icons.trending_up,
                      size: 20,
                      color: Colors.orange,
                    ),
                  ),
              ],
            ),
            if (isFutureDate)
              Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'This prediction is based on historical patterns for this date',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      axisNameWidget: Text('Years Ago'),
                      axisNameSize: 16,
                    ),
                    leftTitles: AxisTitles(
                      axisNameWidget: Text('Values'),
                      axisNameSize: 16,
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _generatePrecipitationSpots(precipitationData),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.1),
                      ),
                    ),
                    // Only show temperature line if we have data
                    if (temperatureData.isNotEmpty)
                      LineChartBarData(
                        spots: _generateTemperatureSpots(temperatureData),
                        isCurved: true,
                        color: Colors.orange,
                        barWidth: 3,
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.orange.withOpacity(0.1),
                        ),
                      ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                          return LineTooltipItem(
                            '${barSpot.barIndex == 0 ? 'Precipitation: ' : 'Temperature: '}${barSpot.y.toStringAsFixed(1)}',
                            TextStyle(color: barSpot.bar.color),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(Colors.blue, 'Precipitation (mm)'),
                if (temperatureData.isNotEmpty) ...[
                  SizedBox(width: 16),
                  _buildLegendItem(Colors.orange, 'Temperature (°C)'),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionConfidence(double rainProbability) {
    bool isFutureDate = _selectedDate.isAfter(DateTime.now().subtract(Duration(days: 1)));

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Prediction Confidence',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (isFutureDate)
                  Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(
                      Icons.warning,
                      size: 18,
                      color: Colors.orange,
                    ),
                  ),
              ],
            ),
            if (isFutureDate)
              Padding(
                padding: EdgeInsets.only(top: 8.0, bottom: 16.0),
                child: Text(
                  'Future predictions have lower confidence due to uncertainty',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (!isFutureDate) ...[
              _buildConfidenceIndicator(
                'Rain Prediction Accuracy',
                min(rainProbability / 100, 1.0),
                _getRainProbabilityColor(rainProbability),
              ),
              SizedBox(height: 8),
            ],
            _buildConfidenceIndicator(
              'Data Coverage',
              precipitationData.isNotEmpty ? 0.9 : 0.3,
              precipitationData.isNotEmpty ? Colors.green : Colors.orange,
            ),
            SizedBox(height: 8),
            _buildConfidenceIndicator(
              'Historical Pattern Analysis',
              isFutureDate ? 0.6 : (temperatureData.isNotEmpty ? 0.85 : 0.7),
              isFutureDate ? Colors.orange : (temperatureData.isNotEmpty ? Colors.green : Colors.yellow),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionIndicator(String label, double value, Color color, String displayValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: value / 100,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              SizedBox(width: 8),
              Text(
                displayValue,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConditionItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildConfidenceIndicator(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        SizedBox(height: 4),
        LinearProgressIndicator(
          value: value,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
        SizedBox(height: 4),
        Text('${(value * 100).toInt()}%', style: TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12)),
      ],
    );
  }

  List<FlSpot> _generatePrecipitationSpots(List<double> data) {
    List<FlSpot> spots = [];
    for (int i = 0; i < min(data.length, 10); i++) {
      spots.add(FlSpot(i.toDouble(), data[i]));
    }
    return spots;
  }

  List<FlSpot> _generateTemperatureSpots(List<double> data) {
    List<FlSpot> spots = [];
    for (int i = 0; i < min(data.length, 10); i++) {
      spots.add(FlSpot(i.toDouble(), data[i]));
    }
    return spots;
  }

  Color _getRainProbabilityColor(double probability) {
    if (probability >= 70) return Colors.red;
    if (probability >= 40) return Colors.orange;
    if (probability >= 20) return Colors.yellow[700]!;
    return Colors.green;
  }

  String _getRainPredictionText(double probability) {
    if (probability >= 70) return 'High chance of rain - Carry an umbrella!';
    if (probability >= 40) return 'Moderate chance of rain - Be prepared';
    if (probability >= 20) return 'Low chance of rain - Mostly dry';
    return 'Very low chance of rain - Clear skies expected';
  }

  Widget _buildDebugInfo() {
    return Card(
      elevation: 2,
      color: Colors.grey[100],
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Debug Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
            SizedBox(height: 8),
            Text(
              'Rain Probability: ${(_predictionData!['rainProbability'] ?? 0).toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              'Avg Precipitation: ${(_predictionData!['avgPrecipitation'] ?? 0).toStringAsFixed(2)} mm',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              'Precipitation Data Points: ${precipitationData.length}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              'Temperature Data Points: ${temperatureData.length}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              'Selected Date: ${_selectedDate.toString().split(' ')[0]}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              'Selected Time: ${_selectedTime.format(context)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
