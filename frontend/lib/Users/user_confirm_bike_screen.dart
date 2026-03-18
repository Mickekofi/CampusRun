import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// Add this import near your other imports at the top
import 'user_payment_screen.dart';

import '../admin_ip.dart';
import '../log_session.dart';
import '../theme_settings.dart';
import '../widgets/app_status_chip.dart';

class UserConfirmBikeScreen extends StatefulWidget {
  const UserConfirmBikeScreen({super.key});

  @override
  State<UserConfirmBikeScreen> createState() => _UserConfirmBikeScreenState();
}

class _UserConfirmBikeScreenState extends State<UserConfirmBikeScreen> {
  bool _isLoading = true;
  String _errorMessage = '';

  Map<String, dynamic>? _bikeDetails;
  List<dynamic> _dropoffStations = [];
  int? _selectedDropoffId;
  String _staticFare = "0.00";

  // THE FIX 1: Renamed variable to match the new reality
  String _allocatedTime = "N/A";
  bool _isFetchingFare = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    final userId = LogSession.instance.userId;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Authentication error. Please log in.";
        _isLoading = false;
      });
      return;
    }

    try {
      final detailsRes = await http.get(
        Uri.parse(
          '${AdminIp.baseUrl}/api/confirm-bike/pending?user_id=$userId',
        ),
      );

      if (detailsRes.statusCode == 200) {
        final detailsBody = jsonDecode(detailsRes.body);
        final stationsRes = await http.get(
          Uri.parse('${AdminIp.baseUrl}/api/confirm-bike/dropoff-stations'),
        );

        if (!mounted) return;
        setState(() {
          _bikeDetails = detailsBody['data'];
          if (stationsRes.statusCode == 200) {
            _dropoffStations = jsonDecode(stationsRes.body)['stations'];
          }
          _isLoading = false;
        });
      } else {
        // NO PENDING BIKE - SHOW EMPTY STATE
        if (!mounted) return;
        setState(() {
          _bikeDetails = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Network connection failed.";
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchStaticFare(int dropoffId) async {
    setState(() {
      _selectedDropoffId = dropoffId;
      _isFetchingFare = true;
    });

    try {
      final res = await http.post(
        Uri.parse('${AdminIp.baseUrl}/api/confirm-bike/estimate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pickup_id': _bikeDetails!['pickup_station_id'],
          'dropoff_id': dropoffId,
        }),
      );

      if (!mounted) return;
      final body = jsonDecode(res.body);

      if (res.statusCode == 200) {
        setState(() {
          _staticFare = body['estimate']?.toString() ?? "0.00";

          // THE FIX 2: Grabbing the raw seconds and formatting as minutes
          if (body['allocated_time'] != null) {
            int seconds = int.tryParse(body['allocated_time'].toString()) ?? 0;
            int mins = seconds ~/ 60;
            _allocatedTime = "$mins mins";
          } else {
            _allocatedTime = "N/A";
          }
        });
      } else {
        // Handle routes that the admin hasn't configured
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppBrandColors.redYellowStart,
            content: Text(body['message'] ?? 'Route not available.'),
          ),
        );
        setState(() {
          _selectedDropoffId = null; // Reset selection so they can't confirm
        });
      }
    } catch (e) {
      // Ignore silently, let user try again
    } finally {
      if (mounted) setState(() => _isFetchingFare = false);
    }
  }

  Future<void> _confirmBike() async {
    if (_selectedDropoffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppBrandColors.redYellowStart,
          content: Text('Please select a valid drop-off station first.'),
        ),
      );
      return;
    }

    // Optional: Show a brief loading indicator while confirming
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppBrandColors.greenMid),
      ),
    );

    try {
      final res = await http.post(
        Uri.parse('${AdminIp.baseUrl}/api/confirm-bike/confirm'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': LogSession.instance.userId,
          'dropoff_station_id': _selectedDropoffId,
        }),
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Dismiss loading dialog

      if (res.statusCode == 200) {
        // SUCCESS: Navigate to the Payment Screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserPaymentScreen()),
        );
      } else {
        final body = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppBrandColors.redYellowStart,
            content: Text(body['message'] ?? 'Failed to confirm bike.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Dismiss loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppBrandColors.redYellowStart,
          content: Text('Network error. Could not confirm bike.'),
        ),
      );
    }
  }

  Future<void> _binSelection() async {
    if (_bikeDetails == null) return;

    final userId = LogSession.instance.userId;

    // Show loading indicator so the user knows an action is happening
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppBrandColors.redYellowStart),
      ),
    );

    try {
      final res = await http.post(
        Uri.parse('${AdminIp.baseUrl}/api/confirm-bike/cancel'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'bike_id': _bikeDetails!['bike_id'],
        }),
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Dismiss loading

      if (res.statusCode == 200) {
        // THE FIX: Wipe the local state so the UI updates to the empty state
        setState(() {
          _bikeDetails = null;
          _selectedDropoffId = null;
          _staticFare = "0.00";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bike released successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to release bike.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to release bike. Network error.')),
      );
    }
  }

  String _imageUrl(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    return '${AdminIp.baseUrl}/${raw.replaceFirst(RegExp('^/+'), '')}';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Text(
          _errorMessage,
          style: const TextStyle(color: AppBrandColors.redYellowStart),
        ),
      );
    }

    if (_bikeDetails == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pedal_bike_rounded,
              size: 80,
              color: AppBrandColors.whiteMuted.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              "Awaiting Selection",
              style: TextStyle(
                color: AppBrandColors.whiteMuted,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Go to the Select tab to choose an e-bike.",
              style: TextStyle(color: AppBrandColors.whiteMuted),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 120.0),
      children: [
        // SECTION A: BIKE DETAILS
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppBrandColors.blackEnd,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppBrandColors.greenMid.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Asset Confirmed",
                style: TextStyle(
                  color: AppBrandColors.whiteMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _imageUrl(_bikeDetails!['bike_image']),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 80,
                        height: 80,
                        color: AppBrandColors.blackStart,
                        child: const Icon(
                          Icons.broken_image,
                          color: AppBrandColors.whiteMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _bikeDetails!['bike_name'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppBrandColors.white,
                          ),
                        ),
                        Text(
                          _bikeDetails!['bike_code'],
                          style: const TextStyle(
                            color: AppBrandColors.whiteMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AppStatusChip(
                          label: 'Battery',
                          value: _bikeDetails!['battery_level'],
                          color: AppBrandColors.greenMid,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // SECTION B: DISTANCE & FARE
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppBrandColors.blackEnd,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppBrandColors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Pickup: ${_bikeDetails!['pickup_name']}",
                style: const TextStyle(
                  color: AppBrandColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                decoration: InputDecoration(
                  labelText: "Select Destination",
                  labelStyle: const TextStyle(color: AppBrandColors.whiteMuted),
                  filled: true,
                  fillColor: AppBrandColors.blackStart,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                dropdownColor: AppBrandColors.blackEnd,
                initialValue: _selectedDropoffId,
                items: _dropoffStations
                    .map(
                      (s) => DropdownMenuItem<int>(
                        value: s['id'],
                        child: Text(
                          s['station_name'],
                          style: const TextStyle(color: AppBrandColors.white),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) _fetchStaticFare(val);
                },
              ),
              const SizedBox(height: 16),
              if (_isFetchingFare)
                const Center(child: CircularProgressIndicator())
              else if (_selectedDropoffId != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppBrandColors.blackStart,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppBrandColors.greenMid.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Allocated Time", // THE FIX 3: Updated Label
                            style: TextStyle(
                              color: AppBrandColors.whiteMuted,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _allocatedTime, // THE FIX 4: Updated Variable
                            style: const TextStyle(
                              color: AppBrandColors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            "Admin Set Fare",
                            style: TextStyle(
                              color: AppBrandColors.whiteMuted,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            "GHS $_staticFare",
                            style: const TextStyle(
                              color: AppBrandColors.greenMid,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // SECTION C & D: ACTIONS
        Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                onPressed: _binSelection,
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppBrandColors.redYellowStart,
                ),
                label: const Text(
                  "Bin",
                  style: TextStyle(color: AppBrandColors.redYellowStart),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppBrandColors.redYellowStart),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _confirmBike,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppBrandColors.greenMid,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  "Confirm & Pay",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
