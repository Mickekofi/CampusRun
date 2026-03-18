import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../admin_ip.dart';
import '../log_session.dart';
import '../theme_settings.dart';
import '../widgets/app_status_chip.dart';

class UserBikeSelectionScreen extends StatefulWidget {
  final void Function(int bikeId, int pickupStationId)? onRideSelected;

  const UserBikeSelectionScreen({super.key, this.onRideSelected});

  @override
  State<UserBikeSelectionScreen> createState() =>
      _UserBikeSelectionScreenState();
}

// ============================================================================
// DATA MODELS
// ============================================================================
class _BikeItem {
  const _BikeItem({
    required this.id,
    required this.bikeCode,
    required this.bikeName,
    required this.bikeImage,
    required this.batteryLevel,
    required this.status,
    required this.stationId,
    required this.stationName,
    required this.etaSeconds,
  });

  final int id;
  final String bikeCode;
  final String bikeName;
  final String bikeImage;
  final int batteryLevel;
  final String status;
  final int stationId;
  final String stationName;
  final int etaSeconds;

  bool get isAvailable => status.toLowerCase() == 'available';
}

class _PickupStationItem {
  const _PickupStationItem({
    required this.id,
    required this.name,
    required this.stationType,
  });

  final int id;
  final String name;
  final String stationType;
}

class _UserBikeSelectionScreenState extends State<UserBikeSelectionScreen> {
  // ============================================================================
  // STATE VARIABLES
  // ============================================================================
  final List<_BikeItem> _bikes = [];
  final List<_PickupStationItem> _pickupStations = [];

  final Map<int, int> _remainingSecondsByBike = {};
  final Map<int, String> _lastStatusByBike = {}; // <-- THE IRONCLAD TRACKER

  final Set<int> _rideSubmittingBikeIds = <int>{};

  bool _loading = false;
  bool _loadingStations = false;
  String _error = '';

  Timer? _countdownTimer;
  Timer? _autoRefreshTimer;
  int? _selectedPickupStationId;

  // ============================================================================
  // LIFECYCLE
  // ============================================================================
  @override
  void initState() {
    super.initState();
    _loadPickupStations();
    _loadBookableBikes(showLoadingState: true);
    _startCountdownTicker();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================
  Map<String, dynamic>? _decodeBody(http.Response response) {
    try {
      return json.decode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  int _toInt(dynamic value) =>
      value is int ? value : int.tryParse('${value ?? 0}') ?? 0;
  String _toText(dynamic value) => value?.toString().trim() ?? '';

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return AppBrandColors.greenMid;
      case 'active':
      case 'reserved':
        return AppBrandColors.redYellowEnd;
      default:
        return AppBrandColors.whiteMuted;
    }
  }

  String _formatEta(int sec) {
    if (sec <= 0) return '00:00';
    final minutes = sec ~/ 60;
    final seconds = sec % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _imageUrl(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return '${AdminIp.baseUrl}/${raw.replaceFirst(RegExp('^/+'), '')}';
  }

  String get _selectedStationName {
    if (_selectedPickupStationId == null) return 'All stations';
    final station = _pickupStations.where(
      (s) => s.id == _selectedPickupStationId,
    );
    return station.isEmpty ? 'All stations' : station.first.name;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? AppBrandColors.redYellowStart
            : AppBrandColors.greenMid,
      ),
    );
  }

  // ============================================================================
  // API CALLS & LOGIC
  // ============================================================================

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadBookableBikes(showLoadingState: false);
    });
  }

  Future<void> _loadBookableBikes({bool showLoadingState = true}) async {
    if (showLoadingState) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }

    try {
      final stationFilter = _selectedPickupStationId == null
          ? ''
          : '?pickup_station_id=$_selectedPickupStationId';
      final uri = Uri.parse(
        '${AdminIp.baseUrl}/api/user_bikeSelection_routes/bikes$stationFilter',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 14));
      final body = _decodeBody(response);

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final rows = body?['bikes'] as List<dynamic>? ?? const <dynamic>[];
        final parsed = rows.map((row) {
          final map = row as Map<String, dynamic>;
          return _BikeItem(
            id: _toInt(map['id']),
            bikeCode: _toText(map['bike_code']),
            bikeName: _toText(map['bike_name']),
            bikeImage: _toText(map['bike_image']),
            batteryLevel: _toInt(map['battery_level']),
            status: _toText(map['status']),
            stationId: _toInt(map['station_id']),
            stationName: _toText(map['station_name']),
            etaSeconds: _toInt(map['eta_seconds']),
          );
        }).toList();

        setState(() {
          _bikes
            ..clear()
            ..addAll(parsed);

          // =================================================================
          // THE FIX: BULLETPROOF ETA STATE MACHINE
          // =================================================================
          final newRemaining = <int, int>{};
          final newStatusMap = <int, String>{};

          for (final b in parsed) {
            final String currentStatus = b.status.toLowerCase();
            final String? lastStatus = _lastStatusByBike[b.id];
            final int? localEta = _remainingSecondsByBike[b.id];

            newStatusMap[b.id] = currentStatus;

            if (b.isAvailable) {
              // Bike is free. Reset clock to 0.
              newRemaining[b.id] = 0;
            } else {
              if (localEta == null) {
                // First time launching app. Grab Admin's dynamic time.
                newRemaining[b.id] = b.etaSeconds;
              } else if (lastStatus == 'available' &&
                  currentStatus != 'available') {
                // We just witnessed someone book this! Start fresh dynamic time.
                newRemaining[b.id] = b.etaSeconds;
              } else if (localEta > 0) {
                // Phone is already counting down.
                // SHIELD UP: Ignore the backend's bouncing refreshes.
                newRemaining[b.id] = localEta;
              } else {
                // localEta is 0. The ride is officially "Delayed".
                // Keep it locked at 0 forever. Do not let server reset it.
                newRemaining[b.id] = 0;
              }
            }
          }

          _remainingSecondsByBike
            ..clear()
            ..addAll(newRemaining);

          _lastStatusByBike
            ..clear()
            ..addAll(newStatusMap);
          // =================================================================

          if (showLoadingState) _loading = false;
        });
      } else {
        if (showLoadingState) {
          setState(() {
            _loading = false;
            _error = body?['message']?.toString() ?? 'Unable to load bikes.';
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      if (showLoadingState) {
        setState(() {
          _loading = false;
          _error = 'Network error: $e';
        });
      }
    }
  }

  Future<void> _loadPickupStations() async {
    setState(() => _loadingStations = true);

    try {
      final uri = Uri.parse(
        '${AdminIp.baseUrl}/api/user_bikeSelection_routes/pickup-stations',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      final body = _decodeBody(response);

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final rows = body?['stations'] as List<dynamic>? ?? const <dynamic>[];
        final stations = rows
            .map((row) {
              final map = row as Map<String, dynamic>;
              return _PickupStationItem(
                id: _toInt(map['id']),
                name: _toText(map['station_name']),
                stationType: _toText(map['station_type']).toLowerCase(),
              );
            })
            .where(
              (s) =>
                  s.stationType.isEmpty ||
                  s.stationType == 'pickup' ||
                  s.stationType == 'both',
            )
            .toList();

        setState(() {
          _pickupStations
            ..clear()
            ..addAll(stations);
          _loadingStations = false;
        });
      } else {
        setState(() => _loadingStations = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStations = false);
    }
  }

  void _startCountdownTicker() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _remainingSecondsByBike.isEmpty) return;
      setState(() {
        for (final entry in _remainingSecondsByBike.entries.toList()) {
          _remainingSecondsByBike[entry.key] = entry.value > 0
              ? entry.value - 1
              : 0;
        }
      });
    });
  }

  Future<void> _selectBike(_BikeItem bike) async {
    final userId = LogSession.instance.userId;
    if (userId == null || userId <= 0) {
      _showSnack('Session user not found. Please login again.', isError: true);
      return;
    }

    if (!bike.isAvailable) {
      final remaining = _remainingSecondsByBike[bike.id] ?? bike.etaSeconds;
      if (remaining <= 0) {
        _showSnack('Ride delayed. Please choose another bike.', isError: true);
      } else {
        _showSnack(
          'Bike is in use. Please choose an available bike.',
          isError: true,
        );
      }
      return;
    }

    setState(() => _rideSubmittingBikeIds.add(bike.id));

    try {
      final uri = Uri.parse(
        '${AdminIp.baseUrl}/api/user_bikeSelection_routes/select',
      );
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'user_id': userId, 'bike_id': bike.id}),
          )
          .timeout(const Duration(seconds: 12));

      final body = _decodeBody(response);
      if (!mounted) return;

      if (response.statusCode == 403 && body?['message'] == 'End Ride First') {
        _showSnack('End Ride First', isError: true);
        return;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSnack(
          body?['message']?.toString() ?? 'Asset Secured. Proceeding...',
        );
        widget.onRideSelected?.call(bike.id, bike.stationId);
      } else {
        _showSnack(
          body?['message']?.toString() ?? 'Failed to select bike.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Network Error. Could not connect.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _rideSubmittingBikeIds.remove(bike.id));
    }
  }

  // ============================================================================
  // UI WIDGET BUILDERS
  // ============================================================================
  Widget _buildTopBar() {
    final available = _bikes
        .where((b) => b.status.toLowerCase() == 'available')
        .length;
    final active = _bikes
        .where((b) => b.status.toLowerCase() == 'active')
        .length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppBrandColors.blackEnd,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppBrandColors.white.withOpacity(0.16)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.place_rounded, color: AppBrandColors.greenMid),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedStationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppBrandColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PopupMenuButton<int?>(
                tooltip: 'Select station',
                color: AppBrandColors.blackEnd,
                onSelected: (value) {
                  setState(() => _selectedPickupStationId = value);
                  _loadBookableBikes(showLoadingState: true);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<int?>(
                    value: null,
                    child: Text(
                      'All stations',
                      style: TextStyle(color: AppBrandColors.white),
                    ),
                  ),
                  ..._pickupStations.map(
                    (s) => PopupMenuItem<int?>(
                      value: s.id,
                      child: Text(
                        s.name,
                        style: const TextStyle(color: AppBrandColors.white),
                      ),
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppBrandColors.white.withOpacity(0.22),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_loadingStations)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppBrandColors.greenMid,
                          ),
                        )
                      else
                        const Icon(
                          Icons.filter_list_rounded,
                          size: 16,
                          color: AppBrandColors.greenMid,
                        ),
                      const SizedBox(width: 6),
                      const Text(
                        'Stations',
                        style: TextStyle(
                          color: AppBrandColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppStatusChip(
                label: 'Available',
                color: AppBrandColors.greenMid,
                value: available,
              ),
              AppStatusChip(
                label: 'Active',
                color: AppBrandColors.redYellowEnd,
                value: active,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBikeRowCard(_BikeItem bike) {
    final isAvailable = bike.isAvailable;
    final remaining = _remainingSecondsByBike[bike.id] ?? bike.etaSeconds;
    final isSubmitting = _rideSubmittingBikeIds.contains(bike.id);
    final isDelayed = !isAvailable && remaining <= 0;

    final buttonText = isAvailable
        ? 'Ride'
        : isDelayed
        ? 'Delayed'
        : 'In Use';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppBrandColors.blackEnd,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _statusColor(bike.status).withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 90,
                height: 90,
                child: bike.bikeImage.isEmpty
                    ? const DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppBrandColors.blackStart,
                        ),
                        child: Icon(
                          Icons.pedal_bike_rounded,
                          color: AppBrandColors.whiteMuted,
                          size: 40,
                        ),
                      )
                    : Image.network(
                        _imageUrl(bike.bikeImage),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppBrandColors.blackStart,
                          ),
                          child: Icon(
                            Icons.broken_image_rounded,
                            color: AppBrandColors.whiteMuted,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bike.bikeName.isEmpty ? bike.bikeCode : bike.bikeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppBrandColors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // THE FIX: RESTORED THE STATION NAME UI
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: AppBrandColors.greenMid,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          bike.stationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppBrandColors.whiteMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bike.bikeCode,
                    style: const TextStyle(
                      color: AppBrandColors.whiteMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      AppStatusChip(
                        label: bike.status.toUpperCase(),
                        color: _statusColor(bike.status),
                      ),
                      AppStatusChip(
                        label: 'Battery',
                        color: AppBrandColors.greenMid,
                        value: bike.batteryLevel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // THE RED ETA DISPLAY
                  Text(
                    isAvailable
                        ? 'ETA: Ready now'
                        : (isDelayed
                              ? 'ETA: Ride delayed'
                              : 'ETA: ${_formatEta(remaining)}'),
                    style: const TextStyle(
                      color: AppBrandColors.redYellowStart,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              height: 48,
              child: ElevatedButton(
                onPressed: (!isAvailable || isSubmitting)
                    ? null
                    : () => _selectBike(bike),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppBrandColors.greenMid,
                  foregroundColor: AppBrandColors.white,
                  disabledBackgroundColor: AppBrandColors.whiteMuted
                      .withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppBrandColors.white,
                        ),
                      )
                    : Text(
                        buttonText,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppBrandColors.blackBackgroundGradient,
        ),
        child: RefreshIndicator(
          onRefresh: () => _loadBookableBikes(showLoadingState: true),
          color: AppBrandColors.greenMid,
          backgroundColor: AppBrandColors.blackEnd,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _buildTopBar(),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppBrandColors.greenMid,
                    ),
                  ),
                )
              else if (_error.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppBrandColors.blackEnd,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppBrandColors.redYellowStart.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    _error,
                    style: const TextStyle(
                      color: AppBrandColors.redYellowStart,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (_bikes.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppBrandColors.blackEnd,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppBrandColors.white.withOpacity(0.1),
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.pedal_bike_rounded,
                        color: AppBrandColors.whiteMuted,
                        size: 48,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No bikes found for this station.',
                        style: TextStyle(
                          color: AppBrandColors.whiteMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._bikes.map(_buildBikeRowCard),
            ],
          ),
        ),
      ),
    );
  }
}
