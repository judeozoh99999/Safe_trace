import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../location/services/location_service.dart';

class SelectCommunityLocationScreen extends StatefulWidget {
  final LatLng currentGpsLocation;
  final String currentSelectedAddress;

  const SelectCommunityLocationScreen({
    super.key,
    required this.currentGpsLocation,
    required this.currentSelectedAddress,
  });

  @override
  State<SelectCommunityLocationScreen> createState() => _SelectCommunityLocationScreenState();
}

class _SelectCommunityLocationScreenState extends State<SelectCommunityLocationScreen> {
  GoogleMapController? _mapController;
  late LatLng _selectedLatLng;
  String _selectedAddress = "Fetching address...";
  bool _isLoadingAddress = false;
  final TextEditingController _searchCtrl = TextEditingController();
  List<String> _suggestions = [];
  bool _showSuggestions = false;

  static const List<String> _nigerianLocations = [
    "Lagos Island, Lagos", "Lagos Mainland, Lagos", "Ikeja, Lagos", "Surulere, Lagos",
    "Yaba, Lagos", "Lekki, Lagos", "Ajah, Lagos", "Apapa, Lagos", "Badagry, Lagos",
    "Ikorodu, Lagos", "Oshodi, Lagos", "Mushin, Lagos", "Agege, Lagos", "Alimosho, Lagos",
    "Victoria Island, Lagos", "Ikoyi, Lagos", "Oniru, Lagos", "Maryland, Lagos",
    "Gbagada, Lagos", "Magodo, Lagos", "Ojota, Lagos", "Mile 2, Lagos", "Festac Town, Lagos",
    "Satellite Town, Lagos", "Amuwo Odofin, Lagos", "Ojo, Lagos", "Abuja Municipal, FCT",
    "Garki, FCT", "Wuse, FCT", "Maitama, FCT", "Gwarinpa, FCT", "Jabi, FCT", "Kubwa, FCT",
    "Lugbe, FCT", "Kuje, FCT", "Asokoro, FCT", "Gudu, FCT", "Utako, FCT", "Kano Municipal, Kano",
    "Fagge, Kano", "Dala, Kano", "Gwale, Kano", "Nasarawa, Kano", "Tarauni, Kano",
    "Ungogo, Kano", "Port Harcourt, Rivers", "Obio-Akpor, Rivers", "Eleme, Rivers",
    "Ikwerre, Rivers", "Oyigbo, Rivers", "Emohua, Rivers", "Ibadan North, Oyo",
    "Ibadan South, Oyo", "Oluyole, Oyo", "Lagelu, Oyo", "Ona-Ara, Oyo", "Akinyele, Oyo",
    "Onitsha, Anambra", "Awka, Anambra", "Nnewi, Anambra", "Enugu North, Enugu",
    "Enugu South, Enugu", "Oji River, Enugu", "Benin City, Edo", "Ikpoba-Okha, Edo",
    "Oredo, Edo", "Egor, Edo", "Ovia North-East, Edo", "Warri, Delta", "Uvwie, Delta",
    "Effurun, Delta", "Sapele, Delta", "Asaba, Delta", "Calabar Municipal, Cross River",
    "Calabar South, Cross River", "Ogoja, Cross River", "Uyo, Akwa Ibom", "Eket, Akwa Ibom",
    "Oron, Akwa Ibom", "Maiduguri, Borno", "Jere, Borno", "Konduga, Borno",
    "Kaduna North, Kaduna", "Kaduna South, Kaduna", "Chikun, Kaduna", "Igabi, Kaduna",
    "Zaria, Kaduna", "Jos North, Plateau", "Jos South, Plateau", "Bukuru, Plateau",
    "Ilorin East, Kwara", "Ilorin West, Kwara", "Offa, Kwara", "Oshogbo, Osun",
    "Ile-Ife, Osun", "Ilesa, Osun", "Akure, Ondo", "Ado-Ekiti, Ekiti", "Abeokuta North, Ogun",
    "Abeokuta South, Ogun", "Sagamu, Ogun", "Ijebu-Ode, Ogun", "Sokoto North, Sokoto",
    "Sokoto South, Sokoto", "Gusau, Zamfara", "Minna, Niger", "Bida, Niger",
    "Kontagora, Niger", "Bauchi, Bauchi", "Gombe, Gombe", "Jalingo, Taraba",
    "Yola North, Adamawa", "Yola South, Adamawa", "Makurdi, Benue", "Gboko, Benue",
    "Lafia, Nasarawa", "Lokoja, Kogi", "Ankpa, Kogi", "Okene, Kogi", "Owerri North, Imo",
    "Owerri West, Imo", "Orlu, Imo", "Orji, Imo", "Ngor Okpala, Imo", "Umuahia North, Abia",
    "Umuahia South, Abia", "Aba North, Abia", "Aba South, Abia", "Damaturu, Yobe",
  ];

  @override
  void initState() {
    super.initState();
    _selectedLatLng = widget.currentGpsLocation;
    _selectedAddress = widget.currentSelectedAddress;
    _reverseGeocodePoint(_selectedLatLng);
  }

  Future<void> _reverseGeocodePoint(LatLng point) async {
    setState(() => _isLoadingAddress = true);
    try {
      final addr = await LocationService.reverseGeocode(point.latitude, point.longitude);
      if (mounted) {
        setState(() {
          _selectedAddress = addr.isNotEmpty ? addr : "Lat: ${point.latitude.toStringAsFixed(4)}, Lng: ${point.longitude.toStringAsFixed(4)}";
          _isLoadingAddress = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _selectedAddress = "Lat: ${point.latitude.toStringAsFixed(4)}, Lng: ${point.longitude.toStringAsFixed(4)}";
          _isLoadingAddress = false;
        });
      }
    }
  }

  void _onSearchChanged(String text) {
    if (text.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    final query = text.toLowerCase();
    final matches = _nigerianLocations
        .where((loc) => loc.toLowerCase().contains(query))
        .take(8)
        .toList();

    setState(() {
      _suggestions = matches;
      _showSuggestions = matches.isNotEmpty;
    });
  }

  void _selectSuggestion(String suggestion) {
    _searchCtrl.text = suggestion;
    setState(() {
      _showSuggestions = false;
    });

    LocationService.geocodeAddress(suggestion).then((coord) {
      if (coord != null && mounted) {
        final newPoint = LatLng(coord.latitude, coord.longitude);
        setState(() {
          _selectedLatLng = newPoint;
          _selectedAddress = suggestion;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newPoint, 13.5));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1D27) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : const Color(0xFF111827), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Select Community Location",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF111827)),
        ),
      ),
      body: Stack(
        children: [
          // 1. Full Screen Google Map
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: CameraPosition(target: _selectedLatLng, zoom: 13.5),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: {
              Marker(
                markerId: const MarkerId('community_selected_pin'),
                position: _selectedLatLng,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              ),
            },
            onTap: (latLng) {
              setState(() {
                _selectedLatLng = latLng;
              });
              _reverseGeocodePoint(latLng);
            },
          ),

          // 2. Top Search & Filter Bar
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // Current Location Reset Button
                GestureDetector(
                  onTap: () async {
                    try {
                      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
                      final gpsPoint = LatLng(pos.latitude, pos.longitude);
                      setState(() {
                        _selectedLatLng = gpsPoint;
                      });
                      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(gpsPoint, 14.0));
                      _reverseGeocodePoint(gpsPoint);
                    } catch (_) {}
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF242838) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.my_location_rounded, color: Color(0xFFEF4444), size: 18),
                        SizedBox(width: 8),
                        Text(
                          "Use My Current Location",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFEF4444)),
                        ),
                      ],
                    ),
                  ),
                ),

                // Search Bar Input
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1D27) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: _onSearchChanged,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          decoration: const InputDecoration(
                            hintText: "Search for a place in Nigeria",
                            hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      if (_searchCtrl.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: Color(0xFF9CA3AF)),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        ),
                    ],
                  ),
                ),

                // Autocomplete Suggestions List
                if (_showSuggestions)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF242838) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFFEF4444)),
                          title: Text(
                            suggestion,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          onTap: () => _selectSuggestion(suggestion),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 3. Bottom Confirmation Card
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D27) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF2E3347) : const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isLoadingAddress ? "Resolving location..." : _selectedAddress,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(context, {
                          'latLng': _selectedLatLng,
                          'address': _selectedAddress,
                        });
                      },
                      child: const Text(
                        "Confirm Location",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ),
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
