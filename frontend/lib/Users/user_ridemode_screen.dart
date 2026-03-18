import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../admin_ip.dart';
import '../log_session.dart';
import '../theme_settings.dart';

class UserRideModeScreen extends StatefulWidget {
  final VoidCallback? onRideEnded;

  const UserRideModeScreen({super.key, this.onRideEnded});

  @override
  State<UserRideModeScreen> createState() => _UserRideModeScreenState();
}

class _UserRideModeScreenState extends State<UserRideModeScreen> {
  // ============================================================================
  // ⚙️ SIMULATION SETTINGS (CHANGE THESE TO MAKE THE GHOST FASTER)
  // ============================================================================
  // How often (in seconds) the app sends data to the Admin Live Tracker
  final int _telemetrySyncInterval = 1; // Default: 2 seconds (Fast updates)

  // The baseline speed in km/h
  final double _baseSpeedKmh = 50.0; // Default: 45 km/h

  // How much the speed fluctuates randomly above the baseline
  final double _speedVariance = 15.0; // Randomly adds up to 15 km/h

  // The "Stride" length. Higher number = ghost covers more map distance per tick
  final double _gpsDriftMultiplier =
      0.005; // Default: 0.005 (Fast map movement)

  // ============================================================================
  // 📦 STATE VARIABLES
  // ============================================================================

  // -- UI & Data State --
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic>? _activeRide;

  // -- Timers --
  Timer? _rideTimer; // Ticks every 1 second for the UI countdown
  Timer? _telemetryTimer; // Ticks based on _telemetrySyncInterval for API sync

  // -- Ride Logic State --
  int _remainingSeconds = 0;
  bool _isDelayed = false;

  // -- Physical Telemetry State (Simulated) --
  double _currentSpeed = 0.0;
  double _simulatedLat = 5.3516;
  double _simulatedLng = -0.7184;
  int _batteryLevel = 100;

  // ============================================================================
  // 🔄 LIFECYCLE METHODS
  // ============================================================================
  @override
  void initState() {
    super.initState();
    _fetchActiveRide();
  }

  @override
  void dispose() {
    _rideTimer?.cancel();
    _telemetryTimer?.cancel();
    super.dispose();
  }

  // ============================================================================
  // 🌐 API COMMUNICATION PIPELINE (DO NOT BREAK)
  // ============================================================================

  /// 1. Boot up the dashboard and fetch the active ride ledger from the backend.
  Future<void> _fetchActiveRide() async {
    final userId = LogSession.instance.userId;
    if (userId == null) return;

    try {
      final res = await http.get(
        Uri.parse('${AdminIp.baseUrl}/api/ridemode/active?user_id=$userId'),
      );

      if (!mounted) return;
      final body = jsonDecode(res.body);

      if (res.statusCode == 200) {
        setState(() {
          _activeRide = body['data'];
          _batteryLevel = _activeRide!['battery_level'] ?? 100;
          _isLoading = false;
        });

        // Sync local clock with the exact database start time
        final startTime = DateTime.parse(_activeRide!['start_time']).toLocal();
        final elapsedSeconds = DateTime.now().difference(startTime).inSeconds;

        // Pull the dynamic allocated time (from the Admin's Route Pricing matrix)
        final allocatedSeconds = _activeRide!['allocated_time'] ?? 660;

        setState(() {
          if (elapsedSeconds >= allocatedSeconds) {
            _remainingSeconds = 0;
            _isDelayed = true;
          } else {
            _remainingSeconds = allocatedSeconds - elapsedSeconds;
            _isDelayed = false;
          }
        });

        _startEngines();
      } else {
        setState(() {
          _activeRide = null;
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

  /// 2. End the ride, apply penalties, and remove the user from the Live Map.
  Future<void> _endRide() async {
    if (_activeRide == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppBrandColors.redYellowStart),
      ),
    );

    try {
      // Step A: Kill the Ghost (Remove from Admin Map)
      await http.post(
        Uri.parse('${AdminIp.baseUrl}/api/admin_live_tracker_routes/location'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': LogSession.instance.userId,
          'latitude': _simulatedLat,
          'longitude': _simulatedLng,
          'is_riding': 0, // '0' tells the tracker to erase this dot
        }),
      );

      // Step B: Permanently close the financial ledger
      final res = await http.post(
        Uri.parse('${AdminIp.baseUrl}/api/ridemode/end'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': LogSession.instance.userId,
          'ride_id': _activeRide!['ride_id'],
          'bike_id': _activeRide!['bike_id'],
        }),
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Clear loading dialog

      if (res.statusCode == 200) {
        _rideTimer?.cancel();
        _telemetryTimer?.cancel();

        setState(() => _activeRide = null);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppBrandColors.greenMid,
            content: Text('Ride Completed! Bike Secured.'),
          ),
        );

        if (widget.onRideEnded != null) widget.onRideEnded!();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppBrandColors.redYellowStart,
            content: Text('Failed to end ride. Please try again.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppBrandColors.redYellowStart,
          content: Text('Network error. Could not end ride.'),
        ),
      );
    }
  }

  /// 3. Push physical data to the backend map (The Ghost Transmitter)
  Future<void> _transmitTelemetryPayload() async {
    if (_activeRide == null) return;

    try {
      await http.post(
        Uri.parse('${AdminIp.baseUrl}/api/admin_live_tracker_routes/location'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': LogSession.instance.userId,
          'latitude': _simulatedLat,
          'longitude': _simulatedLng,
          'speed_kmh': _currentSpeed,
          'heading': Random().nextDouble() * 360,
          'battery_pct': _batteryLevel,
          'is_riding': 1, // '1' keeps the dot alive on the admin map
        }),
      );
    } catch (e) {
      // We swallow this error silently so the UI doesn't stutter during movement
    }
  }

  // ============================================================================
  // 🧠 SIMULATION MATH & TIMERS
  // ============================================================================

  void _startEngines() {
    // Timer 1: The UI Clock (Always ticks exactly 1 second)
    _rideTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else if (!_isDelayed) {
        setState(() => _isDelayed = true); // Trigger the penalty UI instantly
      }
    });

    // Timer 2: The Data Transmitter (Uses your custom interval setting)
    _telemetryTimer = Timer.periodic(
      Duration(seconds: _telemetrySyncInterval),
      (timer) {
        _calculateNextGhostPosition();
        _transmitTelemetryPayload();
      },
    );
  }

  void _calculateNextGhostPosition() {
    final random = Random();

    // 1. Calculate random speed based on your config at the top of the file
    _currentSpeed = _baseSpeedKmh + (random.nextDouble() * _speedVariance);

    // 2. Calculate the GPS jump based on your drift config
    _simulatedLat += (random.nextDouble() - 0.5) * _gpsDriftMultiplier;
    _simulatedLng += (random.nextDouble() - 0.5) * _gpsDriftMultiplier;

    // 3. Slowly drain the battery randomly
    if (random.nextInt(10) > 7 && _batteryLevel > 5) {
      _batteryLevel -= 1;
    }

    if (mounted) setState(() {}); // Trigger UI rebuild with new data
  }

  String _formatEta(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, "0")}:${seconds.toString().padLeft(2, "0")}';
  }

  // ============================================================================
  // 🎨 MODULAR UI BUILDERS
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppBrandColors.blackBackgroundGradient,
        ),
        child: _buildMainView(),
      ),
    );
  }

  Widget _buildMainView() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppBrandColors.greenMid),
      );
    }
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Text(
          _errorMessage,
          style: const TextStyle(
            color: AppBrandColors.redYellowStart,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    if (_activeRide == null) {
      return _buildEmptyState();
    }
    return _buildActiveRideDashboard();
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.directions_bike_rounded,
          size: 80,
          color: AppBrandColors.whiteMuted.withOpacity(0.3),
        ),
        const SizedBox(height: 16),
        const Text(
          "No Active Ride",
          style: TextStyle(
            color: AppBrandColors.whiteMuted,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Head to the Scan tab to unlock a bike.",
          style: TextStyle(color: AppBrandColors.whiteMuted),
        ),
      ],
    );
  }

  Widget _buildActiveRideDashboard() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
      children: [
        _buildAssetHeader(),
        const SizedBox(height: 32),
        if (_isDelayed) _buildPenaltyWarning(),
        _buildCircularTimer(),
        const SizedBox(height: 40),
        _buildTelemetryGrid(),
        const SizedBox(height: 40),
        _buildEndRideButton(),
      ],
    );
  }

  Widget _buildAssetHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "CURRENT ASSET",
              style: TextStyle(
                color: AppBrandColors.whiteMuted,
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _activeRide!['bike_name'] ?? 'Unknown',
              style: const TextStyle(
                color: AppBrandColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppBrandColors.blackEnd,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppBrandColors.greenMid.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Icon(
                _batteryLevel > 20
                    ? Icons.battery_charging_full_rounded
                    : Icons.battery_alert_rounded,
                color: _batteryLevel > 20
                    ? AppBrandColors.greenMid
                    : AppBrandColors.redYellowStart,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                "$_batteryLevel%",
                style: const TextStyle(
                  color: AppBrandColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPenaltyWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppBrandColors.redYellowStart.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppBrandColors.redYellowStart, width: 2),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppBrandColors.redYellowStart,
            size: 32,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "RIDE DELAYED. A PENALTY FEE IS ADDED; WALLET HAS BEEN DEDUCTED.",
              style: TextStyle(
                color: AppBrandColors.redYellowStart,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularTimer() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppBrandColors.blackEnd,
          border: Border.all(
            color: _isDelayed
                ? AppBrandColors.redYellowStart
                : AppBrandColors.greenMid,
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  (_isDelayed
                          ? AppBrandColors.redYellowStart
                          : AppBrandColors.greenMid)
                      .withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              _isDelayed ? "DELAYED" : "TIME REMAINING",
              style: TextStyle(
                color: _isDelayed
                    ? AppBrandColors.redYellowStart
                    : AppBrandColors.greenMid,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatEta(_remainingSeconds),
              style: TextStyle(
                color: _isDelayed
                    ? AppBrandColors.redYellowStart
                    : AppBrandColors.white,
                fontSize: 48,
                fontWeight: FontWeight.w900,
                fontFamily: 'Courier',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryGrid() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppBrandColors.blackEnd,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppBrandColors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.speed_rounded,
                  color: AppBrandColors.whiteMuted,
                ),
                const SizedBox(height: 8),
                Text(
                  _currentSpeed.toStringAsFixed(1),
                  style: const TextStyle(
                    color: AppBrandColors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  "km/h",
                  style: TextStyle(
                    color: AppBrandColors.whiteMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppBrandColors.blackEnd,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppBrandColors.greenMid.withOpacity(0.3),
              ),
            ),
            child: const Column(
              children: [
                Icon(Icons.route_rounded, color: AppBrandColors.whiteMuted),
                SizedBox(height: 8),
                Text(
                  "LIVE",
                  style: TextStyle(
                    color: AppBrandColors.greenMid,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "GPS Syncing",
                  style: TextStyle(
                    color: AppBrandColors.whiteMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEndRideButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton.icon(
            onPressed: _endRide,
            icon: const Icon(Icons.stop_circle_rounded, size: 28),
            label: const Text(
              "END RIDE & LOCK",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppBrandColors.redYellowStart,
              foregroundColor: AppBrandColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Please ensure the bike is parked correctly at an approved station before ending your ride.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppBrandColors.whiteMuted, fontSize: 12),
        ),
      ],
    );
  }
}
