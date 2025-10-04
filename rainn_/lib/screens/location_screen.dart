import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

class LocationScreen extends StatefulWidget {
  @override
  _LocationScreenState createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  Position? _currentPosition;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    
    Position? position = await LocationService.getCurrentLocation();
    
    setState(() {
      _currentPosition = position;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Location'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Location',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoading)
                      Center(child: CircularProgressIndicator())
                    else if (_currentPosition != null) ...[
                      _buildLocationInfo('Latitude', _currentPosition!.latitude.toString()),
                      SizedBox(height: 8),
                      _buildLocationInfo('Longitude', _currentPosition!.longitude.toString()),
                      SizedBox(height: 8),
                      _buildLocationInfo('Accuracy', '${_currentPosition!.accuracy.toStringAsFixed(1)} meters'),
                      SizedBox(height: 8),
                      _buildLocationInfo('Altitude', '${_currentPosition!.altitude.toStringAsFixed(1)} meters'),
                    ] else
                      Text('Location not available'),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _getCurrentLocation,
                      icon: Icon(Icons.refresh),
                      label: Text('Refresh Location'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location Settings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    ListTile(
                      leading: Icon(Icons.settings),
                      title: Text('Open Location Settings'),
                      onTap: () => Geolocator.openLocationSettings(),
                    ),
                    ListTile(
                      leading: Icon(Icons.apps),
                      title: Text('Open App Settings'),
                      onTap: () => Geolocator.openAppSettings(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfo(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        Text(value),
      ],
    );
  }
}
