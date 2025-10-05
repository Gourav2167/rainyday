# 🌧️ Rain Prediction App - API Documentation

## Overview

The Rain Prediction App integrates with NASA's Earth Data API to provide accurate weather predictions based on historical satellite data and atmospheric measurements.

## NASA Earth Data API

### Primary Endpoint
```
Base URL: https://api.nasa.gov/
```

### Key Datasets Used

#### 1. MODIS (Moderate Resolution Imaging Spectroradiometer)
- **Purpose**: Land surface temperature and vegetation data
- **Data Coverage**: Global, 2000-present
- **Resolution**: 1km - 500m
- **Update Frequency**: Daily

#### 2. TRMM/GPM (Tropical Rainfall Measuring Mission/Global Precipitation Measurement)
- **Purpose**: Precipitation and rainfall data
- **Data Coverage**: Global, 1997-present (TRMM), 2014-present (GPM)
- **Resolution**: 0.1° x 0.1° grid
- **Update Frequency**: Real-time to daily

#### 3. AIRS (Atmospheric Infrared Sounder)
- **Purpose**: Atmospheric temperature, humidity, and cloud properties
- **Data Coverage**: Global, 2002-present
- **Resolution**: 45km x 45km
- **Update Frequency**: Twice daily

### API Integration Details

#### Service Class: `NasaApiService`

```dart
class NasaApiService {
  // Core prediction method
  static Future<Map<String, dynamic>> getHistoricalData({
    required double latitude,
    required double longitude,
    required int year,
    required int month,
    required int day,
    required TimeOfDay selectedTime,
  }) async {
    // Implementation details...
  }

  // Debug and testing
  static Future<Map<String, dynamic>> debugApiWithHistoricalData({
    required double latitude,
    required double longitude,
  }) async {
    // Implementation details...
  }
}
```

### Data Processing Pipeline

1. **Location Validation**
   - Verify latitude/longitude coordinates
   - Convert to appropriate grid format

2. **Historical Data Retrieval**
   - Query NASA API for specified date range
   - Aggregate data from multiple satellite sources

3. **Pattern Analysis**
   - Calculate precipitation trends
   - Analyze temperature patterns
   - Evaluate humidity variations

4. **Risk Assessment**
   - Compute rain probability percentage
   - Determine confidence levels
   - Generate weather insights

### Response Format

```json
{
  "rainProbability": 75.5,
  "avgTemperature": 24.8,
  "avgHumidity": 68.2,
  "avgWindSpeed": 12.5,
  "avgPrecipitation": 5.2,
  "confidence": {
    "overall": 82.5,
    "level": "High",
    "low_confidence_reasons": []
  },
  "precipitationData": [2.1, 3.4, 1.8, ...],
  "temperatureData": [23.5, 25.1, 24.2, ...],
  "weatherCondition": "Partly Cloudy",
  "predictionDate": "2024-01-15",
  "location": {
    "latitude": 28.7041,
    "longitude": 77.1025,
    "address": "New Delhi, India"
  }
}
```

## Geolocation Services

### Location Service Integration

#### Primary Package: `geolocator`

```dart
class LocationService {
  // Get current device location
  static Future<Position?> getCurrentLocation() async {
    // Implementation details...
  }

  // Convert coordinates to address
  static Future<String> getLocationAddress(double lat, double lng) async {
    // Implementation details...
  }

  // Format location for display
  static String getLocationString(double latitude, double longitude) {
    // Implementation details...
  }
}
```

### Permission Handling

```xml
<!-- Android Manifest Permissions -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

## Error Handling

### API Error Types

1. **Network Errors**
   - Connection timeout
   - DNS resolution failures
   - SSL/TLS handshake issues

2. **Data Errors**
   - Invalid API responses
   - Missing required fields
   - Data parsing failures

3. **Location Errors**
   - Permission denied
   - GPS unavailable
   - Location services disabled

### Retry Logic

```dart
// Exponential backoff for API retries
const retryDelays = [1, 2, 4, 8, 16]; // seconds

Future<Map<String, dynamic>> _retryApiCall(Function apiCall) async {
  for (int i = 0; i < retryDelays.length; i++) {
    try {
      return await apiCall();
    } catch (e) {
      if (i == retryDelays.length - 1) rethrow;
      await Future.delayed(Duration(seconds: retryDelays[i]));
    }
  }
  throw Exception('Max retries exceeded');
}
```

## Performance Optimization

### Caching Strategy

- **Memory Cache**: Recent predictions stored in app memory
- **Persistent Cache**: Historical data saved locally using SharedPreferences
- **Cache Invalidation**: Automatic cleanup of old data

### Data Compression

- **Request Optimization**: Minimal data fields requested from API
- **Response Compression**: Gzip compression for large datasets
- **Local Storage**: Efficient JSON serialization

## Security Considerations

### API Key Management

```dart
// Secure API key storage (environment variables)
const String _nasaApiKey = String.fromEnvironment('NASA_API_KEY');

// Alternative: Secure storage for sensitive keys
// await FlutterSecureStorage().write(key: 'nasa_api_key', value: apiKey);
```

### Data Privacy

- **Location Data**: Only used for weather predictions, not stored permanently
- **User Data**: No personal information collected or transmitted
- **API Compliance**: Follows NASA Earth Data terms of service

## Testing

### API Testing Methods

```dart
// Built-in API connectivity test
Future<bool> testApiConnection() async {
  try {
    final response = await http.get(
      Uri.parse('$_baseUrl/connectivity-test'),
    );
    return response.statusCode == 200;
  } catch (e) {
    return false;
  }
}

// Debug method for comprehensive testing
Future<Map<String, dynamic>> debugApiWithHistoricalData({
  required double latitude,
  required double longitude,
}) async {
  // Test multiple years of data
  // Validate response consistency
  // Return detailed debug information
}
```

## Rate Limiting

### NASA API Limits

- **Requests per Hour**: 1000 requests per API key
- **Daily Quota**: 10,000 requests per day
- **Concurrent Requests**: Limited to prevent server overload

### App-Level Rate Limiting

```dart
// Request throttling to respect API limits
class ApiRateLimiter {
  static DateTime _lastRequest = DateTime.now();
  static const _minInterval = Duration(milliseconds: 100);

  static Future<void> throttle() async {
    final elapsed = DateTime.now().difference(_lastRequest);
    if (elapsed < _minInterval) {
      await Future.delayed(_minInterval - elapsed);
    }
    _lastRequest = DateTime.now();
  }
}
```

## Monitoring & Analytics

### Usage Tracking

- **API Call Metrics**: Success rates, response times, error frequencies
- **User Engagement**: Feature usage, prediction accuracy feedback
- **Performance Monitoring**: App responsiveness, memory usage

### Debug Information

The app includes comprehensive debug information accessible through:
- Debug screen with API test functionality
- Detailed error messages and stack traces
- Performance metrics and timing information

## Future Enhancements

### Planned API Integrations

1. **Real-time Weather APIs**
   - OpenWeatherMap One Call API
   - WeatherAPI.com for current conditions

2. **Enhanced Satellite Data**
   - GOES-R Series for North America
   - Himawari-8 for Asia-Pacific region

3. **Machine Learning Integration**
   - Custom prediction models
   - Pattern recognition algorithms

### API Version Management

- **Backward Compatibility**: Support for multiple API versions
- **Graceful Degradation**: Fallback mechanisms for API failures
- **Version Detection**: Automatic detection of API capabilities

---

*This documentation covers the technical implementation of API integrations in the Rain Prediction App. For user-facing documentation, see the main README.md file.*
