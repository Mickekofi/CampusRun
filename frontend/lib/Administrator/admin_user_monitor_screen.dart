import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../admin_ip.dart';
import '../log_session.dart';
import '../theme_settings.dart';
import '../widgets/app_status_chip.dart';

class AdminUserMonitorScreen extends StatefulWidget {
  const AdminUserMonitorScreen({super.key});

  @override
  State<AdminUserMonitorScreen> createState() => _AdminUserMonitorScreenState();
}

class _AdminUserMonitorScreenState extends State<AdminUserMonitorScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _viewSearchController = TextEditingController();

  final _statsSectionKey = GlobalKey();
  final _statusSectionKey = GlobalKey();
  final _viewSectionKey = GlobalKey();

  final List<String> _userStatuses = const ['active', 'suspended', 'banned'];
  final List<String> _viewFilters = const [
    'all',
    'active',
    'suspended',
    'banned',
  ];

  bool _isLoadingStats = false;
  bool _isLoadingUsers = false;
  bool _isUpdatingUser = false;

  String _selectedStatusToSet = 'active';
  String _selectedViewFilter = 'all';
  String _viewSearchQuery = '';
  int? _selectedUserId;

  int _viewCurrentPage = 1;
  int _viewTotalPages = 1;
  int _viewTotalUsers = 0;
  static const int _viewPageSize = 12;

  DateTime? _lastRefreshedAt;

  Map<String, dynamic> _totals = const {};
  List<_ChartEntry> _levelBreakdown = const [];
  List<Map<String, dynamic>> _allUsers = const [];
  List<Map<String, dynamic>> _viewUsers = const [];

  int get _adminId => LogSession.instance.userId ?? 0;

  Uri get _baseUri =>
      Uri.parse('${AdminIp.baseUrl}/api/admin_user_monitor_routes');

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
    _viewSearchController.dispose();
    super.dispose();
  }

  late final _appLifecycleObserver = _UserMonitorLifecycleObserver(
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

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  String _toText(dynamic value, {String fallback = '--'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

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

  Color _levelColor(String level) {
    final normalized = level.toLowerCase();
    if (normalized.contains('100')) return AppBrandColors.greenMid;
    if (normalized.contains('200')) return AppBrandColors.greenStart;
    if (normalized.contains('300')) return AppBrandColors.redYellowMid;
    if (normalized.contains('400')) return AppBrandColors.redYellowEnd;
    if (normalized.contains('500') || normalized.contains('master')) {
      return AppBrandColors.redYellowStart;
    }
    return AppBrandColors.whiteMuted;
  }

  String? _resolveProfileImageUrl(dynamic profilePictureRaw) {
    final image = profilePictureRaw?.toString().trim() ?? '';
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
      _loadStats(),
      _loadUsersForStatusSection(),
      _loadViewUsers(),
    ]);
    if (mounted) setState(() => _lastRefreshedAt = DateTime.now());
  }

  Future<void> _refreshAll() async {
    await _loadInitialData();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final response = await http.get(
        Uri.parse('${_baseUri.toString()}/stats'),
        headers: _headers,
      );

      final body = _decodeBody(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = body['data'] is Map<String, dynamic>
            ? body['data'] as Map<String, dynamic>
            : <String, dynamic>{};

        final totals = data['totals'] is Map<String, dynamic>
            ? data['totals'] as Map<String, dynamic>
            : <String, dynamic>{};

        final levelRaw = data['level_breakdown'];
        final levelBreakdown = levelRaw is List
            ? levelRaw.whereType<Map>().map((entry) {
                final mapped = entry.map(
                  (key, value) => MapEntry('$key', value),
                );
                final label = _toText(mapped['level'], fallback: 'Other');
                return _ChartEntry(
                  label: label,
                  value: _toInt(mapped['count']),
                  color: _levelColor(label),
                );
              }).toList()
            : <_ChartEntry>[];

        setState(() {
          _totals = totals;
          _levelBreakdown = levelBreakdown;
          _lastRefreshedAt = DateTime.now();
        });
      } else {
        _showSnack(body['message']?.toString() ?? 'Unable to load user stats.');
      }
    } catch (_) {
      _showSnack('Unable to load user stats.');
    } finally {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _loadUsersForStatusSection() async {
    try {
      final response = await http.get(
        Uri.parse('${_baseUri.toString()}/users?status=all&page=1&limit=250'),
        headers: _headers,
      );

      final body = _decodeBody(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = body['data'];
        final rawRows = data is Map<String, dynamic> ? data['rows'] : data;

        final rows = rawRows is List
            ? rawRows.whereType<Map>().map((entry) {
                return entry.map((key, value) => MapEntry('$key', value));
              }).toList()
            : <Map<String, dynamic>>[];

        setState(() {
          _allUsers = rows;
          if (_allUsers.isNotEmpty && _selectedUserId == null) {
            _selectedUserId = _toInt(_allUsers.first['id']);
          } else if (_selectedUserId != null &&
              !_allUsers.any((row) => _toInt(row['id']) == _selectedUserId)) {
            _selectedUserId = _allUsers.isNotEmpty
                ? _toInt(_allUsers.first['id'])
                : null;
          }
        });
      } else {
        _showSnack(body['message']?.toString() ?? 'Unable to load users.');
      }
    } catch (_) {
      _showSnack('Unable to load users.');
    }
  }

  Future<void> _loadViewUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final query = {
        'status': _selectedViewFilter,
        'page': '$_viewCurrentPage',
        'limit': '$_viewPageSize',
        if (_viewSearchQuery.trim().isNotEmpty) 'q': _viewSearchQuery.trim(),
      };

      final response = await http.get(
        Uri.parse(
          '${_baseUri.toString()}/users',
        ).replace(queryParameters: query),
        headers: _headers,
      );

      final body = _decodeBody(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = body['data'];
        final rowsRaw = data is Map<String, dynamic> ? data['rows'] : data;
        final pagination = data is Map<String, dynamic>
            ? data['pagination'] as Map<String, dynamic>?
            : null;

        final rows = rowsRaw is List
            ? rowsRaw.whereType<Map>().map((entry) {
                return entry.map((key, value) => MapEntry('$key', value));
              }).toList()
            : <Map<String, dynamic>>[];

        setState(() {
          _viewUsers = rows;
          _viewCurrentPage = _toInt(pagination?['page']) == 0
              ? _viewCurrentPage
              : _toInt(pagination?['page']);
          _viewTotalPages = _toInt(pagination?['total_pages']) == 0
              ? 1
              : _toInt(pagination?['total_pages']);
          _viewTotalUsers = _toInt(pagination?['total_users']);
        });
      } else {
        _showSnack(body['message']?.toString() ?? 'Unable to load users.');
      }
    } catch (_) {
      _showSnack('Unable to load users.');
    } finally {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  // ============================================================================
  // ACTIONS
  // ============================================================================

  Future<void> _applyUserStatus() async {
    final userId = _selectedUserId;
    if (userId == null) {
      _showSnack('Please select a user first.');
      return;
    }

    setState(() => _isUpdatingUser = true);
    try {
      final response = await http.patch(
        Uri.parse('${_baseUri.toString()}/users/$userId/status'),
        headers: _headers,
        body: jsonEncode({
          'status': _selectedStatusToSet,
          'admin_id': _adminId,
        }),
      );

      final body = _decodeBody(response);
      final isOk = response.statusCode >= 200 && response.statusCode < 300;
      _showSnack(
        body['message']?.toString() ??
            (isOk
                ? 'User status updated successfully.'
                : 'Unable to update user status.'),
        success: isOk,
      );

      if (isOk) {
        await Future.wait([
          _loadStats(),
          _loadUsersForStatusSection(),
          _loadViewUsers(),
        ]);
      }
    } catch (_) {
      _showSnack('Unable to update user status.');
    } finally {
      if (mounted) setState(() => _isUpdatingUser = false);
    }
  }

  Future<void> _applyViewSearch() async {
    setState(() {
      _viewSearchQuery = _viewSearchController.text.trim();
      _viewCurrentPage = 1;
    });
    await _loadViewUsers();
  }

  Future<void> _goToPreviousPage() async {
    if (_viewCurrentPage <= 1) return;
    setState(() => _viewCurrentPage = _viewCurrentPage - 1);
    await _loadViewUsers();
  }

  Future<void> _goToNextPage() async {
    if (_viewCurrentPage >= _viewTotalPages) return;
    setState(() => _viewCurrentPage = _viewCurrentPage + 1);
    await _loadViewUsers();
  }

  // ============================================================================
  // UI BUILDERS
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final totalStudents = _toInt(_totals['total_students']);
    final activeStudents = _toInt(_totals['active_students']);
    final suspendedStudents = _toInt(_totals['suspended_students']);
    final bannedStudents = _toInt(_totals['banned_students']);

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
              'User Monitor Intelligence',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppBrandColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _buildTopShortcuts(),
            const SizedBox(height: 12),
            _buildStatsSection(
              totalStudents: totalStudents,
              activeStudents: activeStudents,
              suspendedStudents: suspendedStudents,
              bannedStudents: bannedStudents,
            ),
            const SizedBox(height: 14),
            _buildUserStatusSection(),
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
          icon: Icons.manage_accounts_rounded,
          label: 'User Status',
          onTap: () => _scrollToSection(_statusSectionKey),
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

  Widget _buildStatsSection({
    required int totalStudents,
    required int activeStudents,
    required int suspendedStudents,
    required int bannedStudents,
  }) {
    return Card(
      key: _statsSectionKey,
      color: AppBrandColors.blackEnd,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'A. Stats',
              style: TextStyle(
                color: AppBrandColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
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
            Align(
              alignment: Alignment.center,
              child: IconButton(
                tooltip: 'Refresh now',
                onPressed: _isLoadingStats ? null : _refreshAll,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppBrandColors.greenMid,
                ),
              ),
            ),
            if (_isLoadingStats)
              const Center(child: CircularProgressIndicator())
            else ...[
              SizedBox(
                width: 270,
                height: 270,
                child: CustomPaint(
                  painter: _PieChartPainter(
                    entries: _levelBreakdown,
                    totalLabel: '$totalStudents',
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Total Students On Board',
                style: TextStyle(
                  color: AppBrandColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _levelBreakdown
                    .map(
                      (entry) => AppStatusChip(
                        label: entry.label,
                        color: entry.color,
                        value: entry.value,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  AppStatusChip(
                    label: 'Active',
                    color: _statusColor('active'),
                    value: activeStudents,
                  ),
                  AppStatusChip(
                    label: 'Suspended',
                    color: _statusColor('suspended'),
                    value: suspendedStudents,
                  ),
                  AppStatusChip(
                    label: 'Banned',
                    color: _statusColor('banned'),
                    value: bannedStudents,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserStatusSection() {
    final userEntries = _allUsers.map((user) {
      final userId = _toInt(user['id']);
      final fullName = _toText(user['full_name']);
      final studentId = _toText(user['student_id']);
      final status = _toText(user['account_status']);
      return DropdownMenuEntry<int>(
        value: userId,
        label: '$fullName ($studentId) • $status',
      );
    }).toList();

    return Card(
      key: _statusSectionKey,
      color: AppBrandColors.blackEnd,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'B. User Status',
              style: TextStyle(
                color: AppBrandColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            DropdownMenu<int>(
              width: double.infinity,
              initialSelection: _selectedUserId,
              enableFilter: true,
              enableSearch: true,
              requestFocusOnTap: true,
              label: const Text('Select user (search name or student_id)'),
              leadingIcon: const Icon(Icons.person_search_rounded),
              dropdownMenuEntries: userEntries,
              onSelected: (value) => setState(() => _selectedUserId = value),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedStatusToSet,
              items: _userStatuses
                  .map(
                    (status) => DropdownMenuItem<String>(
                      value: status,
                      child: Text(status),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedStatusToSet = value);
              },
              decoration: const InputDecoration(
                labelText: 'Set Account Status',
                prefixIcon: Icon(Icons.admin_panel_settings_rounded),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _isUpdatingUser ? null : _applyUserStatus,
                icon: _isUpdatingUser
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppBrandColors.white,
                        ),
                      )
                    : const Icon(Icons.save_as_rounded),
                label: const Text('Apply User Status'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewSection() {
    final filteredUsers = _viewUsers;

    return Card(
      key: _viewSectionKey,
      color: AppBrandColors.blackEnd,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'C. View',
              style: TextStyle(
                color: AppBrandColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedViewFilter,
              items: _viewFilters
                  .map(
                    (status) =>
                        DropdownMenuItem(value: status, child: Text(status)),
                  )
                  .toList(),
              onChanged: (value) async {
                if (value == null) return;
                setState(() {
                  _selectedViewFilter = value;
                  _viewCurrentPage = 1;
                });
                await _loadViewUsers();
              },
              decoration: const InputDecoration(
                labelText: 'View by Account Status',
                prefixIcon: Icon(Icons.filter_alt_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _viewSearchController,
              onFieldSubmitted: (_) async {
                await _applyViewSearch();
              },
              decoration: const InputDecoration(
                labelText: 'Quick search (name or student_id)',
                prefixIcon: Icon(Icons.search_rounded),
                suffixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isLoadingUsers ? null : _applyViewSearch,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Search'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _isLoadingUsers
                      ? null
                      : () async {
                          _viewSearchController.clear();
                          await _applyViewSearch();
                        },
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text('Clear'),
                ),
                const Spacer(),
                Text(
                  'Total: $_viewTotalUsers',
                  style: const TextStyle(
                    color: AppBrandColors.whiteMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingUsers)
              const Center(child: CircularProgressIndicator())
            else if (filteredUsers.isEmpty)
              const Text(
                'No users found for this selection.',
                style: TextStyle(color: AppBrandColors.whiteMuted),
              )
            else
              ...filteredUsers.map((user) {
                final userId = _toInt(user['id']);
                final fullName = _toText(user['full_name']);
                final studentId = _toText(user['student_id']);
                final status = _toText(user['account_status']);
                final email = _toText(user['email']);
                final phone = _toText(user['phone']);
                final wallet = _toDouble(user['wallet_balance']);
                final totalRides = _toInt(user['total_rides']);
                final profileUrl = _resolveProfileImageUrl(
                  user['profile_picture'],
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppBrandColors.blackStart,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF343434)),
                  ),
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF252525),
                        backgroundImage: profileUrl == null
                            ? null
                            : NetworkImage(profileUrl),
                        child: profileUrl == null
                            ? const Icon(
                                Icons.person_rounded,
                                color: AppBrandColors.whiteMuted,
                              )
                            : null,
                      ),
                      title: Text(
                        '$fullName ($studentId)',
                        style: const TextStyle(
                          color: AppBrandColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        email,
                        style: const TextStyle(
                          color: AppBrandColors.whiteMuted,
                        ),
                      ),
                      trailing: AppStatusChip(
                        label: status,
                        color: _statusColor(status),
                      ),
                      children: [
                        _detailRow('User ID', '$userId'),
                        _detailRow('Student ID', studentId),
                        _detailRow('Full Name', fullName),
                        _detailRow('Email', email),
                        _detailRow('Phone', phone),
                        _detailRow('Wallet Balance', wallet.toStringAsFixed(2)),
                        _detailRow('Total Rides', '$totalRides'),
                        _detailRow('Account Status', status),
                        _detailRow('Profile Picture', profileUrl ?? '--'),
                      ],
                    ),
                  ),
                );
              }),
            if (!_isLoadingUsers && filteredUsers.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _viewCurrentPage > 1 && !_isLoadingUsers
                        ? _goToPreviousPage
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                    label: const Text('Prev'),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Page $_viewCurrentPage of $_viewTotalPages',
                    style: const TextStyle(
                      color: AppBrandColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed:
                        _viewCurrentPage < _viewTotalPages && !_isLoadingUsers
                        ? _goToNextPage
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$key:',
              style: const TextStyle(
                color: AppBrandColors.whiteMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppBrandColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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

    final numberPainter = TextPainter(
      text: TextSpan(
        text: totalLabel,
        style: const TextStyle(
          color: AppBrandColors.white,
          fontSize: 72,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    numberPainter.paint(
      canvas,
      Offset(
        center.dx - numberPainter.width / 2,
        center.dy - numberPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.totalLabel != totalLabel;
  }
}

class _UserMonitorLifecycleObserver with WidgetsBindingObserver {
  _UserMonitorLifecycleObserver({required this.onResume});

  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume();
    }
  }
}
