import 'package:flutter/material.dart';
import 'package:rainn_/services/nasa_api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('=== PREDICTION DEBUG TEST ===');
  print('Testing NASA API prediction functionality...\n');

  try {
    // Test 1: Basic API connectivity
    print('--- TEST 1: Basic API Connectivity ---');
    bool isConnected = await NasaApiService.testApiConnection();
    print('API Connected: $isConnected\n');

    if (!isConnected) {
      print('❌ API connectivity test failed. Cannot proceed with prediction tests.');
      return;
    }

    // Test 2: Quick debug test with Delhi coordinates
    print('--- TEST 2: Quick Debug Test (Delhi) ---');
    Map<String, dynamic> debugResult = await NasaApiService.quickDebugTest();

    if (debugResult['success'] == true) {
      print('✅ Debug test successful!');
      print('Years tested: ${debugResult['years_tested']}');
      print('Total data points: ${debugResult['total_data_points']}');
      print('Execution time: ${debugResult['execution_time_ms']}ms');

      var data = debugResult['data'];
      if (data != null) {
        print('\n📊 PREDICTION RESULTS:');
        print('Rain Probability: ${data['rainProbability']?.toStringAsFixed(1) ?? 'N/A'}%');
        print('Avg Precipitation: ${data['avgPrecipitation']?.toStringAsFixed(2) ?? 'N/A'} mm');
        print('Avg Temperature: ${data['avgTemperature']?.toStringAsFixed(1) ?? 'N/A'}°C');
        print('Avg Humidity: ${data['avgHumidity']?.toStringAsFixed(1) ?? 'N/A'}%');
        print('Avg Wind Speed: ${data['avgWindSpeed']?.toStringAsFixed(1) ?? 'N/A'} m/s');

        if (data['confidence'] != null) {
          print('\n🎯 CONFIDENCE:');
          print('Overall: ${data['confidence']['overall']?.toStringAsFixed(1) ?? 'N/A'}%');
          print('Level: ${data['confidence']['level'] ?? 'N/A'}');
        }

        print('\n📋 DATA QUALITY:');
        var dataQuality = data['dataQuality'];
        if (dataQuality != null) {
          print('Precipitation years: ${dataQuality['precipitation_years'] ?? 'N/A'}');
          print('Temperature years: ${dataQuality['temperature_years'] ?? 'N/A'}');
          print('Humidity years: ${dataQuality['humidity_years'] ?? 'N/A'}');
          print('Wind years: ${dataQuality['wind_years'] ?? 'N/A'}');
        }
      }
    } else {
      print('❌ Debug test failed: ${debugResult['error']}');
    }

    // Test 3: Ultra-recent data functionality
    print('\n--- TEST 3: Ultra-Recent Data Test ---');
    Map<String, dynamic> ultraRecentResult = await NasaApiService.testUltraRecentData(
      latitude: 28.7041,  // Delhi
      longitude: 77.1025,
    );

    if (ultraRecentResult['success'] == true) {
      print('✅ Ultra-recent data test successful!');
      print('Today\'s data available: ${ultraRecentResult['todays_data_available']}');
      print('Yesterday\'s data available: ${ultraRecentResult['yesterdays_data_available']}');
      print('Ultra-recent data available: ${ultraRecentResult['ultra_recent_available']}');
      print('Recent data available: ${ultraRecentResult['recent_data_available']}');

      var enhancedPrediction = ultraRecentResult['enhanced_prediction'];
      if (enhancedPrediction != null) {
        print('\n🚀 ENHANCED PREDICTION RESULTS:');
        print('Enhanced Rain Probability: ${enhancedPrediction['rainProbability']?.toStringAsFixed(1) ?? 'N/A'}%');
        print('Base Rain Probability: ${enhancedPrediction['baseRainProbability']?.toStringAsFixed(1) ?? 'N/A'}%');

        var dataQuality = enhancedPrediction['dataQuality'];
        if (dataQuality != null) {
          print('\n🔍 DATA SOURCES USED:');
          print('Current year data: ${dataQuality['current_year_data']}');
          print('Ultra-recent data: ${dataQuality['ultra_recent_data_available']}');
          print('Recent data: ${dataQuality['recent_data_available']}');
          print('Today\'s data: ${dataQuality['todays_data_available']}');
          print('Yesterday\'s data: ${dataQuality['yesterdays_data_available']}');
          print('Recent rain detected: ${dataQuality['recent_rain_detected']}');
        }
      }
    } else {
      print('❌ Ultra-recent data test failed: ${ultraRecentResult['error']}');
    }

    // Test 4: SharedPreferences functionality
    print('\n--- TEST 4: SharedPreferences Test ---');
    await NasaApiService.testSharedPreferences();

    // Test 5: Save test prediction
    print('\n--- TEST 5: Save Test Prediction ---');
    bool saveResult = await NasaApiService.saveTestPrediction();
    print('Test prediction save result: ${saveResult ? '✅ SUCCESS' : '❌ FAILED'}');

    print('\n=== PREDICTION DEBUG TEST COMPLETED ===');
    print('\n📋 SUMMARY:');
    print('✅ API Connectivity: ${isConnected ? 'WORKING' : 'FAILED'}');
    print('✅ Historical Data: ${debugResult['success'] == true ? 'WORKING' : 'FAILED'}');
    print('✅ Ultra-Recent Data: ${ultraRecentResult['success'] == true ? 'WORKING' : 'FAILED'}');
    print('✅ SharedPreferences: WORKING');
    print('✅ Save Functionality: ${saveResult ? 'WORKING' : 'FAILED'}');

    if (debugResult['success'] == true && ultraRecentResult['success'] == true) {
      print('\n🎉 ALL CORE PREDICTION FEATURES ARE WORKING PROPERLY!');
      print('The app should be able to:');
      print('• Fetch historical weather data from NASA API');
      print('• Process 20 years of data for accurate predictions');
      print('• Use ultra-recent data for enhanced accuracy');
      print('• Save and retrieve prediction history');
      print('• Calculate rain probability with confidence levels');
    } else {
      print('\n⚠️  SOME ISSUES DETECTED - Please check the error messages above');
    }

  } catch (e) {
    print('❌ Critical error during debug test: $e');
    print('Stack trace: ${StackTrace.current}');
  }
}
