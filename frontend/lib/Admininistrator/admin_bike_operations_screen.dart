import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../admin_ip.dart';
import '../log_session.dart';
import '../theme_settings.dart';
import '../widgets/app_status_chip.dart';

class AdminBikeOperationsScreen extends StatefulWidget {
  const AdminBikeOperationsScreen({super.key});

  @override
  State<AdminBikeOperationsScreen> createState() =>
      _AdminBikeOperationsScreenState();
}

class _AdminBikeOperationsScreenState extends State<AdminBikeOperationsScreen> {
  final ScrollController _scrollController = ScrollController();
  final _statsSectionKey = GlobalKey();
  final _lockSectionKey = GlobalKey();
  final _viewSectionKey = GlobalKey();

  final List<String> _statusFilters = const [
    'all',
    'available',
    'reserved',
    'active',
    'maintenance',
    'inactive',
    'tampered',
  ];

  bool _isLoadingOverview = false;
  bool _isLoadingBikes = false;
  bool _isLockingBike = false;

  String _selectedViewStatus = 'all';
  int? _selectedBikeId;

  Map<String, dynamic> _overview = const {};
  List<Map<String, dynamic>> _allBikes = const [];
  List<Map<String, dynamic>> _viewBikes = const [];
  DateTime? _lastRefreshedAt;

  int get _adminId => LogSession.instance.userId ?? 0;

  Uri get _baseUri =>
      Uri.parse('${AdminIp.baseUrl}/api/admin_bike_operations_routes');

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-admin-id': '$_adminId',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_appLifecycleObserver);
    _loadInitialData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_appLifecycleObserver);
    _scrollController.dispose();
    super.dispose();
  }

  late final _appLifecycleObserver = _BikeOperationsLifecycleObserver(
    onResume: () {
      _refreshAll();
    },
  );

  // ============================================================================
  // SHARED HELPERS
  // ============================================================================

  Map<String, dynamic> _decodeBody(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
  }

  String _toText(dynamic value, {String fallback = '--'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Color _statusColor(String label) {
    switch (label.toLowerCase()) {
      case 'available':
        return AppBrandColors.greenMid;
      case 'active':
        return AppBrandColors.redYellowMid;
      case 'inactive':
        return AppBrandColors.whiteMuted;
      case 'reserved':
        return AppBrandColors.redYellowStart;
      case 'maintenance':
        return AppBrandColors.redYellowEnd;
      case 'tampered':
        return AppBrandColors.greenStart;
      default:
        return AppBrandColors.whiteMuted;
    }
  }

  String? _resolveBikeImageUrl(dynamic bikeImageRaw) {
    final image = bikeImageRaw?.toString().trim() ?? '';
    if (image.isEmpty) return null;
    if (image.startsWith('http://') || image.startsWith('https://')) {
      return image;
    }
    if (image.startsWith('/')) {
      return '${AdminIp.baseUrl}$image';
    }
    return '${AdminIp.baseUrl}/$image';
  }

  Future<void> _scrollToSection(GlobalKey key) async {
    if (!_scrollController.hasClients) return;
    BuildContext? ctx = key.currentContext;

    if (ctx == null) {
      final maxExtent = _scrollController.position.maxScrollExtent;
      final step = (maxExtent / 3).clamp(220.0, 900.0);
      var target = _scrollController.offset;

      while (ctx == null && target < maxExtent) {
        target = (target + step).clamp(0.0, maxExtent);
        await _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOut,
        );
        await Future<void>.delayed(const Duration(milliseconds: 24));
        ctx = key.currentContext;
      }
    }

    if (ctx == null) return;

    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  void _showSnack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppBrandColors.greenMid : Colors.red,
      ),
    );
  }

  // ============================================================================
  // DATA LOADERS
  // ============================================================================

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadOverview(),
      _loadBikesForControls(),
      _loadViewBikes(),
    ]);
    if (mounted) {
      setState(() => _lastRefreshedAt = DateTime.now());
    }
  }

  Future<void> _refreshAll() async {
    await _loadInitialData();
  }

  Future<void> _loadOverview() async {
    setState(() => _isLoadingOverview = true);
    try {
      final response = await http.get(
        Uri.parse('${_baseUri.toString()}/overview'),
        headers: _headers,
      );

      final body = _decodeBody(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          setState(() {
            _overview = data;
            _lastRefreshedAt = DateTime.now();
          });
        } else {
          setState(() => _overview = <String, dynamic>{});
        }
      } else {
        _showSnack(body['message']?.toString() ?? 'Unable to load overview.');
      }
    } catch (_) {
      _showSnack('Unable to load overview.');
    } finally {
      if (mounted) setState(() => _isLoadingOverview = false);
    }
  }

  Future<void> _loadBikesForControls() async {
    try {
      final response = await http.get(
        Uri.parse('${_baseUri.toString()}/bikes?status=all'),
        headers: _headers,
      );

      final body = _decodeBody(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = body['data'];
        final bikes = data is List
            ? data.whereType<Map>().map((row) {
                return row.map((key, value) => MapEntry('$key', value));
              }).toList()
            : <Map<String, dynamic>>[];

        setState(() {
          _allBikes = bikes;
          if (_allBikes.isNotEmpty && _selectedBikeId == null) {
            _selectedBikeId = _toInt(_allBikes.first['id']);
          } else if (_selectedBikeId != null &&
              !_allBikes.any((row) => _toInt(row['id']) == _selectedBikeId)) {
            _selectedBikeId = _allBikes.isNotEmpty
                ? _toInt(_allBikes.first['id'])
                : null;
          }
        });
      } else {
        _showSnack(body['message']?.toString() ?? 'Unable to load bike list.');
      }
    } catch (_) {
      _showSnack('Unable to load bike list.');
    }
  }

  Future<void> _loadViewBikes() async {
    setState(() => _isLoadingBikes = true);
    try {
      final response = await http.get(
        Uri.parse('${_baseUri.toString()}/bikes?status=$_selectedViewStatus'),
        headers: _headers,
      );

      final body = _decodeBody(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = body['data'];
        final bikes = data is List
            ? data.whereType<Map>().map((row) {
                return row.map((key, value) => MapEntry('$key', value));
              }).toList()
            : <Map<String, dynamic>>[];

        setState(() => _viewBikes = bikes);
      } else {
        _showSnack(
          body['message']?.toString() ?? 'Unable to load filtered bikes.',
        );
      }
    } catch (_) {
      _showSnack('Unable to load filtered bikes.');
    } finally {
      if (mounted) setState(() => _isLoadingBikes = false);
    }
  }

  // ============================================================================
  // ACTIONS
  // ============================================================================

  Future<void> _lockOrUnlockBike(bool lock) async {
    final bikeId = _selectedBikeId;
    if (bikeId == null) {
      _showSnack('Please select a bike first.');
      return;
    }

    setState(() => _isLockingBike = true);
    try {
      final response = await http.patch(
        Uri.parse('${_baseUri.toString()}/bikes/$bikeId/lock'),
        headers: _headers,
        body: jsonEncode({'lock': lock, 'admin_id': _adminId}),
      );
      final body = _decodeBody(response);
      final isOk = response.statusCode >= 200 && response.statusCode < 300;
      _showSnack(
        body['message']?.toString() ??
            (isOk
                ? (lock
                      ? 'Bike locked successfully.'
                      : 'Bike unlocked successfully.')
                : 'Unable to update bike lock status.'),
        success: isOk,
      );
      if (isOk) {
        await Future.wait([
          _loadOverview(),
          _loadBikesForControls(),
          _loadViewBikes(),
        ]);
      }
    } catch (_) {
      _showSnack('Unable to update bike lock status.');
    } finally {
      if (mounted) setState(() => _isLockingBike = false);
    }
  }

  // ============================================================================
  // UI BUILDERS
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final bikes = _overview['bikes'] is Map<String, dynamic>
        ? _overview['bikes'] as Map<String, dynamic>
        : <String, dynamic>{};

    final chartSeries = [
      _ChartEntry(
        label: 'Available',
        value: _toInt(bikes['available_bikes']),
        color: _statusColor('available'),
      ),
      _ChartEntry(
        label: 'Active',
        value: _toInt(bikes['active_bikes']),
        color: _statusColor('active'),
      ),
      _ChartEntry(
        label: 'Inactive',
        value: _toInt(bikes['inactive_bikes']),
        color: _statusColor('inactive'),
      ),
      _ChartEntry(
        label: 'Reserved',
        value: _toInt(bikes['reserved_bikes']),
        color: _statusColor('reserved'),
      ),
      _ChartEntry(
        label: 'Maintenance',
        value: _toInt(bikes['maintenance_bikes']),
        color: _statusColor('maintenance'),
      ),
      _ChartEntry(
        label: 'Tampered',
        value: _toInt(bikes['tampered_bikes']),
        color: _statusColor('tampered'),
      ),
    ];

    final bottomInset =
        MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 20;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppBrandColors.blackBackgroundGradient,
      ),
      child: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
          children: [
            Text(
              'Bike Operations Core',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppBrandColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _buildTopShortcuts(),
            const SizedBox(height: 12),
            _buildStatsSection(bikes, chartSeries),
            const SizedBox(height: 14),
            _buildLockSection(),
            const SizedBox(height: 14),
            _buildViewSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopShortcuts() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _shortcutButton(
          icon: Icons.pie_chart_rounded,
          label: 'Stats',
          onTap: () => _scrollToSection(_statsSectionKey),
        ),
        _shortcutButton(
          icon: Icons.lock_clock_rounded,
          label: 'Lock Controls',
          onTap: () => _scrollToSection(_lockSectionKey),
        ),
        _shortcutButton(
          icon: Icons.visibility_rounded,
          label: 'View',
          onTap: () => _scrollToSection(_viewSectionKey),
        ),
      ],
    );
  }

  Widget _shortcutButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: AppBrandColors.greenGradient,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppBrandColors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppBrandColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(
    Map<String, dynamic> bikes,
    List<_ChartEntry> chartSeries,
  ) {
    return Card(
      key: _statsSectionKey,
      color: AppBrandColors.blackEnd,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Align(
              alignment: Alignment.center,
              child: Text(
                'A. Bike Stats',
                style: TextStyle(
                  color: AppBrandColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _lastRefreshedAt == null
                      ? 'Fresh data loaded on page open'
                      : 'Last update: ${_lastRefreshedAt!.hour.toString().padLeft(2, '0')}:${_lastRefreshedAt!.minute.toString().padLeft(2, '0')}:${_lastRefreshedAt!.second.toString().padLeft(2, '0')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppBrandColors.whiteMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.center,
                  child: IconButton(
                    tooltip: 'Refresh now',
                    onPressed: _isLoadingOverview ? null : _refreshAll,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppBrandColors.greenMid,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingOverview)
              const Center(child: CircularProgressIndicator())
            else ...[
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 250,
                      height: 250,
                      child: CustomPaint(
                        painter: _PieChartPainter(
                          entries: chartSeries,
                          totalLabel: '${_toInt(bikes['total_bikes'])}',
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Total Bikes',
                      style: TextStyle(
                        color: AppBrandColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: chartSeries
                    .map(
                      (entry) => AppStatusChip(
                        label: entry.label,
                        color: entry.color,
                        value: entry.value,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLockSection() {
    return Card(
      key: _lockSectionKey,
      color: AppBrandColors.blackEnd,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'B. Lock Controls',
              style: TextStyle(
                color: AppBrandColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _selectedBikeId,
              items: _allBikes.map((bike) {
                final bikeId = _toInt(bike['id']);
                final bikeCode = _toText(bike['bike_code']);
                final bikeName = _toText(bike['bike_name']);
                final status = _toText(bike['status']);

                return DropdownMenuItem<int>(
                  value: bikeId,
                  child: Text('#$bikeId • $bikeName • $bikeCode • $status'),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedBikeId = value),
              decoration: const InputDecoration(
                labelText: 'Select Bike',
                prefixIcon: Icon(Icons.directions_bike_rounded),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLockingBike
                        ? null
                        : () => _lockOrUnlockBike(true),
                    icon: const Icon(Icons.lock_rounded),
                    label: const Text('Lock Bike'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLockingBike
                        ? null
                        : () => _lockOrUnlockBike(false),
                    icon: _isLockingBike
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppBrandColors.white,
                            ),
                          )
                        : const Icon(Icons.lock_open_rounded),
                    label: const Text('Unlock Bike'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewSection() {
    return Card(
      key: _viewSectionKey,
      color: AppBrandColors.blackEnd,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'C. View Bikes',
              style: TextStyle(
                color: AppBrandColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedViewStatus,
              items: _statusFilters
                  .map(
                    (status) => DropdownMenuItem<String>(
                      value: status,
                      child: Text(status),
                    ),
                  )
                  .toList(),
              onChanged: (value) async {
                if (value == null) return;
                setState(() => _selectedViewStatus = value);
                await _loadViewBikes();
              },
              decoration: const InputDecoration(
                labelText: 'Filter by Status',
                prefixIcon: Icon(Icons.filter_alt_rounded),
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoadingBikes)
              const Center(child: CircularProgressIndicator())
            else if (_viewBikes.isEmpty)
              const Text(
                'No bikes found for this status filter.',
                style: TextStyle(color: AppBrandColors.whiteMuted),
              )
            else
              ..._viewBikes.map((bike) {
                final bikeId = _toInt(bike['id']);
                final bikeCode = _toText(bike['bike_code']);
                final bikeName = _toText(bike['bike_name']);
                final status = _toText(bike['status']);
                final battery = _toInt(bike['battery_level']);
                final imageUrl = _resolveBikeImageUrl(bike['bike_image']);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppBrandColors.blackStart,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF343434)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 78,
                            height: 78,
                            child: imageUrl == null
                                ? Container(
                                    color: const Color(0xFF252525),
                                    child: const Icon(
                                      Icons.image_not_supported_rounded,
                                      color: AppBrandColors.whiteMuted,
                                    ),
                                  )
                                : Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) {
                                      return Container(
                                        color: const Color(0xFF252525),
                                        child: const Icon(
                                          Icons.broken_image_rounded,
                                          color: AppBrandColors.whiteMuted,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$bikeName ($bikeCode)',
                                style: const TextStyle(
                                  color: AppBrandColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Bike ID: $bikeId',
                                style: const TextStyle(
                                  color: AppBrandColors.whiteMuted,
                                ),
                              ),
                              Text(
                                'Battery: $battery%',
                                style: const TextStyle(
                                  color: AppBrandColors.whiteMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              AppStatusChip(
                                label: status,
                                color: _statusColor(status),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ChartEntry {
  const _ChartEntry({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

class _PieChartPainter extends CustomPainter {
  _PieChartPainter({required this.entries, required this.totalLabel});

  final List<_ChartEntry> entries;
  final String totalLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.34;

    if (total <= 0) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..color = AppBrandColors.whiteMuted;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    var startAngle = -math.pi / 2;
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      if (entry.value <= 0) continue;

      final sweepAngle = (entry.value / total) * (2 * math.pi);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 24
        ..color = entry.color;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }

    final numberPainterWithText = TextPainter(
      text: TextSpan(
        text: totalLabel,
        style: const TextStyle(
          color: AppBrandColors.white,

          // Font Size 72 is for the total number in the center of the pie chart. It is large and bold to make it stand out, while still fitting well within the chart area.
          fontSize: 72,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    numberPainterWithText.paint(
      canvas,
      Offset(
        center.dx - numberPainterWithText.width / 2,
        center.dy - numberPainterWithText.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.totalLabel != totalLabel;
  }
}

class _BikeOperationsLifecycleObserver with WidgetsBindingObserver {
  _BikeOperationsLifecycleObserver({required this.onResume});

  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume();
    }
  }
}
