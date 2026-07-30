import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PanicMapScreen extends StatefulWidget {
  final String victimUid;
  const PanicMapScreen({super.key, required this.victimUid});

  @override
  State<PanicMapScreen> createState() => _PanicMapScreenState();
}

class _PanicMapScreenState extends State<PanicMapScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<DocumentSnapshot>? _panicSubscription;
  Timer? _distanceTimer;

  LatLng? _victimLatLng;
  String _victimName = "Victim";
  String _victimInitials = "V";
  String _victimAddress = "";
  
  Position? _currentUserPosition;
  double _distanceMeters = 0.0;
  bool _isLoading = true;

  BitmapDescriptor? _victimMarkerIcon;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  Future<void> _startTracking() async {
    // 1. Get initial current user location
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      setState(() {
        _currentUserPosition = pos;
      });
    } catch (e) {
      debugPrint("Failed to get user position: $e");
    }

    // 2. Subscribe to active_panics document
    _panicSubscription = FirebaseFirestore.instance
        .collection('active_panics')
        .doc(widget.victimUid)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) {
        _showResolvedDialog();
        return;
      }

      final data = snapshot.data();
      if (data == null || data['is_active'] == false) {
        _showResolvedDialog();
        return;
      }

      final double lat = data['lat'] ?? 0.0;
      final double lng = data['lng'] ?? 0.0;
      final String first = data['first_name'] ?? "";
      final String last = data['last_name'] ?? "";
      final String address = data['address'] ?? "";

      final name = "$first $last".trim();
      final initials = (first.isNotEmpty && last.isNotEmpty)
          ? "${first[0]}${last[0]}".toUpperCase()
          : (first.length >= 2 ? first.substring(0, 2).toUpperCase() : "V");

      // Generate custom marker icon on-the-fly when initials change
      if (_victimInitials != initials || _victimMarkerIcon == null) {
        final icon = await _createInitialsMarkerIcon(initials);
        if (mounted) {
          setState(() {
            _victimMarkerIcon = icon;
          });
        }
      }

      if (mounted) {
        setState(() {
          _victimLatLng = LatLng(lat, lng);
          _victimName = name.isEmpty ? "SafeTrace User" : name;
          _victimInitials = initials;
          _victimAddress = address;
          _isLoading = false;
        });

        _recalculateDistance();
        
        // Center camera on victim if it's the first load
        if (_mapController != null && _victimLatLng != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLng(_victimLatLng!));
        }
      }
    });

    // 3. Periodic timer to update contact position & recalculate distance every 10 seconds
    _distanceTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );
        if (mounted) {
          setState(() {
            _currentUserPosition = pos;
          });
          _recalculateDistance();
        }
      } catch (e) {
        debugPrint("Failed to update user position in timer: $e");
      }
    });
  }

  void _recalculateDistance() {
    if (_currentUserPosition == null || _victimLatLng == null) return;
    
    final dist = _calculateHaversineDistance(
      _currentUserPosition!.latitude,
      _currentUserPosition!.longitude,
      _victimLatLng!.latitude,
      _victimLatLng!.longitude,
    );

    setState(() {
      _distanceMeters = dist;
    });
  }

  double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLon = (lon2 - lon1) * pi / 180.0;
    final a = sin(dLat / 2.0) * sin(dLat / 2.0) +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) *
        sin(dLon / 2.0) * sin(dLon / 2.0);
    final c = 2.0 * atan2(sqrt(a), sqrt(1.0 - a));
    return r * c;
  }

  Future<BitmapDescriptor> _createInitialsMarkerIcon(String initials) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const size = Size(100, 100);
    final center = Offset(size.width / 2, size.height / 2);

    // Draw background rounded square
    final paint = Paint()..color = const Color(0xFFD32F2F);
    const badgeSize = 50.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: badgeSize, height: badgeSize),
      const Radius.circular(12),
    );
    canvas.drawRRect(rect, paint);

    // Draw little pointing triangle at the bottom center of the badge
    final path = Path();
    path.moveTo(center.dx - 8, center.dy + (badgeSize / 2));
    path.lineTo(center.dx, center.dy + (badgeSize / 2) + 8);
    path.lineTo(center.dx + 8, center.dy + (badgeSize / 2));
    path.close();
    canvas.drawPath(path, paint);

    // Draw white text
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: initials,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  void _showResolvedDialog() {
    if (!mounted) return;
    _panicSubscription?.cancel();
    _distanceTimer?.cancel();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Alert Resolved"),
        content: const Text("This emergency panic alert has been resolved or cancelled by the user."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Pop dialog
              Navigator.pop(context); // Pop screen back to home
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return "${meters.toStringAsFixed(0)} m";
    } else {
      final km = meters / 1000;
      return "${km.toStringAsFixed(2)} km";
    }
  }

  @override
  void dispose() {
    _panicSubscription?.cancel();
    _distanceTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Set<Marker> markers = {};
    if (_victimLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('victim'),
          position: _victimLatLng!,
          icon: _victimMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: _victimName, snippet: _victimAddress),
        ),
      );
    }
    if (_currentUserPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_user'),
          position: LatLng(_currentUserPosition!.latitude, _currentUserPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: "My Location"),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Tracking: $_victimName"),
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _victimLatLng ?? (_currentUserPosition != null ? LatLng(_currentUserPosition!.latitude, _currentUserPosition!.longitude) : const LatLng(0.0, 0.0)),
                    zoom: 16,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  markers: markers,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
                
                // Floating Distance & Info Card at the Bottom
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.emergency_share, color: Color(0xFFD32F2F), size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _victimName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Last Address: $_victimAddress",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Distance from victim",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black45,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDistance(_distanceMeters),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD32F2F),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onPressed: () {
                                if (_mapController != null && _victimLatLng != null) {
                                  _mapController!.animateCamera(
                                    CameraUpdate.newLatLngZoom(_victimLatLng!, 16),
                                  );
                                }
                              },
                              icon: const Icon(Icons.my_location, size: 18),
                              label: const Text("Center"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
