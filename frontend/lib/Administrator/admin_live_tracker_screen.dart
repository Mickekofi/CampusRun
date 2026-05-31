// ============================================================
//  admin_live_tracker_screen.dart
//  CampusRun — Admin Live Tracker
// ============================================================
//
//  PURPOSE
//  ────────────────────────────────────────────────────────────
//  Real-time map view that lets the Admin monitor students
//  currently riding bikes on campus.  Each active rider is
//  shown as a labelled pin on an OpenStreetMap tile layer.
//  Selecting a rider displays their detail panel and draws
//  their recent path as a polyline on the map.
//
//  SECTIONS
//  ────────────────────────────────────────────────────────────
//  SECTION 1 — IMPORTS & CONSTANTS
//  SECTION 2 — DATA MODELS
//  SECTION 3 — WIDGET CLASS & STATE DECLARATION
//  SECTION 4 — LIFECYCLE  (init · dispose · onResume)
//  SECTION 5 — HTTP HELPERS  (decode · snack)
//  SECTION 6 — DATA LOADERS  (loadRiders · loadTrail)
//  SECTION 7 — ACTIONS  (select rider · fit all · center select)
//  SECTION 8 — UI BUILDERS
//    8a. _buildTopShortcuts
//    8b. _buildSectionA  (live summary chips)
//    8c. _buildSectionB  (searchable user selector)
//    8d. _buildMapArea   (flutter_map tile + markers + trail)
//    8e. _buildRiderMarker (custom map pin widget)
//    8f. _buildSectionC  (selected rider detail panel)
//  SECTION 9 — BUILD
// ============================================================

// ── SECTION 1 — IMPORTS & CONSTANTS ─────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;

import '../admin_ip.dart';
import '../theme_settings.dart';
import '../widgets/app_status_chip.dart';

// Campus map default centre (adjust to your exact campus GPS coordinates)
const LatLng _kCampusCenter = LatLng(5.3516, -0.7184);
const double _kDefaultZoom = 16.0;

// How often the admin map auto-refreshes rider positions
const Duration _kPollInterval = Duration(seconds: 5);

// OSM tile URL
const String _kTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

// ── SECTION 2 — DATA MODELS ──────────────────────────────────

/// A single active rider returned by GET /active-riders
class _Rider {
  const _Rider({
    required this.userId,
    required this.studentId,
    required this.fullName,
    required this.profilePicture,
    required this.accountStatus,
    required this.position,
    required this.speedKmh,
    required this.heading,
    required this.batteryPct,
    required this.isRiding,
    required this.updatedAt,
  });

  final int userId;
  final String studentId;
  final String fullName;
  final String profilePicture;
  final String accountStatus;
  final LatLng position;
  final double? speedKmh;
  final double? heading;
  final int? batteryPct;
  final bool isRiding;
  final String updatedAt;

  factory _Rider.fromJson(Map<String, dynamic> j) {
    return _Rider(
      userId: _toInt(j['user_id']),
      studentId: _toText(j['student_id']),
      fullName: _toText(j['full_name']),
      profilePicture: _toText(j['profile_picture']),
      accountStatus: _toText(j['account_status']),
      position: LatLng(
        double.tryParse('${j['latitude']}') ?? 0,
        double.tryParse('${j['longitude']}') ?? 0,
      ),
      speedKmh: double.tryParse('${j['speed_kmh']}'),
      heading: double.tryParse('${j['heading']}'),
      batteryPct: _toNullInt(j['battery_pct']),
      isRiding: j['is_riding'] == 1 || j['is_riding'] == true,
      updatedAt: _toText(j['updated_at']),
    );
  }
}

/// A single trail point for the path polyline
class _TrailPoint {
  const _TrailPoint(this.position, this.speedKmh);
  final LatLng position;
  final double? speedKmh;
}

// ── Helper converters (file-scoped, not exported) ─────────────
int _toInt(dynamic v) => v is int ? v : int.tryParse('${v ?? 0}') ?? 0;
int? _toNullInt(dynamic v) => v == null ? null : int.tryParse('$v');
String _toText(dynamic v) => v?.toString().trim() ?? '';

// ── SECTION 3 — WIDGET CLASS & STATE DECLARATION ─────────────

class AdminLiveTrackerScreen extends StatefulWidget {
  const AdminLiveTrackerScreen({super.key});

  @override
  State<AdminLiveTrackerScreen> createState() => _AdminLiveTrackerScreenState();
}

class _AdminLiveTrackerScreenState extends State<AdminLiveTrackerScreen>
    with WidgetsBindingObserver {
  // ── MAP controller ────────────────────────────────────────────────
  final MapController _mapController = MapController();

  // ── SCROLL & SECTION keys (for shortcut scroll-to) ───────────────
  final ScrollController _scroll = ScrollController();
  final _keyA = GlobalKey();
  final _keyB = GlobalKey();
  final _keyC = GlobalKey();

  // ── POLLING timer ────────────────────────────────────────────────
  Timer? _pollTimer;

  // ── RIDERS data ──────────────────────────────────────────────────
  List<_Rider> _riders = [];
  bool _loadingRiders = false;
  String _ridersError = '';

  // ── TRAIL data for the selected rider ────────────────────────────
  List<_TrailPoint> _trail = [];
  bool _loadingTrail = false;

  // ── SELECTED rider & search state ────────────────────────────────
  _Rider? _selectedRider;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // ── "Show all riders" toggle ──────────────────────────────────────
  bool _trackAll = true;

  // ── SECTION 4 — LIFECYCLE ────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRiders();
    _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadRiders();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _searchCtrl.dispose();
    _mapController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── SECTION 5 — HTTP HELPERS ─────────────────────────────────────

  /// Safely decodes an HTTP response body with charset fallback.
  Map<String, dynamic>? _decodeBody(http.Response res) {
    try {
      final raw = utf8.decode(res.bodyBytes);
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  // ── SECTION 6 — DATA LOADERS ─────────────────────────────────────

  /// Starts the auto-poll timer.  The timer fires every [_kPollInterval]
  /// and silently refreshes rider positions without showing a spinner.
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      _kPollInterval,
      (_) => _loadRiders(silent: true),
    );
  }

  /// Fetches all active riders from the backend.
  ///
  /// [silent] — when true the loading spinner is suppressed (used for
  /// background polling so the UI doesn't flicker).
  Future<void> _loadRiders({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _loadingRiders = true;
        _ridersError = '';
      });
    }

    try {
      final url = Uri.parse(
        '${AdminIp.baseUrl}/api/admin_live_tracker_routes/active-riders',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      final data = _decodeBody(res);

      if (!mounted) return;

      if (res.statusCode == 200 && data?['success'] == true) {
        final rawList = data!['riders'];
        final fresh = (rawList is List)
            ? rawList
                  .map((e) => _Rider.fromJson(e as Map<String, dynamic>))
                  .toList()
            : <_Rider>[];

        setState(() {
          _riders = fresh;
          _loadingRiders = false;
          _ridersError = '';
        });

        // Update selected rider's data if it is still in the new list
        if (_selectedRider != null) {
          final updated = _riders.where(
            (r) => r.userId == _selectedRider!.userId,
          );
          if (updated.isNotEmpty) {
            _selectedRider = updated.first;
          }
        }

        // Fit all markers in view when first loading or tracking all
        if (_trackAll && _riders.isNotEmpty && !silent) {
          _fitAllRiders();
        }
      } else {
        if (!silent) {
          setState(() {
            _loadingRiders = false;
            _ridersError = data?['message'] ?? 'Failed to load active riders.';
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _loadingRiders = false;
          _ridersError = 'Network error: $e';
        });
      }
    }
  }

  /// Loads the trail (path history) for the given [rider].
  Future<void> _loadTrail(_Rider rider) async {
    if (!mounted) return;
    setState(() {
      _loadingTrail = true;
      _trail = [];
    });

    try {
      final url = Uri.parse(
        '${AdminIp.baseUrl}/api/admin_live_tracker_routes/rider/${rider.userId}/trail',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      final data = _decodeBody(res);

      if (!mounted) return;

      if (res.statusCode == 200 && data?['success'] == true) {
        final raw = data!['trail'];
        final pts = (raw is List)
            ? raw.map((e) {
                final m = e as Map<String, dynamic>;
                return _TrailPoint(
                  LatLng(
                    double.tryParse('${m['latitude']}') ?? 0,
                    double.tryParse('${m['longitude']}') ?? 0,
                  ),
                  double.tryParse('${m['speed_kmh']}'),
                );
              }).toList()
            : <_TrailPoint>[];
        setState(() {
          _trail = pts;
          _loadingTrail = false;
        });
      } else {
        setState(() {
          _loadingTrail = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingTrail = false;
        });
      }
    }
  }

  // ── SECTION 7 — ACTIONS & HANDLERS ───────────────────────────────

  /// Selects (or deselects) a rider.  When selected, the map centres on
  /// them and their trail is loaded.
  void _selectRider(_Rider? rider) {
    setState(() {
      _selectedRider = rider;
      _trail = [];
    });
    if (rider == null) return;
    _mapController.move(rider.position, _kDefaultZoom + 1);
    _loadTrail(rider);
    // Scroll to detail panel
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(_keyC));
  }

  /// Animates the map camera to fit all active rider markers.
  void _fitAllRiders() {
    if (_riders.isEmpty) return;
    if (_riders.length == 1) {
      _mapController.move(_riders.first.position, _kDefaultZoom);
      return;
    }
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final r in _riders) {
      minLat = math.min(minLat, r.position.latitude);
      maxLat = math.max(maxLat, r.position.latitude);
      minLng = math.min(minLng, r.position.longitude);
      maxLng = math.max(maxLng, r.position.longitude);
    }
    // Calculate the center point
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));

    // Estimate zoom level to fit all points (simple heuristic)
    double zoom = _kDefaultZoom;
    final latDiff = (maxLat - minLat).abs();
    final lngDiff = (maxLng - minLng).abs();
    final maxDiff = math.max(latDiff, lngDiff);
    if (maxDiff > 0.05) zoom = 14;
    if (maxDiff > 0.1) zoom = 13;
    if (maxDiff > 0.2) zoom = 12;
    if (maxDiff > 0.4) zoom = 11;
    if (maxDiff > 0.8) zoom = 10;

    _mapController.move(LatLng(centerLat, centerLng), zoom);
  }

  /// Centres the map on the selected rider's last known position.
  void _centreOnSelected() {
    if (_selectedRider == null) return;
    _mapController.move(_selectedRider!.position, _kDefaultZoom + 1);
  }

  /// Scrolls the page-level scroll view so the widget with [key] is visible.
  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  /// Status color helper — same mapping used across all admin screens.
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppBrandColors.greenMid;
      case 'suspended':
        return AppBrandColors.redYellowEnd;
      case 'banned':
        return AppBrandColors.redYellowStart;
      default:
        return AppBrandColors.whiteMuted;
    }
  }

  /// Returns filtered rider list based on the search query.
  List<_Rider> get _filteredRiders {
    if (_searchQuery.isEmpty) return _riders;
    final q = _searchQuery.toLowerCase();
    return _riders
        .where(
          (r) =>
              r.fullName.toLowerCase().contains(q) ||
              r.studentId.toLowerCase().contains(q),
        )
        .toList();
  }

  // ── SECTION 8 — UI BUILDERS ───────────────────────────────────────

  // ── 8a. Top shortcuts bar ─────────────────────────────────────────

  Widget _buildTopShortcuts() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _shortcutBtn(
            Icons.bar_chart_rounded,
            'Summary',
            () => _scrollTo(_keyA),
          ),
          const SizedBox(width: 10),
          _shortcutBtn(
            Icons.manage_search_rounded,
            'Select Rider',
            () => _scrollTo(_keyB),
          ),
          const SizedBox(width: 10),
          _shortcutBtn(
            Icons.person_pin_circle_rounded,
            'Detail',
            () => _scrollTo(_keyC),
          ),
          const SizedBox(width: 10),
          _shortcutBtn(Icons.refresh_rounded, 'Refresh', () => _loadRiders()),
          const SizedBox(width: 10),
          _shortcutBtn(Icons.fit_screen_rounded, 'Fit All', _fitAllRiders),
        ],
      ),
    );
  }

  Widget _shortcutBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: AppBrandColors.redYellowGradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppBrandColors.white, size: 17),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppBrandColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 8b. Section A — Live summary chips ───────────────────────────

  Widget _buildSectionA() {
    final total = _riders.length;
    final moving = _riders.where((r) => (r.speedKmh ?? 0) > 0.5).length;
    final idle = total - moving;

    return Container(
      key: _keyA,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppBrandColors.blackEnd,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppBrandColors.redYellowMid.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────────
          Row(
            children: [
              const Icon(
                Icons.satellite_alt_rounded,
                color: AppBrandColors.greenMid,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Live Activity',
                style: TextStyle(
                  color: AppBrandColors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              // Live pulse dot
              _LivePulseDot(),
              const SizedBox(width: 6),
              const Text(
                'LIVE',
                style: TextStyle(
                  color: AppBrandColors.greenMid,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Summary chips ────────────────────────────────────────────
          if (_loadingRiders && _riders.isEmpty)
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_ridersError.isNotEmpty && _riders.isEmpty)
            Text(
              _ridersError,
              style: const TextStyle(
                color: AppBrandColors.redYellowStart,
                fontSize: 12,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppStatusChip(
                  label: 'Active Riders',
                  color: AppBrandColors.greenMid,
                  value: total,
                ),
                AppStatusChip(
                  label: 'Moving',
                  color: AppBrandColors.redYellowEnd,
                  value: moving,
                ),
                AppStatusChip(
                  label: 'Idle',
                  color: AppBrandColors.whiteMuted,
                  value: idle,
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── 8c. Section B — Searchable user selector ─────────────────────

  Widget _buildSectionB() {
    return Container(
      key: _keyB,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppBrandColors.blackEnd,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppBrandColors.redYellowMid.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header ───────────────────────────────────────────
          Row(
            children: [
              const Icon(
                Icons.manage_search_rounded,
                color: AppBrandColors.greenMid,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Select Rider to Monitor',
                  style: TextStyle(
                    color: AppBrandColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              // Track-all toggle
              GestureDetector(
                onTap: () {
                  setState(() => _trackAll = !_trackAll);
                  if (_trackAll) {
                    _selectRider(null);
                    _fitAllRiders();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _trackAll
                        ? AppBrandColors.greenMid.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _trackAll
                          ? AppBrandColors.greenMid
                          : AppBrandColors.whiteMuted.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.group_rounded,
                        size: 15,
                        color: _trackAll
                            ? AppBrandColors.greenMid
                            : AppBrandColors.whiteMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'All',
                        style: TextStyle(
                          color: _trackAll
                              ? AppBrandColors.greenMid
                              : AppBrandColors.whiteMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Search field + dropdown ──────────────────────────────────
          if (_riders.isEmpty)
            const Text(
              'No active riders right now.',
              style: TextStyle(color: AppBrandColors.whiteMuted, fontSize: 13),
            )
          else
            Column(
              children: [
                // Search text field that filters the dropdown list
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  style: const TextStyle(color: AppBrandColors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by name or student ID…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),

                // Rider tiles
                ..._filteredRiders.map((rider) => _buildRiderTile(rider)),

                if (_filteredRiders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No match found.',
                      style: TextStyle(
                        color: AppBrandColors.whiteMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRiderTile(_Rider rider) {
    final selected = _selectedRider?.userId == rider.userId;
    return GestureDetector(
      onTap: () {
        setState(() => _trackAll = false);
        _selectRider(selected ? null : rider);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppBrandColors.greenMid.withOpacity(0.12)
              : AppBrandColors.blackStart.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppBrandColors.greenMid
                : AppBrandColors.whiteMuted.withOpacity(0.15),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: AppBrandColors.blackEnd,
              backgroundImage: rider.profilePicture.isNotEmpty
                  ? NetworkImage(
                      rider.profilePicture.startsWith('http')
                          ? rider.profilePicture
                          : '${AdminIp.baseUrl}/${rider.profilePicture}',
                    )
                  : null,
              child: rider.profilePicture.isEmpty
                  ? Text(
                      rider.fullName.isEmpty
                          ? '?'
                          : rider.fullName[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppBrandColors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Name + student ID
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rider.fullName,
                    style: const TextStyle(
                      color: AppBrandColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    rider.studentId,
                    style: const TextStyle(
                      color: AppBrandColors.whiteMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Speed badge
            if (rider.speedKmh != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppBrandColors.redYellowMid.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppBrandColors.redYellowMid.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  '${rider.speedKmh!.toStringAsFixed(1)} km/h',
                  style: const TextStyle(
                    color: AppBrandColors.redYellowEnd,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

            const SizedBox(width: 8),

            // Battery
            if (rider.batteryPct != null)
              Row(
                children: [
                  const Icon(
                    Icons.battery_std_rounded,
                    size: 13,
                    color: AppBrandColors.whiteMuted,
                  ),
                  Text(
                    '${rider.batteryPct}%',
                    style: const TextStyle(
                      color: AppBrandColors.whiteMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),

            const SizedBox(width: 8),

            // Selection indicator
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected
                  ? AppBrandColors.greenMid
                  : AppBrandColors.whiteMuted.withOpacity(0.4),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ── 8d. Map area ──────────────────────────────────────────────────

  Widget _buildMapArea() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      height: 420,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppBrandColors.redYellowMid.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // ── Actual map ──────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _kCampusCenter,
              initialZoom: _kDefaultZoom,
              maxZoom: 19,
              minZoom: 5,
            ),
            children: [
              // Tile layer (OpenStreetMap — no API key needed)
              TileLayer(
                urlTemplate: _kTileUrl,
                userAgentPackageName: 'com.campusrun.frontend',
              ),

              // Trail polyline for selected rider
              if (_selectedRider != null && _trail.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _trail.map((p) => p.position).toList(),
                      color: AppBrandColors.greenMid.withOpacity(0.85),
                      strokeWidth: 3.5,
                    ),
                  ],
                ),

              // Rider markers
              MarkerLayer(markers: _riders.map(_buildMarker).toList()),
            ],
          ),

          // ── Map overlay controls ────────────────────────────────────
          Positioned(
            right: 10,
            bottom: 80,
            child: Column(
              children: [
                _mapControlBtn(
                  icon: Icons.add_rounded,
                  tooltip: 'Zoom in',
                  onTap: () {
                    final z = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, z + 1);
                  },
                ),
                const SizedBox(height: 8),
                _mapControlBtn(
                  icon: Icons.remove_rounded,
                  tooltip: 'Zoom out',
                  onTap: () {
                    final z = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, z - 1);
                  },
                ),
                const SizedBox(height: 8),
                _mapControlBtn(
                  icon: Icons.fit_screen_rounded,
                  tooltip: 'Fit all',
                  onTap: _fitAllRiders,
                ),
                if (_selectedRider != null) ...[
                  const SizedBox(height: 8),
                  _mapControlBtn(
                    icon: Icons.my_location_rounded,
                    tooltip: 'Centre on selected',
                    onTap: _centreOnSelected,
                    active: true,
                  ),
                ],
              ],
            ),
          ),

          // ── Rider count badge (top-left) ────────────────────────────
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppBrandColors.blackEnd.withOpacity(0.92),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppBrandColors.greenMid.withOpacity(0.5),
                ),
              ),
              child: Row(
                children: [
                  _LivePulseDot(),
                  const SizedBox(width: 6),
                  Text(
                    '${_riders.length} rider${_riders.length == 1 ? '' : 's'} live',
                    style: const TextStyle(
                      color: AppBrandColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Loading trail indicator ─────────────────────────────────
          if (_loadingTrail)
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppBrandColors.blackEnd.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Round button used for map overlay controls.
  Widget _mapControlBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: active
                ? AppBrandColors.greenMid.withOpacity(0.85)
                : AppBrandColors.blackEnd.withOpacity(0.88),
            shape: BoxShape.circle,
            border: Border.all(
              color: active
                  ? AppBrandColors.greenMid
                  : AppBrandColors.whiteMuted.withOpacity(0.25),
            ),
          ),
          child: Icon(
            icon,
            color: active ? AppBrandColors.blackStart : AppBrandColors.white,
            size: 18,
          ),
        ),
      ),
    );
  }

  // ── 8e. Map marker widget ─────────────────────────────────────────

  Marker _buildMarker(_Rider rider) {
    final selected = _selectedRider?.userId == rider.userId;
    return Marker(
      point: rider.position,
      width: 72,
      height: 80,
      child: GestureDetector(
        onTap: () {
          setState(() => _trackAll = false);
          _selectRider(selected ? null : rider);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pin bubble
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? AppBrandColors.greenMid
                    : AppBrandColors.redYellowMid.withOpacity(0.92),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppBrandColors.white.withOpacity(0.7),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        (selected
                                ? AppBrandColors.greenMid
                                : AppBrandColors.redYellowMid)
                            .withOpacity(0.55),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.directions_bike_rounded,
                    color: AppBrandColors.white,
                    size: selected ? 18 : 15,
                  ),
                  Text(
                    rider.studentId,
                    style: TextStyle(
                      color: AppBrandColors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            // Downward triangle stem
            CustomPaint(
              painter: _TriangleStemPainter(
                color: selected
                    ? AppBrandColors.greenMid
                    : AppBrandColors.redYellowMid,
              ),
              size: const Size(12, 7),
            ),
          ],
        ),
      ),
    );
  }

  // ── 8f. Section C — Selected rider detail panel ───────────────────

  Widget _buildSectionC() {
    return Container(
      key: _keyC,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppBrandColors.blackEnd,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppBrandColors.redYellowMid.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            children: [
              const Icon(
                Icons.person_pin_circle_rounded,
                color: AppBrandColors.greenMid,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Rider Detail',
                  style: TextStyle(
                    color: AppBrandColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_selectedRider != null)
                GestureDetector(
                  onTap: () => _selectRider(null),
                  child: const Icon(
                    Icons.close_rounded,
                    color: AppBrandColors.whiteMuted,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          if (_selectedRider == null)
            const Text(
              'Tap a rider on the map or in the list above to see their details here.',
              style: TextStyle(color: AppBrandColors.whiteMuted, fontSize: 13),
            )
          else
            _buildRiderDetailCard(_selectedRider!),
        ],
      ),
    );
  }

  Widget _buildRiderDetailCard(_Rider r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Identity row ─────────────────────────────────────────────
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppBrandColors.blackStart,
              backgroundImage: r.profilePicture.isNotEmpty
                  ? NetworkImage(
                      r.profilePicture.startsWith('http')
                          ? r.profilePicture
                          : '${AdminIp.baseUrl}/${r.profilePicture}',
                    )
                  : null,
              child: r.profilePicture.isEmpty
                  ? Text(
                      r.fullName.isEmpty ? '?' : r.fullName[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppBrandColors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.fullName,
                    style: const TextStyle(
                      color: AppBrandColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    r.studentId,
                    style: const TextStyle(
                      color: AppBrandColors.whiteMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            AppStatusChip(
              label: r.accountStatus,
              color: _statusColor(r.accountStatus),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(color: Color(0xFF2C2C2C)),
        const SizedBox(height: 10),

        // ── Live telemetry grid ───────────────────────────────────────
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _detailChip(
              Icons.speed_rounded,
              'Speed',
              r.speedKmh != null
                  ? '${r.speedKmh!.toStringAsFixed(1)} km/h'
                  : '— km/h',
            ),
            _detailChip(
              Icons.explore_rounded,
              'Heading',
              r.heading != null ? '${r.heading!.toStringAsFixed(0)}°' : '—°',
            ),
            _detailChip(
              Icons.battery_charging_full_rounded,
              'Battery',
              r.batteryPct != null ? '${r.batteryPct}%' : '—',
            ),
            _detailChip(
              Icons.location_on_rounded,
              'GPS',
              '${r.position.latitude.toStringAsFixed(5)}, '
                  '${r.position.longitude.toStringAsFixed(5)}',
            ),
            _detailChip(
              Icons.update_rounded,
              'Last ping',
              r.updatedAt.length >= 16
                  ? r.updatedAt.substring(0, 16).replaceFirst('T', ' ')
                  : r.updatedAt,
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Trail info & centre button ────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Text(
                _trail.isEmpty
                    ? 'Loading trail…'
                    : '${_trail.length} trail point${_trail.length == 1 ? '' : 's'} recorded',
                style: const TextStyle(
                  color: AppBrandColors.whiteMuted,
                  fontSize: 12,
                ),
              ),
            ),
            GestureDetector(
              onTap: _centreOnSelected,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  gradient: AppBrandColors.greenGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.my_location_rounded,
                      color: AppBrandColors.white,
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Centre',
                      style: TextStyle(
                        color: AppBrandColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _detailChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppBrandColors.blackStart.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppBrandColors.whiteMuted.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppBrandColors.greenMid, size: 14),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppBrandColors.whiteMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: AppBrandColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── SECTION 9 — BUILD ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppBrandColors.blackStart,
      body: RefreshIndicator(
        onRefresh: () => _loadRiders(),
        color: AppBrandColors.redYellowMid,
        backgroundColor: AppBrandColors.blackEnd,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Top shortcuts
            SliverToBoxAdapter(child: _buildTopShortcuts()),

            // Section A — live summary
            SliverToBoxAdapter(child: _buildSectionA()),

            // Section B — rider selector
            SliverToBoxAdapter(child: _buildSectionB()),

            // Map
            SliverToBoxAdapter(child: _buildMapArea()),

            // Section C — selected detail
            SliverToBoxAdapter(child: _buildSectionC()),

            // Bottom safe area padding
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).padding.bottom + 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom painters ───────────────────────────────────────────────────

/// Draws the small downward-pointing triangle "stem" under a map pin.
class _TriangleStemPainter extends CustomPainter {
  const _TriangleStemPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TriangleStemPainter old) => old.color != color;
}

/// Animated pulsing green dot indicating "live".
class _LivePulseDot extends StatefulWidget {
  @override
  State<_LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<_LivePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.7,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppBrandColors.greenMid,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
