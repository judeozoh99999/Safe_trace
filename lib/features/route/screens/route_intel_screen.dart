import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../../home_shell.dart';
import '../../location/providers/home_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../community/providers/community_provider.dart';
import '../../community/screens/community_feed_screen.dart';
import '../services/route_service.dart';
import '../../notes/screens/log_notes_screen.dart';
import '../../location/services/location_service.dart';

// ─── Providers ─────────────────────────────────────────────────────────────

/// Used by HomeScreen overlay tap to navigate — kept for compatibility
final routeIntelActiveTabProvider = StateProvider<int>((ref) => 0);

// ─── Main Widget ───────────────────────────────────────────────────────────

class RouteIntelScreen extends ConsumerStatefulWidget {
  final LatLng? initialDestLatLng;
  final String? initialDestAddress;
  final bool isPanicAlert;
  final String? victimName;

  final bool nearbyAlertEvent;
  final bool isNearbyAlertHistoricalView;
  final String? historicalCardTitle;
  final bool isDualMarker;
  final String? requesterName;
  final String? recipientName;
  final LatLng? requesterLatLng;
  final LatLng? recipientLatLng;
  final String? requesterAddress;
  final String? recipientAddress;
  final DateTime? connectedAt;

  const RouteIntelScreen({
    super.key,
    this.initialDestLatLng,
    this.initialDestAddress,
    this.isPanicAlert = false,
    this.victimName,
    this.nearbyAlertEvent = false,
    this.isNearbyAlertHistoricalView = false,
    this.historicalCardTitle,
    this.isDualMarker = false,
    this.requesterName,
    this.recipientName,
    this.requesterLatLng,
    this.recipientLatLng,
    this.requesterAddress,
    this.recipientAddress,
    this.connectedAt,
  });

  @override
  ConsumerState<RouteIntelScreen> createState() => _RouteIntelScreenState();
}

class _RouteIntelScreenState extends ConsumerState<RouteIntelScreen>
    with TickerProviderStateMixin {
  bool get isHistoricalMode => widget.isNearbyAlertHistoricalView || widget.nearbyAlertEvent;

  // Map
  GoogleMapController? _mapController;

  // Geolocator variables
  Position? _currentPosition;
  String? _currentUserAddress;
  // ignore: unused_field
  StreamSubscription<Position>? _positionSub;
  bool _permissionDenied = false;
  bool _userPanned = false;
  bool _isProgrammaticMoving = false;

  // Firestore streams
  List<DocumentSnapshot> _communityNotes = [];
  List<DocumentSnapshot> _favourites = [];
  StreamSubscription<QuerySnapshot>? _notesSub;
  StreamSubscription<QuerySnapshot>? _favsSub;

  LatLng? _highlightedFavLatLng;
  String? _highlightedFavAddress;

  LatLng? _selectedLatLng;
  String? _selectedAddress;
  bool _selectedIsFavourite = false;
  bool _showSelectedNoteInput = false;
  final TextEditingController _selectedNoteCtrl = TextEditingController();
  bool _selectedLocationLoading = false;

  String? _selectedNoteUser;
  String? _selectedNoteText;

  // Route
  final TextEditingController _destController = TextEditingController();
  LatLng? _destLatLng;
  List<LatLng> _routePoints = [];
  bool _isRouteLoading = false;
  double _distanceKm = 0.0;
  double _durationMinutes = 0.0;

  // Compass & marker rotation
  StreamSubscription? _compassSubscription;
  double _currentHeading = 0.0;
  BitmapDescriptor? _userDirectionalMarkerIcon;
  BitmapDescriptor? _locationPlusMarkerIcon;

  // Animated Route
  List<LatLng> _animatedRoutePoints = [];
  AnimationController? _routeAnimController;

  // 8km notes filter
  Position? _lastFilterPosition;
  List<CommunityNoteModel> _nearbyNotes = [];

  // Autocomplete
  List<Map<String, String>> _suggestions = [];
  bool _isLoadingSuggestions = false;
  Timer? _debounceTimer;
  final FocusNode _searchFocusNode = FocusNode();
  final LayerLink _searchLayerLink = LayerLink();
  OverlayEntry? _suggestionOverlay;

  // History
  String _historyFilter = "All";

  // Log marker tap
  Map<String, String>? _tappedLog;
  bool _showLogCard = false;

  // Draggable sheet controller
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus) {
        _hideSuggestions();
      }
    });

    // Subscribe to compass events for native GPU map rotation
    _compassSubscription = FlutterCompass.events?.listen((event) {
      final double? heading = event.heading;
      if (heading != null) {
        if ((heading - _currentHeading).abs() > 1.0) {
          if (mounted) {
            setState(() {
              _currentHeading = heading;
            });
          }
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenToCommunityNotes();
      _listenToFavourites();
      _createLocationPlusMarkerIcon().then((icon) {
        if (mounted) {
          setState(() {
            _locationPlusMarkerIcon = icon;
          });
        }
      });

      final bool isDual = widget.isDualMarker || (widget.requesterLatLng != null && widget.recipientLatLng != null);
      if (isDual) {
        _calculateDualRoute();
      } else if (widget.initialDestLatLng != null) {
        debugPrint("ROUTE SCREEN MOUNTED INCOMING DESTINATION LAT ${widget.initialDestLatLng!.latitude} INCOMING DESTINATION LNG ${widget.initialDestLatLng!.longitude}");
        setState(() {
          _selectedLatLng = widget.initialDestLatLng;
          _destLatLng = widget.initialDestLatLng;
          _destController.text = widget.initialDestAddress ?? "Destination";
        });
        _initLocationAndCalculateRoute(widget.initialDestLatLng!, widget.initialDestAddress ?? "Destination");
      } else if (widget.initialDestAddress != null && widget.initialDestAddress!.isNotEmpty) {
        debugPrint("ROUTE SCREEN MOUNTED INCOMING DESTINATION ADDRESS: ${widget.initialDestAddress}");
        _destController.text = widget.initialDestAddress!;
        _initLocation().then((_) => _calculateRoute());
      } else {
        debugPrint("ROUTE SCREEN MOUNTED INCOMING DESTINATION: NONE");
        setState(() {
          _selectedLatLng = null;
          _destLatLng = null;
          _routePoints = [];
          _animatedRoutePoints = [];
        });
        _initLocation();
      }
    });
  }

  @override
  void dispose() {
    _destController.dispose();
    _mapController?.dispose();
    _debounceTimer?.cancel();
    _searchFocusNode.dispose();
    _suggestionOverlay?.remove();
    _sheetController.dispose();
    _compassSubscription?.cancel();
    _routeAnimController?.dispose();
    super.dispose();
  }

  // ─── Autocomplete ─────────────────────────────────────────────────────────

  void _onSearchChanged(String text) {
    _debounceTimer?.cancel();
    setState(() {
      _selectedLatLng = null;
      _destLatLng = null;
      _routePoints = [];
      _animatedRoutePoints = [];
    });

    if (text.trim().length < 2) {
      _hideSuggestions();
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchSuggestions(text.trim());
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    setState(() => _isLoadingSuggestions = true);
    try {
      final dio = Dio();
      final response = await dio.get(
        "https://nominatim.openstreetmap.org/search",
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': 5,
          'addressdetails': 1,
          'countrycodes': 'ng',
        },
        options: Options(headers: {'User-Agent': 'SafeTraceApp/1.0'}),
      );

      if (response.statusCode == 200 && response.data is List) {
        final results = (response.data as List).map<Map<String, String>>((item) {
          final display = item['display_name']?.toString() ?? '';
          final lat = item['lat']?.toString() ?? '';
          final lon = item['lon']?.toString() ?? '';
          // Shorten the label: take first two comma-separated parts
          final parts = display.split(',');
          final label = parts.take(2).join(',').trim();
          return {'label': label, 'full': display, 'lat': lat, 'lon': lon};
        }).toList();

        if (mounted) {
          setState(() {
            _suggestions = results;
            _isLoadingSuggestions = false;
          });
          if (results.isNotEmpty) _showSuggestionsOverlay();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSuggestions = false);
    }
  }

  void _showSuggestionsOverlay() {
    _hideSuggestions();
    final overlay = Overlay.of(context);
    _suggestionOverlay = OverlayEntry(
      builder: (ctx) => _SuggestionOverlay(
        layerLink: _searchLayerLink,
        suggestions: _suggestions,
        isLoading: _isLoadingSuggestions,
        onSelect: _onSuggestionSelected,
      ),
    );
    overlay.insert(_suggestionOverlay!);
  }

  void _hideSuggestions() {
    _suggestionOverlay?.remove();
    _suggestionOverlay = null;
  }

  void _onSuggestionSelected(Map<String, String> suggestion) {
    _hideSuggestions();
    final label = suggestion['label'] ?? '';
    _destController.text = label;
    _searchFocusNode.unfocus();

    final lat = double.tryParse(suggestion['lat'] ?? '');
    final lon = double.tryParse(suggestion['lon'] ?? '');
    if (lat != null && lon != null) {
      _calculateRouteFromLatLng(LatLng(lat, lon), label);
    }
  }

  // ─── Route Calculation ────────────────────────────────────────────────────

  Future<void> _calculateRoute() async {
    final destination = _destController.text.trim();
    if (destination.isEmpty) return;

    setState(() => _isRouteLoading = true);
    _hideSuggestions();

    try {
      final destLatLng = _destLatLng ?? _selectedLatLng ?? await RouteService.geocodeAddress(destination);
      if (destLatLng == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Destination not found. Please try another search.")),
          );
        }
        setState(() => _isRouteLoading = false);
        return;
      }
      await _calculateRouteFromLatLng(destLatLng, destination);
    } catch (e) {
      setState(() => _isRouteLoading = false);
    }
  }

  Future<void> _initLocationAndCalculateRoute(LatLng destLatLng, String label) async {
    await _initLocation();
    await _calculateRouteFromLatLng(destLatLng, label);
  }

  Future<void> _calculateRouteFromLatLng(LatLng destLatLng, String label) async {
    setState(() {
      _isRouteLoading = true;
      _animatedRoutePoints = [];
    });

    if (_currentPosition == null) {
      try {
        _currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      } catch (_) {}
    }

    final homeState = ref.read(homeProvider);
    LatLng startLatLng;
    if (_currentPosition != null) {
      startLatLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    } else if (homeState.currentLatitude != 0.0 && homeState.currentLongitude != 0.0) {
      startLatLng = LatLng(homeState.currentLatitude, homeState.currentLongitude);
    } else {
      startLatLng = destLatLng;
    }

    debugPrint("USER CURRENT GPS LAT ${startLatLng.latitude} LNG ${startLatLng.longitude}");
    debugPrint("DIRECTIONS API CALL ORIGIN LAT ${startLatLng.latitude} ORIGIN LNG ${startLatLng.longitude} DESTINATION LAT ${destLatLng.latitude} DESTINATION LNG ${destLatLng.longitude}");

    try {
      final routeResult = await RouteService.fetchRoute(startLatLng, destLatLng);
      if (routeResult != null && routeResult.polylinePoints.isNotEmpty) {
        // Step 8: Check if endpoint snapped to a road > 2km away from tapped location
        final routeEndpoint = routeResult.polylinePoints.last;
        final snapDistMeters = _calculateHaversineDistance(
          destLatLng.latitude,
          destLatLng.longitude,
          routeEndpoint.latitude,
          routeEndpoint.longitude,
        );

        if (snapDistMeters > 2000.0) {
          debugPrint("[ROUTE_DIRECTIONS] Endpoint snapped >2km away (${(snapDistMeters / 1000).toStringAsFixed(1)}km). Rejecting route.");
          setState(() {
            _isRouteLoading = false;
            _destLatLng = null;
            _routePoints = [];
            _animatedRoutePoints = [];
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Could not find a route to this exact location. Please tap a nearby road or search.")),
            );
          }
          return;
        }

        setState(() {
          _destLatLng = destLatLng;
          _routePoints = routeResult.polylinePoints;
          _distanceKm = routeResult.distanceKm;
          _durationMinutes = routeResult.durationMinutes;
          _isRouteLoading = false;
        });
        _fitMapBounds(startLatLng, destLatLng);

        // Expand panel to show results
        if (_sheetController.isAttached) {
          _sheetController.animateTo(
            0.55,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        }

        // Animate route polyline
        _routeAnimController?.dispose();
        _routeAnimController = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2000),
        );
        final pathAnimation = CurvedAnimation(
          parent: _routeAnimController!,
          curve: Curves.easeInOut,
        );
        _routeAnimController!.addListener(() {
          final double progress = pathAnimation.value;
          final int totalPoints = _routePoints.length;
          final int pointsToShow = (totalPoints * progress).round();
          setState(() {
            _animatedRoutePoints = _routePoints.take(pointsToShow).toList();
          });
        });
        _routeAnimController!.addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            HapticFeedback.heavyImpact(); // Route drawing ready haptic
          }
        });
        _routeAnimController!.forward();
      } else {
        setState(() {
          _isRouteLoading = false;
          _selectedLatLng = null; // dismiss pop-up
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No route found between these two points")),
          );
        }
      }
    } catch (_) {
      setState(() {
        _isRouteLoading = false;
        _selectedLatLng = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No route found between these two points")),
        );
      }
    }
  }

  Future<void> _calculateDualRoute() async {
    final p1 = widget.requesterLatLng;
    final p2 = widget.recipientLatLng;
    if (p1 == null || p2 == null) return;

    setState(() {
      _isRouteLoading = true;
    });

    try {
      final routeResult = await RouteService.fetchRoute(p1, p2);
      if (routeResult != null && routeResult.polylinePoints.isNotEmpty) {
        setState(() {
          _routePoints = routeResult.polylinePoints;
          _animatedRoutePoints = routeResult.polylinePoints;
          _distanceKm = routeResult.distanceKm;
          _durationMinutes = routeResult.durationMinutes.toDouble();
          _isRouteLoading = false;
        });
      } else {
        final meters = _calculateHaversineDistance(p1.latitude, p1.longitude, p2.latitude, p2.longitude);
        final distKm = meters / 1000.0;
        final estMins = (distKm / 0.5).round();
        setState(() {
          _routePoints = [p1, p2];
          _animatedRoutePoints = [p1, p2];
          _distanceKm = distKm;
          _durationMinutes = estMins > 0 ? estMins.toDouble() : 1.0;
          _isRouteLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch dual route: $e");
      final meters = _calculateHaversineDistance(p1.latitude, p1.longitude, p2.latitude, p2.longitude);
      final distKm = meters / 1000.0;
      setState(() {
        _routePoints = [p1, p2];
        _animatedRoutePoints = [p1, p2];
        _distanceKm = distKm;
        _durationMinutes = 1.0;
        _isRouteLoading = false;
      });
    }

    _fitDualMarkerBounds(p1, p2);
  }

  void _fitDualMarkerBounds(LatLng p1, LatLng p2) {
    if (_mapController == null) return;
    final southWest = LatLng(
      p1.latitude < p2.latitude ? p1.latitude : p2.latitude,
      p1.longitude < p2.longitude ? p1.longitude : p2.longitude,
    );
    final northEast = LatLng(
      p1.latitude > p2.latitude ? p1.latitude : p2.latitude,
      p1.longitude > p2.longitude ? p1.longitude : p2.longitude,
    );
    final bounds = LatLngBounds(southwest: southWest, northeast: northEast);
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80.0));
  }

  void _fitMapBounds(LatLng start, LatLng dest) {
    if (_mapController == null) return;
    final distMeters = _calculateHaversineDistance(start.latitude, start.longitude, dest.latitude, dest.longitude);
    if (distMeters > 40000) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(dest, 13.5),
      );
    } else {
      final bounds = LatLngBounds(
        southwest: LatLng(
          start.latitude < dest.latitude ? start.latitude : dest.latitude,
          start.longitude < dest.longitude ? start.longitude : dest.longitude,
        ),
        northeast: LatLng(
          start.latitude > dest.latitude ? start.latitude : dest.latitude,
          start.longitude > dest.longitude ? start.longitude : dest.longitude,
        ),
      );
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    }
  }

  void _centerOnUser() {
    HapticFeedback.lightImpact();
    setState(() {
      _userPanned = false;
    });
    if (_currentPosition != null) {
      _isProgrammaticMoving = true;
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          16.0,
        ),
      );
      _isProgrammaticMoving = false;
    } else {
      final homeState = ref.read(homeProvider);
      final userLatLng = LatLng(homeState.currentLatitude, homeState.currentLongitude);
      if (userLatLng.latitude != 0.0 && userLatLng.longitude != 0.0) {
        _isProgrammaticMoving = true;
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(userLatLng, 16.0));
        _isProgrammaticMoving = false;
      }
    }
  }

  Future<void> _initLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _permissionDenied = true;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _permissionDenied = true;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _permissionDenied = true;
      });
      return;
    }

    setState(() {
      _permissionDenied = false;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      setState(() {
        _currentPosition = position;
      });
      LocationService.reverseGeocode(position.latitude, position.longitude).then((addr) {
        if (mounted) {
          setState(() {
            _currentUserAddress = addr;
          });
        }
      });
      _filterNearbyNotes(position);
      _rebuildUserMarker();
      _isProgrammaticMoving = true;
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 16.0),
      );
      _isProgrammaticMoving = false;
    } catch (_) {}

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 2,
      ),
    ).listen((Position position) {
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
      });
      
      // Update nearby notes if moved > 500 meters
      if (_lastFilterPosition == null) {
        _filterNearbyNotes(position);
      } else {
        final dist = _calculateHaversineDistance(
          _lastFilterPosition!.latitude,
          _lastFilterPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        if (dist > 500.0) {
          _filterNearbyNotes(position);
        }
      }

      if (!_userPanned && _mapController != null) {
        _isProgrammaticMoving = true;
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
        );
        _isProgrammaticMoving = false;
      }
    });
  }

  void _listenToCommunityNotes() {
    _notesSub?.cancel();
    _notesSub = FirebaseFirestore.instance
        .collection('community_notes')
        .where('is_visible', isEqualTo: true)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _communityNotes = snap.docs;
      });
    });
  }

  void _listenToFavourites() {
    _favsSub?.cancel();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _favsSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favourites')
        .orderBy('added_at', descending: true)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _favourites = snap.docs;
      });
    });
  }

  Future<void> _rebuildUserMarker() async {
    if (!mounted) return;
    final authState = ref.read(authNotifierProvider);
    final initials = (authState.firstName.isNotEmpty && authState.lastName.isNotEmpty)
        ? "${authState.firstName[0]}${authState.lastName[0]}".toUpperCase()
        : (authState.firstName.length >= 2 ? authState.firstName.substring(0, 2).toUpperCase() : 'U');

    final icon = await createDirectionalMarkerIcon(initials);
    if (mounted) {
      setState(() {
        _userDirectionalMarkerIcon = icon;
      });
    }
  }

  Future<BitmapDescriptor> createDirectionalMarkerIcon(String initials) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const size = Size(320, 320);
    final center = Offset(size.width / 2, size.height / 2); // (160, 160)

    // 1. Draw static high-res spotlight cone pointing UP (0 degrees / North)
    final conePath = Path();
    conePath.moveTo(center.dx, center.dy);
    conePath.lineTo(center.dx - 85, center.dy - 145);
    conePath.lineTo(center.dx + 85, center.dy - 145);
    conePath.close();

    final conePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx, center.dy),
        Offset(center.dx, center.dy - 145),
        [
          const Color(0xFFEF4444).withOpacity(0.85),
          const Color(0xFFEF4444).withOpacity(0.0),
        ],
      );
    canvas.drawPath(conePath, conePaint);

    // 2. Soft Outer Drop Shadow for Badge
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center + const Offset(0, 2), 34.0, shadowPaint);

    // 3. Outer White Ring
    final whiteRingPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, 33.0, whiteRingPaint);

    // 4. Center Red Avatar Badge
    final badgePaint = Paint()..color = const Color(0xFFEF4444);
    canvas.drawCircle(center, 28.0, badgePaint);

    // 5. Draw User Initials (Bold White Text)
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: initials,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
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

  Future<BitmapDescriptor> _createLocationPlusMarkerIcon() async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const size = Size(100, 100);
    final center = Offset(size.width / 2, size.height / 2);

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center + const Offset(0, 2), 24.0, shadowPaint);

    final whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, 24.0, whitePaint);

    final redPaint = Paint()..color = const Color(0xFFEF4444);
    canvas.drawCircle(center, 20.0, redPaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = const TextSpan(
      text: "+",
      style: TextStyle(
        color: Colors.white,
        fontSize: 26,
        fontWeight: FontWeight.w900,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2 - 2),
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  void _filterNearbyNotes(Position currentPos) {
    try {
      final incidents = ref.read(communityProvider).notes;
      final List<CommunityNoteModel> filtered = [];
      for (final incident in incidents) {
        final dist = _calculateHaversineDistance(
          currentPos.latitude,
          currentPos.longitude,
          incident.latitude,
          incident.longitude,
        );
        if (dist <= 8000.0) { // 8 km in meters
          filtered.add(incident);
        }
      }
      filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      setState(() {
        _nearbyNotes = filtered;
        _lastFilterPosition = currentPos;
      });
    } catch (_) {}
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

  Future<void> _toggleFavourite() async {
    HapticFeedback.heavyImpact();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _selectedLatLng == null) return;

    final lat = _selectedLatLng!.latitude;
    final lng = _selectedLatLng!.longitude;

    if (_selectedIsFavourite) {
      final matchIndex = _favourites.indexWhere((f) {
        final fData = f.data() as Map<String, dynamic>?;
        if (fData == null) return false;
        return (fData['lat'] - lat).abs() < 0.0001 && (fData['lng'] - lng).abs() < 0.0001;
      });
      if (matchIndex != -1) {
        final match = _favourites[matchIndex];
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favourites')
            .doc(match.id)
            .delete();
      }
      setState(() {
        _selectedIsFavourite = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Removed from Favourites")),
      );
    } else {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favourites')
          .add({
        'lat': lat,
        'lng': lng,
        'address': _selectedAddress,
        'label': _selectedAddress,
        'added_at': FieldValue.serverTimestamp(),
      });
      setState(() {
        _selectedIsFavourite = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saved to Favourites")),
      );
    }
  }

  Future<void> _logCurrentSelectedLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _selectedLatLng == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('locations')
        .add({
      'latitude': _selectedLatLng!.latitude,
      'longitude': _selectedLatLng!.longitude,
      'locationName': _selectedAddress,
      'timestamp': FieldValue.serverTimestamp(),
      'note': "Logged Location",
      'aiAdvice': "Location logged manually from map tap.",
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Location logged to history")),
    );
  }

  Future<void> _submitSelectedLocationNote() async {
    final noteText = _selectedNoteCtrl.text.trim();
    if (noteText.isEmpty || _selectedLatLng == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final uData = userDoc.data() ?? {};
    final fName = uData['first_name'] ?? '';
    final lName = uData['last_name'] ?? '';

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('location_logs')
        .add({
      'lat': _selectedLatLng!.latitude,
      'lng': _selectedLatLng!.longitude,
      'address': _selectedAddress,
      'note': noteText,
      'created_at': FieldValue.serverTimestamp(),
      'expires_at': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
    });

    await FirebaseFirestore.instance
        .collection('community_notes')
        .add({
      'lat': _selectedLatLng!.latitude,
      'lng': _selectedLatLng!.longitude,
      'address': _selectedAddress,
      'note': noteText,
      'uid': user.uid,
      'first_name': fName,
      'last_name': lName,
      'created_at': FieldValue.serverTimestamp(),
      'is_visible': true,
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('locations')
        .add({
      'latitude': _selectedLatLng!.latitude,
      'longitude': _selectedLatLng!.longitude,
      'locationName': _selectedAddress,
      'timestamp': FieldValue.serverTimestamp(),
      'note': noteText,
      'aiAdvice': "User dropped a safety pin note at this location.",
    });

    setState(() {
      _showSelectedNoteInput = false;
      _selectedNoteCtrl.clear();
      _selectedLatLng = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Safety note dropped and shared successfully!")),
    );
  }

  void _showFavourites() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Favourite Locations",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_favourites.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32.0),
                      child: Center(
                        child: Text(
                          "No favourite locations added yet.",
                          style: TextStyle(color: Color(0xFF9CA3AF)),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _favourites.length,
                        itemBuilder: (ctx, idx) {
                          final doc = _favourites[idx];
                          final data = doc.data() as Map<String, dynamic>;
                          final addr = data['address'] ?? 'Unknown location';
                          final lat = data['lat'] as double;
                          final lng = data['lng'] as double;

                          return Dismissible(
                            key: Key(doc.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              color: const Color(0xFFEF4444),
                              child: const Icon(Icons.delete_forever, color: Colors.white),
                            ),
                            onDismissed: (direction) async {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .collection('favourites')
                                    .doc(doc.id)
                                    .delete();
                              }
                            },
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFEEF2FF),
                                child: Icon(Icons.star_rounded, color: Color(0xFFF59E0B)),
                              ),
                              title: Text(
                                addr,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                "Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}",
                                style: const TextStyle(fontSize: 11),
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                setState(() {
                                  _highlightedFavLatLng = LatLng(lat, lng);
                                  _highlightedFavAddress = addr;
                                  _isProgrammaticMoving = true;
                                });
                                _mapController?.animateCamera(
                                  CameraUpdate.newLatLngZoom(_highlightedFavLatLng!, 16.0),
                                );
                                setState(() {
                                  _isProgrammaticMoving = false;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _clearRoute() {
    setState(() {
      _destController.clear();
      _destLatLng = null;
      _routePoints = [];
      _distanceKm = 0.0;
      _durationMinutes = 0.0;
    });
    _hideSuggestions();
  }

  // ─── Markers ──────────────────────────────────────────────────────────────

  Set<Marker> _buildMarkers() {
    if (isHistoricalMode) {
      final Set<Marker> nearbyMarkers = {};
      final bool isDual = widget.isDualMarker || (widget.requesterLatLng != null && widget.recipientLatLng != null);

      if (isDual) {
        if (widget.requesterLatLng != null) {
          nearbyMarkers.add(Marker(
            markerId: const MarkerId('requester_loc'),
            position: widget.requesterLatLng!,
            infoWindow: InfoWindow(
              title: widget.requesterName ?? "You",
              snippet: widget.requesterAddress ?? "Location A",
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          ));
        }
        if (widget.recipientLatLng != null) {
          nearbyMarkers.add(Marker(
            markerId: const MarkerId('recipient_loc'),
            position: widget.recipientLatLng!,
            infoWindow: InfoWindow(
              title: widget.recipientName ?? "Contact",
              snippet: widget.recipientAddress ?? "Location B",
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ));
        }
      } else {
        final pos = widget.initialDestLatLng ?? widget.requesterLatLng;
        final addr = widget.initialDestAddress ?? widget.requesterAddress ?? "Location";
        final title = widget.historicalCardTitle ?? "Nearby Alert Connection Location";

        if (pos != null) {
          nearbyMarkers.add(Marker(
            markerId: const MarkerId('historical_loc'),
            position: pos,
            infoWindow: InfoWindow(
              title: title,
              snippet: addr,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          ));
        }
      }
      return nearbyMarkers;
    }

    final homeState = ref.read(homeProvider);
    final Set<Marker> markers = {};

    // User's location marker (large red directional cursor)
    if (_currentPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('user_location'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        infoWindow: const InfoWindow(title: "My Location"),
        icon: _userDirectionalMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        rotation: _currentHeading,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        zIndexInt: 100,
      ));
    }

    // Destination marker
    if (_destLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: _destLatLng!,
        infoWindow: InfoWindow(title: _destController.text),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }

    // Location Plus marker on map tap
    if (_selectedLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('selected_location_plus'),
        position: _selectedLatLng!,
        icon: _locationPlusMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 90,
        onTap: () {
          _showSelectedLocationCardSheet();
        },
      ));
    }

    // Highlighted Favourite marker
    if (_highlightedFavLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('highlighted_favourite'),
        position: _highlightedFavLatLng!,
        infoWindow: InfoWindow(title: _highlightedFavAddress ?? "Favourited Location"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }

    // Community note markers (violet)
    for (final doc in _communityNotes) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      final lat = data['lat'] as double?;
      final lng = data['lng'] as double?;
      if (lat == null || lng == null) continue;

      markers.add(Marker(
        markerId: MarkerId('community_note_${doc.id}'),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        onTap: () {
          HapticFeedback.lightImpact(); // Light haptic on note marker click
          setState(() {
            _selectedLatLng = LatLng(lat, lng);
            _selectedAddress = data['address'] ?? '';
            _selectedNoteUser = "${data['first_name'] ?? ''} ${data['last_name'] ?? ''}".trim();
            if (_selectedNoteUser!.isEmpty) _selectedNoteUser = "Someone";
            _selectedNoteText = data['note'] ?? '';
            _showSelectedNoteInput = false;
            // Dismiss other overlays
            _showLogCard = false;
            _destLatLng = null;
            _highlightedFavLatLng = null;
          });
        },
      ));
    }

    // Community incident markers (legacy compatibility)
    try {
      final incidents = ref.read(communityProvider).notes;
      for (final incident in incidents) {
        markers.add(Marker(
          markerId: MarkerId('incident_${incident.id}'),
          position: LatLng(incident.latitude, incident.longitude),
          infoWindow: InfoWindow(
            title: '${incident.category}: ${incident.location}',
            snippet: incident.noteText,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            incident.severity == 'High' ? BitmapDescriptor.hueRed : BitmapDescriptor.hueOrange,
          ),
        ));
      }
    } catch (_) {}

    // Log markers (purple) — one per location log
    for (final log in homeState.logs) {
      final latStr = log['latitude'] ?? '';
      final lngStr = log['longitude'] ?? '';
      final lat = double.tryParse(latStr);
      final lng = double.tryParse(lngStr);
      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        // Skip log marker if it's right over current user position to avoid overlapping pins
        if (_currentPosition != null) {
          final dist = _calculateHaversineDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            lat,
            lng,
          );
          if (dist < 50.0) continue;
        }

        final logId = log['id'] ?? latStr;
        markers.add(Marker(
          markerId: MarkerId('log_$logId'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          onTap: () {
            setState(() {
              _tappedLog = log;
              _showLogCard = true;
            });
          },
        ));
      }
    }

    return markers;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _formatDuration(double minutes) {
    if (minutes < 60) return "${minutes.round()} mins";
    final hrs = (minutes / 60).floor();
    final mins = (minutes % 60).round();
    return "${hrs}h ${mins}m";
  }

  Widget _buildMarkerImage(String path, IconData fallbackIcon, Color fallbackColor, {double size = 20}) {
    try {
      final file = File(path);
      if (file.existsSync()) return Image.file(file, width: size, height: size);
    } catch (_) {}
    return Icon(fallbackIcon, color: fallbackColor, size: size);
  }

  // ─── Map Widget ───────────────────────────────────────────────────────────

  Widget _buildMap() {
    final hasKey = dotenv.env['GOOGLE_MAPS_API_KEY_ANDROID']?.isNotEmpty ?? false;
    if (!hasKey) {
      return Container(
        color: const Color(0xFFEFF3F8),
        child: const Center(
          child: Text(
            "Map unavailable.\nAdd GOOGLE_MAPS_API_KEY_ANDROID to .env",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    if (_permissionDenied) {
      return Container(
        color: const Color(0xFFEFF3F8),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off_rounded, size: 64, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              const Text(
                "Location Access Needed",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 8),
              const Text(
                "SafeTrace requires GPS access to show you on the map, log safety notes, and compute relative incident distances.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () => Geolocator.openAppSettings(),
                icon: const Icon(Icons.settings, color: Colors.white),
                label: const Text("Open Settings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    final homeState = ref.watch(homeProvider);
    final userLatLng = LatLng(homeState.currentLatitude, homeState.currentLongitude);
    final target = isHistoricalMode
        ? (widget.initialDestLatLng ?? widget.requesterLatLng ?? const LatLng(6.5244, 3.3792))
        : ((_currentPosition != null)
            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
            : ((userLatLng.latitude != 0.0 && userLatLng.longitude != 0.0)
                ? userLatLng
                : (_selectedLatLng ?? const LatLng(0.0, 0.0))));

    return GoogleMap(
      onMapCreated: (controller) {
        _mapController = controller;
        final bool isDual = widget.isDualMarker || (widget.requesterLatLng != null && widget.recipientLatLng != null);
        if (isHistoricalMode && isDual && widget.requesterLatLng != null && widget.recipientLatLng != null) {
          final req = widget.requesterLatLng!;
          final rec = widget.recipientLatLng!;
          final southWest = LatLng(
            min(req.latitude, rec.latitude),
            min(req.longitude, rec.longitude),
          );
          final northEast = LatLng(
            max(req.latitude, rec.latitude),
            max(req.longitude, rec.longitude),
          );
          final bounds = LatLngBounds(southwest: southWest, northeast: northEast);
          Future.delayed(const Duration(milliseconds: 300), () {
            _isProgrammaticMoving = true;
            _mapController?.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 80.0),
            );
            _isProgrammaticMoving = false;
          });
        } else if (isHistoricalMode && (widget.initialDestLatLng != null || widget.requesterLatLng != null)) {
          final bool isDual = widget.isDualMarker || (widget.requesterLatLng != null && widget.recipientLatLng != null);
          if (isDual && widget.requesterLatLng != null && widget.recipientLatLng != null) {
            Future.delayed(const Duration(milliseconds: 200), () {
              _fitDualMarkerBounds(widget.requesterLatLng!, widget.recipientLatLng!);
            });
          } else {
            final pos = widget.initialDestLatLng ?? widget.requesterLatLng!;
            Future.delayed(const Duration(milliseconds: 200), () {
              _mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(pos, 16.0),
              );
            });
          }
        }
      },
      initialCameraPosition: CameraPosition(target: target, zoom: isHistoricalMode ? 16.0 : 14.5),
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      markers: _buildMarkers(),
      polylines: {
        if (_animatedRoutePoints.isNotEmpty || _routePoints.isNotEmpty) ...[
          Polyline(
            polylineId: const PolylineId('route_glow'),
            points: _animatedRoutePoints.isNotEmpty ? _animatedRoutePoints : _routePoints,
            color: (isHistoricalMode ? const Color(0xFF6C3FC4) : const Color(0xFF4F46E5)).withValues(alpha: 0.35),
            width: 10,
          ),
          Polyline(
            polylineId: const PolylineId('route'),
            points: _animatedRoutePoints.isNotEmpty ? _animatedRoutePoints : _routePoints,
            color: isHistoricalMode ? const Color(0xFF6C3FC4) : const Color(0xFF4F46E5),
            width: 5,
          ),
        ],
      },
      onCameraMoveStarted: () {
        if (!_isProgrammaticMoving) {
          setState(() {
            _userPanned = true;
          });
        }
      },
      onLongPress: (latLng) {
        HapticFeedback.mediumImpact();
      },
      onTap: (latLng) {
        // Android marker tap check: if tapped point matches any rendered marker within 0.0001 deg, ignore map tap
        final currentMarkers = _buildMarkers();
        final isMarkerTap = currentMarkers.any((m) {
          return (m.position.latitude - latLng.latitude).abs() < 0.0001 &&
                 (m.position.longitude - latLng.longitude).abs() < 0.0001;
        });
        if (isMarkerTap) return;

        HapticFeedback.mediumImpact();

        // Step 1: Store tapped coordinate atomically
        final selectedDestinationLatLng = LatLng(latLng.latitude, latLng.longitude);

        if (_showLogCard) {
          setState(() => _showLogCard = false);
        }
        _hideSuggestions();

        setState(() {
          _selectedLatLng = selectedDestinationLatLng;
          _destLatLng = selectedDestinationLatLng;
          _selectedAddress = "Fetching address...";
          _selectedIsFavourite = false;
          _showSelectedNoteInput = false;
          _selectedLocationLoading = true;
          _selectedNoteText = null;
          _selectedNoteUser = null;
        });

        // Step 3: Directions API call using exact tapped coordinate
        _calculateRouteFromLatLng(selectedDestinationLatLng, "Tapped Location");

        // Step 2: Reverse geocode exact tapped coordinate
        LocationService.reverseGeocode(selectedDestinationLatLng.latitude, selectedDestinationLatLng.longitude).then((addr) {
          if (!mounted) return;
          final isFav = _favourites.any((f) {
            final fData = f.data() as Map<String, dynamic>?;
            if (fData == null) return false;
            final fLat = fData['lat'] as double?;
            final fLng = fData['lng'] as double?;
            if (fLat == null || fLng == null) return false;
            return (fLat - selectedDestinationLatLng.latitude).abs() < 0.0001 && (fLng - selectedDestinationLatLng.longitude).abs() < 0.0001;
          });
          setState(() {
            _selectedAddress = addr;
            _selectedIsFavourite = isFav;
            _selectedLocationLoading = false;
            _destController.text = addr;
          });
        }).catchError((_) {
          if (!mounted) return;
          final fallback = "Lat: ${selectedDestinationLatLng.latitude.toStringAsFixed(4)}, Lng: ${selectedDestinationLatLng.longitude.toStringAsFixed(4)}";
          setState(() {
            _selectedAddress = fallback;
            _selectedLocationLoading = false;
            _destController.text = fallback;
          });
        });
      },
    );
  }

  void _showSelectedLocationCardSheet() {
    if (_selectedLatLng == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF242838) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Location Details",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedAddress ?? "Fetching address...",
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _calculateRouteFromLatLng(_selectedLatLng!, _selectedAddress ?? "Selected Location");
                        },
                        icon: const Icon(Icons.directions, color: Colors.white),
                        label: const Text("Get Directions", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF1A1D27) : const Color(0xFFF3F4F6),
                        padding: const EdgeInsets.all(12),
                      ),
                      onPressed: () {
                        _toggleFavourite();
                      },
                      icon: Icon(
                        _selectedIsFavourite ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                        color: _selectedIsFavourite ? const Color(0xFF4F46E5) : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── History Bottom Sheet ─────────────────────────────────────────────────

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HistorySheet(
        initialFilter: _historyFilter,
        onFilterChanged: (f) => setState(() => _historyFilter = f),
      ),
    );
  }

  // ─── Share Location ───────────────────────────────────────────────────────

  void _shareLocation() {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user != null) {
      Share.share(
        "Securely track my live location on SafeTrace: https://safetrace.live/track/${user.uid}",
        subject: "SafeTrace Live Location",
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sign in to share your location")),
      );
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Listen for note card click redirection from community feed
    ref.listen<CommunityNoteModel?>(selectedCommunityNoteProvider, (prev, next) {
      if (next != null) {
        final latLng = LatLng(next.latitude, next.longitude);
        setState(() {
          _selectedLatLng = latLng;
          _selectedAddress = next.location;
          _selectedNoteUser = "${next.firstName} ${next.lastName}".trim();
          if (_selectedNoteUser!.isEmpty) _selectedNoteUser = "Someone";
          _selectedNoteText = next.noteText;
          _showSelectedNoteInput = false;
          _showLogCard = false;
          _destLatLng = null;
          _highlightedFavLatLng = null;
        });

        HapticFeedback.lightImpact();

        if (_mapController != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15.0));
        }

        // Reset provider
        Future.microtask(() {
          ref.read(selectedCommunityNoteProvider.notifier).state = null;
        });
      }
    });

    // Listen for updates on communityProvider to re-run the 8km filter
    ref.listen(communityProvider, (prev, next) {
      if (_currentPosition != null) {
        _filterNearbyNotes(_currentPosition!);
      }
    });

    final String userAddress = _currentUserAddress ?? "Current Location";

    final hasRoute = _destLatLng != null;
    final distanceText = hasRoute ? "${_distanceKm.toStringAsFixed(1)} km" : "";
    final timeText = hasRoute ? _formatDuration(_durationMinutes) : "";

    final hasHighRiskIncidents = ref.watch(communityProvider).notes.any((n) => n.severity == 'High');
    final safetyStatus = !hasRoute
        ? "Safe"
        : (hasHighRiskIncidents ? "High Risk" : (_distanceKm > 50 ? "Moderate Risk" : "Safe"));
    final safetyColor = safetyStatus == "High Risk"
        ? const Color(0xFFEF4444)
        : (safetyStatus == "Moderate Risk" ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
    final safetyBg = safetyStatus == "High Risk"
        ? const Color(0xFFFEE2E2)
        : (safetyStatus == "Moderate Risk" ? const Color(0xFFFEF3C7) : const Color(0xFFE8F5E9));

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Full-screen Map ──
          Positioned.fill(child: _buildMap()),

          // ── Top overlay (Reports + History + Favourites) ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Favourites button
                    _MapActionButton(
                      icon: Icons.star_rounded,
                      label: "Favourites",
                      onTap: _showFavourites,
                    ),
                    const SizedBox(width: 8),
                    // History button
                    _MapActionButton(
                      icon: Icons.history_rounded,
                      label: "History",
                      onTap: _showHistory,
                    ),
                    const SizedBox(width: 8),
                    // Reports button
                    _MapActionButton(
                      icon: Icons.warning_amber_rounded,
                      label: "Reports",
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const _ReportsNavigatorProxy(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── My Location (centre) Button ──
          Positioned(
            right: 12,
            bottom: MediaQuery.of(context).size.height * 0.50,
            child: GestureDetector(
              onTap: _centerOnUser,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                alignment: Alignment.center,
                child: _buildMarkerImage(
                  "D:\\app files\\Spotlight Marker.png",
                  Icons.my_location_rounded,
                  const Color(0xFF4F46E5),
                ),
              ),
            ),
          ),

          // ── Selected Tap Location Bubble / Card ──
          if (_selectedLatLng != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).size.height * 0.48, // Place it nicely above the default sheet height
              child: Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5)),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _selectedNoteUser != null 
                                          ? "Note by $_selectedNoteUser"
                                          : (_selectedIsFavourite ? "⭐ Favourited Location" : "Selected Location"),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                    ),
                                    if (_selectedLocationLoading) ...[
                                      const SizedBox(width: 8),
                                      const SizedBox(
                                        width: 10,
                                        height: 10,
                                        child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF4F46E5)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedAddress ?? "Fetching address...",
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _selectedLatLng = null;
                                _selectedNoteText = null;
                                _selectedNoteUser = null;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Coordinates: ${_selectedLatLng!.latitude.toStringAsFixed(5)}, ${_selectedLatLng!.longitude.toStringAsFixed(5)}",
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                      ),
                      
                      if (_selectedNoteText != null) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        const Text(
                          "NOTE",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedNoteText!,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937), height: 1.4),
                        ),
                      ],

                      if (_selectedNoteText == null) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _selectedIsFavourite ? Icons.star_rounded : Icons.star_border_rounded,
                                color: _selectedIsFavourite ? const Color(0xFFF59E0B) : const Color(0xFF9CA3AF),
                                size: 28,
                              ),
                              onPressed: _toggleFavourite,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                Icons.edit_note_rounded,
                                color: _showSelectedNoteInput ? const Color(0xFF4F46E5) : const Color(0xFF9CA3AF),
                                size: 28,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showSelectedNoteInput = !_showSelectedNoteInput;
                                });
                              },
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              onPressed: _logCurrentSelectedLocation,
                              icon: const Icon(Icons.bookmark_added_rounded, size: 18, color: Colors.white),
                              label: const Text("Log Location", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ],
                        ),
                      ],

                      if (_showSelectedNoteInput && _selectedNoteText == null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _selectedNoteCtrl,
                                decoration: InputDecoration(
                                  hintText: "Add note about this place...",
                                  hintStyle: const TextStyle(fontSize: 13),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.send_rounded, color: Color(0xFF4F46E5)),
                              onPressed: _submitSelectedLocationNote,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // ── Tapped Log Card ──
          if (_showLogCard && _tappedLog != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: MediaQuery.of(context).size.height * 0.48,
              child: _LogTapCard(
                log: _tappedLog!,
                onClose: () => setState(() => _showLogCard = false),
              ),
            ),

          // ── Draggable Bottom Sheet ──
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.25,
            minChildSize: 0.25,
            maxChildSize: 0.92,
            snap: true,
            snapSizes: const [0.25, 0.55, 0.92],
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4)),
                  ],
                ),
                child: Column(
                  children: [
                    // Drag handle
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0, bottom: 4.0),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),

                    // Scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isHistoricalMode) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF6366F1), width: 1.5),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.wifi_tethering_rounded, color: Color(0xFF4F46E5), size: 22),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            widget.historicalCardTitle ?? "Nearby Alert Connection Location",
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF1E1B4B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (widget.connectedAt != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        "Connected at ${widget.connectedAt!.hour.toString().padLeft(2, '0')}:${widget.connectedAt!.minute.toString().padLeft(2, '0')}",
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4338CA)),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    const Divider(color: Color(0xFFC7D2FE), height: 1),
                                    const SizedBox(height: 12),
                                    if (widget.isDualMarker || (widget.requesterLatLng != null && widget.recipientLatLng != null)) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6C3FC4).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFF6C3FC4).withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.straighten_rounded, color: Color(0xFF6C3FC4), size: 20),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _distanceKm != null
                                                      ? (_distanceKm! < 1.0
                                                          ? "Distance: ${(_distanceKm! * 1000).round()} m"
                                                          : "Distance: ${_distanceKm!.toStringAsFixed(2)} km")
                                                      : (_isRouteLoading ? "Calculating distance..." : "Distance calculated"),
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF6C3FC4),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (_durationMinutes != null && _durationMinutes! > 0)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF6C3FC4),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  "~${_durationMinutes} mins drive",
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.location_on_rounded, color: Color(0xFF7C3AED), size: 18),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              "${widget.requesterName ?? 'You'} was at ${widget.requesterAddress ?? 'Location A'}",
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF312E81)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.location_on_rounded, color: Color(0xFF0284C7), size: 18),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              "${widget.recipientName ?? 'Contact'} was at ${widget.recipientAddress ?? 'Location B'}",
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF312E81)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.location_on_rounded, color: Color(0xFF7C3AED), size: 18),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              widget.initialDestAddress ?? widget.requesterAddress ?? "Location",
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF312E81)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ] else ...[
                              // ── Search card ──
                              _SearchCard(
                                destController: _destController,
                                searchFocusNode: _searchFocusNode,
                                layerLink: _searchLayerLink,
                                userAddress: userAddress,
                                isLoading: _isRouteLoading,
                                hasRoute: hasRoute,
                                onChanged: _onSearchChanged,
                                onSubmit: (_) => _calculateRoute(),
                                onClear: _clearRoute,
                                onLogLocation: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const LogNotesScreen()),
                                  );
                                },
                                onShareLocation: _shareLocation,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // ── Route results (shown only after a search) ──
                            if (_isRouteLoading)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20.0),
                                child: Center(
                                  child: Column(
                                    children: [
                                      CircularProgressIndicator(color: Color(0xFFEF4444)),
                                      SizedBox(height: 12),
                                      Text(
                                        "Calculating safest route...",
                                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else if (hasRoute) ...[
                              // Route header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Current Location → ${_destController.text}",
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF111827),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: safetyBg,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            safetyStatus,
                                            style: TextStyle(
                                              color: safetyColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        timeText,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        distanceText,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6B7280),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                            ],

                            // ── Community Safety Notes ──
                            const Text(
                              "Community Safety Notes",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 12),

                             if (_nearbyNotes.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24.0),
                                child: Center(
                                  child: Text(
                                    "No community reports near you right now.",
                                    style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              )
                            else ...[
                              ..._nearbyNotes.take(8).map((incident) {
                                final tag = incident.category.toUpperCase();
                                Color color = const Color(0xFF2563EB);
                                Color bg = const Color(0xFFDBEAFE);
                                IconData icon = Icons.info_outline;

                                if (tag.contains("POLICE") || tag.contains("CHECKPOINT")) {
                                  color = const Color(0xFFD97706);
                                  bg = const Color(0xFFFEF3C7);
                                  icon = Icons.local_police_outlined;
                                } else if (tag.contains("TRAFFIC")) {
                                  color = const Color(0xFF2563EB);
                                  bg = const Color(0xFFDBEAFE);
                                  icon = Icons.traffic_outlined;
                                } else if (tag.contains("ROBBERY") || tag.contains("RIOT") || tag.contains("SUSPICIOUS")) {
                                  color = const Color(0xFFEF4444);
                                  bg = const Color(0xFFFEE2E2);
                                  icon = Icons.warning_amber_rounded;
                                } else if (tag.contains("ACCIDENT")) {
                                  color = const Color(0xFFEF4444);
                                  bg = const Color(0xFFFEE2E2);
                                  icon = Icons.car_crash_outlined;
                                } else if (tag.contains("FLOOD")) {
                                  color = const Color(0xFF0D9488);
                                  bg = const Color(0xFFCCFBF1);
                                  icon = Icons.water_drop_outlined;
                                }

                                return _CommunitySafetyNote(
                                  title: incident.location,
                                  tag: tag,
                                  tagColor: color,
                                  tagBg: bg,
                                  desc: incident.noteText,
                                  time: incident.timeAgo,
                                  icon: icon,
                                );
                              }),
                              if (_nearbyNotes.length > 8)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: TextButton.icon(
                                      onPressed: () {
                                        ref.read(homeShellIndexProvider.notifier).state = 2; // Community feed tab
                                      },
                                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                                      label: const Text("View more in Community"),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFF4F46E5),
                                        alignment: Alignment.centerLeft,
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                ),
                            ],

                            // Bottom padding
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ═══════════════════════════════════════════════════════════════════════════

/// Search card with autocomplete, location line, and Log/Share action icons
class _SearchCard extends StatelessWidget {
  final TextEditingController destController;
  final FocusNode searchFocusNode;
  final LayerLink layerLink;
  final String userAddress;
  final bool isLoading;
  final bool hasRoute;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClear;
  final VoidCallback onLogLocation;
  final VoidCallback onShareLocation;

  const _SearchCard({
    required this.destController,
    required this.searchFocusNode,
    required this.layerLink,
    required this.userAddress,
    required this.isLoading,
    required this.hasRoute,
    required this.onChanged,
    required this.onSubmit,
    required this.onClear,
    required this.onLogLocation,
    required this.onShareLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Where to?" search field
          CompositedTransformTarget(
            link: layerLink,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  if (isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF4444)),
                    )
                  else
                    const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: destController,
                      focusNode: searchFocusNode,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                      decoration: const InputDecoration(
                        hintText: "Where to?",
                        hintStyle: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: onChanged,
                      onSubmitted: onSubmit,
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                  if (destController.text.isNotEmpty)
                    GestureDetector(
                      onTap: onClear,
                      child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF9CA3AF)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // From: current location + action icons row
          Row(
            children: [
              const Icon(Icons.my_location_rounded, size: 14, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "From: $userAddress",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Log Location action button
              _ActionIconButton(
                icon: Icons.add_location_alt_outlined,
                label: "Log",
                color: const Color(0xFF4F46E5),
                bg: const Color(0xFFEEF2FF),
                onTap: onLogLocation,
              ),
              const SizedBox(width: 8),
              // Share Location as icon only
              _ActionIconButton(
                icon: Icons.share_outlined,
                label: "Share",
                color: const Color(0xFF059669),
                bg: const Color(0xFFECFDF5),
                onTap: onShareLocation,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small icon + label action button used in search card
class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _ActionIconButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top-right map action button (Reports / History)
class _MapActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MapActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF4F46E5)),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Route stat box (Distance / With Traffic)
class _StatBox extends StatelessWidget {
  final String value;
  final String label;

  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Community safety note card
class _CommunitySafetyNote extends StatelessWidget {
  final String title;
  final String tag;
  final Color tagColor;
  final Color tagBg;
  final String desc;
  final String time;
  final IconData icon;

  const _CommunitySafetyNote({
    required this.title,
    required this.tag,
    required this.tagColor,
    required this.tagBg,
    required this.desc,
    required this.time,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: tagColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(4)),
                      child: Text(tag,
                          style: TextStyle(color: tagColor, fontSize: 8, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(desc,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), height: 1.35)),
                const SizedBox(height: 6),
                Text(time,
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card that appears at the bottom of the map when a log marker is tapped
class _LogTapCard extends StatelessWidget {
  final Map<String, String> log;
  final VoidCallback onClose;

  const _LogTapCard({required this.log, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final location = log['location'] ?? 'Unknown location';
    final note = log['note'] ?? '';
    final timestampStr = log['timestamp'] ?? '';
    String timeLabel = '';
    try {
      final dt = DateTime.parse(timestampStr).toLocal();
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final now = DateTime.now();
      final dayStr = (dt.year == now.year && dt.month == now.month && dt.day == now.day)
          ? 'Today'
          : '${dt.day}/${dt.month}/${dt.year}';
      timeLabel = '$dayStr at $hour:$min $ampm';
    } catch (_) {}

    return AnimatedSlide(
      offset: Offset.zero,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.location_on_rounded, color: Color(0xFF7C3AED), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (timeLabel.isNotEmpty)
                        Text(
                          timeLabel,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_rounded, size: 14, color: Color(0xFF6B7280)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Suggestion overlay rendered via the Overlay system
class _SuggestionOverlay extends StatelessWidget {
  final LayerLink layerLink;
  final List<Map<String, String>> suggestions;
  final bool isLoading;
  final ValueChanged<Map<String, String>> onSelect;

  const _SuggestionOverlay({
    required this.layerLink,
    required this.suggestions,
    required this.isLoading,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return CompositedTransformFollower(
      link: layerLink,
      showWhenUnlinked: false,
      offset: const Offset(0, 52),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: screenWidth - 64,
          child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF4444)),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    itemCount: suggestions.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    itemBuilder: (context, index) {
                      final s = suggestions[index];
                      return InkWell(
                        onTap: () => onSelect(s),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.place_outlined, size: 16, color: Color(0xFF9CA3AF)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  s['label'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111827),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    ),
    );
  }
}

/// History bottom sheet shown when History button is tapped
class _HistorySheet extends ConsumerStatefulWidget {
  final String initialFilter;
  final ValueChanged<String> onFilterChanged;

  const _HistorySheet({required this.initialFilter, required this.onFilterChanged});

  @override
  ConsumerState<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends ConsumerState<_HistorySheet> {
  late String _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final homeLogs = ref.watch(homeProvider).logs;

    final historyItems = homeLogs.map((log) {
      final loc = log["location"] ?? "Unknown Location";
      final parts = loc.split(",");
      final title = parts.first.trim();
      final sub = parts.length > 1 ? parts.sublist(1).join(",").trim() : "";
      final note = log["note"] ?? "";

      final timestampStr = log["timestamp"] ?? "";
      String time = "";
      String day = "";
      try {
        final dt = DateTime.parse(timestampStr).toLocal();
        final now = DateTime.now();
        final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        final min = dt.minute.toString().padLeft(2, '0');
        final ampm = dt.hour >= 12 ? "PM" : "AM";
        time = "$hour:$min $ampm";
        if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
          day = "Today";
        } else if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) {
          day = "Yesterday";
        } else {
          day = "${dt.day}/${dt.month}/${dt.year}";
        }
      } catch (_) {}

      return {
        "title": title,
        "sub": sub,
        "note": note,
        "time": time,
        "day": day,
      };
    }).toList();

    final filtered = historyItems.where((item) {
      if (_filter == "Today") return item["day"] == "Today";
      if (_filter == "Yesterday") return item["day"] == "Yesterday";
      return true;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, size: 20, color: Color(0xFF4F46E5)),
                    const SizedBox(width: 8),
                    const Text(
                      "History",
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                    ),
                    const Spacer(),
                    Text(
                      "${filtered.length} logs",
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Filter pills
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: ["All", "Today", "Yesterday"].map((f) {
                    final isSelected = _filter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _filter = f);
                          widget.onFilterChanged(f);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF131522) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF131522) : const Color(0xFFE5E7EB),
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            f,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),

              // List
              Expanded(
                child: filtered.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.history_toggle_off_rounded, size: 48, color: Color(0xFFD1D5DB)),
                          SizedBox(height: 12),
                          Text(
                            "No location logs yet.",
                            style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Use 'Log Location' to save your whereabouts.",
                            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                          ),
                        ],
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        itemBuilder: (context, index) {
                          final log = filtered[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3E8FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.location_on_rounded,
                                      color: Color(0xFF7C3AED), size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        log["title"]!,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                      if ((log["sub"] ?? '').isNotEmpty) ...[
                                        const SizedBox(height: 1),
                                        Text(
                                          log["sub"]!,
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      if ((log["note"] ?? '').isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Text(
                                          log["note"]!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF4B5563),
                                            height: 1.35,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      log["time"]!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      log["day"]!,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        "7d",
                                        style: TextStyle(
                                          color: Color(0xFF4F46E5),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              // Footer notice
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.access_time_rounded, color: Color(0xFF2563EB), size: 15),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Location logs are automatically deleted after 7 days.",
                        style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Proxy widget to show reports via the community reports screen
class _ReportsNavigatorProxy extends ConsumerWidget {
  const _ReportsNavigatorProxy();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Navigate back and activate reports tab via homeShellIndexProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pop();
      ref.read(homeShellIndexProvider.notifier).state = 2;
    });
    return const SizedBox.shrink();
  }
}
