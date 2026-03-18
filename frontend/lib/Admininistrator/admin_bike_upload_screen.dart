import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../admin_ip.dart';
import '../log_session.dart';
import '../theme_settings.dart';

class AdminBikeUploadScreen extends StatefulWidget {
  const AdminBikeUploadScreen({super.key});

  @override
  State<AdminBikeUploadScreen> createState() => _AdminBikeUploadScreenState();
}

class _AdminBikeUploadScreenState extends State<AdminBikeUploadScreen> {
  final _scrollController = ScrollController();
  final _createSectionKey = GlobalKey();
  final _updateSectionKey = GlobalKey();
  final _deleteSectionKey = GlobalKey();

  final _createFormKey = GlobalKey<FormState>();
  final _updateFormKey = GlobalKey<FormState>();

  final _createCodeController = TextEditingController();
  final _createNameController = TextEditingController();
  final _createBatteryController = TextEditingController(text: '100');
  int? _createStationId;
  String? _createImagePath;
  String _createStatus = 'inactive';

  final _updateCodeController = TextEditingController();
  final _updateNameController = TextEditingController();
  final _updateBatteryController = TextEditingController(text: '100');
  int? _updateStationId;
  String? _updateImagePath;
  String _updateStatus = 'inactive';
  int? _selectedUpdateBikeId;

  bool _isLoading = false;
  bool _isLoadingStations = false;
  bool _isCreating = false;
  bool _isUpdating = false;
  bool _isUploadingCreateImage = false;
  bool _isUploadingUpdateImage = false;

  List<Map<String, dynamic>> _bikes = const [];
  List<Map<String, dynamic>> _stations = const [];

  final List<String> _statuses = const [
    'available',
    'reserved',
    'active',
    'maintenance',
    'inactive',
    'tampered',
  ];

  int get _adminId => LogSession.instance.userId ?? 0;

  Uri get _bikesUri =>
      Uri.parse('${AdminIp.baseUrl}/api/admin_bike_upload_routes/bikes');

  Uri get _uploadUri =>
      Uri.parse('${AdminIp.baseUrl}/api/admin_bike_upload_routes/upload-image');

  Uri get _stationsUri =>
      Uri.parse('${AdminIp.baseUrl}/api/admin_station_upload_routes/stations');

  Map<String, String> get _jsonHeaders => {
    'Content-Type': 'application/json',
    'x-admin-id': '$_adminId',
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _createCodeController.dispose();
    _createNameController.dispose();
    _createBatteryController.dispose();
    _updateCodeController.dispose();
    _updateNameController.dispose();
    _updateBatteryController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_loadBikes(), _loadStations()]);
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadBikes(), _loadStations()]);
  }

  Future<void> _scrollToSection(GlobalKey key) async {
    if (!_scrollController.hasClients) return;

    if (key == _deleteSectionKey) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );

      final deleteContext = _deleteSectionKey.currentContext;
      if (deleteContext != null) {
        await Scrollable.ensureVisible(
          deleteContext,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          alignment: 0.04,
        );
      }
      return;
    }

    final sectionContext = key.currentContext;
    if (sectionContext == null) return;

    final sectionBox = sectionContext.findRenderObject() as RenderBox?;
    final scrollContext = _scrollController.position.context.storageContext;
    final scrollBox = scrollContext.findRenderObject() as RenderBox?;

    if (sectionBox != null && scrollBox != null) {
      final sectionOffset = sectionBox
          .localToGlobal(Offset.zero, ancestor: scrollBox)
          .dy;
      final rawTarget = _scrollController.offset + sectionOffset - 20;
      final target = rawTarget.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );

      await _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    await Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      alignment: 0.06,
    );
  }

  Future<void> _loadBikes() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(_bikesUri, headers: _jsonHeaders);
      final body = _decodeBody(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = body['data'];
        if (data is List) {
          setState(() {
            _bikes = data.whereType<Map>().map((e) {
              return e.map((key, value) => MapEntry('$key', value));
            }).toList();
          });
        }
      } else {
        _showSnack(body['message']?.toString() ?? 'Unable to load bikes.');
      }
    } catch (_) {
      _showSnack('Unable to load bikes right now.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStations() async {
    setState(() => _isLoadingStations = true);
    try {
      final response = await http.get(_stationsUri, headers: _jsonHeaders);
      final body = _decodeBody(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = body['data'];
        if (data is List) {
          setState(() {
            _stations = data.whereType<Map>().map((e) {
              return e.map((key, value) => MapEntry('$key', value));
            }).toList();
          });
        }
      } else {
        _showSnack(body['message']?.toString() ?? 'Unable to load stations.');
      }
    } catch (_) {
      _showSnack('Unable to load stations right now.');
    } finally {
      if (mounted) setState(() => _isLoadingStations = false);
    }
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String? _resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '${AdminIp.baseUrl}$path';
  }

  Future<String?> _uploadImageToServer({required bool isCreateSection}) async {
    final pickerResult = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (pickerResult == null || pickerResult.files.isEmpty) {
      return null;
    }

    final file = pickerResult.files.single;
    if (file.bytes == null && (file.path == null || file.path!.isEmpty)) {
      _showSnack('Unable to read selected image file.');
      return null;
    }

    setState(() {
      if (isCreateSection) {
        _isUploadingCreateImage = true;
      } else {
        _isUploadingUpdateImage = true;
      }
    });

    try {
      final request = http.MultipartRequest('POST', _uploadUri);
      request.headers['x-admin-id'] = '$_adminId';

      if (file.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'bike_image',
            file.bytes!,
            filename: file.name,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('bike_image', file.path!),
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final body = _decodeBody(response);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _showSnack(body['message']?.toString() ?? 'Image upload failed.');
        return null;
      }

      final imagePath = body['data'] is Map<String, dynamic>
          ? (body['data']['image_path']?.toString())
          : null;

      if (imagePath == null || imagePath.isEmpty) {
        _showSnack('Image upload succeeded but no path was returned.');
        return null;
      }

      _showSnack('Image uploaded successfully.', success: true);
      return imagePath;
    } catch (_) {
      _showSnack('Image upload failed.');
      return null;
    } finally {
      if (mounted) {
        setState(() {
          if (isCreateSection) {
            _isUploadingCreateImage = false;
          } else {
            _isUploadingUpdateImage = false;
          }
        });
      }
    }
  }

  Future<void> _uploadCreateImage() async {
    final imagePath = await _uploadImageToServer(isCreateSection: true);
    if (imagePath == null) return;
    setState(() => _createImagePath = imagePath);
  }

  Future<void> _uploadUpdateImage() async {
    final imagePath = await _uploadImageToServer(isCreateSection: false);
    if (imagePath == null) return;
    setState(() => _updateImagePath = imagePath);
  }

  Future<void> _createBike() async {
    if (!_createFormKey.currentState!.validate()) return;
    if (_createStationId == null) {
      _showSnack('Please select a station ID.');
      return;
    }

    setState(() => _isCreating = true);
    try {
      final payload = {
        'bike_code': _createCodeController.text.trim(),
        'bike_name': _createNameController.text.trim(),
        'bike_image': _createImagePath,
        'battery_level':
            int.tryParse(_createBatteryController.text.trim()) ?? 100,
        'status': _createStatus,
        'current_station_id': _createStationId,
        'admin_id': _adminId,
      };

      final response = await http.post(
        _bikesUri,
        headers: _jsonHeaders,
        body: jsonEncode(payload),
      );
      final body = _decodeBody(response);
      final ok = response.statusCode >= 200 && response.statusCode < 300;

      _showSnack(
        body['message']?.toString() ??
            (ok ? 'Bike created successfully.' : 'Unable to create bike.'),
        success: ok,
      );

      if (!ok) return;
      _resetCreateForm();
      await _loadBikes();
      await _scrollToSection(_updateSectionKey);
    } catch (_) {
      _showSnack('Unable to create bike right now.');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _updateBike() async {
    if (_selectedUpdateBikeId == null) {
      _showSnack('Select a bike to update first.');
      return;
    }
    if (!_updateFormKey.currentState!.validate()) return;
    if (_updateStationId == null) {
      _showSnack('Please select a station ID.');
      return;
    }

    setState(() => _isUpdating = true);
    try {
      final payload = {
        'bike_code': _updateCodeController.text.trim(),
        'bike_name': _updateNameController.text.trim(),
        'bike_image': _updateImagePath,
        'battery_level':
            int.tryParse(_updateBatteryController.text.trim()) ?? 100,
        'status': _updateStatus,
        'current_station_id': _updateStationId,
        'admin_id': _adminId,
      };

      final response = await http.put(
        Uri.parse('${_bikesUri.toString()}/$_selectedUpdateBikeId'),
        headers: _jsonHeaders,
        body: jsonEncode(payload),
      );
      final body = _decodeBody(response);
      final ok = response.statusCode >= 200 && response.statusCode < 300;

      _showSnack(
        body['message']?.toString() ??
            (ok ? 'Bike updated successfully.' : 'Unable to update bike.'),
        success: ok,
      );

      if (!ok) return;
      await _loadBikes();
    } catch (_) {
      _showSnack('Unable to update bike right now.');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _deleteBike(int bikeId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppBrandColors.blackEnd,
          title: const Text(
            'Delete Bike',
            style: TextStyle(color: AppBrandColors.white),
          ),
          content: const Text(
            'Are you sure you want to delete this bike? This action cannot be undone.',
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

    if (shouldDelete != true) return;

    try {
      final response = await http.delete(
        Uri.parse('${_bikesUri.toString()}/$bikeId'),
        headers: _jsonHeaders,
      );
      final body = _decodeBody(response);
      final ok = response.statusCode >= 200 && response.statusCode < 300;

      _showSnack(
        body['message']?.toString() ??
            (ok ? 'Bike deleted successfully.' : 'Unable to delete bike.'),
        success: ok,
      );

      if (!ok) return;

      if (_selectedUpdateBikeId == bikeId) {
        _resetUpdateForm();
      }
      await _loadBikes();
    } catch (_) {
      _showSnack('Unable to delete bike right now.');
    }
  }

  void _onSelectBikeForUpdate(int? bikeId) {
    if (bikeId == null) return;

    final selectedBike = _bikes.cast<Map<String, dynamic>?>().firstWhere(
      (bike) => _toInt(bike?['id']) == bikeId,
      orElse: () => null,
    );

    if (selectedBike == null) {
      _showSnack('Selected bike details could not be loaded.');
      return;
    }

    setState(() {
      _selectedUpdateBikeId = bikeId;
      _updateCodeController.text = '${selectedBike['bike_code'] ?? ''}';
      _updateNameController.text = '${selectedBike['bike_name'] ?? ''}';
      _updateBatteryController.text = '${selectedBike['battery_level'] ?? 100}';
      _updateStationId = selectedBike['current_station_id'] is int
          ? selectedBike['current_station_id'] as int
          : int.tryParse('${selectedBike['current_station_id'] ?? ''}');
      _updateImagePath = selectedBike['bike_image']?.toString();

      final candidateStatus = '${selectedBike['status'] ?? 'inactive'}';
      _updateStatus = _statuses.contains(candidateStatus)
          ? candidateStatus
          : 'inactive';
    });
  }

  void _resetCreateForm() {
    setState(() {
      _createCodeController.clear();
      _createNameController.clear();
      _createBatteryController.text = '100';
      _createStationId = null;
      _createImagePath = null;
      _createStatus = 'inactive';
    });
  }

  void _resetUpdateForm() {
    setState(() {
      _selectedUpdateBikeId = null;
      _updateCodeController.clear();
      _updateNameController.clear();
      _updateBatteryController.text = '100';
      _updateStationId = null;
      _updateImagePath = null;
      _updateStatus = 'inactive';
    });
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

  int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
  }

  //Updating the Build UI with a new One Below

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 130;
    final isBusy =
        _isLoading || _isLoadingStations || _isCreating || _isUpdating;

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Bike Upload Center',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppBrandColors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: isBusy ? null : _refreshAll,
                  icon: isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Modern admin workflow for Create, Update, and Delete bike records.',
              style: TextStyle(color: AppBrandColors.whiteMuted),
            ),
            const SizedBox(height: 14),
            _buildQuickShortcuts(),
            const SizedBox(height: 16),
            _buildCreateSection(),
            const SizedBox(height: 14),
            _buildUpdateSection(),
            const SizedBox(height: 14),
            _buildDeleteSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickShortcuts() {
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
          _shortcutButton(
            label: 'Section A · Create',
            icon: Icons.add_circle_rounded,
            onTap: () => _scrollToSection(_createSectionKey),
          ),
          _shortcutButton(
            label: 'Section B · Update',
            icon: Icons.edit_note_rounded,
            onTap: () => _scrollToSection(_updateSectionKey),
          ),
          _shortcutButton(
            label: 'Section C · Delete',
            icon: Icons.delete_sweep_rounded,
            onTap: () => _scrollToSection(_deleteSectionKey),
          ),
        ],
      ),
    );
  }

  Widget _shortcutButton({
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

  // The UI here causes a "layout overflow" error on smaller screens because the dropdowns and buttons have fixed widths and don't adapt well to limited horizontal space. To fix this, we can make the dropdowns expand to fill available space and allow buttons to wrap onto multiple lines if needed. The updated code below includes these adjustments.

  /*
  Widget _buildCreateSection() {
    final imageUrl = _resolveImageUrl(_createImagePath);

    return Card(
      key: _createSectionKey,
      color: AppBrandColors.blackEnd,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _createFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Section A (Create)',
                style: TextStyle(
                  color: AppBrandColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Upload bike image to server, then create bike record with stored path.',
                style: TextStyle(color: AppBrandColors.whiteMuted),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _createCodeController,
                decoration: const InputDecoration(
                  labelText: 'Bike Code',
                  prefixIcon: Icon(Icons.qr_code_rounded),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Bike code is required'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _createNameController,
                decoration: const InputDecoration(
                  labelText: 'Bike Name',
                  prefixIcon: Icon(Icons.pedal_bike_rounded),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Bike name is required'
                    : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _createBatteryController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Battery %',
                        prefixIcon: Icon(Icons.battery_5_bar_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _createStationId,
                      decoration: const InputDecoration(
                        labelText: 'Station ID',
                        prefixIcon: Icon(Icons.location_city_rounded),
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
                      onChanged: _isLoadingStations
                          ? null
                          : (value) {
                              setState(() => _createStationId = value);
                            },
                      validator: (value) =>
                          value == null ? 'Station ID is required' : null,
                    ),
                  ),
                ],
              ),
              if (_isLoadingStations)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Loading stations...',
                    style: TextStyle(color: AppBrandColors.whiteMuted),
                  ),
                ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _createStatus,
                items: _statuses
                    .map(
                      (status) =>
                          DropdownMenuItem(value: status, child: Text(status)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _createStatus = value);
                },
                decoration: const InputDecoration(
                  labelText: 'Bike Status',
                  prefixIcon: Icon(Icons.flag_circle_rounded),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isUploadingCreateImage
                        ? null
                        : _uploadCreateImage,
                    icon: _isUploadingCreateImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppBrandColors.white,
                            ),
                          )
                        : const Icon(Icons.upload_file_rounded),
                    label: Text(
                      _createImagePath == null
                          ? 'Upload Bike Image'
                          : 'Re-upload Image',
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _resetCreateForm,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Reset'),
                  ),
                ],
              ),

              if (_createImagePath != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Stored path: $_createImagePath',
                  style: const TextStyle(
                    color: AppBrandColors.whiteMuted,
                    fontSize: 12,
                  ),
                ),
                if (imageUrl != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isCreating ? null : _createBike,
                  icon: _isCreating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppBrandColors.white,
                          ),
                        )
                      : const Icon(Icons.add_task_rounded),
                  label: const Text('Create Bike Record'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

*/

  Widget _buildCreateSection() {
    final imageUrl = _resolveImageUrl(_createImagePath);

    return Card(
      key: _createSectionKey,
      color: AppBrandColors.blackEnd,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _createFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Section A (Create)',
                style: TextStyle(
                  color: AppBrandColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Upload bike image to server, then create bike record with stored path.',
                style: TextStyle(color: AppBrandColors.whiteMuted),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _createCodeController,
                decoration: const InputDecoration(
                  labelText: 'Bike Code',
                  prefixIcon: Icon(Icons.qr_code_rounded),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Bike code is required'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _createNameController,
                decoration: const InputDecoration(
                  labelText: 'Bike Name',
                  prefixIcon: Icon(Icons.pedal_bike_rounded),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Bike name is required'
                    : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _createBatteryController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Battery %',
                        prefixIcon: Icon(Icons.battery_5_bar_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      // THE FIX 1: Forces the dropdown to obey screen limits
                      isExpanded: true,
                      initialValue: _createStationId,
                      decoration: const InputDecoration(
                        labelText: 'Station ID',
                        prefixIcon: Icon(Icons.location_city_rounded),
                      ),
                      items: _stations
                          .map(
                            (station) => DropdownMenuItem<int>(
                              value: _toInt(station['id']),
                              child: Text(
                                '${station['id']} · ${station['station_name'] ?? 'Station'}',
                                // THE FIX 2: Truncates long station names with "..."
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _isLoadingStations
                          ? null
                          : (value) {
                              setState(() => _createStationId = value);
                            },
                      validator: (value) =>
                          value == null ? 'Station ID is required' : null,
                    ),
                  ),
                ],
              ),
              if (_isLoadingStations)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Loading stations...',
                    style: TextStyle(color: AppBrandColors.whiteMuted),
                  ),
                ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _createStatus,
                items: _statuses
                    .map(
                      (status) =>
                          DropdownMenuItem(value: status, child: Text(status)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _createStatus = value);
                },
                decoration: const InputDecoration(
                  labelText: 'Bike Status',
                  prefixIcon: Icon(Icons.flag_circle_rounded),
                ),
              ),
              const SizedBox(height: 10),

              // THE FIX 3: Replaced 'Row' with 'Wrap' so buttons stack on small screens
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isUploadingCreateImage
                        ? null
                        : _uploadCreateImage,
                    icon: _isUploadingCreateImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppBrandColors.white,
                            ),
                          )
                        : const Icon(Icons.upload_file_rounded),
                    label: Text(
                      _createImagePath == null
                          ? 'Upload Bike Image'
                          : 'Re-upload Image',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _resetCreateForm,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Reset'),
                  ),
                ],
              ),

              if (_createImagePath != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Stored path: $_createImagePath',
                  style: const TextStyle(
                    color: AppBrandColors.whiteMuted,
                    fontSize: 12,
                  ),
                ),
                if (imageUrl != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isCreating ? null : _createBike,
                  icon: _isCreating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppBrandColors.white,
                          ),
                        )
                      : const Icon(Icons.add_task_rounded),
                  label: const Text('Create Bike Record'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // This UI causes a "Layout Overflow" error on smaller screens because the dropdowns and buttons have fixed widths and don't adapt well to limited horizontal space. To fix this, we can make the dropdowns expand to fill available space and allow buttons to wrap onto multiple lines if needed. The updated code below includes these adjustments.

  /*
  Widget _buildUpdateSection() {
    final imageUrl = _resolveImageUrl(_updateImagePath);

    return Card(
      key: _updateSectionKey,
      color: AppBrandColors.blackEnd,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _updateFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Section B (Update)',
                style: TextStyle(
                  color: AppBrandColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pull bikes from database, bind into widgets, then update details.',
                style: TextStyle(color: AppBrandColors.whiteMuted),
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<int>(
                  initialValue: _selectedUpdateBikeId,
                  decoration: const InputDecoration(
                    labelText: 'Select Bike to Update',
                    prefixIcon: Icon(Icons.manage_search_rounded),
                  ),
                  items: _bikes
                      .map(
                        (bike) => DropdownMenuItem<int>(
                          value: _toInt(bike['id']),
                          child: Text(
                            '${bike['bike_code'] ?? '--'} · ${bike['bike_name'] ?? ''}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _onSelectBikeForUpdate,
                ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _updateCodeController,
                decoration: const InputDecoration(
                  labelText: 'Bike Code',
                  prefixIcon: Icon(Icons.qr_code_rounded),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Bike code is required'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _updateNameController,
                decoration: const InputDecoration(
                  labelText: 'Bike Name',
                  prefixIcon: Icon(Icons.pedal_bike_rounded),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Bike name is required'
                    : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _updateBatteryController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Battery %',
                        prefixIcon: Icon(Icons.battery_5_bar_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _updateStationId,
                      decoration: const InputDecoration(
                        labelText: 'Station ID',
                        prefixIcon: Icon(Icons.location_city_rounded),
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
                      onChanged: _isLoadingStations
                          ? null
                          : (value) {
                              setState(() => _updateStationId = value);
                            },
                      validator: (value) =>
                          value == null ? 'Station ID is required' : null,
                    ),
                  ),
                ],
              ),
              if (_isLoadingStations)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Loading stations...',
                    style: TextStyle(color: AppBrandColors.whiteMuted),
                  ),
                ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _updateStatus,
                items: _statuses
                    .map(
                      (status) =>
                          DropdownMenuItem(value: status, child: Text(status)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _updateStatus = value);
                },
                decoration: const InputDecoration(
                  labelText: 'Bike Status',
                  prefixIcon: Icon(Icons.flag_circle_rounded),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isUploadingUpdateImage
                        ? null
                        : _uploadUpdateImage,
                    icon: _isUploadingUpdateImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppBrandColors.white,
                            ),
                          )
                        : const Icon(Icons.upload_file_rounded),
                    label: Text(
                      _updateImagePath == null
                          ? 'Upload Bike Image'
                          : 'Re-upload Image',
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _resetUpdateForm,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Reset'),
                  ),
                ],
              ),
              if (_updateImagePath != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Stored path: $_updateImagePath',
                  style: const TextStyle(
                    color: AppBrandColors.whiteMuted,
                    fontSize: 12,
                  ),
                ),
                if (imageUrl != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : _updateBike,
                  icon: _isUpdating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppBrandColors.white,
                          ),
                        )
                      : const Icon(Icons.system_update_alt_rounded),
                  label: const Text('Update Bike Record'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



*/

  Widget _buildUpdateSection() {
    final imageUrl = _resolveImageUrl(_updateImagePath);

    return Card(
      key: _updateSectionKey,
      color: AppBrandColors.blackEnd,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _updateFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Section B (Update)',
                style: TextStyle(
                  color: AppBrandColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pull bikes from database, bind into widgets, then update details.',
                style: TextStyle(color: AppBrandColors.whiteMuted),
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<int>(
                  // THE FIX 1: Prevent Bike Dropdown from overflowing
                  isExpanded: true,
                  initialValue: _selectedUpdateBikeId,
                  decoration: const InputDecoration(
                    labelText: 'Select Bike to Update',
                    prefixIcon: Icon(Icons.manage_search_rounded),
                  ),
                  items: _bikes
                      .map(
                        (bike) => DropdownMenuItem<int>(
                          value: _toInt(bike['id']),
                          child: Text(
                            '${bike['bike_code'] ?? '--'} · ${bike['bike_name'] ?? ''}',
                            overflow: TextOverflow
                                .ellipsis, // Cuts off long names cleanly
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _onSelectBikeForUpdate,
                ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _updateCodeController,
                decoration: const InputDecoration(
                  labelText: 'Bike Code',
                  prefixIcon: Icon(Icons.qr_code_rounded),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Bike code is required'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _updateNameController,
                decoration: const InputDecoration(
                  labelText: 'Bike Name',
                  prefixIcon: Icon(Icons.pedal_bike_rounded),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Bike name is required'
                    : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _updateBatteryController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Battery %',
                        prefixIcon: Icon(Icons.battery_5_bar_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      // THE FIX 2: Prevent Station Dropdown from overflowing
                      isExpanded: true,
                      initialValue: _updateStationId,
                      decoration: const InputDecoration(
                        labelText: 'Station ID',
                        prefixIcon: Icon(Icons.location_city_rounded),
                      ),
                      items: _stations
                          .map(
                            (station) => DropdownMenuItem<int>(
                              value: _toInt(station['id']),
                              child: Text(
                                '${station['id']} · ${station['station_name'] ?? 'Station'}',
                                overflow: TextOverflow
                                    .ellipsis, // Cuts off long station names cleanly
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _isLoadingStations
                          ? null
                          : (value) {
                              setState(() => _updateStationId = value);
                            },
                      validator: (value) =>
                          value == null ? 'Station ID is required' : null,
                    ),
                  ),
                ],
              ),
              if (_isLoadingStations)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Loading stations...',
                    style: TextStyle(color: AppBrandColors.whiteMuted),
                  ),
                ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _updateStatus,
                items: _statuses
                    .map(
                      (status) =>
                          DropdownMenuItem(value: status, child: Text(status)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _updateStatus = value);
                },
                decoration: const InputDecoration(
                  labelText: 'Bike Status',
                  prefixIcon: Icon(Icons.flag_circle_rounded),
                ),
              ),
              const SizedBox(height: 16), // Increased spacing slightly
              // THE FIX 3: Replaced 'Row' with 'Wrap' to allow dynamic button stacking on small screens
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isUploadingUpdateImage
                        ? null
                        : _uploadUpdateImage,
                    icon: _isUploadingUpdateImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppBrandColors.white,
                            ),
                          )
                        : const Icon(Icons.upload_file_rounded),
                    label: Text(
                      _updateImagePath == null
                          ? 'Upload Bike Image'
                          : 'Re-upload Image',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _resetUpdateForm,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Reset'),
                  ),
                ],
              ),

              if (_updateImagePath != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Stored path: $_updateImagePath',
                  style: const TextStyle(
                    color: AppBrandColors.whiteMuted,
                    fontSize: 12,
                  ),
                ),
                if (imageUrl != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : _updateBike,
                  icon: _isUpdating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppBrandColors.white,
                          ),
                        )
                      : const Icon(Icons.system_update_alt_rounded),
                  label: const Text(
                    'Update Bike Record',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ), // Thicker button matches Create Section
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteSection() {
    return Card(
      key: _deleteSectionKey,
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
                    'Section C (Delete)',
                    style: TextStyle(
                      color: AppBrandColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loadBikes,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const Text(
              'Pull bikes from database and delete selected records when necessary.',
              style: TextStyle(color: AppBrandColors.whiteMuted),
            ),
            const SizedBox(height: 10),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_bikes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'No bikes available to delete.',
                  style: TextStyle(color: AppBrandColors.whiteMuted),
                ),
              )
            else
              ..._bikes.map((bike) {
                final bikeId = _toInt(bike['id']);
                final imageUrl = _resolveImageUrl(
                  bike['bike_image']?.toString(),
                );

                return Card(
                  color: AppBrandColors.blackStart,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: imageUrl == null
                        ? const CircleAvatar(
                            backgroundColor: AppBrandColors.greenMid,
                            child: Icon(
                              Icons.pedal_bike_rounded,
                              color: AppBrandColors.white,
                            ),
                          )
                        : CircleAvatar(backgroundImage: NetworkImage(imageUrl)),
                    title: Text(
                      '${bike['bike_code'] ?? '--'} · ${bike['bike_name'] ?? ''}',
                      style: const TextStyle(
                        color: AppBrandColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Status: ${bike['status'] ?? ''} | Battery: ${bike['battery_level'] ?? '--'}%',
                      style: const TextStyle(color: AppBrandColors.whiteMuted),
                    ),
                    trailing: IconButton(
                      onPressed: () => _deleteBike(bikeId),
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
}
