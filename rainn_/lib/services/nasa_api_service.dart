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

      print('Requesting historical data for year ${historicalYear}, date range: $startDate to $endDate');

      futures.add(getWeatherData(
        latitude: latitude,
        longitude: longitude,
        startDate: startDate,
        endDate: endDate,
      ));
    }

    try {
      List<Map<String, dynamic>> results = await Future.wait(futures);
      print('Got ${results.length} historical results from API calls');
      DateTime selectedDate = DateTime(year, month, day);
      return _processHistoricalData(results, selectedDate, selectedTime);
    } catch (e) {
      print('Error in getHistoricalData: $e');
      throw Exception('Failed to fetch historical data: $e');
    }
  }

  // Get current year live data for more accurate predictions
  static Future<Map<String, dynamic>> getCurrentYearData({
    required double latitude,
    required double longitude,
    required int year,
    required int month,
    required int day,
  }) async {
    print('Fetching current year live data for year $year');

    // Format date as integer YYYYMMDD for NASA API
    int startDate = int.parse('$year${month.toString().padLeft(2, '0')}${day.toString().padLeft(2, '0')}');

    // Calculate end date properly (3 days later)
    int endYear = year;
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

    print('Current year date range: $startDate to $endDate');

    try {
      Map<String, dynamic> currentData = await getWeatherData(
        latitude: latitude,
        longitude: longitude,
        startDate: startDate,
        endDate: endDate,
      );

      print('Successfully fetched current year data');
      return currentData;
    } catch (e) {
      print('Error fetching current year data: $e');
      print('Continuing with historical data only');
      return {}; // Return empty map if current data fetch fails
    }
  }

  // Get very recent data (last 7 days) for ultra-accurate predictions
  static Future<Map<String, dynamic>> getVeryRecentData({
    required double latitude,
    required double longitude,
    int daysBack = 7,
  }) async {
    print('Fetching very recent data for the last $daysBack days');

    DateTime now = DateTime.now();
    DateTime startDate = now.subtract(Duration(days: daysBack));
    DateTime endDate = now;

    // Format dates for NASA API
    int startDateInt = int.parse('${startDate.year}${startDate.month.toString().padLeft(2, '0')}${startDate.day.toString().padLeft(2, '0')}');
    int endDateInt = int.parse('${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}');

    print('Recent data date range: $startDateInt to $endDateInt');

    try {
      Map<String, dynamic> recentData = await getWeatherData(
        latitude: latitude,
        longitude: longitude,
        startDate: startDateInt,
        endDate: endDateInt,
      );

      print('Successfully fetched very recent data');
      return recentData;
    } catch (e) {
      print('Error fetching very recent data: $e');
      print('Continuing without recent data');
      return {}; // Return empty map if recent data fetch fails
    }
  }

  // Get yesterday's specific data for maximum accuracy
  static Future<double?> getYesterdaysPrecipitation({
    required double latitude,
    required double longitude,
  }) async {
    print('Fetching yesterday\'s precipitation data');

    DateTime yesterday = DateTime.now().subtract(Duration(days: 1));

    // Format date for NASA API
    int startDate = int.parse('${yesterday.year}${yesterday.month.toString().padLeft(2, '0')}${yesterday.day.toString().padLeft(2, '0')}');
    int endDate = startDate; // Single day

    print('Yesterday\'s date: $startDate');

    try {
      Map<String, dynamic> yesterdayData = await getWeatherData(
        latitude: latitude,
        longitude: longitude,
        startDate: startDate,
        endDate: endDate,
      );

      // Extract yesterday's precipitation if available
      if (yesterdayData.containsKey('properties') &&
          yesterdayData['properties'].containsKey('parameter') &&
          yesterdayData['properties']['parameter'].containsKey('PRECTOTCORR')) {

        var precipData = yesterdayData['properties']['parameter']['PRECTOTCORR'];
        if (precipData is Map && precipData.isNotEmpty) {
          // Get the first (and likely only) value for yesterday
          var firstKey = precipData.keys.first;
          var value = precipData[firstKey];

          if (value != null && value != -999.0 && value != -999 && value >= 0.0) {
            double precipValue = (value is int) ? value.toDouble() : value as double;
            print('Yesterday\'s precipitation: ${precipValue.toStringAsFixed(2)} mm');
            return precipValue;
          }
        }
      }

      print('No valid precipitation data found for yesterday');
      return null;
    } catch (e) {
      print('Error fetching yesterday\'s data: $e');
      return null;
    }
  }

  // Get today's data if available (real-time data)
  static Future<Map<String, dynamic>?> getTodaysData({
    required double latitude,
    required double longitude,
  }) async {
    print('Fetching today\'s real-time data');

    DateTime today = DateTime.now();

    // Format date for NASA API
    int startDate = int.parse('${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}');
    int endDate = startDate; // Single day

    print('Today\'s date: $startDate');

    try {
      Map<String, dynamic> todayData = await getWeatherData(
        latitude: latitude,
        longitude: longitude,
        startDate: startDate,
        endDate: endDate,
      );

      // Check if we got valid data for today
      if (todayData.containsKey('properties') &&
          todayData['properties'].containsKey('parameter')) {

        var parameter = todayData['properties']['parameter'];
        bool hasValidData = false;

        // Check if any parameter has valid data
        parameter.forEach((paramName, paramData) {
          if (paramData is Map && paramData.isNotEmpty) {
            paramData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                hasValidData = true;
              }
            });
          }
        });

        if (hasValidData) {
          print('Successfully fetched today\'s real-time data');
          return todayData;
        } else {
          print('Today\'s data exists but contains no valid values');
          return null;
        }
      }

      print('No valid today\'s data available');
      return null;
    } catch (e) {
      print('Error fetching today\'s data: $e');
      return null;
    }
  }

  // Get ultra-recent data (last 3 days) for maximum accuracy
  static Future<Map<String, dynamic>> getUltraRecentData({
    required double latitude,
    required double longitude,
    int daysBack = 3,
  }) async {
    print('Fetching ultra-recent data for the last $daysBack days');

    DateTime now = DateTime.now();
    DateTime startDate = now.subtract(Duration(days: daysBack));
    DateTime endDate = now;

    // Format dates for NASA API
    int startDateInt = int.parse('${startDate.year}${startDate.month.toString().padLeft(2, '0')}${startDate.day.toString().padLeft(2, '0')}');
    int endDateInt = int.parse('${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}');

    print('Ultra-recent data date range: $startDateInt to $endDateInt');

    try {
      Map<String, dynamic> ultraRecentData = await getWeatherData(
        latitude: latitude,
        longitude: longitude,
        startDate: startDateInt,
        endDate: endDateInt,
      );

      print('Successfully fetched ultra-recent data');
      return ultraRecentData;
    } catch (e) {
      print('Error fetching ultra-recent data: $e');
      print('Continuing without ultra-recent data');
      return {}; // Return empty map if ultra-recent data fetch fails
    }
  }

  // Enhanced method that combines historical data with current year live data and recent data
  static Future<Map<String, dynamic>> getEnhancedWeatherData({
    required double latitude,
    required double longitude,
    required int year,
    required int month,
    required int day,
    TimeOfDay? selectedTime,
  }) async {
    print('=== FETCHING ULTRA-ENHANCED WEATHER DATA ===');
    print('Combining historical data with current year live data, ultra-recent data, and real-time data');

    // Check if the selected date is in the past (more than 1 day ago)
    DateTime selectedDate = DateTime(year, month, day);
    DateTime yesterday = DateTime.now().subtract(Duration(days: 1));
    bool isPastDate = selectedDate.isBefore(yesterday);

    print('Selected date: ${selectedDate.toString().split(' ')[0]}');
    print('Is past date: $isPastDate');

    // Step 1: Get historical data (20 years) - Always the primary source
    Map<String, dynamic> historicalResult = await getHistoricalData(
      latitude: latitude,
      longitude: longitude,
      year: year,
      month: month,
      day: day,
      selectedTime: selectedTime,
    );

    // Step 2: For past dates, use minimal recent data for context only
    // For recent dates, use recent data with appropriate weighting
    if (isPastDate) {
      print('Processing PAST DATE - Using historical data as primary source');

      // For past dates, only get current year data for the same historical period
      Map<String, dynamic> currentData = await getCurrentYearData(
        latitude: latitude,
        longitude: longitude,
        year: year,
        month: month,
        day: day,
      );

      // Process with minimal recent data influence
      return _processHistoricalDateData(
        historicalResult,
        currentData,
        selectedTime,
      );
    } else {
      print('Processing RECENT DATE - Using enhanced recent data weighting');

      // For recent dates, use all data sources with appropriate weighting
      Map<String, dynamic> currentData = await getCurrentYearData(
        latitude: latitude,
        longitude: longitude,
        year: year,
        month: month,
        day: day,
      );

      Map<String, dynamic> ultraRecentData = await getUltraRecentData(
        latitude: latitude,
        longitude: longitude,
        daysBack: 3,
      );

      Map<String, dynamic> recentData = await getVeryRecentData(
        latitude: latitude,
        longitude: longitude,
        daysBack: 7,
      );

      Map<String, dynamic>? todaysData = await getTodaysData(
        latitude: latitude,
        longitude: longitude,
      );

      double? yesterdaysPrecipitation = await getYesterdaysPrecipitation(
        latitude: latitude,
        longitude: longitude,
      );

      return _processUltraEnhancedDataWithRealTime(
        historicalResult,
        currentData,
        ultraRecentData,
        recentData,
        todaysData,
        yesterdaysPrecipitation,
        selectedTime,
      );
    }
  }

  // Process historical data for past dates with minimal recent data influence
  static Map<String, dynamic> _processHistoricalDateData(
    Map<String, dynamic> historicalResult,
    Map<String, dynamic> currentData,
    TimeOfDay? selectedTime,
  ) {
    print('=== PROCESSING HISTORICAL DATE DATA ===');
    print('Using historical data as primary source with minimal recent data influence');

    // Extract historical data (primary source)
    List<double> historicalPrecipitation = historicalResult['precipitationData'] ?? [];
    List<double> historicalTemperature = historicalResult['temperatureData'] ?? [];
    List<double> historicalHumidity = historicalResult['humidityData'] ?? [];
    List<double> historicalWindSpeed = historicalResult['windSpeedData'] ?? [];

    print('Historical data points (primary source):');
    print('- Precipitation: ${historicalPrecipitation.length}');
    print('- Temperature: ${historicalTemperature.length}');
    print('- Humidity: ${historicalHumidity.length}');
    print('- Wind Speed: ${historicalWindSpeed.length}');

    // Extract current year data for the same historical period (context only)
    List<double> currentPrecipitation = [];
    List<double> currentTemperature = [];
    List<double> currentHumidity = [];
    List<double> currentWindSpeed = [];

    if (currentData.isNotEmpty && currentData.containsKey('properties')) {
      var properties = currentData['properties'];
      if (properties != null && properties.containsKey('parameter')) {
        var parameter = properties['parameter'];

        // Extract current precipitation data (minimal influence)
        if (parameter.containsKey('PRECTOTCORR')) {
          var precipData = parameter['PRECTOTCORR'];
          if (precipData is Map) {
            precipData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999 && value >= 0.0 && value <= 100.0) {
                double precipValue = (value is int) ? value.toDouble() : value as double;
                if (precipValue <= 50.0) {
                  currentPrecipitation.add(precipValue);
                }
              }
            });
          }
        }

        // Extract current temperature data
        if (parameter.containsKey('T2M')) {
          var tempData = parameter['T2M'];
          if (tempData is Map) {
            tempData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double tempValue = (value is int) ? value.toDouble() : value as double;
                currentTemperature.add(tempValue);
              }
            });
          }
        }

        // Extract current humidity data
        if (parameter.containsKey('RH2M')) {
          var humidityData = parameter['RH2M'];
          if (humidityData is Map) {
            humidityData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double humidityValue = (value is int) ? value.toDouble() : value as double;
                currentHumidity.add(humidityValue);
              }
            });
          }
        }

        // Extract current wind speed data
        if (parameter.containsKey('WS2M')) {
          var windData = parameter['WS2M'];
          if (windData is Map) {
            windData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double windValue = (value is int) ? value.toDouble() : value as double;
                currentWindSpeed.add(windValue);
              }
            });
          }
        }

        print('Current year data points (context only):');
        print('- Precipitation: ${currentPrecipitation.length}');
        print('- Temperature: ${currentTemperature.length}');
        print('- Humidity: ${currentHumidity.length}');
        print('- Wind Speed: ${currentWindSpeed.length}');
      }
    }

    // For past dates, use historical data as primary source with minimal current year influence
    List<double> combinedPrecipitation = [];
    List<double> combinedTemperature = [];
    List<double> combinedHumidity = [];
    List<double> combinedWindSpeed = [];

    // STEP 1: HISTORICAL DATA - PRIMARY SOURCE (90% influence)
    if (historicalPrecipitation.isNotEmpty) {
      // Use most of the historical data for past date predictions
      int historicalSampleSize = min(historicalPrecipitation.length, 15); // Use up to 15 historical samples
      for (int i = 0; i < historicalSampleSize; i++) {
        combinedPrecipitation.add(historicalPrecipitation[i]);
      }
      print('Added $historicalSampleSize historical precipitation samples as primary source');
    }

    // STEP 2: CURRENT YEAR DATA - CONTEXT ONLY (10% influence)
    if (currentPrecipitation.isNotEmpty) {
      // Add only a small sample of current year data for context
      int contextSampleSize = min(currentPrecipitation.length, 3); // Very limited context
      for (int i = 0; i < contextSampleSize; i++) {
        combinedPrecipitation.add(currentPrecipitation[i]);
      }
      print('Added $contextSampleSize current year precipitation samples for context only');
    }

    // Apply similar conservative weighting for other parameters
    if (historicalTemperature.isNotEmpty) {
      int historicalSampleSize = min(historicalTemperature.length, 12);
      for (int i = 0; i < historicalSampleSize; i++) {
        combinedTemperature.add(historicalTemperature[i]);
      }
    }

    if (currentTemperature.isNotEmpty) {
      int contextSampleSize = min(currentTemperature.length, 2);
      for (int i = 0; i < contextSampleSize; i++) {
        combinedTemperature.add(currentTemperature[i]);
      }
    }

    if (historicalHumidity.isNotEmpty) {
      int historicalSampleSize = min(historicalHumidity.length, 12);
      for (int i = 0; i < historicalSampleSize; i++) {
        combinedHumidity.add(historicalHumidity[i]);
      }
    }

    if (currentHumidity.isNotEmpty) {
      int contextSampleSize = min(currentHumidity.length, 2);
      for (int i = 0; i < contextSampleSize; i++) {
        combinedHumidity.add(currentHumidity[i]);
      }
    }

    if (historicalWindSpeed.isNotEmpty) {
      int historicalSampleSize = min(historicalWindSpeed.length, 10);
      for (int i = 0; i < historicalSampleSize; i++) {
        combinedWindSpeed.add(historicalWindSpeed[i]);
      }
    }

    if (currentWindSpeed.isNotEmpty) {
      int contextSampleSize = min(currentWindSpeed.length, 2);
      for (int i = 0; i < contextSampleSize; i++) {
        combinedWindSpeed.add(currentWindSpeed[i]);
      }
    }

    print('Combined data points for historical date:');
    print('- Precipitation: ${combinedPrecipitation.length} (Historical: ${historicalPrecipitation.length}, Context: ${currentPrecipitation.length})');
    print('- Temperature: ${combinedTemperature.length}');
    print('- Humidity: ${combinedHumidity.length}');
    print('- Wind Speed: ${combinedWindSpeed.length}');

    // Analyze recent rain patterns for historical dates
    Map<String, dynamic> historicalRecentRainAnalysis = _analyzeHistoricalRecentRainPatterns(
      historicalPrecipitation,
      currentPrecipitation,
    );

    // Use enhanced probability calculation with historical recent rain awareness
    double rainProbability = calculateEnhancedRainProbabilityWithCurrentYearAwareness(
      combinedPrecipitation,
      combinedTemperature,
      combinedHumidity,
      combinedWindSpeed,
      selectedTime,
      historicalRecentRainAnalysis,
    );

    // Calculate averages from combined data
    double avgPrecipitation = combinedPrecipitation.isNotEmpty
        ? combinedPrecipitation.reduce((a, b) => a + b) / combinedPrecipitation.length
        : 0.0;

    double avgTemperature = combinedTemperature.isNotEmpty
        ? combinedTemperature.reduce((a, b) => a + b) / combinedTemperature.length
        : 0.0;

    double avgHumidity = combinedHumidity.isNotEmpty
        ? combinedHumidity.reduce((a, b) => a + b) / combinedHumidity.length
        : 0.0;

    double avgWindSpeed = combinedWindSpeed.isNotEmpty
        ? combinedWindSpeed.reduce((a, b) => a + b) / combinedWindSpeed.length
        : 0.0;

    print('Historical date rain probability: ${rainProbability.toStringAsFixed(2)}%');
    print('Average precipitation: ${avgPrecipitation.toStringAsFixed(2)} mm');
    print('Average temperature: ${avgTemperature.toStringAsFixed(2)}°C');
    print('Average humidity: ${avgHumidity.toStringAsFixed(2)}%');
    print('Average wind speed: ${avgWindSpeed.toStringAsFixed(2)} m/s');

    // Calculate prediction confidence for historical data
    Map<String, dynamic> confidenceData = _calculatePredictionConfidence(
      combinedPrecipitation,
      combinedTemperature,
      combinedHumidity,
      combinedWindSpeed,
      DateTime.now(), // Use current date for seasonal calculation
    );

    return {
      'rainProbability': rainProbability,
      'baseRainProbability': combinedPrecipitation.isNotEmpty
          ? (combinedPrecipitation.where((p) => p > 1.0).length / combinedPrecipitation.length) * 100.0
          : 0.0,
      'avgPrecipitation': avgPrecipitation,
      'avgTemperature': avgTemperature,
      'avgHumidity': avgHumidity,
      'avgWindSpeed': avgWindSpeed,
      'precipitationData': combinedPrecipitation,
      'temperatureData': combinedTemperature,
      'humidityData': combinedHumidity,
      'windSpeedData': combinedWindSpeed,
      'selectedTime': selectedTime != null ? {
        'hour': selectedTime.hour,
        'minute': selectedTime.minute,
      } : null,
      'confidence': confidenceData,
      'isHistoricalDate': true,
      'dataQuality': {
        'historical_data_primary': true,
        'current_year_data': currentPrecipitation.isNotEmpty,
        'current_year_context_only': currentPrecipitation.isNotEmpty,
        'historical_precipitation_points': historicalPrecipitation.length,
        'current_year_context_points': currentPrecipitation.length,
        'total_precipitation_years': combinedPrecipitation.length,
        'temperature_years': combinedTemperature.length,
        'humidity_years': combinedHumidity.length,
        'wind_years': combinedWindSpeed.length,
      },
      'data_sources': {
        'historical_years': 20,
        'current_year_context': currentData.isNotEmpty,
        'total_data_points': combinedPrecipitation.length + combinedTemperature.length + combinedHumidity.length + combinedWindSpeed.length,
        'historical_weight_multiplier': 90, // 90% historical data
        'current_year_context_multiplier': 10, // 10% current year context
      },
    };
  }

  // Process and combine all data sources for ultra-enhanced predictions with real-time data
  static Map<String, dynamic> _processUltraEnhancedDataWithRealTime(
    Map<String, dynamic> historicalResult,
    Map<String, dynamic> currentData,
    Map<String, dynamic> ultraRecentData,
    Map<String, dynamic> recentData,
    Map<String, dynamic>? todaysData,
    double? yesterdaysPrecipitation,
    TimeOfDay? selectedTime,
  ) {
    print('=== PROCESSING ULTRA-ENHANCED DATA WITH REAL-TIME SOURCES ===');
    print('Combining historical + current year + ultra-recent + recent + today\'s + yesterday data');

    // Extract historical data
    List<double> historicalPrecipitation = historicalResult['precipitationData'] ?? [];
    List<double> historicalTemperature = historicalResult['temperatureData'] ?? [];
    List<double> historicalHumidity = historicalResult['humidityData'] ?? [];
    List<double> historicalWindSpeed = historicalResult['windSpeedData'] ?? [];

    print('Historical data points:');
    print('- Precipitation: ${historicalPrecipitation.length}');
    print('- Temperature: ${historicalTemperature.length}');
    print('- Humidity: ${historicalHumidity.length}');
    print('- Wind Speed: ${historicalWindSpeed.length}');

    // Extract current year data if available
    List<double> currentPrecipitation = [];
    List<double> currentTemperature = [];
    List<double> currentHumidity = [];
    List<double> currentWindSpeed = [];

    if (currentData.isNotEmpty && currentData.containsKey('properties')) {
      var properties = currentData['properties'];
      if (properties != null && properties.containsKey('parameter')) {
        var parameter = properties['parameter'];

        // Extract current precipitation data
        if (parameter.containsKey('PRECTOTCORR')) {
          var precipData = parameter['PRECTOTCORR'];
          if (precipData is Map) {
            precipData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999 && value >= 0.0 && value <= 100.0) {
                double precipValue = (value is int) ? value.toDouble() : value as double;
                if (precipValue <= 50.0) {
                  currentPrecipitation.add(precipValue);
                }
              }
            });
          }
        }

        // Extract current temperature data
        if (parameter.containsKey('T2M')) {
          var tempData = parameter['T2M'];
          if (tempData is Map) {
            tempData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double tempValue = (value is int) ? value.toDouble() : value as double;
                currentTemperature.add(tempValue);
              }
            });
          }
        }

        // Extract current humidity data
        if (parameter.containsKey('RH2M')) {
          var humidityData = parameter['RH2M'];
          if (humidityData is Map) {
            humidityData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double humidityValue = (value is int) ? value.toDouble() : value as double;
                currentHumidity.add(humidityValue);
              }
            });
          }
        }

        // Extract current wind speed data
        if (parameter.containsKey('WS2M')) {
          var windData = parameter['WS2M'];
          if (windData is Map) {
            windData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double windValue = (value is int) ? value.toDouble() : value as double;
                currentWindSpeed.add(windValue);
              }
            });
          }
        }

        print('Current year data points:');
        print('- Precipitation: ${currentPrecipitation.length}');
        print('- Temperature: ${currentTemperature.length}');
        print('- Humidity: ${currentHumidity.length}');
        print('- Wind Speed: ${currentWindSpeed.length}');
      }
    }

    // Extract ultra-recent data (last 3 days) if available
    List<double> ultraRecentPrecipitation = [];
    List<double> ultraRecentTemperature = [];
    List<double> ultraRecentHumidity = [];
    List<double> ultraRecentWindSpeed = [];

    if (ultraRecentData.isNotEmpty && ultraRecentData.containsKey('properties')) {
      var properties = ultraRecentData['properties'];
      if (properties != null && properties.containsKey('parameter')) {
        var parameter = properties['parameter'];

        // Extract ultra-recent precipitation data
        if (parameter.containsKey('PRECTOTCORR')) {
          var precipData = parameter['PRECTOTCORR'];
          if (precipData is Map) {
            precipData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999 && value >= 0.0 && value <= 100.0) {
                double precipValue = (value is int) ? value.toDouble() : value as double;
                if (precipValue <= 50.0) {
                  ultraRecentPrecipitation.add(precipValue);
                }
              }
            });
          }
        }

        // Extract ultra-recent temperature data
        if (parameter.containsKey('T2M')) {
          var tempData = parameter['T2M'];
          if (tempData is Map) {
            tempData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double tempValue = (value is int) ? value.toDouble() : value as double;
                ultraRecentTemperature.add(tempValue);
              }
            });
          }
        }

        // Extract ultra-recent humidity data
        if (parameter.containsKey('RH2M')) {
          var humidityData = parameter['RH2M'];
          if (humidityData is Map) {
            humidityData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double humidityValue = (value is int) ? value.toDouble() : value as double;
                ultraRecentHumidity.add(humidityValue);
              }
            });
          }
        }

        // Extract ultra-recent wind speed data
        if (parameter.containsKey('WS2M')) {
          var windData = parameter['WS2M'];
          if (windData is Map) {
            windData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double windValue = (value is int) ? value.toDouble() : value as double;
                ultraRecentWindSpeed.add(windValue);
              }
            });
          }
        }

        print('Ultra-recent data points (last 3 days):');
        print('- Precipitation: ${ultraRecentPrecipitation.length}');
        print('- Temperature: ${ultraRecentTemperature.length}');
        print('- Humidity: ${ultraRecentHumidity.length}');
        print('- Wind Speed: ${ultraRecentWindSpeed.length}');
      }
    }

    // Extract very recent data (last 7 days) if available
    List<double> recentPrecipitation = [];
    List<double> recentTemperature = [];
    List<double> recentHumidity = [];
    List<double> recentWindSpeed = [];

    if (recentData.isNotEmpty && recentData.containsKey('properties')) {
      var properties = recentData['properties'];
      if (properties != null && properties.containsKey('parameter')) {
        var parameter = properties['parameter'];

        // Extract recent precipitation data
        if (parameter.containsKey('PRECTOTCORR')) {
          var precipData = parameter['PRECTOTCORR'];
          if (precipData is Map) {
            precipData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999 && value >= 0.0 && value <= 100.0) {
                double precipValue = (value is int) ? value.toDouble() : value as double;
                if (precipValue <= 50.0) {
                  recentPrecipitation.add(precipValue);
                }
              }
            });
          }
        }

        // Extract recent temperature data
        if (parameter.containsKey('T2M')) {
          var tempData = parameter['T2M'];
          if (tempData is Map) {
            tempData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double tempValue = (value is int) ? value.toDouble() : value as double;
                recentTemperature.add(tempValue);
              }
            });
          }
        }

        // Extract recent humidity data
        if (parameter.containsKey('RH2M')) {
          var humidityData = parameter['RH2M'];
          if (humidityData is Map) {
            humidityData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double humidityValue = (value is int) ? value.toDouble() : value as double;
                recentHumidity.add(humidityValue);
              }
            });
          }
        }

        // Extract recent wind speed data
        if (parameter.containsKey('WS2M')) {
          var windData = parameter['WS2M'];
          if (windData is Map) {
            windData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double windValue = (value is int) ? value.toDouble() : value as double;
                recentWindSpeed.add(windValue);
              }
            });
          }
        }

        print('Very recent data points (last 7 days):');
        print('- Precipitation: ${recentPrecipitation.length}');
        print('- Temperature: ${recentTemperature.length}');
        print('- Humidity: ${recentHumidity.length}');
        print('- Wind Speed: ${recentWindSpeed.length}');
      }
    }

    // Extract today's data if available (HIGHEST PRIORITY)
    List<double> todaysPrecipitation = [];
    List<double> todaysTemperature = [];
    List<double> todaysHumidity = [];
    List<double> todaysWindSpeed = [];

    if (todaysData != null && todaysData.containsKey('properties')) {
      var properties = todaysData['properties'];
      if (properties != null && properties.containsKey('parameter')) {
        var parameter = properties['parameter'];

        // Extract today's precipitation data
        if (parameter.containsKey('PRECTOTCORR')) {
          var precipData = parameter['PRECTOTCORR'];
          if (precipData is Map) {
            precipData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999 && value >= 0.0 && value <= 100.0) {
                double precipValue = (value is int) ? value.toDouble() : value as double;
                if (precipValue <= 50.0) {
                  todaysPrecipitation.add(precipValue);
                }
              }
            });
          }
        }

        // Extract today's temperature data
        if (parameter.containsKey('T2M')) {
          var tempData = parameter['T2M'];
          if (tempData is Map) {
            tempData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double tempValue = (value is int) ? value.toDouble() : value as double;
                todaysTemperature.add(tempValue);
              }
            });
          }
        }

        // Extract today's humidity data
        if (parameter.containsKey('RH2M')) {
          var humidityData = parameter['RH2M'];
          if (humidityData is Map) {
            humidityData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double humidityValue = (value is int) ? value.toDouble() : value as double;
                todaysHumidity.add(humidityValue);
              }
            });
          }
        }

        // Extract today's wind speed data
        if (parameter.containsKey('WS2M')) {
          var windData = parameter['WS2M'];
          if (windData is Map) {
            windData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double windValue = (value is int) ? value.toDouble() : value as double;
                todaysWindSpeed.add(windValue);
              }
            });
          }
        }

        print('Today\'s real-time data points:');
        print('- Precipitation: ${todaysPrecipitation.length}');
        print('- Temperature: ${todaysTemperature.length}');
        print('- Humidity: ${todaysHumidity.length}');
        print('- Wind Speed: ${todaysWindSpeed.length}');
      }
    }

    // Analyze current year precipitation patterns for recent rain detection
    Map<String, dynamic> currentYearAnalysis = _analyzeCurrentYearPatterns(currentPrecipitation);

    // Combine data with ULTRA-HIGH weight for very recent data
    List<double> combinedPrecipitation = [];
    List<double> combinedTemperature = [];
    List<double> combinedHumidity = [];
    List<double> combinedWindSpeed = [];

    // STEP 1: TODAY'S DATA - ABSOLUTE HIGHEST PRIORITY (if available)
    if (todaysPrecipitation.isNotEmpty) {
      // Add today's data 25 times for maximum influence (even more than yesterday)
      for (int i = 0; i < 25; i++) {
        combinedPrecipitation.addAll(todaysPrecipitation);
      }
      print('Added today\'s data 25x: ${todaysPrecipitation.length} points');
    }

    // STEP 2: YESTERDAY'S DATA - HIGHEST PRIORITY (if available)
    if (yesterdaysPrecipitation != null) {
      // Add yesterday's data 20 times for maximum influence
      for (int i = 0; i < 20; i++) {
        combinedPrecipitation.add(yesterdaysPrecipitation);
      }
      print('Added yesterday\'s data 20x: ${yesterdaysPrecipitation.toStringAsFixed(2)} mm');
    }

    // STEP 3: ULTRA-RECENT DATA (last 3 days) - VERY HIGH PRIORITY
    if (ultraRecentPrecipitation.isNotEmpty) {
      // Enhanced weighting for ultra-recent data
      String last3DaysTrend = _analyzeRecentTrend(ultraRecentPrecipitation)['trend'];
      int ultraRecentMultiplier = 15; // Base multiplier for ultra-recent data

      // Boost for increasing rain trends in ultra-recent data
      if (last3DaysTrend == 'increasing_rain') {
        ultraRecentMultiplier += 8;
      }

      for (int i = 0; i < ultraRecentMultiplier && i < ultraRecentPrecipitation.length; i++) {
        combinedPrecipitation.addAll(ultraRecentPrecipitation);
      }
      print('Added ultra-recent data ${ultraRecentMultiplier}x (trend: $last3DaysTrend)');
    }

    // STEP 4: VERY RECENT DATA (last 7 days) - HIGH PRIORITY
    if (recentPrecipitation.isNotEmpty) {
      // Enhanced weighting for very recent data
      String last7DaysTrend = currentYearAnalysis['last7DaysTrend'];
      int recentMultiplier = 12; // Base multiplier for recent data

      // Boost for increasing rain trends in recent data
      if (last7DaysTrend == 'increasing_rain') {
        recentMultiplier += 5;
      }

      for (int i = 0; i < recentMultiplier && i < recentPrecipitation.length; i++) {
        combinedPrecipitation.addAll(recentPrecipitation);
      }
      print('Added very recent data ${recentMultiplier}x (trend: $last7DaysTrend)');
    }

    // STEP 5: CURRENT YEAR DATA - HIGH PRIORITY
    if (currentPrecipitation.isNotEmpty) {
      // Enhanced weighting based on recent patterns
      String last7DaysTrend = currentYearAnalysis['last7DaysTrend'];
      double recentTrendScore = currentYearAnalysis['recentTrendScore'] ?? 0.0;
      double? yesterdaysData = currentYearAnalysis['yesterdaysData'];

      // Base multiplier with recent trend consideration
      int baseMultiplier = 5;
      if (currentYearAnalysis['hasRecentRain']) {
        baseMultiplier = 8;
      }

      // Boost multiplier for increasing rain trends
      if (last7DaysTrend == 'increasing_rain') {
        baseMultiplier += 3;
      }

      // Apply enhanced weighting
      int effectiveMultiplier = min(baseMultiplier, 15);

      for (int i = 0; i < effectiveMultiplier && i < currentPrecipitation.length; i++) {
        combinedPrecipitation.addAll(currentPrecipitation);
      }

      print('Enhanced current year precipitation weighting:');
      print('- Base multiplier: ${currentYearAnalysis['hasRecentRain'] ? 8 : 5}');
      print('- Trend boost: ${last7DaysTrend == 'increasing_rain' ? '+3' : '0'}');
      print('- Final multiplier: $effectiveMultiplier');
    }

    // STEP 6: HISTORICAL DATA - LOWER PRIORITY
    if (historicalPrecipitation.isNotEmpty) {
      int historicalSampleSize = currentYearAnalysis['hasRecentRain'] ? 6 : 10; // Even fewer if recent rain
      historicalSampleSize = min(historicalSampleSize, historicalPrecipitation.length);

      // Sample historical data more sparsely
      int stepSize = (historicalPrecipitation.length / historicalSampleSize).round();
      stepSize = max(1, stepSize);

      for (int i = 0; i < historicalPrecipitation.length && combinedPrecipitation.length < historicalSampleSize * 2; i += stepSize) {
        combinedPrecipitation.add(historicalPrecipitation[i]);
      }
      print('Added $historicalSampleSize historical precipitation samples (step: $stepSize)');
    }

    // Apply similar weighting for other parameters
    if (todaysTemperature.isNotEmpty) {
      for (int i = 0; i < 20 && i < todaysTemperature.length; i++) {
        combinedTemperature.addAll(todaysTemperature);
      }
    }

    if (ultraRecentTemperature.isNotEmpty) {
      for (int i = 0; i < 12 && i < ultraRecentTemperature.length; i++) {
        combinedTemperature.addAll(ultraRecentTemperature);
      }
    }

    if (recentTemperature.isNotEmpty) {
      for (int i = 0; i < 10 && i < recentTemperature.length; i++) {
        combinedTemperature.addAll(recentTemperature);
      }
    }

    if (currentTemperature.isNotEmpty) {
      int currentYearMultiplier = currentYearAnalysis['hasRecentRain'] ? 6 : 4;
      for (int i = 0; i < currentYearMultiplier && i < currentTemperature.length; i++) {
        combinedTemperature.addAll(currentTemperature);
      }
    }

    if (historicalTemperature.isNotEmpty) {
      int historicalSampleSize = min(8, historicalTemperature.length);
      for (int i = 0; i < historicalSampleSize; i++) {
        combinedTemperature.add(historicalTemperature[i]);
      }
    }

    // Apply similar weighting for humidity
    if (todaysHumidity.isNotEmpty) {
      for (int i = 0; i < 20 && i < todaysHumidity.length; i++) {
        combinedHumidity.addAll(todaysHumidity);
      }
    }

    if (ultraRecentHumidity.isNotEmpty) {
      for (int i = 0; i < 12 && i < ultraRecentHumidity.length; i++) {
        combinedHumidity.addAll(ultraRecentHumidity);
      }
    }

    if (recentHumidity.isNotEmpty) {
      for (int i = 0; i < 10 && i < recentHumidity.length; i++) {
        combinedHumidity.addAll(recentHumidity);
      }
    }

    if (currentHumidity.isNotEmpty) {
      int currentYearMultiplier = currentYearAnalysis['hasRecentRain'] ? 6 : 4;
      for (int i = 0; i < currentYearMultiplier && i < currentHumidity.length; i++) {
        combinedHumidity.addAll(currentHumidity);
      }
    }

    if (historicalHumidity.isNotEmpty) {
      int historicalSampleSize = min(8, historicalHumidity.length);
      for (int i = 0; i < historicalSampleSize; i++) {
        combinedHumidity.add(historicalHumidity[i]);
      }
    }

    // Apply similar weighting for wind speed
    if (todaysWindSpeed.isNotEmpty) {
      for (int i = 0; i < 15 && i < todaysWindSpeed.length; i++) {
        combinedWindSpeed.addAll(todaysWindSpeed);
      }
    }

    if (ultraRecentWindSpeed.isNotEmpty) {
      for (int i = 0; i < 10 && i < ultraRecentWindSpeed.length; i++) {
        combinedWindSpeed.addAll(ultraRecentWindSpeed);
      }
    }

    if (recentWindSpeed.isNotEmpty) {
      for (int i = 0; i < 8 && i < recentWindSpeed.length; i++) {
        combinedWindSpeed.addAll(recentWindSpeed);
      }
    }

    if (currentWindSpeed.isNotEmpty) {
      int currentYearMultiplier = currentYearAnalysis['hasRecentRain'] ? 5 : 3;
      for (int i = 0; i < currentYearMultiplier && i < currentWindSpeed.length; i++) {
        combinedWindSpeed.addAll(currentWindSpeed);
      }
    }

    if (historicalWindSpeed.isNotEmpty) {
      int historicalSampleSize = min(6, historicalWindSpeed.length);
      for (int i = 0; i < historicalSampleSize; i++) {
        combinedWindSpeed.add(historicalWindSpeed[i]);
      }
    }

    print('Combined data points after ultra-enhanced weighting:');
    print('- Precipitation: ${combinedPrecipitation.length}');
    print('- Temperature: ${combinedTemperature.length}');
    print('- Humidity: ${combinedHumidity.length}');
    print('- Wind Speed: ${combinedWindSpeed.length}');

    // Use enhanced probability calculation with current year awareness
    double enhancedRainProbability = calculateEnhancedRainProbabilityWithCurrentYearAwareness(
      combinedPrecipitation,
      combinedTemperature,
      combinedHumidity,
      combinedWindSpeed,
      selectedTime,
      currentYearAnalysis,
    );

    // Calculate averages from combined data
    double avgPrecipitation = combinedPrecipitation.isNotEmpty
        ? combinedPrecipitation.reduce((a, b) => a + b) / combinedPrecipitation.length
        : 0.0;

    double avgTemperature = combinedTemperature.isNotEmpty
        ? combinedTemperature.reduce((a, b) => a + b) / combinedTemperature.length
        : 0.0;

    double avgHumidity = combinedHumidity.isNotEmpty
        ? combinedHumidity.reduce((a, b) => a + b) / combinedHumidity.length
        : 0.0;

    double avgWindSpeed = combinedWindSpeed.isNotEmpty
        ? combinedWindSpeed.reduce((a, b) => a + b) / combinedWindSpeed.length
        : 0.0;

    print('Ultra-enhanced rain probability: ${enhancedRainProbability.toStringAsFixed(2)}%');
    print('Average precipitation: ${avgPrecipitation.toStringAsFixed(2)} mm');
    print('Average temperature: ${avgTemperature.toStringAsFixed(2)}°C');
    print('Average humidity: ${avgHumidity.toStringAsFixed(2)}%');
    print('Average wind speed: ${avgWindSpeed.toStringAsFixed(2)} m/s');

    // Calculate prediction confidence with current year consideration
    Map<String, dynamic> confidenceData = _calculateEnhancedPredictionConfidence(
      combinedPrecipitation,
      combinedTemperature,
      combinedHumidity,
      combinedWindSpeed,
      currentPrecipitation,
    );

    return {
      'rainProbability': enhancedRainProbability,
      'baseRainProbability': combinedPrecipitation.isNotEmpty
          ? (combinedPrecipitation.where((p) => p > 1.0).length / combinedPrecipitation.length) * 100.0
          : 0.0,
      'avgPrecipitation': avgPrecipitation,
      'avgTemperature': avgTemperature,
      'avgHumidity': avgHumidity,
      'avgWindSpeed': avgWindSpeed,
      'precipitationData': combinedPrecipitation,
      'temperatureData': combinedTemperature,
      'humidityData': combinedHumidity,
      'windSpeedData': combinedWindSpeed,
      'selectedTime': selectedTime != null ? {
        'hour': selectedTime.hour,
        'minute': selectedTime.minute,
      } : null,
      'confidence': confidenceData,
      'currentYearAnalysis': currentYearAnalysis,
      'yesterdaysPrecipitation': yesterdaysPrecipitation,
      'todaysDataAvailable': todaysData != null,
      'ultraRecentDataAvailable': ultraRecentData.isNotEmpty,
      'dataQuality': {
        'current_year_data': currentPrecipitation.isNotEmpty,
        'ultra_recent_data_available': ultraRecentPrecipitation.isNotEmpty,
        'recent_data_available': recentPrecipitation.isNotEmpty,
        'todays_data_available': todaysPrecipitation.isNotEmpty,
        'yesterdays_data_available': yesterdaysPrecipitation != null,
        'current_precipitation_points': currentPrecipitation.length,
        'ultra_recent_precipitation_points': ultraRecentPrecipitation.length,
        'recent_precipitation_points': recentPrecipitation.length,
        'todays_precipitation_points': todaysPrecipitation.length,
        'historical_precipitation_points': historicalPrecipitation.length,
        'total_precipitation_years': combinedPrecipitation.length,
        'temperature_years': combinedTemperature.length,
        'humidity_years': combinedHumidity.length,
        'wind_years': combinedWindSpeed.length,
        'recent_rain_detected': currentYearAnalysis['hasRecentRain'],
      },
      'data_sources': {
        'current_year_available': currentData.isNotEmpty,
        'ultra_recent_available': ultraRecentData.isNotEmpty,
        'recent_data_available': recentData.isNotEmpty,
        'todays_data_available': todaysData != null,
        'yesterdays_data_available': yesterdaysPrecipitation != null,
        'historical_years': 20,
        'total_data_points': combinedPrecipitation.length + combinedTemperature.length + combinedHumidity.length + combinedWindSpeed.length,
        'current_year_weight_multiplier': currentYearAnalysis['hasRecentRain'] ? 8 : 5,
        'ultra_recent_weight_multiplier': ultraRecentPrecipitation.isNotEmpty ? 15 : 0,
        'recent_data_weight_multiplier': recentPrecipitation.isNotEmpty ? 12 : 0,
        'todays_data_weight_multiplier': todaysPrecipitation.isNotEmpty ? 25 : 0,
        'yesterdays_data_weight_multiplier': yesterdaysPrecipitation != null ? 20 : 0,
      },
    };
  }

  // Process and combine all data sources for ultra-enhanced predictions
  static Map<String, dynamic> _processUltraEnhancedData(
    Map<String, dynamic> historicalResult,
    Map<String, dynamic> currentData,
    Map<String, dynamic> recentData,
    double? yesterdaysPrecipitation,
    TimeOfDay? selectedTime,
  ) {
    print('=== PROCESSING ULTRA-ENHANCED DATA ===');
    print('Combining historical + current year + very recent + yesterday data');

    // Extract historical data
    List<double> historicalPrecipitation = historicalResult['precipitationData'] ?? [];
    List<double> historicalTemperature = historicalResult['temperatureData'] ?? [];
    List<double> historicalHumidity = historicalResult['humidityData'] ?? [];
    List<double> historicalWindSpeed = historicalResult['windSpeedData'] ?? [];

    print('Historical data points:');
    print('- Precipitation: ${historicalPrecipitation.length}');
    print('- Temperature: ${historicalTemperature.length}');
    print('- Humidity: ${historicalHumidity.length}');
    print('- Wind Speed: ${historicalWindSpeed.length}');

    // Extract current year data if available
    List<double> currentPrecipitation = [];
    List<double> currentTemperature = [];
    List<double> currentHumidity = [];
    List<double> currentWindSpeed = [];

    if (currentData.isNotEmpty && currentData.containsKey('properties')) {
      var properties = currentData['properties'];
      if (properties != null && properties.containsKey('parameter')) {
        var parameter = properties['parameter'];

        // Extract current precipitation data
        if (parameter.containsKey('PRECTOTCORR')) {
          var precipData = parameter['PRECTOTCORR'];
          if (precipData is Map) {
            precipData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999 && value >= 0.0 && value <= 100.0) {
                double precipValue = (value is int) ? value.toDouble() : value as double;
                if (precipValue <= 50.0) {
                  currentPrecipitation.add(precipValue);
                }
              }
            });
          }
        }

        // Extract current temperature data
        if (parameter.containsKey('T2M')) {
          var tempData = parameter['T2M'];
          if (tempData is Map) {
            tempData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double tempValue = (value is int) ? value.toDouble() : value as double;
                currentTemperature.add(tempValue);
              }
            });
          }
        }

        // Extract current humidity data
        if (parameter.containsKey('RH2M')) {
          var humidityData = parameter['RH2M'];
          if (humidityData is Map) {
            humidityData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double humidityValue = (value is int) ? value.toDouble() : value as double;
                currentHumidity.add(humidityValue);
              }
            });
          }
        }

        // Extract current wind speed data
        if (parameter.containsKey('WS2M')) {
          var windData = parameter['WS2M'];
          if (windData is Map) {
            windData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double windValue = (value is int) ? value.toDouble() : value as double;
                currentWindSpeed.add(windValue);
              }
            });
          }
        }

        print('Current year data points:');
        print('- Precipitation: ${currentPrecipitation.length}');
        print('- Temperature: ${currentTemperature.length}');
        print('- Humidity: ${currentHumidity.length}');
        print('- Wind Speed: ${currentWindSpeed.length}');
      }
    }

    // Extract very recent data (last 7 days) if available
    List<double> recentPrecipitation = [];
    List<double> recentTemperature = [];
    List<double> recentHumidity = [];
    List<double> recentWindSpeed = [];

    if (recentData.isNotEmpty && recentData.containsKey('properties')) {
      var properties = recentData['properties'];
      if (properties != null && properties.containsKey('parameter')) {
        var parameter = properties['parameter'];

        // Extract recent precipitation data
        if (parameter.containsKey('PRECTOTCORR')) {
          var precipData = parameter['PRECTOTCORR'];
          if (precipData is Map) {
            precipData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999 && value >= 0.0 && value <= 100.0) {
                double precipValue = (value is int) ? value.toDouble() : value as double;
                if (precipValue <= 50.0) {
                  recentPrecipitation.add(precipValue);
                }
              }
            });
          }
        }

        // Extract recent temperature data
        if (parameter.containsKey('T2M')) {
          var tempData = parameter['T2M'];
          if (tempData is Map) {
            tempData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double tempValue = (value is int) ? value.toDouble() : value as double;
                recentTemperature.add(tempValue);
              }
            });
          }
        }

        // Extract recent humidity data
        if (parameter.containsKey('RH2M')) {
          var humidityData = parameter['RH2M'];
          if (humidityData is Map) {
            humidityData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double humidityValue = (value is int) ? value.toDouble() : value as double;
                recentHumidity.add(humidityValue);
              }
            });
          }
        }

        // Extract recent wind speed data
        if (parameter.containsKey('WS2M')) {
          var windData = parameter['WS2M'];
          if (windData is Map) {
            windData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double windValue = (value is int) ? value.toDouble() : value as double;
                recentWindSpeed.add(windValue);
              }
            });
          }
        }

        print('Very recent data points (last 7 days):');
        print('- Precipitation: ${recentPrecipitation.length}');
        print('- Temperature: ${recentTemperature.length}');
        print('- Humidity: ${recentHumidity.length}');
        print('- Wind Speed: ${recentWindSpeed.length}');
      }
    }

    // Analyze current year precipitation patterns for recent rain detection
    Map<String, dynamic> currentYearAnalysis = _analyzeCurrentYearPatterns(currentPrecipitation);

    // Combine data with ULTRA-HIGH weight for very recent data
    List<double> combinedPrecipitation = [];
    List<double> combinedTemperature = [];
    List<double> combinedHumidity = [];
    List<double> combinedWindSpeed = [];

    // STEP 1: YESTERDAY'S DATA - HIGHEST PRIORITY (if available)
    if (yesterdaysPrecipitation != null) {
      // Add yesterday's data 20 times for maximum influence
      for (int i = 0; i < 20; i++) {
        combinedPrecipitation.add(yesterdaysPrecipitation);
      }
      print('Added yesterday\'s data 20x: ${yesterdaysPrecipitation.toStringAsFixed(2)} mm');
    }

    // STEP 2: VERY RECENT DATA (last 7 days) - SECOND HIGHEST PRIORITY
    if (recentPrecipitation.isNotEmpty) {
      // Enhanced weighting for very recent data
      String last7DaysTrend = currentYearAnalysis['last7DaysTrend'];
      int recentMultiplier = 12; // Base multiplier for recent data

      // Boost for increasing rain trends in recent data
      if (last7DaysTrend == 'increasing_rain') {
        recentMultiplier += 5;
      }

      for (int i = 0; i < recentMultiplier && i < recentPrecipitation.length; i++) {
        combinedPrecipitation.addAll(recentPrecipitation);
      }
      print('Added very recent data ${recentMultiplier}x (trend: $last7DaysTrend)');
    }

    // STEP 3: CURRENT YEAR DATA - HIGH PRIORITY
    if (currentPrecipitation.isNotEmpty) {
      // Enhanced weighting based on recent patterns
      String last7DaysTrend = currentYearAnalysis['last7DaysTrend'];
      double recentTrendScore = currentYearAnalysis['recentTrendScore'] ?? 0.0;
      double? yesterdaysData = currentYearAnalysis['yesterdaysData'];

      // Base multiplier with recent trend consideration
      int baseMultiplier = 5;
      if (currentYearAnalysis['hasRecentRain']) {
        baseMultiplier = 8;
      }

      // Boost multiplier for increasing rain trends
      if (last7DaysTrend == 'increasing_rain') {
        baseMultiplier += 3;
      }

      // Apply enhanced weighting
      int effectiveMultiplier = min(baseMultiplier, 15);

      for (int i = 0; i < effectiveMultiplier && i < currentPrecipitation.length; i++) {
        combinedPrecipitation.addAll(currentPrecipitation);
      }

      print('Enhanced current year precipitation weighting:');
      print('- Base multiplier: ${currentYearAnalysis['hasRecentRain'] ? 8 : 5}');
      print('- Trend boost: ${last7DaysTrend == 'increasing_rain' ? '+3' : '0'}');
      print('- Final multiplier: $effectiveMultiplier');
    }

    // STEP 4: HISTORICAL DATA - LOWER PRIORITY
    if (historicalPrecipitation.isNotEmpty) {
      int historicalSampleSize = currentYearAnalysis['hasRecentRain'] ? 6 : 10; // Even fewer if recent rain
      historicalSampleSize = min(historicalSampleSize, historicalPrecipitation.length);

      // Sample historical data more sparsely
      int stepSize = (historicalPrecipitation.length / historicalSampleSize).round();
      stepSize = max(1, stepSize);

      for (int i = 0; i < historicalPrecipitation.length && combinedPrecipitation.length < historicalSampleSize * 2; i += stepSize) {
        combinedPrecipitation.add(historicalPrecipitation[i]);
      }
      print('Added $historicalSampleSize historical precipitation samples (step: $stepSize)');
    }

    // Apply similar weighting for other parameters
    if (recentTemperature.isNotEmpty) {
      for (int i = 0; i < 10 && i < recentTemperature.length; i++) {
        combinedTemperature.addAll(recentTemperature);
      }
    }

    if (currentTemperature.isNotEmpty) {
      int currentYearMultiplier = currentYearAnalysis['hasRecentRain'] ? 6 : 4;
      for (int i = 0; i < currentYearMultiplier && i < currentTemperature.length; i++) {
        combinedTemperature.addAll(currentTemperature);
      }
    }

    if (historicalTemperature.isNotEmpty) {
      int historicalSampleSize = min(8, historicalTemperature.length);
      for (int i = 0; i < historicalSampleSize; i++) {
        combinedTemperature.add(historicalTemperature[i]);
      }
    }

    // Apply similar weighting for humidity
    if (recentHumidity.isNotEmpty) {
      for (int i = 0; i < 10 && i < recentHumidity.length; i++) {
        combinedHumidity.addAll(recentHumidity);
      }
    }

    if (currentHumidity.isNotEmpty) {
      int currentYearMultiplier = currentYearAnalysis['hasRecentRain'] ? 6 : 4;
      for (int i = 0; i < currentYearMultiplier && i < currentHumidity.length; i++) {
        combinedHumidity.addAll(currentHumidity);
      }
    }

    if (historicalHumidity.isNotEmpty) {
      int historicalSampleSize = min(8, historicalHumidity.length);
      for (int i = 0; i < historicalSampleSize; i++) {
        combinedHumidity.add(historicalHumidity[i]);
      }
    }

    // Apply similar weighting for wind speed
    if (recentWindSpeed.isNotEmpty) {
      for (int i = 0; i < 8 && i < recentWindSpeed.length; i++) {
        combinedWindSpeed.addAll(recentWindSpeed);
      }
    }

    if (currentWindSpeed.isNotEmpty) {
      int currentYearMultiplier = currentYearAnalysis['hasRecentRain'] ? 5 : 3;
      for (int i = 0; i < currentYearMultiplier && i < currentWindSpeed.length; i++) {
        combinedWindSpeed.addAll(currentWindSpeed);
      }
    }

    if (historicalWindSpeed.isNotEmpty) {
      int historicalSampleSize = min(6, historicalWindSpeed.length);
      for (int i = 0; i < historicalSampleSize; i++) {
        combinedWindSpeed.add(historicalWindSpeed[i]);
      }
    }

    print('Combined data points after ultra-enhanced weighting:');
    print('- Precipitation: ${combinedPrecipitation.length}');
    print('- Temperature: ${combinedTemperature.length}');
    print('- Humidity: ${combinedHumidity.length}');
    print('- Wind Speed: ${combinedWindSpeed.length}');

    // Use enhanced probability calculation with current year awareness
    double enhancedRainProbability = calculateEnhancedRainProbabilityWithCurrentYearAwareness(
      combinedPrecipitation,
      combinedTemperature,
      combinedHumidity,
      combinedWindSpeed,
      selectedTime,
      currentYearAnalysis,
    );

    // Calculate averages from combined data
    double avgPrecipitation = combinedPrecipitation.isNotEmpty
        ? combinedPrecipitation.reduce((a, b) => a + b) / combinedPrecipitation.length
        : 0.0;

    double avgTemperature = combinedTemperature.isNotEmpty
        ? combinedTemperature.reduce((a, b) => a + b) / combinedTemperature.length
        : 0.0;

    double avgHumidity = combinedHumidity.isNotEmpty
        ? combinedHumidity.reduce((a, b) => a + b) / combinedHumidity.length
        : 0.0;

    double avgWindSpeed = combinedWindSpeed.isNotEmpty
        ? combinedWindSpeed.reduce((a, b) => a + b) / combinedWindSpeed.length
        : 0.0;

    print('Ultra-enhanced rain probability: ${enhancedRainProbability.toStringAsFixed(2)}%');
    print('Average precipitation: ${avgPrecipitation.toStringAsFixed(2)} mm');
    print('Average temperature: ${avgTemperature.toStringAsFixed(2)}°C');
    print('Average humidity: ${avgHumidity.toStringAsFixed(2)}%');
    print('Average wind speed: ${avgWindSpeed.toStringAsFixed(2)} m/s');

    // Calculate prediction confidence with current year consideration
    Map<String, dynamic> confidenceData = _calculateEnhancedPredictionConfidence(
      combinedPrecipitation,
      combinedTemperature,
      combinedHumidity,
      combinedWindSpeed,
      currentPrecipitation,
    );

    return {
      'rainProbability': enhancedRainProbability,
      'baseRainProbability': combinedPrecipitation.isNotEmpty
          ? (combinedPrecipitation.where((p) => p > 1.0).length / combinedPrecipitation.length) * 100.0
          : 0.0,
      'avgPrecipitation': avgPrecipitation,
      'avgTemperature': avgTemperature,
      'avgHumidity': avgHumidity,
      'avgWindSpeed': avgWindSpeed,
      'precipitationData': combinedPrecipitation,
      'temperatureData': combinedTemperature,
      'humidityData': combinedHumidity,
      'windSpeedData': combinedWindSpeed,
      'selectedTime': selectedTime != null ? {
        'hour': selectedTime.hour,
        'minute': selectedTime.minute,
      } : null,
      'confidence': confidenceData,
      'currentYearAnalysis': currentYearAnalysis,
      'yesterdaysPrecipitation': yesterdaysPrecipitation,
      'dataQuality': {
        'current_year_data': currentPrecipitation.isNotEmpty,
        'recent_data_available': recentPrecipitation.isNotEmpty,
        'yesterdays_data_available': yesterdaysPrecipitation != null,
        'current_precipitation_points': currentPrecipitation.length,
        'recent_precipitation_points': recentPrecipitation.length,
        'historical_precipitation_points': historicalPrecipitation.length,
        'total_precipitation_years': combinedPrecipitation.length,
        'temperature_years': combinedTemperature.length,
        'humidity_years': combinedHumidity.length,
        'wind_years': combinedWindSpeed.length,
        'recent_rain_detected': currentYearAnalysis['hasRecentRain'],
      },
      'data_sources': {
        'current_year_available': currentData.isNotEmpty,
        'recent_data_available': recentData.isNotEmpty,
        'yesterdays_data_available': yesterdaysPrecipitation != null,
        'historical_years': 20,
        'total_data_points': combinedPrecipitation.length + combinedTemperature.length + combinedHumidity.length + combinedWindSpeed.length,
        'current_year_weight_multiplier': currentYearAnalysis['hasRecentRain'] ? 8 : 5,
        'recent_data_weight_multiplier': recentPrecipitation.isNotEmpty ? 12 : 0,
        'yesterdays_data_weight_multiplier': yesterdaysPrecipitation != null ? 20 : 0,
      },
    };
  }

  // Process and combine historical data with current year data
  static Map<String, dynamic> _processEnhancedData(
    Map<String, dynamic> historicalResult,
    Map<String, dynamic> currentData,
    TimeOfDay? selectedTime,
  ) {
    print('=== PROCESSING ENHANCED DATA ===');

    // Extract historical data
    List<double> historicalPrecipitation = historicalResult['precipitationData'] ?? [];
    List<double> historicalTemperature = historicalResult['temperatureData'] ?? [];
    List<double> historicalHumidity = historicalResult['humidityData'] ?? [];
    List<double> historicalWindSpeed = historicalResult['windSpeedData'] ?? [];

    print('Historical data points:');
    print('- Precipitation: ${historicalPrecipitation.length}');
    print('- Temperature: ${historicalTemperature.length}');
    print('- Humidity: ${historicalHumidity.length}');
    print('- Wind Speed: ${historicalWindSpeed.length}');

    // Extract current year data if available
    List<double> currentPrecipitation = [];
    List<double> currentTemperature = [];
    List<double> currentHumidity = [];
    List<double> currentWindSpeed = [];

    if (currentData.isNotEmpty && currentData.containsKey('properties')) {
      var properties = currentData['properties'];
      if (properties != null && properties.containsKey('parameter')) {
        var parameter = properties['parameter'];

        // Extract current precipitation data
        if (parameter.containsKey('PRECTOTCORR')) {
          var precipData = parameter['PRECTOTCORR'];
          if (precipData is Map) {
            precipData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999 && value >= 0.0 && value <= 100.0) {
                double precipValue = (value is int) ? value.toDouble() : value as double;
                if (precipValue <= 50.0) {
                  currentPrecipitation.add(precipValue);
                }
              }
            });
          }
        }

        // Extract current temperature data
        if (parameter.containsKey('T2M')) {
          var tempData = parameter['T2M'];
          if (tempData is Map) {
            tempData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double tempValue = (value is int) ? value.toDouble() : value as double;
                currentTemperature.add(tempValue);
              }
            });
          }
        }

        // Extract current humidity data
        if (parameter.containsKey('RH2M')) {
          var humidityData = parameter['RH2M'];
          if (humidityData is Map) {
            humidityData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double humidityValue = (value is int) ? value.toDouble() : value as double;
                currentHumidity.add(humidityValue);
              }
            });
          }
        }

        // Extract current wind speed data
        if (parameter.containsKey('WS2M')) {
          var windData = parameter['WS2M'];
          if (windData is Map) {
            windData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999) {
                double windValue = (value is int) ? value.toDouble() : value as double;
                currentWindSpeed.add(windValue);
              }
            });
          }
        }

        print('Current year data points:');
        print('- Precipitation: ${currentPrecipitation.length}');
        print('- Temperature: ${currentTemperature.length}');
        print('- Humidity: ${currentHumidity.length}');
        print('- Wind Speed: ${currentWindSpeed.length}');
      }
    }

    // Analyze current year precipitation patterns for recent rain detection
    Map<String, dynamic> currentYearAnalysis = _analyzeCurrentYearPatterns(currentPrecipitation);

    // Combine data with MUCH higher weight for current year (especially if recent rain detected)
    List<double> combinedPrecipitation = [];
    List<double> combinedTemperature = [];
    List<double> combinedHumidity = [];
    List<double> combinedWindSpeed = [];

    // Prioritize current year data heavily with enhanced recent data weighting
    if (currentPrecipitation.isNotEmpty) {
      // Enhanced weighting based on recent patterns
      String last7DaysTrend = currentYearAnalysis['last7DaysTrend'];
      double recentTrendScore = currentYearAnalysis['recentTrendScore'] ?? 0.0;
      double? yesterdaysData = currentYearAnalysis['yesterdaysData'];

      // Base multiplier with recent trend consideration
      int baseMultiplier = 5;
      if (currentYearAnalysis['hasRecentRain']) {
        baseMultiplier = 8;
      }

      // Boost multiplier for increasing rain trends
      if (last7DaysTrend == 'increasing_rain') {
        baseMultiplier += 3;
      }

      // Extra boost for yesterday's rain
      if (yesterdaysData != null && yesterdaysData > 2.0) {
        baseMultiplier += 4; // Significant boost for recent heavy rain
      } else if (yesterdaysData != null && yesterdaysData > 0.5) {
        baseMultiplier += 2; // Moderate boost for recent light rain
      }

      // Apply enhanced weighting with diminishing returns for older data
      int effectiveMultiplier = min(baseMultiplier, 15); // Cap at 15x to prevent over-weighting

      for (int i = 0; i < effectiveMultiplier && i < currentPrecipitation.length; i++) {
        combinedPrecipitation.addAll(currentPrecipitation);
      }

      print('Enhanced current year precipitation weighting:');
      print('- Base multiplier: ${currentYearAnalysis['hasRecentRain'] ? 8 : 5}');
      print('- Trend boost: ${last7DaysTrend == 'increasing_rain' ? '+3' : '0'}');
      print('- Yesterday boost: ${yesterdaysData != null && yesterdaysData > 0.5 ? '+${yesterdaysData > 2.0 ? 4 : 2}' : '0'}');
      print('- Final multiplier: $effectiveMultiplier');
      print('- Reason: ${currentYearAnalysis['hasRecentRain'] ? 'recent rain' : 'no recent rain'}, $last7DaysTrend trend');
    }

    if (currentTemperature.isNotEmpty) {
      int currentYearMultiplier = currentYearAnalysis['hasRecentRain'] ? 6 : 4;
      for (int i = 0; i < currentYearMultiplier && i < currentTemperature.length; i++) {
        combinedTemperature.addAll(currentTemperature);
      }
    }

    if (currentHumidity.isNotEmpty) {
      int currentYearMultiplier = currentYearAnalysis['hasRecentRain'] ? 6 : 4;
      for (int i = 0; i < currentYearMultiplier && i < currentHumidity.length; i++) {
        combinedHumidity.addAll(currentHumidity);
      }
    }

    if (currentWindSpeed.isNotEmpty) {
      int currentYearMultiplier = currentYearAnalysis['hasRecentRain'] ? 6 : 4;
      for (int i = 0; i < currentYearMultiplier && i < currentWindSpeed.length; i++) {
        combinedWindSpeed.addAll(currentWindSpeed);
      }
    }

    // Add historical data with significantly reduced weight
    if (historicalPrecipitation.isNotEmpty) {
      int historicalSampleSize = currentYearAnalysis['hasRecentRain'] ? 8 : 12; // Even fewer if recent rain
      historicalSampleSize = min(historicalSampleSize, historicalPrecipitation.length);

      // Sample historical data more sparsely
      int stepSize = (historicalPrecipitation.length / historicalSampleSize).round();
      stepSize = max(1, stepSize);

      for (int i = 0; i < historicalPrecipitation.length && combinedPrecipitation.length < historicalSampleSize * 3; i += stepSize) {
        combinedPrecipitation.add(historicalPrecipitation[i]);
      }
      print('Added $historicalSampleSize historical precipitation samples (step: $stepSize)');
    }

    if (historicalTemperature.isNotEmpty) {
      int historicalSampleSize = min(10, historicalTemperature.length);
      for (int i = 0; i < historicalSampleSize; i++) {
        combinedTemperature.add(historicalTemperature[i]);
      }
    }

    if (historicalHumidity.isNotEmpty) {
      int historicalSampleSize = min(10, historicalHumidity.length);
      for (int i = 0; i < historicalSampleSize; i++) {
        combinedHumidity.add(historicalHumidity[i]);
      }
    }

    if (historicalWindSpeed.isNotEmpty) {
      int historicalSampleSize = min(10, historicalWindSpeed.length);
      for (int i = 0; i < historicalSampleSize; i++) {
        combinedWindSpeed.add(historicalWindSpeed[i]);
      }
    }

    print('Combined data points after enhanced weighting:');
    print('- Precipitation: ${combinedPrecipitation.length}');
    print('- Temperature: ${combinedTemperature.length}');
    print('- Humidity: ${combinedHumidity.length}');
    print('- Wind Speed: ${combinedWindSpeed.length}');

    // Use enhanced probability calculation with current year awareness
    double enhancedRainProbability = calculateEnhancedRainProbabilityWithCurrentYearAwareness(
      combinedPrecipitation,
      combinedTemperature,
      combinedHumidity,
      combinedWindSpeed,
      selectedTime,
      currentYearAnalysis,
    );

    // Calculate averages from combined data
    double avgPrecipitation = combinedPrecipitation.isNotEmpty
        ? combinedPrecipitation.reduce((a, b) => a + b) / combinedPrecipitation.length
        : 0.0;

    double avgTemperature = combinedTemperature.isNotEmpty
        ? combinedTemperature.reduce((a, b) => a + b) / combinedTemperature.length
        : 0.0;

    double avgHumidity = combinedHumidity.isNotEmpty
        ? combinedHumidity.reduce((a, b) => a + b) / combinedHumidity.length
        : 0.0;

    double avgWindSpeed = combinedWindSpeed.isNotEmpty
        ? combinedWindSpeed.reduce((a, b) => a + b) / combinedWindSpeed.length
        : 0.0;

    print('Enhanced rain probability with current year awareness: ${enhancedRainProbability.toStringAsFixed(2)}%');
    print('Average precipitation: ${avgPrecipitation.toStringAsFixed(2)} mm');
    print('Average temperature: ${avgTemperature.toStringAsFixed(2)}°C');
    print('Average humidity: ${avgHumidity.toStringAsFixed(2)}%');
    print('Average wind speed: ${avgWindSpeed.toStringAsFixed(2)} m/s');

    // Calculate prediction confidence with current year consideration
    Map<String, dynamic> confidenceData = _calculateEnhancedPredictionConfidence(
      combinedPrecipitation,
      combinedTemperature,
      combinedHumidity,
      combinedWindSpeed,
      currentPrecipitation,
    );

    return {
      'rainProbability': enhancedRainProbability,
      'baseRainProbability': combinedPrecipitation.isNotEmpty
          ? (combinedPrecipitation.where((p) => p > 1.0).length / combinedPrecipitation.length) * 100.0
          : 0.0,
      'avgPrecipitation': avgPrecipitation,
      'avgTemperature': avgTemperature,
      'avgHumidity': avgHumidity,
      'avgWindSpeed': avgWindSpeed,
      'precipitationData': combinedPrecipitation,
      'temperatureData': combinedTemperature,
      'humidityData': combinedHumidity,
      'windSpeedData': combinedWindSpeed,
      'selectedTime': selectedTime != null ? {
        'hour': selectedTime.hour,
        'minute': selectedTime.minute,
      } : null,
      'confidence': confidenceData,
      'currentYearAnalysis': currentYearAnalysis,
      'dataQuality': {
        'current_year_data': currentPrecipitation.isNotEmpty,
        'current_precipitation_points': currentPrecipitation.length,
        'historical_precipitation_points': historicalPrecipitation.length,
        'total_precipitation_years': combinedPrecipitation.length,
        'temperature_years': combinedTemperature.length,
        'humidity_years': combinedHumidity.length,
        'wind_years': combinedWindSpeed.length,
        'recent_rain_detected': currentYearAnalysis['hasRecentRain'],
      },
      'data_sources': {
        'current_year_available': currentData.isNotEmpty,
        'historical_years': 20,
        'total_data_points': combinedPrecipitation.length + combinedTemperature.length + combinedHumidity.length + combinedWindSpeed.length,
        'current_year_weight_multiplier': currentYearAnalysis['hasRecentRain'] ? 8 : 5,
      },
    };
  }

  // Analyze current year patterns to detect recent rain with enhanced recent data priority
  static Map<String, dynamic> _analyzeCurrentYearPatterns(List<double> currentPrecipitation) {
    if (currentPrecipitation.isEmpty) {
      return {
        'hasRecentRain': false,
        'recentRainScore': 0.0,
        'maxRecentPrecipitation': 0.0,
        'avgRecentPrecipitation': 0.0,
        'recentRainyDays': 0,
        'yesterdaysData': null,
        'last7DaysTrend': 'no_data',
        'recentTrendScore': 0.0,
      };
    }

    double maxPrecip = currentPrecipitation.reduce((a, b) => a > b ? a : b);
    double avgPrecip = currentPrecipitation.reduce((a, b) => a + b) / currentPrecipitation.length;
    int recentRainyDays = currentPrecipitation.where((p) => p > 1.0).length;
    int significantRainyDays = currentPrecipitation.where((p) => p > 3.0).length;

    // Enhanced recent data analysis - prioritize last 7 days if available
    Map<String, dynamic> recentTrend = _analyzeRecentTrend(currentPrecipitation);

    // Calculate yesterday's data specifically (if available)
    double? yesterdaysData = _getYesterdaysData(currentPrecipitation);

    // Calculate recent rain score (0-100, higher = more recent rain)
    double recentRainScore = 0.0;

    // Factor 1: Significant rain days in current year
    if (significantRainyDays > 0) {
      recentRainScore += 40.0;
    } else if (recentRainyDays > 0) {
      recentRainScore += 25.0;
    }

    // Factor 2: High maximum precipitation
    if (maxPrecip > 10.0) {
      recentRainScore += 30.0;
    } else if (maxPrecip > 5.0) {
      recentRainScore += 20.0;
    } else if (maxPrecip > 2.0) {
      recentRainScore += 10.0;
    }

    // Factor 3: Above average precipitation
    if (avgPrecip > 2.0) {
      recentRainScore += 25.0;
    } else if (avgPrecip > 1.0) {
      recentRainScore += 15.0;
    }

    // Factor 4: Rain frequency
    double rainFrequency = recentRainyDays / currentPrecipitation.length;
    recentRainScore += rainFrequency * 20.0; // Up to 20 points for frequency

    // Factor 5: Recent trend boost (last 7 days)
    String last7DaysTrend = recentTrend['trend'];
    double recentTrendScore = recentTrend['score'];
    if (last7DaysTrend == 'increasing_rain') {
      recentRainScore += 15.0; // Boost for increasing rain trend
    } else if (last7DaysTrend == 'decreasing_rain') {
      recentRainScore -= 10.0; // Reduce for decreasing rain trend
    }

    // Factor 6: Yesterday's specific data
    if (yesterdaysData != null && yesterdaysData > 2.0) {
      recentRainScore += 20.0; // Significant boost for recent rain yesterday
    } else if (yesterdaysData != null && yesterdaysData > 0.5) {
      recentRainScore += 10.0; // Moderate boost for light rain yesterday
    }

    bool hasRecentRain = recentRainScore > 25.0; // Lower threshold for recent rain detection

    print('Enhanced Current Year Analysis:');
    print('- Recent Rain Score: ${recentRainScore.toStringAsFixed(2)}');
    print('- Has Recent Rain: $hasRecentRain');
    print('- Max Precipitation: ${maxPrecip.toStringAsFixed(2)} mm');
    print('- Avg Precipitation: ${avgPrecip.toStringAsFixed(2)} mm');
    print('- Rainy Days: $recentRainyDays/${currentPrecipitation.length}');
    print('- Last 7 Days Trend: $last7DaysTrend (Score: ${recentTrendScore.toStringAsFixed(2)})');
    print('- Yesterday\'s Data: ${yesterdaysData?.toStringAsFixed(2) ?? 'Not available'} mm');

    return {
      'hasRecentRain': hasRecentRain,
      'recentRainScore': recentRainScore,
      'maxRecentPrecipitation': maxPrecip,
      'avgRecentPrecipitation': avgPrecip,
      'recentRainyDays': recentRainyDays,
      'significantRainyDays': significantRainyDays,
      'rainFrequency': rainFrequency,
      'yesterdaysData': yesterdaysData,
      'last7DaysTrend': last7DaysTrend,
      'recentTrendScore': recentTrendScore,
    };
  }

  // Analyze recent trend in the last 7 days
  static Map<String, dynamic> _analyzeRecentTrend(List<double> precipitationData) {
    if (precipitationData.length < 3) {
      return {
        'trend': 'insufficient_data',
        'score': 0.0,
        'avgRecent': 0.0,
      };
    }

    // Get last 7 days or available recent data
    int recentDays = min(7, precipitationData.length);
    List<double> recentData = precipitationData.sublist(precipitationData.length - recentDays);

    double avgRecent = recentData.reduce((a, b) => a + b) / recentData.length;
    double maxRecent = recentData.reduce((a, b) => a > b ? a : b);

    // Calculate trend (comparing first half vs second half of recent period)
    int midPoint = (recentDays / 2).floor();
    List<double> firstHalf = recentData.sublist(0, midPoint);
    List<double> secondHalf = recentData.sublist(midPoint);

    double avgFirstHalf = firstHalf.isNotEmpty ? firstHalf.reduce((a, b) => a + b) / firstHalf.length : 0.0;
    double avgSecondHalf = secondHalf.isNotEmpty ? secondHalf.reduce((a, b) => a + b) / secondHalf.length : 0.0;

    String trend = 'stable';
    double trendScore = 0.0;

    if (avgSecondHalf > avgFirstHalf * 1.5) {
      trend = 'increasing_rain';
      trendScore = (avgSecondHalf - avgFirstHalf) / avgFirstHalf; // Normalized trend strength
    } else if (avgFirstHalf > avgSecondHalf * 1.5) {
      trend = 'decreasing_rain';
      trendScore = (avgFirstHalf - avgSecondHalf) / avgFirstHalf; // Normalized trend strength
    }

    print('Recent Trend Analysis (${recentDays} days):');
    print('- Trend: $trend');
    print('- Trend Score: ${trendScore.toStringAsFixed(3)}');
    print('- Avg Recent: ${avgRecent.toStringAsFixed(2)} mm');
    print('- Max Recent: ${maxRecent.toStringAsFixed(2)} mm');

    return {
      'trend': trend,
      'score': trendScore,
      'avgRecent': avgRecent,
      'maxRecent': maxRecent,
    };
  }

  // Get yesterday's specific data if available
  static double? _getYesterdaysData(List<double> precipitationData) {
    // Assuming the data is ordered chronologically (most recent last)
    // Yesterday would be the second-to-last data point if available
    if (precipitationData.length >= 2) {
      return precipitationData[precipitationData.length - 2]; // Second to last = yesterday
    } else if (precipitationData.length == 1) {
      return precipitationData.last; // If only one data point, assume it's recent
    }
    return null; // No recent data available
  }

  // Analyze recent rain patterns for historical dates
  static Map<String, dynamic> _analyzeHistoricalRecentRainPatterns(
    List<double> historicalPrecipitation,
    List<double> currentPrecipitation,
  ) {
    print('=== ANALYZING HISTORICAL RECENT RAIN PATTERNS ===');

    // Combine historical and current year data for analysis
    List<double> combinedPrecipitation = [];
    combinedPrecipitation.addAll(historicalPrecipitation);
    combinedPrecipitation.addAll(currentPrecipitation);

    if (combinedPrecipitation.isEmpty) {
      return {
        'hasRecentRain': false,
        'recentRainScore': 0.0,
        'maxRecentPrecipitation': 0.0,
        'avgRecentPrecipitation': 0.0,
        'recentRainyDays': 0,
        'yesterdaysData': null,
        'recentTrend': 'no_data',
        'recentTrendScore': 0.0,
        'analysisType': 'historical',
      };
    }

    double maxPrecip = combinedPrecipitation.reduce((a, b) => a > b ? a : b);
    double avgPrecip = combinedPrecipitation.reduce((a, b) => a + b) / combinedPrecipitation.length;
    int recentRainyDays = combinedPrecipitation.where((p) => p > 1.0).length;
    int significantRainyDays = combinedPrecipitation.where((p) => p > 3.0).length;

    // Analyze recent trend from the combined data
    Map<String, dynamic> recentTrend = _analyzeRecentTrend(combinedPrecipitation);

    // Calculate yesterday's data specifically (if available)
    double? yesterdaysData = _getYesterdaysData(combinedPrecipitation);

    // Calculate recent rain score (0-100, higher = more recent rain)
    double recentRainScore = 0.0;

    // Factor 1: Significant rain days in combined data
    if (significantRainyDays > 0) {
      recentRainScore += 40.0;
    } else if (recentRainyDays > 0) {
      recentRainScore += 25.0;
    }

    // Factor 2: High maximum precipitation
    if (maxPrecip > 10.0) {
      recentRainScore += 30.0;
    } else if (maxPrecip > 5.0) {
      recentRainScore += 20.0;
    } else if (maxPrecip > 2.0) {
      recentRainScore += 10.0;
    }

    // Factor 3: Above average precipitation
    if (avgPrecip > 2.0) {
      recentRainScore += 25.0;
    } else if (avgPrecip > 1.0) {
      recentRainScore += 15.0;
    }

    // Factor 4: Rain frequency
    double rainFrequency = recentRainyDays / combinedPrecipitation.length;
    recentRainScore += rainFrequency * 20.0; // Up to 20 points for frequency

    // Factor 5: Recent trend boost
    String lastTrend = recentTrend['trend'];
    double recentTrendScore = recentTrend['score'];
    if (lastTrend == 'increasing_rain') {
      recentRainScore += 15.0; // Boost for increasing rain trend
    } else if (lastTrend == 'decreasing_rain') {
      recentRainScore -= 10.0; // Reduce for decreasing rain trend
    }

    // Factor 6: Yesterday's specific data
    if (yesterdaysData != null && yesterdaysData > 2.0) {
      recentRainScore += 20.0; // Significant boost for recent rain yesterday
    } else if (yesterdaysData != null && yesterdaysData > 0.5) {
      recentRainScore += 10.0; // Moderate boost for light rain yesterday
    }

    bool hasRecentRain = recentRainScore > 25.0; // Lower threshold for recent rain detection

    print('Historical Recent Rain Analysis:');
    print('- Recent Rain Score: ${recentRainScore.toStringAsFixed(2)}');
    print('- Has Recent Rain: $hasRecentRain');
    print('- Max Precipitation: ${maxPrecip.toStringAsFixed(2)} mm');
    print('- Avg Precipitation: ${avgPrecip.toStringAsFixed(2)} mm');
    print('- Rainy Days: $recentRainyDays/${combinedPrecipitation.length}');
    print('- Recent Trend: $lastTrend (Score: ${recentTrendScore.toStringAsFixed(2)})');
    print('- Yesterday\'s Data: ${yesterdaysData?.toStringAsFixed(2) ?? 'Not available'} mm');
    print('- Analysis Type: Historical (using ${historicalPrecipitation.length} historical + ${currentPrecipitation.length} current year points)');

    return {
      'hasRecentRain': hasRecentRain,
      'recentRainScore': recentRainScore,
      'maxRecentPrecipitation': maxPrecip,
      'avgRecentPrecipitation': avgPrecip,
      'recentRainyDays': recentRainyDays,
      'significantRainyDays': significantRainyDays,
      'rainFrequency': rainFrequency,
      'yesterdaysData': yesterdaysData,
      'recentTrend': lastTrend,
      'recentTrendScore': recentTrendScore,
      'analysisType': 'historical',
      'dataSources': {
        'historical_points': historicalPrecipitation.length,
        'current_year_points': currentPrecipitation.length,
        'total_points': combinedPrecipitation.length,
      },
    };
  }

  // Enhanced confidence calculation that considers live data availability
  static Map<String, dynamic> _calculateEnhancedPredictionConfidence(
    List<double> precipitation,
    List<double> temperature,
    List<double> humidity,
    List<double> windSpeed,
    List<double> currentPrecipitation,
  ) {
    // Start with base confidence calculation
    Map<String, dynamic> baseConfidence = _calculatePredictionConfidence(
      precipitation,
      temperature,
      humidity,
      windSpeed,
      DateTime.now(), // Use current date for seasonal calculation
    );

    double overallConfidence = baseConfidence['overall'];

    // Boost confidence if current year data is available
    if (currentPrecipitation.isNotEmpty) {
      overallConfidence += 15.0; // Boost by 15% for having current year data

      // Additional boost based on current year data quality
      if (currentPrecipitation.length >= 3) {
        overallConfidence += 5.0; // Extra boost for good current data
      }

      print('Confidence boosted by live data: +15-20%');
    } else {
      overallConfidence -= 10.0; // Penalty for missing current year data
      print('Confidence reduced due to missing live data: -10%');
    }

    // Ensure confidence is within 0-100% range
    overallConfidence = max(0.0, min(100.0, overallConfidence));

    return {
      'overall': overallConfidence,
      'level': _getConfidenceLevel(overallConfidence),
      'factors': [...baseConfidence['factors'], if (currentPrecipitation.isNotEmpty) 'Current Year Data Available'],
      'low_confidence_reasons': baseConfidence['low_confidence_reasons'],
      'data_quality_score': baseConfidence['data_quality_score'],
      'live_data_bonus': currentPrecipitation.isNotEmpty ? 15.0 : 0.0,
    };
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

        // Extract precipitation data (PRECTOTCORR) with enhanced validation
        if (parameter.containsKey('PRECTOTCORR')) {
          var precipData = parameter['PRECTOTCORR'];
          if (precipData is Map) {
            precipData.forEach((dateKey, value) {
              if (value != null && value != -999.0 && value != -999 && value >= 0.0 && value <= 100.0) {
                double precipValue = (value is int) ? value.toDouble() : value as double;
                // Additional validation: reasonable daily precipitation limit
                if (precipValue <= 50.0) { // Max 50mm per day is reasonable
                  precipitationValues.add(precipValue);
                }
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
    double enhancedRainProbability = calculateEnhancedRainProbability(
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
  static double calculateEnhancedRainProbability(
    List<double> precipitation,
    List<double> temperature,
    List<double> humidity,
    List<double> windSpeed,
    TimeOfDay? selectedTime,
  ) {
    if (precipitation.isEmpty) return 0.0;

    // Step 1: Analyze precipitation patterns for sunny condition detection
    Map<String, dynamic> precipAnalysis = _analyzePrecipitationPatterns(precipitation);

    // Step 2: Calculate base probability with improved sunny day detection
    double baseProbability = _calculateImprovedBaseProbability(precipitation, precipAnalysis);

    // Step 3: Apply enhanced weather factor adjustments for sunny conditions
    Map<String, double> weatherFactors = _calculateEnhancedWeatherFactors(
      temperature, humidity, windSpeed, precipAnalysis
    );

    // Step 4: Apply time-based adjustments with local climate awareness
    double timeAdjustment = _calculateImprovedTimeAdjustment(selectedTime, precipAnalysis);

    // Step 5: Combine all factors with adaptive weighting based on sunny conditions
    double enhancedProbability = _combineProbabilityFactors(
      baseProbability, weatherFactors, timeAdjustment, precipAnalysis
    );

    // Step 6: Apply final validation and bounds checking
    return _finalizeProbability(enhancedProbability, precipAnalysis);
  }

  // Enhanced rain probability calculation with current year awareness
  static double calculateEnhancedRainProbabilityWithCurrentYearAwareness(
    List<double> precipitation,
    List<double> temperature,
    List<double> humidity,
    List<double> windSpeed,
    TimeOfDay? selectedTime,
    Map<String, dynamic> currentYearAnalysis,
  ) {
    if (precipitation.isEmpty) return 0.0;

    // Step 1: Analyze precipitation patterns for sunny condition detection
    Map<String, dynamic> precipAnalysis = _analyzePrecipitationPatterns(precipitation);

    // Step 2: Calculate base probability with current year awareness
    double baseProbability = _calculateImprovedBaseProbabilityWithCurrentYearAwareness(
      precipitation,
      precipAnalysis,
      currentYearAnalysis
    );

    // Step 3: Apply enhanced weather factor adjustments with current year context
    Map<String, double> weatherFactors = _calculateEnhancedWeatherFactorsWithCurrentYearAwareness(
      temperature,
      humidity,
      windSpeed,
      precipAnalysis,
      currentYearAnalysis
    );

    // Step 4: Apply time-based adjustments with current year context
    double timeAdjustment = _calculateImprovedTimeAdjustmentWithCurrentYearAwareness(
      selectedTime,
      precipAnalysis,
      currentYearAnalysis
    );

    // Step 5: Combine all factors with current year adaptive weighting
    double enhancedProbability = _combineProbabilityFactorsWithCurrentYearAwareness(
      baseProbability,
      weatherFactors,
      timeAdjustment,
      precipAnalysis,
      currentYearAnalysis
    );

    // Step 6: Apply final validation with current year context
    return _finalizeProbabilityWithCurrentYearAwareness(
      enhancedProbability,
      precipAnalysis,
      currentYearAnalysis
    );
  }

  // Calculate improved base probability with current year awareness
  static double _calculateImprovedBaseProbabilityWithCurrentYearAwareness(
    List<double> precipitation,
    Map<String, dynamic> precipAnalysis,
    Map<String, dynamic> currentYearAnalysis,
  ) {
    int totalDays = precipAnalysis['totalDays'];
    int significantRainDays = precipAnalysis['significantRainDays'];

    // Use higher threshold for significant rain (3mm+ instead of 2mm+)
    double baseProbability = (significantRainDays / totalDays) * 100.0;

    // Enhanced penalty for consistently dry conditions
    if (precipAnalysis['isConsistentlyDry']) {
      // Strong penalty for consistently dry locations
      baseProbability = max(0.0, baseProbability - 35.0);

      // Additional penalty based on dryness score
      double drynessScore = precipAnalysis['drynessScore'];
      if (drynessScore > 80.0) {
        baseProbability = max(0.0, baseProbability - 25.0); // Extra penalty for extremely dry
      } else if (drynessScore > 60.0) {
        baseProbability = max(0.0, baseProbability - 15.0); // Moderate extra penalty
      }
    } else if (significantRainDays == 0) {
      // Moderate penalty if no significant rain but not consistently dry
      baseProbability = max(0.0, baseProbability - 15.0);
    }

    // CURRENT YEAR AWARENESS: Boost probability if recent rain detected
    bool hasRecentRain = currentYearAnalysis['hasRecentRain'] ?? false;
    if (hasRecentRain) {
      double recentRainScore = currentYearAnalysis['recentRainScore'] ?? 0.0;
      double boostFactor = min(recentRainScore / 30.0, 2.0); // Up to 2x boost for recent rain

      // Apply boost based on recent rain intensity
      if (recentRainScore > 60.0) {
        baseProbability = min(100.0, baseProbability + 25.0); // Strong boost for intense recent rain
      } else if (recentRainScore > 40.0) {
        baseProbability = min(100.0, baseProbability + 15.0); // Moderate boost for moderate recent rain
      } else if (recentRainScore > 20.0) {
        baseProbability = min(100.0, baseProbability + 8.0);  // Light boost for light recent rain
      }

      print('Base probability boosted by recent rain: +${boostFactor > 1.0 ? (boostFactor * 100 - 100).toStringAsFixed(0) : "0"}%');
    }

    return baseProbability;
  }

  // Calculate enhanced weather factors with current year awareness
  static Map<String, double> _calculateEnhancedWeatherFactorsWithCurrentYearAwareness(
    List<double> temperature,
    List<double> humidity,
    List<double> windSpeed,
    Map<String, dynamic> precipAnalysis,
    Map<String, dynamic> currentYearAnalysis,
  ) {
    double temperatureFactor = 0.0;
    double humidityFactor = 0.0;
    double windFactor = 0.0;

    bool isConsistentlyDry = precipAnalysis['isConsistentlyDry'];
    bool hasRecentRain = currentYearAnalysis['hasRecentRain'] ?? false;

    // Enhanced temperature adjustments
    if (temperature.isNotEmpty) {
      double avgTemp = temperature.reduce((a, b) => a + b) / temperature.length;

      if (isConsistentlyDry && !hasRecentRain) {
        // Stronger adjustments for consistently dry locations WITHOUT recent rain
        if (avgTemp > 35) {
          temperatureFactor = -15.0; // Very strong decrease for extreme heat in dry areas
        } else if (avgTemp > 30) {
          temperatureFactor = -10.0; // Strong decrease for hot weather in dry areas
        } else if (avgTemp > 25) {
          temperatureFactor = -6.0;  // Moderate decrease for warm weather in dry areas
        } else if (avgTemp < 5) {
          temperatureFactor = 3.0;   // Slight increase for very cold weather
        }
      } else if (hasRecentRain) {
        // Reduce temperature penalties if there's recent rain (indicates changeable weather)
        if (avgTemp > 35) {
          temperatureFactor = -5.0; // Reduced penalty for extreme heat with recent rain
        } else if (avgTemp > 28) {
          temperatureFactor = -2.0; // Reduced penalty for hot weather with recent rain
        } else if (avgTemp < 5) {
          temperatureFactor = 5.0;  // Increased boost for very cold weather with recent rain
        }
      } else {
        // Standard adjustments for other locations
        if (avgTemp > 35) {
          temperatureFactor = -8.0;
        } else if (avgTemp > 28) {
          temperatureFactor = -4.0;
        } else if (avgTemp < 5) {
          temperatureFactor = 2.0;
        }
      }
    }

    // Enhanced humidity adjustments
    if (humidity.isNotEmpty) {
      double avgHumidity = humidity.reduce((a, b) => a + b) / humidity.length;

      if (isConsistentlyDry && !hasRecentRain) {
        // Much stronger adjustments for dry locations without recent rain
        if (avgHumidity < 25) {
          humidityFactor = -12.0; // Very strong decrease for very low humidity in dry areas
        } else if (avgHumidity < 35) {
          humidityFactor = -8.0;  // Strong decrease for low humidity in dry areas
        } else if (avgHumidity < 45) {
          humidityFactor = -4.0;  // Moderate decrease for moderate humidity in dry areas
        } else if (avgHumidity > 85) {
          humidityFactor = 4.0;   // Slight increase for very high humidity
        }
      } else if (hasRecentRain) {
        // Adjust for recent rain conditions
        if (avgHumidity < 30) {
          humidityFactor = -3.0; // Reduced penalty for low humidity with recent rain
        } else if (avgHumidity < 40) {
          humidityFactor = -1.0; // Minimal penalty for dry conditions with recent rain
        } else if (avgHumidity > 85) {
          humidityFactor = 8.0;  // Increased boost for very high humidity with recent rain
        } else if (avgHumidity > 70) {
          humidityFactor = 4.0;  // Moderate boost for high humidity with recent rain
        }
      } else {
        // Standard adjustments for other locations
        if (avgHumidity < 30) {
          humidityFactor = -6.0;
        } else if (avgHumidity < 40) {
          humidityFactor = -3.0;
        } else if (avgHumidity > 85) {
          humidityFactor = 3.0;
        }
      }
    }

    // Enhanced wind adjustments
    if (windSpeed.isNotEmpty) {
      double avgWindSpeed = windSpeed.reduce((a, b) => a + b) / windSpeed.length;

      if (isConsistentlyDry && !hasRecentRain) {
        // Consider wind patterns in dry areas without recent rain
        if (avgWindSpeed > 15) {
          windFactor = -3.0; // Slight decrease for strong winds in dry areas
        } else if (avgWindSpeed < 3) {
          windFactor = -2.0; // Light winds can indicate stable high pressure (sunny)
        }
      } else if (hasRecentRain) {
        // Adjust wind for recent rain conditions
        if (avgWindSpeed > 15) {
          windFactor = 2.0;  // Slight increase for strong winds with recent rain (could indicate storms)
        } else if (avgWindSpeed < 3) {
          windFactor = 1.0;  // Reduced penalty for light winds with recent rain
        }
      } else {
        // Standard wind adjustments
        if (avgWindSpeed > 15) {
          windFactor = -2.0;
        }
      }
    }

    return {
      'temperature': temperatureFactor,
      'humidity': humidityFactor,
      'wind': windFactor,
    };
  }

  // Calculate improved time adjustments with current year awareness
  static double _calculateImprovedTimeAdjustmentWithCurrentYearAwareness(
    TimeOfDay? selectedTime,
    Map<String, dynamic> precipAnalysis,
    Map<String, dynamic> currentYearAnalysis,
  ) {
    if (selectedTime == null) return 0.0;

    int hour = selectedTime.hour;
    bool isConsistentlyDry = precipAnalysis['isConsistentlyDry'];
    bool hasRecentRain = currentYearAnalysis['hasRecentRain'] ?? false;

    // Base time adjustments
    double baseTimeAdjustment = 0.0;

    if (hour >= 5 && hour < 11) {
      // Morning: Generally lower rain probability
      baseTimeAdjustment = -5.0;
    } else if (hour >= 11 && hour < 17) {
      // Afternoon: Standard probability, often when thunderstorms occur
      baseTimeAdjustment = 1.0;
    } else if (hour >= 17 && hour < 21) {
      // Evening: Higher probability in many regions
      baseTimeAdjustment = 3.0;
    } else {
      // Night/Late night: Often highest probability for sustained rain
      baseTimeAdjustment = 5.0;
    }

    // Adjust for consistently dry conditions
    if (isConsistentlyDry && !hasRecentRain) {
      // Reduce time-based increases for dry locations without recent rain
      if (baseTimeAdjustment > 0) {
        baseTimeAdjustment = baseTimeAdjustment * 0.5; // Reduce positive adjustments by half
      }
      // Enhance negative adjustments for dry locations
      if (baseTimeAdjustment < 0) {
        baseTimeAdjustment = baseTimeAdjustment * 1.2; // Slightly enhance negative adjustments
      }
    } else if (hasRecentRain) {
      // Increase time-based adjustments for locations with recent rain
      if (baseTimeAdjustment > 0) {
        baseTimeAdjustment = baseTimeAdjustment * 1.3; // Increase positive adjustments by 30%
      }
      // Reduce negative adjustments for locations with recent rain
      if (baseTimeAdjustment < 0) {
        baseTimeAdjustment = baseTimeAdjustment * 0.8; // Reduce negative adjustments by 20%
      }
    }

    return baseTimeAdjustment;
  }

  // Combine all probability factors with current year adaptive weighting
  static double _combineProbabilityFactorsWithCurrentYearAwareness(
    double baseProbability,
    Map<String, double> weatherFactors,
    double timeAdjustment,
    Map<String, dynamic> precipAnalysis,
    Map<String, dynamic> currentYearAnalysis,
  ) {
    bool isConsistentlyDry = precipAnalysis['isConsistentlyDry'];
    double drynessScore = precipAnalysis['drynessScore'];
    bool hasRecentRain = currentYearAnalysis['hasRecentRain'] ?? false;

    // Adaptive weighting based on dryness and recent rain
    double tempWeight = 0.9;
    double humidityWeight = 0.9;
    double windWeight = 0.7;
    double timeWeight = 0.8;

    if (isConsistentlyDry && !hasRecentRain) {
      // Higher weight for temperature and humidity in dry areas without recent rain
      tempWeight = 1.2;
      humidityWeight = 1.3;
      timeWeight = 0.6; // Lower weight for time in dry areas
    } else if (hasRecentRain) {
      // Higher weight for humidity and time when there's recent rain
      humidityWeight = 1.4;
      timeWeight = 1.1; // Higher weight for time with recent rain
      tempWeight = 1.0; // Normal weight for temperature with recent rain
    }

    double enhancedProbability = baseProbability +
      (weatherFactors['temperature']! * tempWeight) +
      (weatherFactors['humidity']! * humidityWeight) +
      (weatherFactors['wind']! * windWeight) +
      (timeAdjustment * timeWeight);

    return enhancedProbability;
  }

  // Final probability validation with current year context
  static double _finalizeProbabilityWithCurrentYearAwareness(
    double probability,
    Map<String, dynamic> precipAnalysis,
    Map<String, dynamic> currentYearAnalysis,
  ) {
    bool isConsistentlyDry = precipAnalysis['isConsistentlyDry'];
    double drynessScore = precipAnalysis['drynessScore'];
    bool hasRecentRain = currentYearAnalysis['hasRecentRain'] ?? false;

    // Additional reduction for extremely dry conditions WITHOUT recent rain
    if (isConsistentlyDry && drynessScore > 80.0 && !hasRecentRain) {
      probability = max(0.0, probability - 10.0); // Extra 10% reduction for extremely dry
    } else if (isConsistentlyDry && drynessScore > 60.0 && !hasRecentRain) {
      probability = max(0.0, probability - 5.0);  // Extra 5% reduction for very dry
    }

    // BOOST for recent rain conditions
    if (hasRecentRain) {
      double recentRainScore = currentYearAnalysis['recentRainScore'] ?? 0.0;
      if (recentRainScore > 60.0) {
        probability = min(100.0, probability + 8.0); // Boost for intense recent rain
      } else if (recentRainScore > 40.0) {
        probability = min(100.0, probability + 5.0); // Moderate boost for moderate recent rain
      } else if (recentRainScore > 20.0) {
        probability = min(100.0, probability + 3.0); // Light boost for light recent rain
      }
    }

    // Ensure probability is within 0-100% range
    double finalProbability = max(0.0, min(100.0, probability));

    // Log the improvements for debugging
    print('=== ENHANCED PROBABILITY CALCULATION WITH CURRENT YEAR AWARENESS ===');
    print('Original probability: ${probability.toStringAsFixed(2)}%');
    print('Dryness score: ${drynessScore.toStringAsFixed(2)}');
    print('Is consistently dry: $isConsistentlyDry');
    print('Has recent rain: $hasRecentRain');
    print('Final probability: ${finalProbability.toStringAsFixed(2)}%');

    return finalProbability;
  }

  // Analyze precipitation patterns to detect consistently dry conditions
  static Map<String, dynamic> _analyzePrecipitationPatterns(List<double> precipitation) {
    if (precipitation.isEmpty) {
      return {
        'isConsistentlyDry': false,
        'drynessScore': 0.0,
        'maxPrecipitation': 0.0,
        'significantRainDays': 0,
        'totalDays': 0,
      };
    }

    double maxPrecip = precipitation.reduce((a, b) => a > b ? a : b);
    int significantRainDays = precipitation.where((p) => p > 3.0).length; // Higher threshold for significant rain
    int moderateRainDays = precipitation.where((p) => p > 1.0).length;
    int totalDays = precipitation.length;

    // Calculate dryness score (0-100, higher = more consistently dry)
    double drynessScore = 0.0;

    // Factor 1: Very few significant rain days
    if (significantRainDays == 0) {
      drynessScore += 40.0;
    } else if (significantRainDays < totalDays * 0.05) { // Less than 5% significant rain days
      drynessScore += 25.0;
    }

    // Factor 2: Low maximum precipitation
    if (maxPrecip < 5.0) {
      drynessScore += 30.0;
    } else if (maxPrecip < 10.0) {
      drynessScore += 15.0;
    }

    // Factor 3: Overall dry pattern (most days have very little rain)
    double avgPrecip = precipitation.reduce((a, b) => a + b) / totalDays;
    if (avgPrecip < 0.5) {
      drynessScore += 20.0;
    } else if (avgPrecip < 1.0) {
      drynessScore += 10.0;
    }

    // Factor 4: Consistency in dry conditions
    int veryDryDays = precipitation.where((p) => p < 0.1).length;
    double dryConsistency = veryDryDays / totalDays;
    drynessScore += dryConsistency * 15.0; // Up to 15 points for consistency

    bool isConsistentlyDry = drynessScore > 60.0; // Threshold for consistently dry conditions

    return {
      'isConsistentlyDry': isConsistentlyDry,
      'drynessScore': drynessScore,
      'maxPrecipitation': maxPrecip,
      'significantRainDays': significantRainDays,
      'moderateRainDays': moderateRainDays,
      'totalDays': totalDays,
      'avgPrecipitation': avgPrecip,
      'dryConsistency': dryConsistency,
    };
  }

  // Calculate improved base probability with better sunny day handling
  static double _calculateImprovedBaseProbability(List<double> precipitation, Map<String, dynamic> precipAnalysis) {
    int totalDays = precipAnalysis['totalDays'];
    int significantRainDays = precipAnalysis['significantRainDays'];

    // Use higher threshold for significant rain (3mm+ instead of 2mm+)
    double baseProbability = (significantRainDays / totalDays) * 100.0;

    // Enhanced penalty for consistently dry conditions
    if (precipAnalysis['isConsistentlyDry']) {
      // Strong penalty for consistently dry locations
      baseProbability = max(0.0, baseProbability - 35.0);

      // Additional penalty based on dryness score
      double drynessScore = precipAnalysis['drynessScore'];
      if (drynessScore > 80.0) {
        baseProbability = max(0.0, baseProbability - 25.0); // Extra penalty for extremely dry
      } else if (drynessScore > 60.0) {
        baseProbability = max(0.0, baseProbability - 15.0); // Moderate extra penalty
      }
    } else if (significantRainDays == 0) {
      // Moderate penalty if no significant rain but not consistently dry
      baseProbability = max(0.0, baseProbability - 15.0);
    }

    return baseProbability;
  }

  // Calculate enhanced weather factors with stronger sunny condition adjustments
  static Map<String, double> _calculateEnhancedWeatherFactors(
    List<double> temperature,
    List<double> humidity,
    List<double> windSpeed,
    Map<String, dynamic> precipAnalysis,
  ) {
    double temperatureFactor = 0.0;
    double humidityFactor = 0.0;
    double windFactor = 0.0;

    bool isConsistentlyDry = precipAnalysis['isConsistentlyDry'];

    // Enhanced temperature adjustments
    if (temperature.isNotEmpty) {
      double avgTemp = temperature.reduce((a, b) => a + b) / temperature.length;

      if (isConsistentlyDry) {
        // Stronger adjustments for consistently dry locations
        if (avgTemp > 35) {
          temperatureFactor = -15.0; // Very strong decrease for extreme heat in dry areas
        } else if (avgTemp > 30) {
          temperatureFactor = -10.0; // Strong decrease for hot weather in dry areas
        } else if (avgTemp > 25) {
          temperatureFactor = -6.0;  // Moderate decrease for warm weather in dry areas
        } else if (avgTemp < 5) {
          temperatureFactor = 3.0;   // Slight increase for very cold weather
        }
      } else {
        // Standard adjustments for other locations
        if (avgTemp > 35) {
          temperatureFactor = -8.0;
        } else if (avgTemp > 28) {
          temperatureFactor = -4.0;
        } else if (avgTemp < 5) {
          temperatureFactor = 2.0;
        }
      }
    }

    // Enhanced humidity adjustments
    if (humidity.isNotEmpty) {
      double avgHumidity = humidity.reduce((a, b) => a + b) / humidity.length;

      if (isConsistentlyDry) {
        // Much stronger adjustments for dry locations
        if (avgHumidity < 25) {
          humidityFactor = -12.0; // Very strong decrease for very low humidity in dry areas
        } else if (avgHumidity < 35) {
          humidityFactor = -8.0;  // Strong decrease for low humidity in dry areas
        } else if (avgHumidity < 45) {
          humidityFactor = -4.0;  // Moderate decrease for moderate humidity in dry areas
        } else if (avgHumidity > 85) {
          humidityFactor = 4.0;   // Slight increase for very high humidity
        }
      } else {
        // Standard adjustments for other locations
        if (avgHumidity < 30) {
          humidityFactor = -6.0;
        } else if (avgHumidity < 40) {
          humidityFactor = -3.0;
        } else if (avgHumidity > 85) {
          humidityFactor = 3.0;
        }
      }
    }

    // Enhanced wind adjustments
    if (windSpeed.isNotEmpty) {
      double avgWindSpeed = windSpeed.reduce((a, b) => a + b) / windSpeed.length;

      if (isConsistentlyDry) {
        // Consider wind patterns in dry areas
        if (avgWindSpeed > 15) {
          windFactor = -3.0; // Slight decrease for strong winds in dry areas
        } else if (avgWindSpeed < 3) {
          windFactor = -2.0; // Light winds can indicate stable high pressure (sunny)
        }
      } else {
        // Standard wind adjustments
        if (avgWindSpeed > 15) {
          windFactor = -2.0;
        }
      }
    }

    return {
      'temperature': temperatureFactor,
      'humidity': humidityFactor,
      'wind': windFactor,
    };
  }

  // Calculate improved time adjustments with local climate awareness
  static double _calculateImprovedTimeAdjustment(TimeOfDay? selectedTime, Map<String, dynamic> precipAnalysis) {
    if (selectedTime == null) return 0.0;

    int hour = selectedTime.hour;
    bool isConsistentlyDry = precipAnalysis['isConsistentlyDry'];

    // Base time adjustments
    double baseTimeAdjustment = 0.0;

    if (hour >= 5 && hour < 11) {
      // Morning: Generally lower rain probability
      baseTimeAdjustment = -5.0;
    } else if (hour >= 11 && hour < 17) {
      // Afternoon: Standard probability, often when thunderstorms occur
      baseTimeAdjustment = 1.0;
    } else if (hour >= 17 && hour < 21) {
      // Evening: Higher probability in many regions
      baseTimeAdjustment = 3.0;
    } else {
      // Night/Late night: Often highest probability for sustained rain
      baseTimeAdjustment = 5.0;
    }

    // Adjust for consistently dry conditions
    if (isConsistentlyDry) {
      // Reduce time-based increases for dry locations
      if (baseTimeAdjustment > 0) {
        baseTimeAdjustment = baseTimeAdjustment * 0.5; // Reduce positive adjustments by half
      }
      // Enhance negative adjustments for dry locations
      if (baseTimeAdjustment < 0) {
        baseTimeAdjustment = baseTimeAdjustment * 1.2; // Slightly enhance negative adjustments
      }
    }

    return baseTimeAdjustment;
  }

  // Combine all probability factors with adaptive weighting
  static double _combineProbabilityFactors(
    double baseProbability,
    Map<String, double> weatherFactors,
    double timeAdjustment,
    Map<String, dynamic> precipAnalysis,
  ) {
    bool isConsistentlyDry = precipAnalysis['isConsistentlyDry'];
    double drynessScore = precipAnalysis['drynessScore'];

    // Adaptive weighting based on dryness
    double tempWeight = isConsistentlyDry ? 1.2 : 0.9;  // Higher weight for temperature in dry areas
    double humidityWeight = isConsistentlyDry ? 1.3 : 0.9; // Higher weight for humidity in dry areas
    double windWeight = 0.7;
    double timeWeight = isConsistentlyDry ? 0.6 : 0.8; // Lower weight for time in dry areas

    double enhancedProbability = baseProbability +
      (weatherFactors['temperature']! * tempWeight) +
      (weatherFactors['humidity']! * humidityWeight) +
      (weatherFactors['wind']! * windWeight) +
      (timeAdjustment * timeWeight);

    return enhancedProbability;
  }

  // Final probability validation and bounds checking
  static double _finalizeProbability(double probability, Map<String, dynamic> precipAnalysis) {
    bool isConsistentlyDry = precipAnalysis['isConsistentlyDry'];
    double drynessScore = precipAnalysis['drynessScore'];

    // Additional reduction for extremely dry conditions
    if (isConsistentlyDry && drynessScore > 80.0) {
      probability = max(0.0, probability - 10.0); // Extra 10% reduction for extremely dry
    } else if (isConsistentlyDry && drynessScore > 60.0) {
      probability = max(0.0, probability - 5.0);  // Extra 5% reduction for very dry
    }

    // Ensure probability is within 0-100% range
    double finalProbability = max(0.0, min(100.0, probability));

    // Log the improvements for debugging
    print('=== ENHANCED PROBABILITY CALCULATION ===');
    print('Original probability: ${probability.toStringAsFixed(2)}%');
    print('Dryness score: ${drynessScore.toStringAsFixed(2)}');
    print('Is consistently dry: $isConsistentlyDry');
    print('Final probability: ${finalProbability.toStringAsFixed(2)}%');

    return finalProbability;
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

  // Test ultra-recent data functionality
  static Future<Map<String, dynamic>> testUltraRecentData({
    required double latitude,
    required double longitude,
  }) async {
    print('=== TESTING ULTRA-RECENT DATA FUNCTIONALITY ===');
    print('Location: $latitude, $longitude');

    // Test 1: Today's data
    print('\n--- TEST 1: Today\'s Real-Time Data ---');
    Map<String, dynamic>? todaysData = await getTodaysData(
      latitude: latitude,
      longitude: longitude,
    );

    if (todaysData != null) {
      print('✓ Today\'s data successfully fetched');
      print('Today\'s data keys: ${todaysData.keys.toList()}');
    } else {
      print('✗ Today\'s data not available');
    }

    // Test 2: Yesterday's data
    print('\n--- TEST 2: Yesterday\'s Data ---');
    double? yesterdaysPrecipitation = await getYesterdaysPrecipitation(
      latitude: latitude,
      longitude: longitude,
    );

    if (yesterdaysPrecipitation != null) {
      print('✓ Yesterday\'s data successfully fetched: ${yesterdaysPrecipitation.toStringAsFixed(2)} mm');
    } else {
      print('✗ Yesterday\'s data not available');
    }

    // Test 3: Ultra-recent data (last 3 days)
    print('\n--- TEST 3: Ultra-Recent Data (3 days) ---');
    Map<String, dynamic> ultraRecentData = await getUltraRecentData(
      latitude: latitude,
      longitude: longitude,
      daysBack: 3,
    );

    if (ultraRecentData.isNotEmpty) {
      print('✓ Ultra-recent data successfully fetched');
      print('Ultra-recent data keys: ${ultraRecentData.keys.toList()}');
    } else {
      print('✗ Ultra-recent data not available');
    }

    // Test 4: Recent data (last 7 days)
    print('\n--- TEST 4: Recent Data (7 days) ---');
    Map<String, dynamic> recentData = await getVeryRecentData(
      latitude: latitude,
      longitude: longitude,
      daysBack: 7,
    );

    if (recentData.isNotEmpty) {
      print('✓ Recent data successfully fetched');
      print('Recent data keys: ${recentData.keys.toList()}');
    } else {
      print('✗ Recent data not available');
    }

    // Test 5: Full enhanced prediction with all data sources
    print('\n--- TEST 5: Full Enhanced Prediction ---');
    try {
      var stopwatch = Stopwatch()..start();
      Map<String, dynamic> enhancedData = await getEnhancedWeatherData(
        latitude: latitude,
        longitude: longitude,
        year: DateTime.now().year,
        month: DateTime.now().month,
        day: DateTime.now().day,
        selectedTime: TimeOfDay.now(),
      );
      stopwatch.stop();

      print('✓ Enhanced prediction completed in ${stopwatch.elapsedMilliseconds}ms');
      print('Enhanced prediction keys: ${enhancedData.keys.toList()}');

      // Show data source availability
      Map<String, dynamic> dataSources = enhancedData['data_sources'] ?? {};
      Map<String, dynamic> dataQuality = enhancedData['dataQuality'] ?? {};

      print('\n=== DATA SOURCE SUMMARY ===');
      print('Today\'s data: ${dataQuality['todays_data_available'] ? '✓' : '✗'}');
      print('Yesterday\'s data: ${dataQuality['yesterdays_data_available'] ? '✓' : '✗'}');
      print('Ultra-recent data: ${dataQuality['ultra_recent_data_available'] ? '✓' : '✗'}');
      print('Recent data: ${dataQuality['recent_data_available'] ? '✓' : '✗'}');
      print('Current year data: ${dataQuality['current_year_data'] ? '✓' : '✗'}');

      print('\n=== WEIGHT MULTIPLIERS ===');
      print('Today\'s weight: ${dataSources['todays_data_weight_multiplier']}x');
      print('Yesterday\'s weight: ${dataSources['yesterdays_data_weight_multiplier']}x');
      print('Ultra-recent weight: ${dataSources['ultra_recent_weight_multiplier']}x');
      print('Recent weight: ${dataSources['recent_data_weight_multiplier']}x');
      print('Current year weight: ${dataSources['current_year_weight_multiplier']}x');

      return {
        'success': true,
        'message': 'Ultra-recent data test completed',
        'todays_data_available': todaysData != null,
        'yesterdays_data_available': yesterdaysPrecipitation != null,
        'ultra_recent_available': ultraRecentData.isNotEmpty,
        'recent_data_available': recentData.isNotEmpty,
        'enhanced_prediction': enhancedData,
        'execution_time_ms': stopwatch.elapsedMilliseconds,
      };

    } catch (e) {
      print('✗ Enhanced prediction test failed: $e');
      return {
        'success': false,
        'error': 'Enhanced prediction test failed: $e',
      };
    }
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
