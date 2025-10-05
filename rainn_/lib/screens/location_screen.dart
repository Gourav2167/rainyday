import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import '../services/location_service.dart';
import '../services/nasa_api_service.dart';
import 'prediction_screen.dart';

class LocationScreen extends StatefulWidget {
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;

  const LocationScreen({Key? key, this.selectedDate, this.selectedTime}) : super(key: key);

  @override
  _LocationScreenState createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  LatLng? _selectedLocation;
  LatLng? _currentLocation;
  bool _isLoading = false;
  bool _isSearching = false;
  MapController _mapController = MapController();
  List<Marker> _markers = [];
  TextEditingController _searchController = TextEditingController();
  List<Location> _searchResults = [];
  List<String> _searchSuggestions = [];
  Timer? _searchTimer;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadSavedMapState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedMapState() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      double? savedLat = prefs.getDouble('map_center_lat');
      double? savedLng = prefs.getDouble('map_center_lng');
      double? savedZoom = prefs.getDouble('map_zoom');

      if (savedLat != null && savedLng != null && savedZoom != null && mounted) {
        setState(() {
          _mapController.move(LatLng(savedLat, savedLng), savedZoom);
        });
        print('Loaded saved map state: $savedLat, $savedLng, zoom: $savedZoom');
      }
    } catch (e) {
      print('Error loading saved map state: $e');
      // Continue without saved state - not critical
    }
  }

  Future<void> _saveMapState() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      if (_mapController.camera.center != null) {
        await prefs.setDouble('map_center_lat', _mapController.camera.center!.latitude);
        await prefs.setDouble('map_center_lng', _mapController.camera.center!.longitude);
        await prefs.setDouble('map_zoom', _mapController.camera.zoom);
        print('Saved map state: ${_mapController.camera.center!.latitude}, ${_mapController.camera.center!.longitude}, zoom: ${_mapController.camera.zoom}');
      }
    } catch (e) {
      print('Error saving map state: $e');
      // Continue without saving state - not critical
    }
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _showSuggestions = false;
        _searchSuggestions.clear();
      });
      return;
    }

    // Debounce search to avoid too many API calls
    _searchTimer?.cancel();
    _searchTimer = Timer(Duration(milliseconds: 500), () {
      _getSearchSuggestions(query);
    });
  }

  Future<void> _getSearchSuggestions(String query) async {
    if (query.length < 3) return; // Only search for queries with 3+ characters

    try {
      print('Getting suggestions for: $query');
      List<Location> locations = await locationFromAddress(query).timeout(
        Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Search timed out'),
      );

      if (mounted) {
        setState(() {
          _searchSuggestions = locations.take(5).map((location) {
            return '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)} - ${query}';
          }).toList();
          _showSuggestions = true;
        });
      }
    } catch (e) {
      print('Error getting suggestions: $e');

      // Provide fallback suggestions for common locations
      if (query.toLowerCase().contains('bangalore') || query.toLowerCase().contains('bengaluru')) {
        setState(() {
          _searchSuggestions = [
            '12.9716, 77.5946 - Bangalore, India',
            '12.9716, 77.5946 - Bengaluru, Karnataka',
          ];
          _showSuggestions = true;
        });
      } else if (query.toLowerCase().contains('mumbai')) {
        setState(() {
          _searchSuggestions = [
            '19.0760, 72.8777 - Mumbai, India',
          ];
          _showSuggestions = true;
        });
      } else if (query.toLowerCase().contains('delhi')) {
        setState(() {
          _searchSuggestions = [
            '28.7041, 77.1025 - Delhi, India',
          ];
          _showSuggestions = true;
        });
      } else {
        setState(() {
          _searchSuggestions.clear();
          _showSuggestions = false;
        });
      }
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _showSuggestions = false;
    });

    try {
      print('Searching for location: $query');
      List<Location> locations = await locationFromAddress(query);

      print('Found ${locations.length} locations');

      if (locations.isNotEmpty) {
        Location firstResult = locations.first;
        LatLng newLocation = LatLng(firstResult.latitude, firstResult.longitude);

        setState(() {
          _selectedLocation = newLocation;
          _searchResults = locations;
          _isSearching = false;
          _updateMarkers();
          _mapController.move(newLocation, 12.0);
          _saveMapState();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found location successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No locations found for "$query". Try a different search term.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Search error: $e');
      setState(() => _isSearching = false);

      String errorMessage = 'Search failed';
      if (e.toString().contains('No address found')) {
        errorMessage = 'Location not found. Try a different search term.';
      } else {
        errorMessage = 'Search error: ${e.toString()}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    Position? position = await LocationService.getCurrentLocation();

    if (position != null) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _selectedLocation = _currentLocation;
        _isLoading = false;
        _updateMarkers();
        _mapController.move(_currentLocation!, 10.0);
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _updateMarkers() {
    _markers.clear();

    if (_currentLocation != null) {
      _markers.add(
        Marker(
          point: _currentLocation!,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              Icons.my_location,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      );
    }

    if (_selectedLocation != null && _selectedLocation != _currentLocation) {
      _markers.add(
        Marker(
          point: _selectedLocation!,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              Icons.location_on,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      );
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedLocation = point;
      _updateMarkers();
    });
  }

  void _predictForSelectedLocation() {
    if (_selectedLocation != null) {
      print('LocationScreen: Starting prediction for location: ${_selectedLocation!.latitude}, ${_selectedLocation!.longitude}');

      // Navigate to prediction screen with selected location and current date
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PredictionScreen(
            latitude: _selectedLocation!.latitude,
            longitude: _selectedLocation!.longitude,
            selectedDate: widget.selectedDate ?? DateTime.now(),
            selectedTime: widget.selectedTime ?? TimeOfDay.now(),
          ),
        ),
      ).then((_) {
        // This will be called when returning from prediction screen
        print('LocationScreen: Returned from prediction screen');
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a location first'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _runLocationDebugTest() {
    if (_selectedLocation != null) {
      _showDebugDialog(_selectedLocation!.latitude, _selectedLocation!.longitude);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a location first to run debug test'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showDebugDialog(double latitude, double longitude) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.bug_report, color: Colors.blue),
              SizedBox(width: 8),
              Text('Location Debug Test'),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Location: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}'),
                SizedBox(height: 8),
                Text('This will test the NASA API with 20 years of historical data for this location.'),
                SizedBox(height: 8),
                Text('The test includes:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('• API connectivity check'),
                Text('• Single year data fetch'),
                Text('• 20-year historical analysis'),
                Text('• Performance metrics'),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Run Debug Test'),
              onPressed: () {
                Navigator.of(context).pop();
                _executeDebugTest(latitude, longitude);
              },
            ),
          ],
        );
      },
    );
  }

  void _executeDebugTest(double latitude, double longitude) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.bug_report, color: Colors.blue),
              SizedBox(width: 8),
              Text('Running Debug Test...'),
            ],
          ),
          content: Container(
            height: 120,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Testing NASA API with 20 years of data...'),
                SizedBox(height: 8),
                Text('This may take a few moments...', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );

    try {
      Map<String, dynamic> debugResult = await NasaApiService.debugApiWithHistoricalData(
        latitude: latitude,
        longitude: longitude,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Show results dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    debugResult['success'] == true ? Icons.check_circle : Icons.error,
                    color: debugResult['success'] == true ? Colors.green : Colors.red,
                  ),
                  SizedBox(width: 8),
                  Text('Debug Test Results'),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debugResult['success'] == true ? '✓ Test completed successfully!' : '✗ Test failed',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: debugResult['success'] == true ? Colors.green : Colors.red,
                      ),
                    ),
                    SizedBox(height: 12),
                    if (debugResult['success'] == true) ...[
                      Text('• Years tested: ${debugResult['years_tested']}'),
                      Text('• Data points collected: ${debugResult['total_data_points']}'),
                      Text('• Execution time: ${debugResult['execution_time_ms']}ms'),
                      if (debugResult.containsKey('data') && debugResult['data'].containsKey('rainProbability'))
                        Text('• Rain probability: ${debugResult['data']['rainProbability'].toStringAsFixed(1)}%'),
                    ] else ...[
                      Text('• Error: ${debugResult['error']}'),
                      if (debugResult.containsKey('step'))
                        Text('• Failed at step: ${debugResult['step']}'),
                    ],
                    SizedBox(height: 16),
                    Text(
                      'Check the console/logs for detailed debug information.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Show error dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.error, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Debug Test Failed'),
                ],
              ),
              content: Text('An unexpected error occurred: $e'),
              actions: [
                TextButton(
                  child: Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    }
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Search Location'),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Enter city, address, or place name',
                        prefixIcon: Icon(Icons.search),
                        suffixIcon: _isSearching
                            ? Container(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _showSuggestions = false;
                                    _searchSuggestions.clear();
                                  });
                                },
                              ),
                      ),
                      onChanged: (value) {
                        _onSearchChanged(value);
                        setState(() {}); // Update dialog state
                      },
                      onSubmitted: (value) {
                        Navigator.of(context).pop();
                        _searchLocation(value);
                      },
                    ),
                    if (_showSuggestions && _searchSuggestions.isNotEmpty)
                      Container(
                        constraints: BoxConstraints(maxHeight: 150),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchSuggestions.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: Text(_searchSuggestions[index]),
                              onTap: () {
                                Navigator.of(context).pop();
                                _selectSuggestion(_searchSuggestions[index]);
                              },
                            );
                          },
                        ),
                      ),
                    SizedBox(height: 16),
                    Text(
                      'Popular Cities:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildQuickCityButton('Bangalore', LatLng(12.9716, 77.5946)),
                          _buildQuickCityButton('Mumbai', LatLng(19.0760, 72.8777)),
                          _buildQuickCityButton('Delhi', LatLng(28.7041, 77.1025)),
                          _buildQuickCityButton('Chennai', LatLng(13.0827, 80.2707)),
                          _buildQuickCityButton('Hyderabad', LatLng(17.3850, 78.4867)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _searchController.clear();
                    setState(() {
                      _showSuggestions = false;
                      _searchSuggestions.clear();
                    });
                  },
                ),
                ElevatedButton(
                  child: Text('Search'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _searchLocation(_searchController.text);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildQuickCityButton(String cityName, LatLng coordinates) {
    return Padding(
      padding: EdgeInsets.only(right: 8.0),
      child: ElevatedButton(
        onPressed: () {
          Navigator.of(context).pop();
          setState(() {
            _selectedLocation = coordinates;
            _updateMarkers();
            _mapController.move(_selectedLocation!, 12.0);
            _saveMapState();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$cityName selected'),
              backgroundColor: Colors.green,
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: TextStyle(fontSize: 12),
        ),
        child: Text(cityName),
      ),
    );
  }

  void _selectSuggestion(String suggestion) {
    // Parse coordinates from suggestion string
    RegExp coordRegex = RegExp(r'([0-9.-]+),\s*([0-9.-]+)');
    Match? match = coordRegex.firstMatch(suggestion);

    if (match != null) {
      double lat = double.parse(match.group(1)!);
      double lng = double.parse(match.group(2)!);

      setState(() {
        _selectedLocation = LatLng(lat, lng);
        _updateMarkers();
        _mapController.move(_selectedLocation!, 12.0);
        _saveMapState();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location selected successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Select Location'),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () => _showSearchDialog(context),
            tooltip: 'Search location',
          ),
          IconButton(
            icon: Icon(Icons.bug_report),
            onPressed: _runLocationDebugTest,
            tooltip: 'Debug NASA API for selected location',
          ),
          IconButton(
            icon: Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'Go to current location',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation ?? LatLng(20.5937, 78.9629), // Default to India
              initialZoom: _currentLocation != null ? 10.0 : 5.0,
              onTap: _onMapTap,
              maxZoom: 18.0,
              minZoom: 3.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.rainn',
              ),
              MarkerLayer(
                markers: _markers,
              ),
            ],
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tap on the map to select a location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 2,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    if (_selectedLocation != null) ...[
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Selected: ${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _predictForSelectedLocation,
                        icon: Icon(Icons.cloud),
                        label: Text('Predict Rain for Selected Location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        tooltip: 'Current Location',
        child: Icon(Icons.my_location),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildLocationInfo(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
        ),
        Text(
          value,
          style: TextStyle(color: Colors.blue[600]),
        ),
      ],
    );
  }
}
