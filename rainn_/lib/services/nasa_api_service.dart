import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_service.dart';

class NasaApiService {
  static const String baseUrl = 'https://power.larc.nasa.gov/api/temporal/daily/point';

  // Test method to verify API connectivity
  static Future<bool> testApiConnection() async {
    try {
      // Try a simple API call first
      final testUrl = Uri.parse(
        'https://power.larc.nasa.gov/api/temporal/daily/point?parameters=PRECTOTCORR&'
        'community=RE&'
        'longitude=77.1025&'
        'latitude=28.7041&'
        'start=20230101&'
        'end=20230101&'
        'format=JSON'
      );

      print('Testing basic API connectivity with URL: $testUrl');

      final response = await http.get(testUrl).timeout(Duration(seconds: 10));

      print('Test response status: ${response.statusCode}');
      print('Test response body length: ${response.body.length}');
      print('Test response body: ${response.body}');

      if (response.statusCode == 200) {
        print('Basic API test successful!');
        return true;
      } else {
        print('Basic API test failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Basic API test failed with error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> getWeatherData({
    required double latitude,
    required double longitude,
    required int startDate,
    required int endDate,
  }) async {
    final url = Uri.parse(
      '$baseUrl?parameters=PRECTOTCORR,T2M,TS,T2M_MIN,T2M_MAX,RH2M,WS2M&'
      'community=RE&'
      'longitude=$longitude&'
      'latitude=$latitude&'
      'start=$startDate&'
      'end=$endDate&'
      'format=JSON'
    );

    print('API URL: $url');
    print('Location: $latitude, $longitude');
    print('Date range: $startDate to $endDate');

    try {
      final response = await http.get(url);

      print('Response status: ${response.statusCode}');
      print('Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('SUCCESS! Full API Response keys: ${data.keys.toList()}');
        print('Full response: $data');

        return data;
      } else {
        print('API Error Response: ${response.body}');
        throw Exception('Failed to load weather data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Network error: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> getHistoricalData({
    required double latitude,
    required double longitude,
    required int year,
    required int month,
    required int day,
    TimeOfDay? selectedTime,
  }) async {
    // Get 20 years of historical data for the same date
    List<Future<Map<String, dynamic>>> futures = [];

    for (int i = 0; i < 20; i++) {
      int historicalYear = year - i - 1;

      // Format date as integer YYYYMMDD for NASA API
      int startDate = int.parse('$historicalYear${month.toString().padLeft(2, '0')}${day.toString().padLeft(2, '0')}');

      // Calculate end date properly (3 days later)
      int endYear = historicalYear;
      int endMonth = month;
      int endDay = day + 2; // 3 days range

      // Handle month/year boundaries
      if (endDay > 28) { // Use 28 to be safe across all months
        endDay = endDay - 28;
        endMonth = endMonth + 1;
        if (endMonth > 12) {
          endMonth = 1;
          endYear = endYear + 1;
        }
      }

      int endDate = int.parse('$endYear${endMonth.toString().padLeft(2, '0')}${endDay.toString().padLeft(2, '0')}');

      print('Requesting data for year ${historicalYear}, date range: $startDate to $endDate');

      futures.add(getWeatherData(
        latitude: latitude,
        longitude: longitude,
        startDate: startDate,
        endDate: endDate,
      ));
    }

    try {
      List<Map<String, dynamic>> results = await Future.wait(futures);
      print('Got ${results.length} results from API calls');
      DateTime selectedDate = DateTime(year, month, day);
      return _processHistoricalData(results, selectedDate, selectedTime);
    } catch (e) {
      print('Error in getHistoricalData: $e');
      throw Exception('Failed to fetch historical data: $e');
    }
  }

  static Map<String, dynamic> _processHistoricalData(List<Map<String, dynamic>> data, DateTime selectedDate, [TimeOfDay? selectedTime]) {
    List<double> precipitationValues = [];
    List<double> temperatureValues = [];
    List<double> humidityValues = [];
    List<double> windSpeedValues = [];

    print('Processing ${data.length} years of historical data with enhanced parameters');

    for (var i = 0; i < data.length; i++) {
      var yearData = data[i];
      print('Year data $i: $yearData');

      try {
        var properties = yearData['properties'];
        if (properties == null) {
          print('No properties found in year data $i');
          continue;
        }

        var parameter = properties['parameter'];
        if (parameter == null) {
          print('No parameter found in year data $i');
          continue;
        }

        print('Parameter data for year $i: $parameter');

        // Extract precipitation data (PRECTOTCORR)
        if (parameter.containsKey('PRECTOTCORR')) {
          var precipData = parameter['PRECTOTCORR'];
          if (precipData is Map) {
            precipData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double precipValue = (value is int) ? value.toDouble() : value as double;
                precipitationValues.add(precipValue);
              }
            });
          }
        }

        // Extract temperature data (T2M - Temperature at 2 Meters)
        if (parameter.containsKey('T2M')) {
          var tempData = parameter['T2M'];
          if (tempData is Map) {
            tempData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double tempValue = (value is int) ? value.toDouble() : value as double;
                temperatureValues.add(tempValue);
              }
            });
          }
        }

        // Extract humidity data (RH2M - Relative Humidity at 2 Meters)
        if (parameter.containsKey('RH2M')) {
          var humidityData = parameter['RH2M'];
          if (humidityData is Map) {
            humidityData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double humidityValue = (value is int) ? value.toDouble() : value as double;
                humidityValues.add(humidityValue);
              }
            });
          }
        }

        // Extract wind speed data (WS2M - Wind Speed at 2 Meters)
        if (parameter.containsKey('WS2M')) {
          var windData = parameter['WS2M'];
          if (windData is Map) {
            windData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double windValue = (value is int) ? value.toDouble() : value as double;
                windSpeedValues.add(windValue);
              }
            });
          }
        }

      } catch (e) {
        print('Error processing year data $i: $e');
      }
    }

    print('Final results:');
    print('Precipitation values: ${precipitationValues.length} points');
    print('Temperature values: ${temperatureValues.length} points');
    print('Humidity values: ${humidityValues.length} points');
    print('Wind speed values: ${windSpeedValues.length} points');

    // Enhanced rain probability calculation using multiple factors
    double enhancedRainProbability = _calculateEnhancedRainProbability(
      precipitationValues,
      temperatureValues,
      humidityValues,
      windSpeedValues,
      selectedTime,
    );

    // Calculate averages
    double avgPrecipitation = precipitationValues.isNotEmpty
        ? precipitationValues.reduce((a, b) => a + b) / precipitationValues.length
        : 0.0;

    double avgTemperature = temperatureValues.isNotEmpty
        ? temperatureValues.reduce((a, b) => a + b) / temperatureValues.length
        : 0.0;

    double avgHumidity = humidityValues.isNotEmpty
        ? humidityValues.reduce((a, b) => a + b) / humidityValues.length
        : 0.0;

    double avgWindSpeed = windSpeedValues.isNotEmpty
        ? windSpeedValues.reduce((a, b) => a + b) / windSpeedValues.length
        : 0.0;

    print('Enhanced rain probability: $enhancedRainProbability%');
    print('Average precipitation: $avgPrecipitation mm');
    print('Average temperature: $avgTemperature°C');
    print('Average humidity: $avgHumidity%');
    print('Average wind speed: $avgWindSpeed m/s');

    // Calculate prediction confidence
    Map<String, dynamic> confidenceData = _calculatePredictionConfidence(
      precipitationValues,
      temperatureValues,
      humidityValues,
      windSpeedValues,
      selectedDate,
    );

    print('Prediction confidence: ${confidenceData['overall']}% (${confidenceData['level']})');

    return {
      'rainProbability': enhancedRainProbability,
      'baseRainProbability': precipitationValues.isNotEmpty
          ? (precipitationValues.where((p) => p > 1.0).length / precipitationValues.length) * 100.0
          : 0.0,
      'avgPrecipitation': avgPrecipitation,
      'avgTemperature': avgTemperature,
      'avgHumidity': avgHumidity,
      'avgWindSpeed': avgWindSpeed,
      'precipitationData': precipitationValues,
      'temperatureData': temperatureValues,
      'humidityData': humidityValues,
      'windSpeedData': windSpeedValues,
      'selectedTime': selectedTime != null ? {
        'hour': selectedTime.hour,
        'minute': selectedTime.minute,
      } : null,
      'confidence': confidenceData,
      'dataQuality': {
        'precipitation_years': precipitationValues.length,
        'temperature_years': temperatureValues.length,
        'humidity_years': humidityValues.length,
        'wind_years': windSpeedValues.length,
      },
    };
  }

  // Enhanced rain probability calculation using multiple weather factors
  static double _calculateEnhancedRainProbability(
    List<double> precipitation,
    List<double> temperature,
    List<double> humidity,
    List<double> windSpeed,
    TimeOfDay? selectedTime,
  ) {
    if (precipitation.isEmpty) return 0.0;

    // Base probability from precipitation data
    int rainyDays = precipitation.where((p) => p > 1.0).length;
    double baseProbability = (rainyDays / precipitation.length) * 100.0;

    // Weather factor adjustments
    double temperatureFactor = 0.0;
    double humidityFactor = 0.0;
    double windFactor = 0.0;

    if (temperature.isNotEmpty) {
      double avgTemp = temperature.reduce((a, b) => a + b) / temperature.length;
      // Lower temperatures tend to increase rain probability in many regions
      if (avgTemp < 15) {
        temperatureFactor = 5.0; // Increase probability for cold weather
      } else if (avgTemp > 30) {
        temperatureFactor = -3.0; // Decrease probability for very hot weather
      }
    }

    if (humidity.isNotEmpty) {
      double avgHumidity = humidity.reduce((a, b) => a + b) / humidity.length;
      // High humidity increases rain probability
      if (avgHumidity > 70) {
        humidityFactor = 8.0;
      } else if (avgHumidity > 50) {
        humidityFactor = 3.0;
      } else if (avgHumidity < 30) {
        humidityFactor = -5.0; // Low humidity decreases rain probability
      }
    }

    if (windSpeed.isNotEmpty) {
      double avgWindSpeed = windSpeed.reduce((a, b) => a + b) / windSpeed.length;
      // Moderate wind speeds can indicate changing weather patterns
      if (avgWindSpeed > 5 && avgWindSpeed < 15) {
        windFactor = 2.0; // Slight increase for moderate winds
      } else if (avgWindSpeed > 15) {
        windFactor = -2.0; // Strong winds might indicate different weather systems
      }
    }

    // Apply time-based adjustments
    double timeAdjustment = _calculateTimeAdjustment(selectedTime);

    // Combine all factors
    double enhancedProbability = baseProbability + temperatureFactor + humidityFactor + windFactor + timeAdjustment;

    // Ensure probability is within 0-100% range
    return max(0.0, min(100.0, enhancedProbability));
  }

  // Advanced confidence calculation based on data quality and consistency
  static Map<String, dynamic> _calculatePredictionConfidence(
    List<double> precipitation,
    List<double> temperature,
    List<double> humidity,
    List<double> windSpeed,
    DateTime selectedDate,
  ) {
    double overallConfidence = 100.0;
    List<String> confidenceFactors = [];
    List<String> lowConfidenceReasons = [];

    // Factor 1: Data availability (most important)
    int totalDataPoints = precipitation.length + temperature.length + humidity.length + windSpeed.length;
    int expectedDataPoints = 80; // 20 years * 4 data points per year

    if (totalDataPoints < 20) {
      overallConfidence -= 40;
      lowConfidenceReasons.add("Very limited historical data available");
      confidenceFactors.add("Data Availability: Critical");
    } else if (totalDataPoints < 40) {
      overallConfidence -= 20;
      lowConfidenceReasons.add("Limited historical data available");
      confidenceFactors.add("Data Availability: Low");
    } else if (totalDataPoints < 60) {
      overallConfidence -= 10;
      confidenceFactors.add("Data Availability: Moderate");
    } else {
      confidenceFactors.add("Data Availability: High");
    }

    // Factor 2: Data consistency
    if (precipitation.isNotEmpty) {
      double precipStdDev = _calculateStandardDeviation(precipitation);
      double precipMean = precipitation.reduce((a, b) => a + b) / precipitation.length;
      double precipCV = precipStdDev / precipMean; // Coefficient of variation

      if (precipCV > 1.5) {
        overallConfidence -= 15;
        lowConfidenceReasons.add("High variability in precipitation patterns");
        confidenceFactors.add("Pattern Consistency: Low");
      } else if (precipCV > 1.0) {
        overallConfidence -= 5;
        confidenceFactors.add("Pattern Consistency: Moderate");
      } else {
        confidenceFactors.add("Pattern Consistency: High");
      }
    }

    // Factor 3: Seasonal data quality
    int month = selectedDate.month;
    bool isExtremeSeason = month == 12 || month == 1 || month == 6 || month == 7; // Winter/Summer extremes

    if (isExtremeSeason && precipitation.length < 15) {
      overallConfidence -= 10;
      lowConfidenceReasons.add("Limited data for extreme season");
      confidenceFactors.add("Seasonal Data: Limited");
    } else {
      confidenceFactors.add("Seasonal Data: Adequate");
    }

    // Factor 4: Recent data availability (last 5 years more important)
    int currentYear = DateTime.now().year;
    int recentDataPoints = 0;

    // This would need actual date tracking to be fully accurate
    // For now, assume last 25% of data points are recent
    int recentThreshold = (precipitation.length * 0.25).toInt();
    if (precipitation.length >= recentThreshold) {
      confidenceFactors.add("Recent Data: Available");
    } else {
      overallConfidence -= 10;
      lowConfidenceReasons.add("Limited recent data for trend analysis");
      confidenceFactors.add("Recent Data: Limited");
    }

    // Factor 5: Parameter completeness
    int availableParameters = 0;
    if (precipitation.isNotEmpty) availableParameters++;
    if (temperature.isNotEmpty) availableParameters++;
    if (humidity.isNotEmpty) availableParameters++;
    if (windSpeed.isNotEmpty) availableParameters++;

    if (availableParameters < 2) {
      overallConfidence -= 20;
      lowConfidenceReasons.add("Missing key weather parameters");
      confidenceFactors.add("Parameter Completeness: Poor");
    } else if (availableParameters < 4) {
      overallConfidence -= 5;
      confidenceFactors.add("Parameter Completeness: Good");
    } else {
      confidenceFactors.add("Parameter Completeness: Excellent");
    }

    // Ensure confidence is within 0-100% range
    overallConfidence = max(0.0, min(100.0, overallConfidence));

    return {
      'overall': overallConfidence,
      'level': _getConfidenceLevel(overallConfidence),
      'factors': confidenceFactors,
      'low_confidence_reasons': lowConfidenceReasons,
      'data_quality_score': (totalDataPoints / expectedDataPoints * 100).clamp(0.0, 100.0),
    };
  }

  static double _calculateStandardDeviation(List<double> values) {
    if (values.isEmpty) return 0.0;

    double mean = values.reduce((a, b) => a + b) / values.length;
    double sumSquaredDiffs = values.map((value) => pow(value - mean, 2).toDouble()).reduce((a, b) => a + b);
    return sqrt(sumSquaredDiffs / values.length);
  }

  static String _getConfidenceLevel(double confidence) {
    if (confidence >= 80) return 'High';
    if (confidence >= 60) return 'Moderate';
    if (confidence >= 40) return 'Low';
    return 'Very Low';
  }

  static double _calculateTimeAdjustment(TimeOfDay? selectedTime) {
    if (selectedTime == null) return 0.0;

    int hour = selectedTime.hour;

    // More sophisticated time-based adjustments based on typical weather patterns
    if (hour >= 5 && hour < 11) {
      // Morning: Generally lower rain probability, but can vary by region
      return -3.0;
    } else if (hour >= 11 && hour < 17) {
      // Afternoon: Standard probability, often when thunderstorms occur
      return 2.0;
    } else if (hour >= 17 && hour < 21) {
      // Evening: Higher probability in many regions
      return 5.0;
    } else {
      // Night/Late night: Often highest probability for sustained rain
      return 8.0;
    }
  }

  // Apply time-based adjustments to make predictions more accurate for specific times of day
  static double _applyTimeBasedAdjustment(double baseProbability, TimeOfDay? selectedTime) {
    if (selectedTime == null) return baseProbability;

    int hour = selectedTime.hour;

    // Time-based probability adjustments based on typical weather patterns
    if (hour >= 6 && hour < 12) {
      // Morning: Slightly lower rain probability
      return max(0, baseProbability - 5);
    } else if (hour >= 12 && hour < 18) {
      // Afternoon: Standard probability
      return baseProbability;
    } else if (hour >= 18 && hour < 22) {
      // Evening: Slightly higher rain probability
      return min(100, baseProbability + 8);
    } else {
      // Night/Late night: Higher rain probability
      return min(100, baseProbability + 12);
    }
  }

  // Comprehensive debugging method for testing NASA API with 20 years of data
  static Future<Map<String, dynamic>> debugApiWithHistoricalData({
    required double latitude,
    required double longitude,
    int? specificYear,
    int? specificMonth,
    int? specificDay,
  }) async {
    print('=== NASA API DEBUG SESSION STARTED ===');
    print('Location: $latitude, $longitude');
    print('Using 20 years of historical data');

    // Use current date if not specified
    DateTime now = DateTime.now();
    int year = specificYear ?? now.year;
    int month = specificMonth ?? now.month;
    int day = specificDay ?? now.day;

    print('Testing date: $year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}');

    // Step 1: Test basic connectivity
    print('\n--- STEP 1: Testing basic API connectivity ---');
    bool isConnected = await testApiConnection();
    if (!isConnected) {
      return {
        'success': false,
        'error': 'Failed to connect to NASA API',
        'step': 'connectivity_test'
      };
    }
    print('✓ Basic connectivity test passed');

    // Step 2: Test single year data fetch
    print('\n--- STEP 2: Testing single year data fetch ---');
    try {
      int testStartDate = int.parse('${year-1}${month.toString().padLeft(2, '0')}${day.toString().padLeft(2, '0')}');
      int testEndDate = testStartDate + 2; // 3 days range

      Map<String, dynamic> singleYearData = await getWeatherData(
        latitude: latitude,
        longitude: longitude,
        startDate: testStartDate,
        endDate: testEndDate,
      );

      print('✓ Single year data fetch successful');
      print('Single year response keys: ${singleYearData.keys.toList()}');

      if (singleYearData.containsKey('properties')) {
        var properties = singleYearData['properties'];
        if (properties.containsKey('parameter')) {
          var parameters = properties['parameter'];
          print('Available parameters: ${parameters.keys.toList()}');
        }
      }
    } catch (e) {
      print('✗ Single year data fetch failed: $e');
      return {
        'success': false,
        'error': 'Single year data fetch failed: $e',
        'step': 'single_year_test'
      };
    }

    // Step 3: Test 20-year historical data fetch
    print('\n--- STEP 3: Testing 20-year historical data fetch ---');
    try {
      var stopwatch = Stopwatch()..start();
      Map<String, dynamic> historicalData = await getHistoricalData(
        latitude: latitude,
        longitude: longitude,
        year: year,
        month: month,
        day: day,
        selectedTime: TimeOfDay(hour: 12, minute: 0), // Noon
      );
      stopwatch.stop();

      print('✓ 20-year historical data fetch completed in ${stopwatch.elapsedMilliseconds}ms');
      print('Historical data keys: ${historicalData.keys.toList()}');

      // Detailed analysis of results
      if (historicalData.containsKey('precipitationData')) {
        List<dynamic> precipData = historicalData['precipitationData'];
        print('Total precipitation data points: ${precipData.length}');
        print('Sample precipitation values: ${precipData.take(5).toList()}');

        double avgPrecip = historicalData['avgPrecipitation'] ?? 0.0;
        double rainProb = historicalData['rainProbability'] ?? 0.0;

        print('Average precipitation: $avgPrecip mm');
        print('Rain probability: $rainProb%');

        // Count rainy days
        int rainyDays = precipData.where((p) => p > 1.0).length;
        print('Rainy days count: $rainyDays out of ${precipData.length}');
      }

      print('\n=== DEBUG SESSION COMPLETED SUCCESSFULLY ===');
      return {
        'success': true,
        'message': 'All tests passed successfully',
        'data': historicalData,
        'years_tested': 20,
        'total_data_points': historicalData['precipitationData']?.length ?? 0,
        'execution_time_ms': stopwatch.elapsedMilliseconds,
      };

    } catch (e) {
      print('✗ 20-year historical data fetch failed: $e');
      return {
        'success': false,
        'error': '20-year historical data fetch failed: $e',
        'step': 'historical_data_test'
      };
    }
  }

  // Method to run a quick test with default Delhi coordinates
  static Future<Map<String, dynamic>> quickDebugTest() async {
    print('Running quick debug test with Delhi coordinates...');
    return debugApiWithHistoricalData(
      latitude: 28.7041,
      longitude: 77.1025,
    );
  }

  // Test SharedPreferences functionality
  static Future<void> testSharedPreferences() async {
    print('=== TESTING SHARED PREFERENCES ===');
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Test 1: Save a test item
      String testKey = 'test_prediction';
      Map<String, dynamic> testRecord = {
        'id': 'test_001',
        'timestamp': DateTime.now().toIso8601String(),
        'location': {
          'latitude': 28.7041,
          'longitude': 77.1025,
          'address': 'Test Location',
        },
        'prediction': {
          'rainProbability': 75.0,
          'avgTemperature': 25.0,
        }
      };

      print('Test 1: Saving test item...');
      await prefs.setString(testKey, json.encode(testRecord));
      print('✓ Test item saved to SharedPreferences');

      // Test 2: Retrieve the test item
      print('Test 2: Retrieving test item...');
      String? retrieved = prefs.getString(testKey);
      if (retrieved != null) {
        Map<String, dynamic> decoded = json.decode(retrieved);
        print('✓ Test item retrieved successfully: ${decoded['id']}');
      } else {
        print('✗ Failed to retrieve test item');
      }

      // Test 3: Check history key
      print('Test 3: Checking history key...');
      List<String> historyItems = prefs.getStringList(_historyKey) ?? [];
      print('Current history items in SharedPreferences: ${historyItems.length}');

      // Test 4: Clean up test
      print('Test 4: Cleaning up test...');
      await prefs.remove(testKey);
      print('✓ Test cleanup completed');

      print('=== SHARED PREFERENCES TEST COMPLETED ===');
    } catch (e) {
      print('✗ SharedPreferences test failed: $e');
    }
  }

  // Simple test to save a prediction directly
  static Future<bool> saveTestPrediction() async {
    try {
      print('=== SAVING TEST PREDICTION ===');

      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Create a simple test prediction
      Map<String, dynamic> testPrediction = {
        'id': 'test_${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': DateTime.now().toIso8601String(),
        'location': {
          'latitude': 28.7041,
          'longitude': 77.1025,
          'address': 'Test Delhi Location',
        },
        'date': {
          'year': DateTime.now().year,
          'month': DateTime.now().month,
          'day': DateTime.now().day,
          'formatted': DateTime.now().toString().split(' ')[0],
        },
        'time': {
          'hour': TimeOfDay.now().hour,
          'minute': TimeOfDay.now().minute,
          'formatted': '${TimeOfDay.now().hour.toString().padLeft(2, '0')}:${TimeOfDay.now().minute.toString().padLeft(2, '0')}',
        },
        'prediction': {
          'rainProbability': 75.0,
          'avgTemperature': 25.0,
          'avgHumidity': 60.0,
          'avgWindSpeed': 5.0,
        }
      };

      print('Created test prediction: ${testPrediction['id']}');

      // Get existing history
      List<String> existingHistory = prefs.getStringList(_historyKey) ?? [];
      print('Existing history count: ${existingHistory.length}');

      // Add test prediction
      List<dynamic> historyList = [];
      if (existingHistory.isNotEmpty) {
        historyList = existingHistory.map((item) => json.decode(item)).toList();
      }
      historyList.insert(0, testPrediction);

      // Save back
      List<String> updatedHistory = historyList.map((item) => json.encode(item)).toList();
      await prefs.setStringList(_historyKey, updatedHistory);

      print('Test prediction saved successfully');
      print('Total items after save: ${updatedHistory.length}');

      // Verify
      List<String> verifyHistory = prefs.getStringList(_historyKey) ?? [];
      print('Verification count: ${verifyHistory.length}');

      if (verifyHistory.length > 0) {
        Map<String, dynamic> firstItem = json.decode(verifyHistory.first);
        print('First item: ${firstItem['id']} - ${firstItem['location']['address']}');
        return true;
      }

      return false;
    } catch (e) {
      print('Error saving test prediction: $e');
      return false;
    }
  }

  // Prediction History Management
  static const String _historyKey = 'prediction_history';
  static const int _maxHistoryItems = 50; // Keep only last 50 predictions

  // Save prediction to history
  static Future<void> savePredictionToHistory({
    required double latitude,
    required double longitude,
    required DateTime date,
    required TimeOfDay time,
    required Map<String, dynamic> predictionData,
  }) async {
    try {
      print('=== STARTING SAVE TO HISTORY ===');
      print('Location: $latitude, $longitude');
      print('Date: ${date.toString()}');
      print('Time: ${time.hour}:${time.minute}');
      print('Rain Probability: ${predictionData['rainProbability']}%');

      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Get location address for better display (with fallback)
      String locationAddress;
      try {
        locationAddress = await LocationService.getLocationAddress(latitude, longitude);
        print('Got location address: $locationAddress');
      } catch (e) {
        print('Error getting location address: $e');
        locationAddress = '$latitude, $longitude';
      }

      // Create prediction record (convert TimeOfDay to serializable format)
      Map<String, dynamic> predictionRecord = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          'address': locationAddress,
        },
        'date': {
          'year': date.year,
          'month': date.month,
          'day': date.day,
          'formatted': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        },
        'time': {
          'hour': time.hour,
          'minute': time.minute,
          'formatted': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
        },
        'prediction': predictionData,
      };

      print('Created prediction record with ID: ${predictionRecord['id']}');

      // Get existing history
      List<String> history = prefs.getStringList(_historyKey) ?? [];
      print('Existing history items in SharedPreferences: ${history.length}');

      // Add new prediction to the beginning
      List<dynamic> historyList = [];
      if (history.isNotEmpty) {
        try {
          historyList = history.map((item) => json.decode(item)).toList();
          print('Successfully parsed ${historyList.length} existing history items');
        } catch (e) {
          print('Error parsing existing history: $e');
          print('Resetting history due to parse error');
          historyList = [];
        }
      }

      // Add new prediction to the beginning
      historyList.insert(0, predictionRecord);
      print('Added new prediction. Total items now: ${historyList.length}');

      // Keep only the last N items
      if (historyList.length > _maxHistoryItems) {
        historyList = historyList.sublist(0, _maxHistoryItems);
        print('Trimmed history to $_maxHistoryItems items');
      }

      // Save back to SharedPreferences
      List<String> updatedHistory = historyList.map((item) => json.encode(item)).toList();
      print('About to save ${updatedHistory.length} items to SharedPreferences');
      print('Sample item: ${updatedHistory.first.substring(0, min(100, updatedHistory.first.length))}...');

      await prefs.setStringList(_historyKey, updatedHistory);
      print('prefs.setStringList() completed');

      // Immediate verification with detailed logging
      List<String> verifyHistory = prefs.getStringList(_historyKey) ?? [];
      print('IMMEDIATE VERIFICATION:');
      print('Key used: $_historyKey');
      print('Items retrieved: ${verifyHistory.length}');
      print('Expected items: ${updatedHistory.length}');

      if (verifyHistory.length != updatedHistory.length) {
        print('CRITICAL MISMATCH: Expected ${updatedHistory.length} items but got ${verifyHistory.length}');
      }

      if (verifyHistory.isNotEmpty) {
        try {
          Map<String, dynamic> firstItem = json.decode(verifyHistory.first);
          print('First item verification: ${firstItem['id']} - ${firstItem['location']['address']}');

          // Additional verification - check if our new item is actually there
          bool foundNewItem = verifyHistory.any((item) {
            try {
              Map<String, dynamic> decoded = json.decode(item);
              return decoded['id'] == predictionRecord['id'];
            } catch (e) {
              return false;
            }
          });
          print('New item found in storage: $foundNewItem');

          if (!foundNewItem) {
            print('CRITICAL: Our new item was not found in storage!');
            print('Looking for ID: ${predictionRecord['id']}');
          }
        } catch (e) {
          print('Error verifying first item: $e');
        }
      } else {
        print('CRITICAL: No items found in SharedPreferences after save!');
        print('This indicates the save operation failed');
      }

      print('=== SAVE TO HISTORY COMPLETED ===');
    } catch (e) {
      print('CRITICAL ERROR saving prediction to history: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  // Get prediction history
  static Future<List<Map<String, dynamic>>> getPredictionHistory() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> history = prefs.getStringList(_historyKey) ?? [];

      print('Loading prediction history from SharedPreferences');
      print('Raw history items in SharedPreferences: ${history.length}');

      if (history.isEmpty) {
        print('No history items found in SharedPreferences');
        return [];
      }

      // Parse history items
      List<Map<String, dynamic>> historyList = [];
      for (int i = 0; i < history.length; i++) {
        try {
          String item = history[i];
          print('Parsing history item $i: ${item.substring(0, min(100, item.length))}...');
          Map<String, dynamic> predictionRecord = json.decode(item);
          historyList.add(predictionRecord);
          print('Successfully parsed item $i: ${predictionRecord['id']} - ${predictionRecord['location']['address']}');
        } catch (e) {
          print('Error parsing history item $i: $e');
        }
      }

      // Sort by timestamp (newest first)
      historyList.sort((a, b) {
        DateTime aTime = DateTime.parse(a['timestamp']);
        DateTime bTime = DateTime.parse(b['timestamp']);
        return bTime.compareTo(aTime); // Newest first
      });

      print('Successfully loaded and parsed ${historyList.length} prediction history items');
      for (int i = 0; i < min(3, historyList.length); i++) {
        var item = historyList[i];
        print('Recent item ${i + 1}: ${item['location']['address']} - ${item['prediction']['rainProbability']}% rain - ${item['timestamp']}');
      }

      return historyList;
    } catch (e) {
      print('Error loading prediction history: $e');
      return [];
    }
  }

  // Clear prediction history
  static Future<void> clearPredictionHistory() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
      print('Prediction history cleared');
    } catch (e) {
      print('Error clearing prediction history: $e');
    }
  }

  // Get history statistics
  static Future<Map<String, dynamic>> getHistoryStatistics() async {
    List<Map<String, dynamic>> history = await getPredictionHistory();

    if (history.isEmpty) {
      return {
        'total_predictions': 0,
        'unique_locations': 0,
        'date_range': null,
        'avg_rain_probability': 0.0,
      };
    }

    // Calculate statistics
    Set<String> uniqueLocations = Set();
    double totalRainProbability = 0.0;
    DateTime? earliestDate;
    DateTime? latestDate;

    for (var record in history) {
      // Count unique locations
      String locationKey = '${record['location']['latitude']}_${record['location']['longitude']}';
      uniqueLocations.add(locationKey);

      // Sum rain probabilities
      double rainProb = record['prediction']['rainProbability'] ?? 0.0;
      totalRainProbability += rainProb;

      // Track date range
      DateTime recordDate = DateTime(
        record['date']['year'],
        record['date']['month'],
        record['date']['day'],
      );

      if (earliestDate == null || recordDate.isBefore(earliestDate)) {
        earliestDate = recordDate;
      }
      if (latestDate == null || recordDate.isAfter(latestDate)) {
        latestDate = recordDate;
      }
    }

    return {
      'total_predictions': history.length,
      'unique_locations': uniqueLocations.length,
      'date_range': earliestDate != null && latestDate != null
          ? '${earliestDate.toString().split(' ')[0]} to ${latestDate.toString().split(' ')[0]}'
          : null,
      'avg_rain_probability': history.isNotEmpty ? totalRainProbability / history.length : 0.0,
    };
  }
}
