import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../admin_ip.dart';
import '../log_session.dart';
import '../theme_settings.dart';

class AdminStationUploadScreen extends StatefulWidget {
  const AdminStationUploadScreen({super.key});

  @override
  State<AdminStationUploadScreen> createState() =>
      _AdminStationUploadScreenState();
}

class _AdminStationUploadScreenState extends State<AdminStationUploadScreen> {
  // ============================================================================
  // SCROLL + SECTION KEYS
  // ============================================================================

  final _scrollController = ScrollController();
  final _sectionAKey = GlobalKey();
  final _sectionBKey = GlobalKey();
  final _sectionCKey = GlobalKey();
  final _sectionDKey = GlobalKey();
  final _sectionEKey = GlobalKey();
  final _sectionFKey = GlobalKey();

  // ============================================================================
  // FORM KEYS
  // ============================================================================

  final _createStationFormKey = GlobalKey<FormState>();
  final _updateStationFormKey = GlobalKey<FormState>();
  final _priceFormKey = GlobalKey<FormState>();
  final _createZoneFormKey = GlobalKey<FormState>();

  // ============================================================================
  // SECTION A (CREATE STATION)
  // ============================================================================

  final _createNameController = TextEditingController();
  final _createLatController = TextEditingController();
  final _createLngController = TextEditingController();
  final _createRadiusController = TextEditingController(text: '50');
  final _createBasePriceController = TextEditingController(text: '0');
  String _createStationType = 'both';
  String _createStationStatus = 'active';

  // ============================================================================
  // SECTION B (UPDATE STATION)
  // ============================================================================

  int? _selectedUpdateStationId;
  final _updateNameController = TextEditingController();
  final _updateLatController = TextEditingController();
  final _updateLngController = TextEditingController();
  final _updateRadiusController = TextEditingController(text: '50');
  final _updateBasePriceController = TextEditingController(text: '0');
  String _updateStationType = 'both';
  String _updateStationStatus = 'active';

  // ============================================================================
  // SECTION D (PRICES)
  // ============================================================================

  int? _priceFromStationId;
  int? _priceToStationId;
  final _priceCedisController = TextEditingController();
  final _priceEtaMinutesController = TextEditingController();
  final _priceDescriptionController = TextEditingController();
  String _priceStatus = 'active';

  // ============================================================================
  // SECTION E (CREATE BANNED ZONE)
  // ============================================================================

  final _zoneNameController = TextEditingController();
  final _zoneLatController = TextEditingController();
  final _zoneLngController = TextEditingController();
  final _zoneRadiusController = TextEditingController(text: '100');
  final _zoneReasonController = TextEditingController();
  String _zoneStatus = 'active';

  // ============================================================================
  // DATA + FLAGS
  // ============================================================================

  final List<String> _stationTypes = const ['pickup', 'dropoff', 'both'];
  final List<String> _stationStatuses = const ['active', 'inactive'];
  final List<String> _priceStatuses = const ['active', 'inactive'];
  final List<String> _zoneStatuses = const ['active', 'inactive'];

  bool _isLoadingStations = false;
  bool _isLoadingPrices = false;
  bool _isLoadingZones = false;

  bool _isCreatingStation = false;
  bool _isUpdatingStation = false;
  bool _isCreatingPrice = false;
  bool _isCreatingZone = false;

  List<Map<String, dynamic>> _stations = const [];
  List<Map<String, dynamic>> _prices = const [];
  List<Map<String, dynamic>> _bannedZones = const [];

  int get _adminId => LogSession.instance.userId ?? 0;

  Uri get _baseUri =>
      Uri.parse('${AdminIp.baseUrl}/api/admin_station_upload_routes');

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-admin-id': '$_adminId',
  };

  // ============================================================================
  // LIFECYCLE
  // ============================================================================

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.dispose();

    _createNameController.dispose();
    _createLatController.dispose();
    _createLngController.dispose();
    _createRadiusController.dispose();
    _createBasePriceController.dispose();

    _updateNameController.dispose();
    _updateLatController.dispose();
    _updateLngController.dispose();
    _updateRadiusController.dispose();
    _updateBasePriceController.dispose();

    _priceCedisController.dispose();
    _priceEtaMinutesController.dispose();
    _priceDescriptionController.dispose();

    _zoneNameController.dispose();
    _zoneLatController.dispose();
    _zoneLngController.dispose();
    _zoneRadiusController.dispose();
    _zoneReasonController.dispose();

    super.dispose();
  }

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

  void _showSnack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppBrandColors.greenMid : Colors.red,
      ),
    );
  }

  Future<void> _scrollToSection(GlobalKey key) async {
    if (!_scrollController.hasClients) return;
    BuildContext? ctx = key.currentContext;

    if (ctx == null) {
      final maxExtent = _scrollController.position.maxScrollExtent;
      final step = (maxExtent / 4).clamp(220.0, 900.0);
      var target = _scrollController.offset;

      while (ctx == null && target < maxExtent) {
        target = (target + step).clamp(0.0, maxExtent);
        await _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        ctx = key.currentContext;
      }

      if (ctx == null) {
        await _scrollController.animateTo(
          maxExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));
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

  Future<void> _loadInitialData() async {
    await Future.wait([_loadStations(), _loadPrices(), _loadBannedZones()]);
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadStations(), _loadPrices(), _loadBannedZones()]);
  }

  // ============================================================================
  // DATA LOADERS
  // ============================================================================

  Future<void> _loadStations() async {
    setState(() => _isLoadingStations = true);
    try {
      final response = await http.get(
        Uri.parse('${_baseUri.toString()}/stations'),
        headers: _headers,
      );

      final body = _decodeBody(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = body['data'];
        if (data is List) {
          setState(() {
            _stations = data.whereType<Map>().map((row) {
              return row.map((key, value) => MapEntry('$key', value));
            }).toList();
          });
        }
      } else {
        _showSnack(body['message']?.toString() ?? 'Unable to load stations.');
      }
    } catch (_) {
      _showSnack('Unable to load stations.');
    } finally {
      if (mounted) setState(() => _isLoadingStations = false);
    }
  }

  Future<void> _loadPrices() async {
    setState(() => _isLoadingPrices = true);
    try {
      final response = await http.get(
        Uri.parse('${_baseUri.toString()}/prices'),
        headers: _headers,
      );

      final body = _decodeBody(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = body['data'];
        if (data is List) {
          setState(() {
            _prices = data.whereType<Map>().map((row) {
              return row.map((key, value) => MapEntry('$key', value));
            }).toList();
          });
        }
      } else {
        _showSnack(
          body['message']?.toString() ?? 'Unable to load transport prices.',
        );
      }
    } catch (_) {
      _showSnack('Unable to load transport prices.');
    } finally {
      if (mounted) setState(() => _isLoadingPrices = false);
    }
  }

  Future<void> _loadBannedZones() async {
    setState(() => _isLoadingZones = true);
    try {
      final response = await http.get(
        Uri.parse('${_baseUri.toString()}/banned-zones'),
        headers: _headers,
      );

      final body = _decodeBody(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = body['data'];
        if (data is List) {
          setState(() {
            _bannedZones = data.whereType<Map>().map((row) {
              return row.map((key, value) => MapEntry('$key', value));
            }).toList();
          });
        }
      } else {
        _showSnack(
          body['message']?.toString() ?? 'Unable to load banned zones.',
        );
      }
    } catch (_) {
      _showSnack('Unable to load banned zones.');
    } finally {
      if (mounted) setState(() => _isLoadingZones = false);
    }
  }

  // ============================================================================
  // SECTION A: CREATE STATION
  // ============================================================================

  Future<void> _createStation() async {
    if (!_createStationFormKey.currentState!.validate()) return;

    setState(() => _isCreatingStation = true);
    try {
      final payload = {
        'station_name': _createNameController.text.trim(),
        'station_type': _createStationType,
        'latitude': double.parse(_createLatController.text.trim()),
        'longitude': double.parse(_createLngController.text.trim()),
        'radius_meters':
            int.tryParse(_createRadiusController.text.trim()) ?? 50,
        'base_price':
            double.tryParse(_createBasePriceController.text.trim()) ?? 0.0,
        'status': _createStationStatus,
        'admin_id': _adminId,
      };

      final response = await http.post(
        Uri.parse('${_baseUri.toString()}/stations'),
        headers: _headers,
        body: jsonEncode(payload),
      );

      final body = _decodeBody(response);
      final isOk = response.statusCode >= 200 && response.statusCode < 300;
      _showSnack(
        body['message']?.toString() ??
            (isOk
                ? 'Station created successfully.'
                : 'Unable to create station.'),
        success: isOk,
      );

      if (!isOk) return;
      _resetCreateStationForm();
      await _loadStations();
      await _scrollToSection(_sectionBKey);
    } catch (_) {
      _showSnack('Unable to create station right now.');
    } finally {
      if (mounted) setState(() => _isCreatingStation = false);
    }
  }

  void _resetCreateStationForm() {
    setState(() {
      _createNameController.clear();
      _createLatController.clear();
      _createLngController.clear();
      _createRadiusController.text = '50';
      _createBasePriceController.text = '0';
      _createStationType = 'both';
      _createStationStatus = 'active';
    });
  }

  // ============================================================================
  // SECTION B: UPDATE STATION
  // ============================================================================

  void _onPickStationForUpdate(int? stationId) {
    if (stationId == null) return;

    final selected = _stations.cast<Map<String, dynamic>?>().firstWhere(
      (row) => _toInt(row?['id']) == stationId,
      orElse: () => null,
    );

    if (selected == null) {
      _showSnack('Unable to load selected station details.');
      return;
    }

    setState(() {
      _selectedUpdateStationId = stationId;
      _updateNameController.text = '${selected['station_name'] ?? ''}';
      _updateLatController.text = '${selected['latitude'] ?? ''}';
      _updateLngController.text = '${selected['longitude'] ?? ''}';
      _updateRadiusController.text = '${selected['radius_meters'] ?? 50}';
      _updateBasePriceController.text = '${selected['base_price'] ?? 0}';

      final typeValue = '${selected['station_type'] ?? 'both'}';
      _updateStationType = _stationTypes.contains(typeValue)
          ? typeValue
          : 'both';

      final statusValue = '${selected['status'] ?? 'active'}';
      _updateStationStatus = _stationStatuses.contains(statusValue)
          ? statusValue
          : 'active';
    });
  }

  Future<void> _updateStation() async {
    if (_selectedUpdateStationId == null) {
      _showSnack('Select a station to update.');
      return;
    }
    if (!_updateStationFormKey.currentState!.validate()) return;

    setState(() => _isUpdatingStation = true);
    try {
      final payload = {
        'station_name': _updateNameController.text.trim(),
        'station_type': _updateStationType,
        'latitude': double.parse(_updateLatController.text.trim()),
        'longitude': double.parse(_updateLngController.text.trim()),
        'radius_meters':
            int.tryParse(_updateRadiusController.text.trim()) ?? 50,
        'base_price':
            double.tryParse(_updateBasePriceController.text.trim()) ?? 0.0,
        'status': _updateStationStatus,
        'admin_id': _adminId,
      };

      final response = await http.put(
        Uri.parse('${_baseUri.toString()}/stations/$_selectedUpdateStationId'),
        headers: _headers,
        body: jsonEncode(payload),
      );

      final body = _decodeBody(response);
      final isOk = response.statusCode >= 200 && response.statusCode < 300;
      _showSnack(
        body['message']?.toString() ??
            (isOk
                ? 'Station updated successfully.'
                : 'Unable to update station.'),
        success: isOk,
      );

      if (!isOk) return;
      await _loadStations();
    } catch (_) {
      _showSnack('Unable to update station right now.');
    } finally {
      if (mounted) setState(() => _isUpdatingStation = false);
    }
  }

  void _resetUpdateStationForm() {
    setState(() {
      _selectedUpdateStationId = null;
      _updateNameController.clear();
      _updateLatController.clear();
      _updateLngController.clear();
      _updateRadiusController.text = '50';
      _updateBasePriceController.text = '0';
      _updateStationType = 'both';
      _updateStationStatus = 'active';
    });
  }

  // ============================================================================
  // SECTION C: VIEW + DELETE STATIONS
  // ============================================================================

  Future<void> _deleteStation(int stationId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppBrandColors.blackEnd,
          title: const Text(
            'Delete Station',
            style: TextStyle(color: AppBrandColors.white),
          ),
          content: const Text(
            'Delete this station? This action cannot be undone.',
            style: TextStyle(color: AppBrandColors.whiteMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse('${_baseUri.toString()}/stations/$stationId'),
        headers: _headers,
      );

      final body = _decodeBody(response);
      final isOk = response.statusCode >= 200 && response.statusCode < 300;
      _showSnack(
        body['message']?.toString() ??
            (isOk
                ? 'Station deleted successfully.'
                : 'Unable to delete station.'),
        success: isOk,
      );

      if (!isOk) return;
      if (_selectedUpdateStationId == stationId) {
        _resetUpdateStationForm();
      }
      await _loadStations();
      await _loadPrices();
    } catch (_) {
      _showSnack('Unable to delete station right now.');
    }
  }

  // ============================================================================
  // SECTION D: ROUTE PRICES
  // ============================================================================
  /*
  Future<void> _saveRoutePrice() async {
    if (!_priceFormKey.currentState!.validate()) return;

    if (_priceFromStationId == null || _priceToStationId == null) {
      _showSnack('Select both FROM and TO stations.');
      return;
    }

    if (_priceFromStationId == _priceToStationId) {
      _showSnack('FROM and TO stations must be different.');
      return;
    }

    setState(() => _isCreatingPrice = true);
    try {
      final payload = {
        'from_station_id': _priceFromStationId,
        'to_station_id': _priceToStationId,
        'price_cedis': double.parse(_priceCedisController.text.trim()),
        'estimated_duration_minutes':
            _priceEtaMinutesController.text.trim().isEmpty
            ? null
            : int.tryParse(_priceEtaMinutesController.text.trim()),
        'description': _priceDescriptionController.text.trim().isEmpty
            ? null
            : _priceDescriptionController.text.trim(),
        'status': _priceStatus,
        'admin_id': _adminId,
      };

      final response = await http.post(
        Uri.parse('${_baseUri.toString()}/prices'),
        headers: _headers,
        body: jsonEncode(payload),
      );

      final body = _decodeBody(response);
      final isOk = response.statusCode >= 200 && response.statusCode < 300;
      _showSnack(
        body['message']?.toString() ??
            (isOk ? 'Route price saved.' : 'Unable to save route price.'),
        success: isOk,
      );

      if (!isOk) return;
      _priceCedisController.clear();
      _priceEtaMinutesController.clear();
      _priceDescriptionController.clear();
      await _loadPrices();
    } catch (_) {
      _showSnack('Unable to save route price right now.');
    } finally {
      if (mounted) setState(() => _isCreatingPrice = false);
    }
  }


  */

  Future<void> _deletePrice(int priceId) async {
    try {
      final response = await http.delete(
        Uri.parse('${_baseUri.toString()}/prices/$priceId'),
        headers: _headers,
      );

      final body = _decodeBody(response);
      final isOk = response.statusCode >= 200 && response.statusCode < 300;
      _showSnack(
        body['message']?.toString() ??
            (isOk
                ? 'Transport price deleted successfully.'
                : 'Unable to delete transport price.'),
        success: isOk,
      );

      if (isOk) {
        await _loadPrices();
      }
    } catch (_) {
      _showSnack('Unable to delete transport price right now.');
    }
  }

  Future<void> _saveRoutePrice() async {
    if (!_priceFormKey.currentState!.validate()) return;

    if (_priceFromStationId == null || _priceToStationId == null) {
      _showSnack('Select both FROM and TO stations.');
      return;
    }

    if (_priceFromStationId == _priceToStationId) {
      _showSnack('FROM and TO stations must be different.');
      return;
    }

    setState(() => _isCreatingPrice = true);
    try {
      // THE FIX: Convert human minutes to machine seconds right here
      final String minStr = _priceEtaMinutesController.text.trim();
      final int? allocatedSeconds = minStr.isNotEmpty
          ? (int.tryParse(minStr) ?? 0) * 60
          : null;

      final payload = {
        'from_station_id': _priceFromStationId,
        'to_station_id': _priceToStationId,
        'price_cedis': double.parse(_priceCedisController.text.trim()),

        // THE FIX: Send the exact key and the seconds to the backend
        'allocated_time': allocatedSeconds,

        'description': _priceDescriptionController.text.trim().isEmpty
            ? null
            : _priceDescriptionController.text.trim(),
        'status': _priceStatus,
        'admin_id': _adminId,
      };

      final response = await http.post(
        Uri.parse('${_baseUri.toString()}/prices'),
        headers: _headers,
        body: jsonEncode(payload),
      );

      final body = _decodeBody(response);
      final isOk = response.statusCode >= 200 && response.statusCode < 300;
      _showSnack(
        body['message']?.toString() ??
            (isOk ? 'Route price saved.' : 'Unable to save route price.'),
        success: isOk,
      );

      if (!isOk) return;
      _priceCedisController.clear();
      _priceEtaMinutesController.clear();
      _priceDescriptionController.clear();
      await _loadPrices();
    } catch (_) {
      _showSnack('Unable to save route price right now.');
    } finally {
      if (mounted) setState(() => _isCreatingPrice = false);
    }
  }

  // ============================================================================
  // SECTION E/F: BANNED ZONES
  // ============================================================================

  Future<void> _createBannedZone() async {
    if (!_createZoneFormKey.currentState!.validate()) return;

    setState(() => _isCreatingZone = true);
    try {
      final payload = {
        'zone_name': _zoneNameController.text.trim(),
        'latitude': double.parse(_zoneLatController.text.trim()),
        'longitude': double.parse(_zoneLngController.text.trim()),
        'radius_meters': int.tryParse(_zoneRadiusController.text.trim()) ?? 100,
        'reason': _zoneReasonController.text.trim().isEmpty
            ? null
            : _zoneReasonController.text.trim(),
        'status': _zoneStatus,
        'admin_id': _adminId,
      };

      final response = await http.post(
        Uri.parse('${_baseUri.toString()}/banned-zones'),
        headers: _headers,
        body: jsonEncode(payload),
      );

      final body = _decodeBody(response);
      final isOk = response.statusCode >= 200 && response.statusCode < 300;
      _showSnack(
        body['message']?.toString() ??
            (isOk
                ? 'Banned zone created successfully.'
                : 'Unable to create banned zone.'),
        success: isOk,
      );

      if (!isOk) return;
      _zoneNameController.clear();
      _zoneLatController.clear();
      _zoneLngController.clear();
      _zoneRadiusController.text = '100';
      _zoneReasonController.clear();
      _zoneStatus = 'active';
      await _loadBannedZones();
      await _scrollToSection(_sectionFKey);
    } catch (_) {
      _showSnack('Unable to create banned zone right now.');
    } finally {
      if (mounted) setState(() => _isCreatingZone = false);
    }
  }

  Future<void> _deleteBannedZone(int zoneId) async {
    try {
      final response = await http.delete(
        Uri.parse('${_baseUri.toString()}/banned-zones/$zoneId'),
        headers: _headers,
      );

      final body = _decodeBody(response);
      final isOk = response.statusCode >= 200 && response.statusCode < 300;
      _showSnack(
        body['message']?.toString() ??
            (isOk
                ? 'Banned zone deleted successfully.'
                : 'Unable to delete banned zone.'),
        success: isOk,
      );

      if (isOk) {
        await _loadBannedZones();
      }
    } catch (_) {
      _showSnack('Unable to delete banned zone right now.');
    }
  }

  // ============================================================================
  // WIDGET BUILDERS
  // ============================================================================

  Widget _buildShortcutButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppBrandColors.redYellowMid,
        foregroundColor: AppBrandColors.white,
      ),
    );
  }

  Widget _buildTopShortcuts() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppBrandColors.blackEnd,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _buildShortcutButton(
            label: 'A · Create',
            icon: Icons.add_location_alt_rounded,
            onTap: () => _scrollToSection(_sectionAKey),
          ),
          _buildShortcutButton(
            label: 'B · Update',
            icon: Icons.edit_location_alt_rounded,
            onTap: () => _scrollToSection(_sectionBKey),
          ),
          _buildShortcutButton(
            label: 'C · Delete Stations',
            icon: Icons.delete_forever_rounded,
            onTap: () => _scrollToSection(_sectionCKey),
          ),
          _buildShortcutButton(
            label: 'D · Prices',
            icon: Icons.price_change_rounded,
            onTap: () => _scrollToSection(_sectionDKey),
          ),
          _buildShortcutButton(
            label: 'E · Create Zones',
            icon: Icons.warning_amber_rounded,
            onTap: () => _scrollToSection(_sectionEKey),
          ),
          _buildShortcutButton(
            label: 'F · Delete Zones',
            icon: Icons.gpp_bad_rounded,
            onTap: () => _scrollToSection(_sectionFKey),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionA() {
    return Card(
      key: _sectionAKey,
      color: AppBrandColors.blackEnd,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _createStationFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Section A (Create Station)',
                style: TextStyle(
                  color: AppBrandColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hint: Latitude around Ghana campus is often ~5.x, longitude ~-0.x, radius controls geofence size in meters.',
                style: TextStyle(color: AppBrandColors.whiteMuted),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _createNameController,
                decoration: const InputDecoration(
                  labelText: 'Station Name',
                  hintText: 'e.g. North Campus Junction',
                  prefixIcon: Icon(Icons.store_mall_directory_rounded),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Station name is required'
                    : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _createLatController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        hintText: 'e.g. 5.64321000',
                        prefixIcon: Icon(Icons.navigation_rounded),
                      ),
                      validator: (value) =>
                          (double.tryParse(value ?? '') == null)
                          ? 'Valid latitude required'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _createLngController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        hintText: 'e.g. -0.18765000',
                        prefixIcon: Icon(Icons.explore_rounded),
                      ),
                      validator: (value) =>
                          (double.tryParse(value ?? '') == null)
                          ? 'Valid longitude required'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _createRadiusController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Radius (meters)',
                        hintText: 'e.g. 50',
                        prefixIcon: Icon(Icons.radar_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _createBasePriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Base Price (GHS)',
                        hintText: 'e.g. 0 or 2.5',
                        prefixIcon: Icon(Icons.payments_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _createStationType,
                      items: _stationTypes
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _createStationType = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Station Type',
                        prefixIcon: Icon(Icons.alt_route_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _createStationStatus,
                      items: _stationStatuses
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _createStationStatus = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(Icons.flag_circle_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isCreatingStation ? null : _createStation,
                      icon: _isCreatingStation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppBrandColors.white,
                              ),
                            )
                          : const Icon(Icons.add_business_rounded),
                      label: const Text('Create Station'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _resetCreateStationForm,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Reset'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionB() {
    return Card(
      key: _sectionBKey,
      color: AppBrandColors.blackEnd,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _updateStationFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Section B (Update Station)',
                style: TextStyle(
                  color: AppBrandColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pick an existing station first, fields will auto-populate for editing.',
                style: TextStyle(color: AppBrandColors.whiteMuted),
              ),
              const SizedBox(height: 12),
              if (_isLoadingStations)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<int>(
                  initialValue: _selectedUpdateStationId,
                  decoration: const InputDecoration(
                    labelText: 'Select Station to Update',
                    prefixIcon: Icon(Icons.find_in_page_rounded),
                  ),
                  items: _stations
                      .map(
                        (station) => DropdownMenuItem<int>(
                          value: _toInt(station['id']),
                          child: Text(
                            '${station['id']} · ${station['station_name'] ?? 'Station'}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _onPickStationForUpdate,
                ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _updateNameController,
                decoration: const InputDecoration(
                  labelText: 'Station Name',
                  prefixIcon: Icon(Icons.edit_location_alt_rounded),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Station name is required'
                    : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _updateLatController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        prefixIcon: Icon(Icons.navigation_rounded),
                      ),
                      validator: (value) =>
                          (double.tryParse(value ?? '') == null)
                          ? 'Valid latitude required'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _updateLngController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        prefixIcon: Icon(Icons.explore_rounded),
                      ),
                      validator: (value) =>
                          (double.tryParse(value ?? '') == null)
                          ? 'Valid longitude required'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _updateRadiusController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Radius (meters)',
                        prefixIcon: Icon(Icons.radar_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _updateBasePriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Base Price (GHS)',
                        prefixIcon: Icon(Icons.payments_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _updateStationType,
                      items: _stationTypes
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _updateStationType = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Station Type',
                        prefixIcon: Icon(Icons.alt_route_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _updateStationStatus,
                      items: _stationStatuses
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _updateStationStatus = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(Icons.flag_circle_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUpdatingStation ? null : _updateStation,
                      icon: _isUpdatingStation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppBrandColors.white,
                              ),
                            )
                          : const Icon(Icons.save_as_rounded),
                      label: const Text('Update Station'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _resetUpdateStationForm,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Reset'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionC() {
    return Card(
      key: _sectionCKey,
      color: AppBrandColors.blackEnd,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Section C (View & Delete Stations)',
                    style: TextStyle(
                      color: AppBrandColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loadStations,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Stations loaded: ${_stations.length} · Banned zones loaded: ${_bannedZones.length} (see Section F for zone deletion).',
              style: const TextStyle(color: AppBrandColors.whiteMuted),
            ),
            const SizedBox(height: 10),
            if (_isLoadingStations)
              const Center(child: CircularProgressIndicator())
            else if (_stations.isEmpty)
              const Text(
                'No stations found.',
                style: TextStyle(color: AppBrandColors.whiteMuted),
              )
            else
              ..._stations.map((station) {
                final stationId = _toInt(station['id']);
                return Card(
                  color: AppBrandColors.blackStart,
                  child: ListTile(
                    title: Text(
                      '${station['station_name'] ?? '--'} (${station['station_type'] ?? ''})',
                      style: const TextStyle(
                        color: AppBrandColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'ID: $stationId · Radius: ${station['radius_meters'] ?? '--'}m · Base: GHS ${station['base_price'] ?? '--'}',
                      style: const TextStyle(color: AppBrandColors.whiteMuted),
                    ),
                    trailing: IconButton(
                      onPressed: () => _deleteStation(stationId),
                      icon: const Icon(
                        Icons.delete_forever_rounded,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  /*

  Widget _buildSectionD() {
    return Card(
      key: _sectionDKey,
      color: AppBrandColors.blackEnd,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _priceFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Section D (Transport Prices)',
                style: TextStyle(
                  color: AppBrandColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Set station-to-station transport prices (e.g. North Campus → South Campus = 10 GHS).',
                style: TextStyle(color: AppBrandColors.whiteMuted),
              ),
              const SizedBox(height: 4),
              const Text(
                'You can also store ETA (minutes) for this route to use in rider bike selection.',
                style: TextStyle(color: AppBrandColors.whiteMuted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _priceFromStationId,
                      decoration: const InputDecoration(
                        labelText: 'From Station',
                        prefixIcon: Icon(Icons.trip_origin_rounded),
                      ),
                      items: _stations
                          .map(
                            (station) => DropdownMenuItem<int>(
                              value: _toInt(station['id']),
                              child: Text(
                                '${station['id']} · ${station['station_name'] ?? 'Station'}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _priceFromStationId = value);
                      },
                      validator: (value) =>
                          value == null ? 'Select FROM station' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _priceToStationId,
                      decoration: const InputDecoration(
                        labelText: 'To Station',
                        prefixIcon: Icon(Icons.place_rounded),
                      ),
                      items: _stations
                          .map(
                            (station) => DropdownMenuItem<int>(
                              value: _toInt(station['id']),
                              child: Text(
                                '${station['id']} · ${station['station_name'] ?? 'Station'}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _priceToStationId = value);
                      },
                      validator: (value) =>
                          value == null ? 'Select TO station' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceCedisController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Price (GHS)',
                        hintText: 'e.g. 10',
                        prefixIcon: Icon(Icons.attach_money_rounded),
                      ),
                      validator: (value) =>
                          (double.tryParse(value ?? '') == null)
                          ? 'Valid price required'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _priceStatus,
                      items: _priceStatuses
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _priceStatus = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(Icons.flag_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _priceEtaMinutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Estimated Duration (minutes)',
                  hintText: 'e.g. 12',
                  prefixIcon: Icon(Icons.schedule_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final eta = int.tryParse(value.trim());
                  if (eta == null || eta < 0) {
                    return 'Enter valid ETA minutes';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _priceDescriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'e.g. Peak hour route',
                  prefixIcon: Icon(Icons.description_rounded),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isCreatingPrice ? null : _saveRoutePrice,
                icon: _isCreatingPrice
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppBrandColors.white,
                        ),
                      )
                    : const Icon(Icons.price_change_rounded),
                label: const Text('Save Route Price'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Saved route prices',
                    style: TextStyle(
                      color: AppBrandColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _loadPrices,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              if (_isLoadingPrices)
                const Center(child: CircularProgressIndicator())
              else if (_prices.isEmpty)
                const Text(
                  'No route prices yet.',
                  style: TextStyle(color: AppBrandColors.whiteMuted),
                )
              else
                ..._prices.map((price) {
                  final priceId = _toInt(price['id']);
                  return Card(
                    color: AppBrandColors.blackStart,
                    child: ListTile(
                      title: Text(
                        '${price['from_station_name'] ?? '--'} → ${price['to_station_name'] ?? '--'}',
                        style: const TextStyle(
                          color: AppBrandColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'GHS ${price['price_cedis'] ?? '--'} · ETA: ${price['estimated_duration_minutes'] ?? '--'} min · ${price['status'] ?? ''}',
                        style: const TextStyle(
                          color: AppBrandColors.whiteMuted,
                        ),
                      ),
                      trailing: IconButton(
                        onPressed: () => _deletePrice(priceId),
                        icon: const Icon(
                          Icons.delete_rounded,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }


*/

  // This UI design Causes "Layout OverFlow" due to Drop Down Menus having fixed sizes so long text try to go off the borders of the widget

  /*

  Widget _buildSectionD() {
    return Card(
      key: _sectionDKey,
      color: AppBrandColors.blackEnd,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _priceFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Section D (Transport Prices & Limits)',
                style: TextStyle(
                  color: AppBrandColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Set station-to-station transport prices (e.g. North Campus → South Campus = 10 GHS).',
                style: TextStyle(color: AppBrandColors.whiteMuted),
              ),
              const SizedBox(height: 4),
              const Text(
                'Set the Allocated Time (minutes) for this route to enforce late penalties.',
                style: TextStyle(
                  color: AppBrandColors.redYellowStart,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _priceFromStationId,
                      decoration: const InputDecoration(
                        labelText: 'From Station',
                        prefixIcon: Icon(Icons.trip_origin_rounded),
                      ),
                      items: _stations
                          .map(
                            (station) => DropdownMenuItem<int>(
                              value: _toInt(station['id']),
                              child: Text(
                                '${station['id']} · ${station['station_name'] ?? 'Station'}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _priceFromStationId = value);
                      },
                      validator: (value) =>
                          value == null ? 'Select FROM station' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _priceToStationId,
                      decoration: const InputDecoration(
                        labelText: 'To Station',
                        prefixIcon: Icon(Icons.place_rounded),
                      ),
                      items: _stations
                          .map(
                            (station) => DropdownMenuItem<int>(
                              value: _toInt(station['id']),
                              child: Text(
                                '${station['id']} · ${station['station_name'] ?? 'Station'}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _priceToStationId = value);
                      },
                      validator: (value) =>
                          value == null ? 'Select TO station' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceCedisController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Price (GHS)',
                        hintText: 'e.g. 10',
                        prefixIcon: Icon(Icons.attach_money_rounded),
                      ),
                      validator: (value) =>
                          (double.tryParse(value ?? '') == null)
                          ? 'Valid price required'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _priceStatus,
                      items: _priceStatuses
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _priceStatus = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(Icons.flag_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                // Note: I kept your original controller name so your code doesn't break,
                // but the UI labels are now completely accurate to the new logic.
                controller: _priceEtaMinutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Allocated Time (minutes)',
                  hintText: 'e.g. 15',
                  prefixIcon: Icon(Icons.timer_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final eta = int.tryParse(value.trim());
                  if (eta == null || eta < 0) {
                    return 'Enter valid minutes';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _priceDescriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'e.g. Peak hour route',
                  prefixIcon: Icon(Icons.description_rounded),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isCreatingPrice ? null : _saveRoutePrice,
                icon: _isCreatingPrice
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppBrandColors.white,
                        ),
                      )
                    : const Icon(Icons.price_change_rounded),
                label: const Text('Save Route Price'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Saved route prices',
                    style: TextStyle(
                      color: AppBrandColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _loadPrices,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              if (_isLoadingPrices)
                const Center(child: CircularProgressIndicator())
              else if (_prices.isEmpty)
                const Text(
                  'No route prices yet.',
                  style: TextStyle(color: AppBrandColors.whiteMuted),
                )
              else
                ..._prices.map((price) {
                  final priceId = _toInt(price['id']);

                  // THE FIX: Grabbing raw seconds from the DB and formatting as minutes for the Admin view
                  final allocatedSeconds = int.tryParse(
                    price['allocated_time']?.toString() ?? '',
                  );
                  final allocatedMins = allocatedSeconds != null
                      ? '${allocatedSeconds ~/ 60} mins'
                      : '--';

                  return Card(
                    color: AppBrandColors.blackStart,
                    child: ListTile(
                      title: Text(
                        '${price['from_station_name'] ?? '--'} → ${price['to_station_name'] ?? '--'}',
                        style: const TextStyle(
                          color: AppBrandColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'GHS ${price['price_cedis'] ?? '--'} · Limit: $allocatedMins · ${price['status'] ?? ''}',
                        style: const TextStyle(
                          color: AppBrandColors.whiteMuted,
                        ),
                      ),
                      trailing: IconButton(
                        onPressed: () => _deletePrice(priceId),
                        icon: const Icon(
                          Icons.delete_rounded,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

*/

  Widget _buildSectionD() {
    return Card(
      key: _sectionDKey,
      color: AppBrandColors.blackEnd,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _priceFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Section D (Transport Prices & Limits)',
                style: TextStyle(
                  color: AppBrandColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Set station-to-station transport prices (e.g. North Campus → South Campus = 10 GHS).',
                style: TextStyle(color: AppBrandColors.whiteMuted),
              ),
              const SizedBox(height: 4),
              const Text(
                'Set the Allocated Time (minutes) for this route to enforce late penalties.',
                style: TextStyle(
                  color: AppBrandColors.redYellowStart,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      // THE FIX: Forces the dropdown to obey screen width limits
                      isExpanded: true,
                      initialValue: _priceFromStationId,
                      decoration: const InputDecoration(
                        labelText: 'From Station',
                        prefixIcon: Icon(Icons.trip_origin_rounded),
                      ),
                      items: _stations
                          .map(
                            (station) => DropdownMenuItem<int>(
                              value: _toInt(station['id']),
                              child: Text(
                                '${station['id']} · ${station['station_name'] ?? 'Station'}',
                                // THE FIX: Truncates long names
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _priceFromStationId = value);
                      },
                      validator: (value) =>
                          value == null ? 'Select FROM station' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      // THE FIX: Forces the dropdown to obey screen width limits
                      isExpanded: true,
                      initialValue: _priceToStationId,
                      decoration: const InputDecoration(
                        labelText: 'To Station',
                        prefixIcon: Icon(Icons.place_rounded),
                      ),
                      items: _stations
                          .map(
                            (station) => DropdownMenuItem<int>(
                              value: _toInt(station['id']),
                              child: Text(
                                '${station['id']} · ${station['station_name'] ?? 'Station'}',
                                // THE FIX: Truncates long names
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _priceToStationId = value);
                      },
                      validator: (value) =>
                          value == null ? 'Select TO station' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceCedisController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Price (GHS)',
                        hintText: 'e.g. 10',
                        prefixIcon: Icon(Icons.attach_money_rounded),
                      ),
                      validator: (value) =>
                          (double.tryParse(value ?? '') == null)
                          ? 'Valid price required'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true, // Structural consistency
                      initialValue: _priceStatus,
                      items: _priceStatuses
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                item,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _priceStatus = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(Icons.flag_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _priceEtaMinutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Allocated Time (minutes)',
                  hintText: 'e.g. 15',
                  prefixIcon: Icon(Icons.timer_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final eta = int.tryParse(value.trim());
                  if (eta == null || eta < 0) {
                    return 'Enter valid minutes';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _priceDescriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'e.g. Peak hour route',
                  prefixIcon: Icon(Icons.description_rounded),
                ),
              ),
              const SizedBox(
                height: 16,
              ), // Increased spacing to match aesthetic
              // THE FIX: Stretched to full width to match Create/Update sections
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isCreatingPrice ? null : _saveRoutePrice,
                  icon: _isCreatingPrice
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppBrandColors.white,
                          ),
                        )
                      : const Icon(Icons.price_change_rounded),
                  label: const Text(
                    'Save Route Price',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Saved route prices',
                    style: TextStyle(
                      color: AppBrandColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _loadPrices,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              if (_isLoadingPrices)
                const Center(child: CircularProgressIndicator())
              else if (_prices.isEmpty)
                const Text(
                  'No route prices yet.',
                  style: TextStyle(color: AppBrandColors.whiteMuted),
                )
              else
                ..._prices.map((price) {
                  final priceId = _toInt(price['id']);

                  // Grabbing raw seconds from the DB and formatting as minutes for the Admin view
                  final allocatedSeconds = int.tryParse(
                    price['allocated_time']?.toString() ?? '',
                  );
                  final allocatedMins = allocatedSeconds != null
                      ? '${allocatedSeconds ~/ 60} mins'
                      : '--';

                  return Card(
                    color: AppBrandColors.blackStart,
                    child: ListTile(
                      title: Text(
                        '${price['from_station_name'] ?? '--'} → ${price['to_station_name'] ?? '--'}',
                        style: const TextStyle(
                          color: AppBrandColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'GHS ${price['price_cedis'] ?? '--'} · Limit: $allocatedMins · ${price['status'] ?? ''}',
                        style: const TextStyle(
                          color: AppBrandColors.whiteMuted,
                        ),
                      ),
                      trailing: IconButton(
                        onPressed: () => _deletePrice(priceId),
                        icon: const Icon(
                          Icons.delete_rounded,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionE() {
    return Card(
      key: _sectionEKey,
      color: AppBrandColors.blackEnd,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _createZoneFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Section E (Create Banned Zone)',
                style: TextStyle(
                  color: AppBrandColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Define restricted coordinates and radius for unsafe or prohibited areas.',
                style: TextStyle(color: AppBrandColors.whiteMuted),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _zoneNameController,
                decoration: const InputDecoration(
                  labelText: 'Zone Name',
                  hintText: 'e.g. Main Highway Crossing',
                  prefixIcon: Icon(Icons.warning_amber_rounded),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Zone name is required'
                    : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _zoneLatController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        hintText: 'e.g. 5.64000000',
                        prefixIcon: Icon(Icons.navigation_rounded),
                      ),
                      validator: (value) =>
                          (double.tryParse(value ?? '') == null)
                          ? 'Valid latitude required'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _zoneLngController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        hintText: 'e.g. -0.19000000',
                        prefixIcon: Icon(Icons.explore_rounded),
                      ),
                      validator: (value) =>
                          (double.tryParse(value ?? '') == null)
                          ? 'Valid longitude required'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _zoneRadiusController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Radius (meters)',
                        hintText: 'e.g. 100',
                        prefixIcon: Icon(Icons.radar_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _zoneStatus,
                      items: _zoneStatuses
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _zoneStatus = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(Icons.flag_circle_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _zoneReasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: 'e.g. Heavy vehicle traffic zone',
                  prefixIcon: Icon(Icons.info_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isCreatingZone ? null : _createBannedZone,
                icon: _isCreatingZone
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppBrandColors.white,
                        ),
                      )
                    : const Icon(Icons.block_rounded),
                label: const Text('Create Banned Zone'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionF() {
    return Card(
      key: _sectionFKey,
      color: AppBrandColors.blackEnd,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Section F (View & Delete Banned Zones)',
                    style: TextStyle(
                      color: AppBrandColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loadBannedZones,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_isLoadingZones)
              const Center(child: CircularProgressIndicator())
            else if (_bannedZones.isEmpty)
              const Text(
                'No banned zones found.',
                style: TextStyle(color: AppBrandColors.whiteMuted),
              )
            else
              ..._bannedZones.map((zone) {
                final zoneId = _toInt(zone['id']);
                return Card(
                  color: AppBrandColors.blackStart,
                  child: ListTile(
                    title: Text(
                      '${zone['zone_name'] ?? '--'}',
                      style: const TextStyle(
                        color: AppBrandColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '(${zone['latitude'] ?? '--'}, ${zone['longitude'] ?? '--'}) · Radius: ${zone['radius_meters'] ?? '--'}m · ${zone['status'] ?? ''}',
                      style: const TextStyle(color: AppBrandColors.whiteMuted),
                    ),
                    trailing: IconButton(
                      onPressed: () => _deleteBannedZone(zoneId),
                      icon: const Icon(
                        Icons.delete_forever_rounded,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 130;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppBrandColors.blackBackgroundGradient,
      ),
      child: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
          children: [
            Text(
              'Station Operations Hub',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppBrandColors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create, update, delete stations, manage route prices, and manage banned zones.',
              style: TextStyle(color: AppBrandColors.whiteMuted),
            ),
            const SizedBox(height: 14),
            _buildTopShortcuts(),
            const SizedBox(height: 14),
            _buildSectionA(),
            const SizedBox(height: 14),
            _buildSectionB(),
            const SizedBox(height: 14),
            _buildSectionC(),
            const SizedBox(height: 14),
            _buildSectionD(),
            const SizedBox(height: 14),
            _buildSectionE(),
            const SizedBox(height: 14),
            _buildSectionF(),
          ],
        ),
      ),
    );
  }
}
