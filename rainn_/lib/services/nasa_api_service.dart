import 'dart:convert';
import 'package:http/http.dart' as http;

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
      '$baseUrl?parameters=PRECTOTCORR&'
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
  }) async {
    // Get 10 years of historical data for the same date
    List<Future<Map<String, dynamic>>> futures = [];

    for (int i = 0; i < 10; i++) {
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
      return _processHistoricalData(results);
    } catch (e) {
      print('Error in getHistoricalData: $e');
      throw Exception('Failed to fetch historical data: $e');
    }
  }

  static Map<String, dynamic> _processHistoricalData(List<Map<String, dynamic>> data) {
    List<double> precipitationValues = [];

    print('Processing ${data.length} years of historical data');

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

        // Handle PRECTOTCORR (Precipitation) - the main parameter we need for rain prediction
        if (parameter.containsKey('PRECTOTCORR')) {
          var precipData = parameter['PRECTOTCORR'];
          print('Precipitation data: $precipData');
          print('Precipitation data type: ${precipData.runtimeType}');

          if (precipData is Map) {
            print('Precipitation data keys: ${precipData.keys.toList()}');

            // Extract values from the date-keyed structure
            precipData.forEach((dateKey, value) {
              print('Date: $dateKey, Precipitation: $value (type: ${value.runtimeType})');
              if (value != null && value != -999.0 && value != -999) {
                // Ensure proper type conversion to double
                double precipValue = (value is int) ? value.toDouble() : value as double;
                precipitationValues.add(precipValue);
              }
            });

            print('Extracted ${precipitationValues.length} precipitation values from date map');
          } else {
            print('Precipitation data is not a Map, trying direct value extraction');
            // Handle case where PRECTOTCORR might be a direct value
            if (precipData is num && precipData != -999.0 && precipData != -999) {
              double precipValue = (precipData is int) ? precipData.toDouble() : precipData as double;
              precipitationValues.add(precipValue);
            }
          }
        } else {
          print('PRECTOTCORR parameter not found in response');
          print('Available parameters: ${parameter.keys.toList()}');
        }
      } catch (e) {
        print('Error processing year data $i: $e');
      }
    }

    print('Final results:');
    print('Precipitation values: $precipitationValues');
    print('Total precipitation data points collected: ${precipitationValues.length}');

    // Calculate rain probability based on precipitation data
    int rainyDays = precipitationValues.where((p) => p > 1.0).length;
    double rainProbability = precipitationValues.isNotEmpty
        ? (rainyDays / precipitationValues.length.toDouble()) * 100.0
        : 0.0;

    print('Calculated rainy days: $rainyDays out of ${precipitationValues.length}');
    print('Final rain probability: $rainProbability%');

    return {
      'rainProbability': rainProbability,
      'avgPrecipitation': precipitationValues.isNotEmpty
          ? precipitationValues.reduce((a, b) => a + b) / precipitationValues.length.toDouble()
          : 0.0,
      'avgTemperature': 0.0, // Not available with current parameters
      'avgHumidity': 0.0,    // Not available with current parameters
      'precipitationData': precipitationValues,
      'temperatureData': [],
      'humidityData': [],
    };
  }
}
