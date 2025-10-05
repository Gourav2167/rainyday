// Test script to verify the improved rain prediction accuracy
import 'package:flutter/material.dart';
import 'lib/services/nasa_api_service.dart';

void main() async {
  print('=== TESTING IMPROVED RAIN PREDICTION ACCURACY ===');

  // Test case 1: Consistently dry location (like a desert)
  print('\n--- TEST CASE 1: Consistently Dry Location ---');
  List<double> dryPrecipitation = [0.0, 0.1, 0.0, 0.2, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0];
  List<double> highTemp = [35.0, 38.0, 36.0, 37.0, 39.0, 35.0, 36.0, 38.0, 37.0, 35.0, 36.0, 38.0, 37.0, 35.0, 36.0, 38.0, 37.0, 35.0, 36.0, 38.0];
  List<double> lowHumidity = [15.0, 12.0, 18.0, 14.0, 10.0, 16.0, 13.0, 11.0, 17.0, 15.0, 12.0, 18.0, 14.0, 10.0, 16.0, 13.0, 11.0, 17.0, 15.0, 12.0];

  double dryProbability = NasaApiService.calculateEnhancedRainProbability(
    dryPrecipitation,
    highTemp,
    lowHumidity,
    [5.0, 6.0, 4.0, 7.0, 5.0, 6.0, 4.0, 7.0, 5.0, 6.0, 4.0, 7.0, 5.0, 6.0, 4.0, 7.0, 5.0, 6.0, 4.0, 7.0],
    TimeOfDay(hour: 12, minute: 0),
  );

  print('Consistently dry location probability: ${dryProbability.toStringAsFixed(2)}%');
  print('Expected: Very low probability (< 20%)');
  print('Test ${dryProbability < 20.0 ? 'PASSED' : 'FAILED'}: ${dryProbability < 20.0 ? '✓ Correctly shows low probability for dry conditions' : '✗ Still showing high probability for dry conditions'}');

  // Test case 2: Location with some rain but mostly dry
  print('\n--- TEST CASE 2: Location with Occasional Rain ---');
  List<double> occasionalPrecipitation = [0.0, 0.1, 0.0, 2.5, 0.0, 0.0, 0.1, 0.0, 3.2, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0, 1.8, 0.0, 0.0];
  List<double> moderateTemp = [28.0, 30.0, 29.0, 27.0, 31.0, 28.0, 30.0, 29.0, 26.0, 28.0, 30.0, 29.0, 27.0, 31.0, 28.0, 30.0, 29.0, 26.0, 28.0, 30.0];
  List<double> moderateHumidity = [45.0, 42.0, 48.0, 65.0, 40.0, 46.0, 43.0, 49.0, 68.0, 44.0, 41.0, 47.0, 64.0, 39.0, 45.0, 42.0, 48.0, 67.0, 43.0, 46.0];

  double occasionalProbability = NasaApiService.calculateEnhancedRainProbability(
    occasionalPrecipitation,
    moderateTemp,
    moderateHumidity,
    [8.0, 9.0, 7.0, 12.0, 8.0, 9.0, 7.0, 11.0, 8.0, 9.0, 7.0, 12.0, 8.0, 9.0, 7.0, 11.0, 8.0, 9.0, 7.0, 12.0],
    TimeOfDay(hour: 15, minute: 0),
  );

  print('Occasional rain location probability: ${occasionalProbability.toStringAsFixed(2)}%');
  print('Expected: Moderate probability (20-50%)');
  print('Test ${occasionalProbability >= 20.0 && occasionalProbability <= 50.0 ? 'PASSED' : 'FAILED'}: ${occasionalProbability >= 20.0 && occasionalProbability <= 50.0 ? '✓ Shows moderate probability for occasional rain' : '✗ Incorrect probability for occasional rain'}');

  // Test case 3: Location with frequent rain
  print('\n--- TEST CASE 3: Location with Frequent Rain ---');
  List<double> rainyPrecipitation = [5.2, 3.1, 7.8, 2.5, 4.6, 6.3, 1.8, 8.9, 3.4, 5.7, 2.1, 6.8, 4.3, 7.2, 1.5, 5.9, 3.7, 8.1, 2.8, 4.4];
  List<double> coolTemp = [22.0, 24.0, 21.0, 25.0, 23.0, 20.0, 24.0, 19.0, 26.0, 22.0, 25.0, 21.0, 24.0, 20.0, 23.0, 25.0, 22.0, 21.0, 24.0, 23.0];
  List<double> highHumidity = [78.0, 82.0, 75.0, 88.0, 80.0, 85.0, 76.0, 90.0, 77.0, 83.0, 79.0, 86.0, 74.0, 89.0, 81.0, 84.0, 78.0, 87.0, 80.0, 82.0];

  double rainyProbability = NasaApiService.calculateEnhancedRainProbability(
    rainyPrecipitation,
    coolTemp,
    highHumidity,
    [12.0, 15.0, 10.0, 18.0, 13.0, 16.0, 11.0, 19.0, 14.0, 17.0, 12.0, 15.0, 10.0, 18.0, 13.0, 16.0, 11.0, 19.0, 14.0, 17.0],
    TimeOfDay(hour: 20, minute: 0),
  );

  print('Frequent rain location probability: ${rainyProbability.toStringAsFixed(2)}%');
  print('Expected: High probability (> 60%)');
  print('Test ${rainyProbability > 60.0 ? 'PASSED' : 'FAILED'}: ${rainyProbability > 60.0 ? '✓ Correctly shows high probability for rainy conditions' : '✗ Not showing high enough probability for rainy conditions'}');

  // Test case 4: Edge case - No precipitation data
  print('\n--- TEST CASE 4: Edge Case - No Precipitation Data ---');
  double noDataProbability = NasaApiService.calculateEnhancedRainProbability(
    [],
    [25.0, 26.0, 24.0, 27.0, 25.0],
    [50.0, 52.0, 48.0, 54.0, 50.0],
    [5.0, 6.0, 4.0, 7.0, 5.0],
    TimeOfDay(hour: 12, minute: 0),
  );

  print('No data probability: ${noDataProbability.toStringAsFixed(2)}%');
  print('Expected: 0.0% (no data available)');
  print('Test ${noDataProbability == 0.0 ? 'PASSED' : 'FAILED'}: ${noDataProbability == 0.0 ? '✓ Correctly returns 0% for no data' : '✗ Incorrectly returns probability for no data'}');

  print('\n=== TEST SUMMARY ===');
  print('The improved algorithm should now:');
  print('1. Show very low probabilities (< 20%) for consistently dry locations');
  print('2. Show moderate probabilities (20-50%) for locations with occasional rain');
  print('3. Show high probabilities (> 60%) for locations with frequent rain');
  print('4. Handle edge cases properly (no data returns 0%)');

  print('\nThese improvements should significantly reduce false high-percentage predictions');
  print('for sunny/dry conditions while maintaining accuracy for rainy conditions.');
}
