import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/nasa_api_service.dart';
import '../services/location_service.dart';
import 'dart:math';

class PredictionScreen extends StatefulWidget {
  @override
  _PredictionScreenState createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  Map<String, dynamic>? _predictionData;
  bool _isLoading = false;
  String? _error;
  DateTime _selectedDate = DateTime.now();
  List<double> precipitationData = [];
  List<double> temperatureData = [];

  @override
  void initState() {
    super.initState();
    _loadPredictionData();
  }

  Future<void> _loadPredictionData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get current location
      var position = await LocationService.getCurrentLocation();
      if (position == null) {
        throw Exception('Unable to get current location');
      }

      // Get prediction for selected date
      var data = await NasaApiService.getHistoricalData(
        latitude: position.latitude,
        longitude: position.longitude,
        year: _selectedDate.year,
        month: _selectedDate.month,
        day: _selectedDate.day,
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
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadPredictionData();
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
            icon: Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadPredictionData,
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

    print('Prediction Screen - Rain Probability: $rainProbability%');
    print('Prediction Screen - Avg Precipitation: $avgPrecipitation mm');
    print('Prediction Screen - Precipitation Data Length: ${precipitationData.length}');

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateSelector(),
          SizedBox(height: 16),
          _buildMainPredictionCard(rainProbability, avgPrecipitation),
          SizedBox(height: 16),
          // Show weather conditions card even with zero values for debugging
          _buildWeatherConditionsCard(avgTemperature, avgHumidity),
          SizedBox(height: 16),
          _buildHistoricalChart(precipitationData, temperatureData),
          SizedBox(height: 16),
          _buildPredictionConfidence(rainProbability),
          SizedBox(height: 16),
          _buildDebugInfo(), // Add debug information
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.blue),
            SizedBox(width: 12),
            Text(
              'Selected Date: ${_selectedDate.toString().split(' ')[0]}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Spacer(),
         /*   Text(
              'Tap calendar icon to change date',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),*/
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
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Historical Trends (Last 10 Years)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prediction Confidence',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildConfidenceIndicator(
              'Rain Prediction Accuracy',
              min(rainProbability / 100, 1.0),
              _getRainProbabilityColor(rainProbability),
            ),
            SizedBox(height: 8),
            _buildConfidenceIndicator(
              'Data Coverage',
              precipitationData.isNotEmpty ? 0.9 : 0.3,
              precipitationData.isNotEmpty ? Colors.green : Colors.orange,
            ),
            SizedBox(height: 8),
            _buildConfidenceIndicator(
              'Historical Data Quality',
              temperatureData.isNotEmpty ? 0.85 : 0.4,
              temperatureData.isNotEmpty ? Colors.green : Colors.orange,
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
          ],
        ),
      ),
    );
  }
}
