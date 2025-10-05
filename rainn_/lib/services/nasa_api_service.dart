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

  // Enhanced method that combines historical data with current year live data
  static Future<Map<String, dynamic>> getEnhancedWeatherData({
    required double latitude,
    required double longitude,
    required int year,
    required int month,
    required int day,
    TimeOfDay? selectedTime,
  }) async {
    print('=== FETCHING ENHANCED WEATHER DATA ===');
    print('Combining historical data with current year live data');

    // Step 1: Get historical data (20 years)
    Map<String, dynamic> historicalResult = await getHistoricalData(
      latitude: latitude,
      longitude: longitude,
      year: year,
      month: month,
      day: day,
      selectedTime: selectedTime,
    );

    // Step 2: Try to get current year data
    Map<String, dynamic> currentData = await getCurrentYearData(
      latitude: latitude,
      longitude: longitude,
      year: year,
      month: month,
      day: day,
    );

    // Step 3: Process and combine the data
    return _processEnhancedData(historicalResult, currentData, selectedTime);
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

    // Prioritize current year data heavily
    if (currentPrecipitation.isNotEmpty) {
      // Add current year data multiple times to increase its weight
      int currentYearMultiplier = currentYearAnalysis['hasRecentRain'] ? 8 : 5;
      for (int i = 0; i < currentYearMultiplier && i < currentPrecipitation.length; i++) {
        combinedPrecipitation.addAll(currentPrecipitation);
      }
      print('Added current year precipitation data $currentYearMultiplier times due to ${currentYearAnalysis['hasRecentRain'] ? 'recent rain' : 'no recent rain'}');
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

  // Analyze current year patterns to detect recent rain
  static Map<String, dynamic> _analyzeCurrentYearPatterns(List<double> currentPrecipitation) {
    if (currentPrecipitation.isEmpty) {
      return {
        'hasRecentRain': false,
        'recentRainScore': 0.0,
        'maxRecentPrecipitation': 0.0,
        'avgRecentPrecipitation': 0.0,
        'recentRainyDays': 0,
      };
    }

    double maxPrecip = currentPrecipitation.reduce((a, b) => a > b ? a : b);
    double avgPrecip = currentPrecipitation.reduce((a, b) => a + b) / currentPrecipitation.length;
    int recentRainyDays = currentPrecipitation.where((p) => p > 1.0).length;
    int significantRainyDays = currentPrecipitation.where((p) => p > 3.0).length;

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

    bool hasRecentRain = recentRainScore > 30.0; // Lower threshold for recent rain detection

    print('Current Year Analysis:');
    print('- Recent Rain Score: ${recentRainScore.toStringAsFixed(2)}');
    print('- Has Recent Rain: $hasRecentRain');
    print('- Max Precipitation: ${maxPrecip.toStringAsFixed(2)} mm');
    print('- Avg Precipitation: ${avgPrecip.toStringAsFixed(2)} mm');
    print('- Rainy Days: $recentRainyDays/${currentPrecipitation.length}');

    return {
      'hasRecentRain': hasRecentRain,
      'recentRainScore': recentRainScore,
      'maxRecentPrecipitation': maxPrecip,
      'avgRecentPrecipitation': avgPrecip,
      'recentRainyDays': recentRainyDays,
      'significantRainyDays': significantRainyDays,
      'rainFrequency': rainFrequency,
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
