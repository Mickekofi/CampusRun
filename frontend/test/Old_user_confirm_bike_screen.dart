/*

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../admin_ip.dart';
import '../log_session.dart';
import '../theme_settings.dart';

class UserConfirmBikeScreen extends StatefulWidget {
  const UserConfirmBikeScreen({super.key});

  @override
  State<UserConfirmBikeScreen> createState() => _UserConfirmBikeScreenState();
}

class _UserConfirmBikeScreenState extends State<UserConfirmBikeScreen> {
  bool _loading = false;
  String _error = '';

  Map<String, dynamic>? _bike;
  Map<String, dynamic>? _pickupStation;
  List<Map<String, dynamic>> _dropoffStations = [];

  int? _selectedDropoffStationId;

  bool _useOtherPlace = false;
  final TextEditingController _arrivalNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfirmData();
  }

  @override
  void dispose() {
    _arrivalNoteController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _decodeBody(http.Response response) {
    try {
      final raw = utf8.decode(response.bodyBytes);
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  int _toInt(dynamic v) => v is int ? v : int.tryParse('${v ?? 0}') ?? 0;
  double _toDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? 0}') ?? 0;

  // ...existing code...

  // ...existing code...

  Future<void> _loadConfirmData() async {
    final userId = LogSession.instance.userId;
    if (userId == null || userId <= 0) {
      setState(() => _error = 'Session user not found.');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final selectedUri = Uri.parse(
        '${AdminIp.baseUrl}/api/user_confirmBike_routes/selected?user_id=$userId',
      );
      final selectedRes = await http
          .get(selectedUri)
          .timeout(const Duration(seconds: 15));
      final selectedBody = _decodeBody(selectedRes);

      if (selectedRes.statusCode < 200 || selectedRes.statusCode >= 300) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error =
              selectedBody?['message']?.toString() ??
              'Failed to load selected bike.';
        });
        return;
      }

      final selectedData = (selectedBody?['data'] is Map<String, dynamic>)
          ? selectedBody!['data'] as Map<String, dynamic>
          : (selectedBody ?? <String, dynamic>{});

      final bike =
          (selectedData['bike'] ?? selectedData['selected_bike'])
              as Map<String, dynamic>? ??
          {};
      final pickup =
          (selectedData['pickup_station'] ?? selectedData['station'])
              as Map<String, dynamic>? ??
          {};

      final dropUri = Uri.parse(
        '${AdminIp.baseUrl}/api/user_confirmBike_routes/dropoff-options?user_id=$userId',
      );
      final dropRes = await http
          .get(dropUri)
          .timeout(const Duration(seconds: 15));
      final dropBody = _decodeBody(dropRes);

      final rawDropoffs =
          (dropBody?['data']?['dropoff_stations'] ??
                  dropBody?['dropoff_stations'] ??
                  dropBody?['data'] ??
                  const [])
              as List;

      final parsedDropoffs = rawDropoffs
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry('$k', v)))
          .map<Map<String, dynamic>>((e) => e)
          .where((e) {
            final hasPrice = e['has_transport_price'];
            if (hasPrice is bool) return hasPrice;
            final price = _toDouble(e['transport_price'] ?? e['price']);
            return price > 0;
          })
          .toList();

      if (!mounted) return;
      setState(() {
        _bike = bike.isEmpty ? null : bike;
        _pickupStation = pickup.isEmpty ? null : pickup;
        _dropoffStations = parsedDropoffs;
        _selectedDropoffStationId = parsedDropoffs.isNotEmpty
            ? _toInt(
                parsedDropoffs.first['station_id'] ??
                    parsedDropoffs.first['id'],
              )
            : null;
        _loading = false;
        _error = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Network error: $e';
      });
    }
  }

  // ...existing code...
  // ...existing code...

  /*
  Future<void> _loadConfirmData() async {
    final userId = LogSession.instance.userId;
    if (userId == null || userId <= 0) {
      setState(() {
        _error = 'Session user not found.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final uri = Uri.parse(
        '${AdminIp.baseUrl}/api/user_dashboard_routes/confirm_bike_data?user_id=$userId',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      final body = _decodeBody(response);

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = body?['data'] as Map<String, dynamic>? ?? {};

        final bike = data['bike'] as Map<String, dynamic>? ?? {};
        final pickup = data['pickup_station'] as Map<String, dynamic>? ?? {};

        final rawDropoffs = (data['dropoff_stations'] as List?) ?? const [];
        final parsedDropoffs = rawDropoffs
            .whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry('$k', v)))
            .map<Map<String, dynamic>>((e) => e)
            .where((e) {
              // Keep only stations where transport price exists and is > 0 or explicitly available.
              final hasPrice = e['has_transport_price'];
              if (hasPrice is bool) return hasPrice;
              final price = _toDouble(e['transport_price'] ?? e['price']);
              return price > 0;
            })
            .toList();

        setState(() {
          _bike = bike.isEmpty ? null : bike;
          _pickupStation = pickup.isEmpty ? null : pickup;
          _dropoffStations = parsedDropoffs;
          _selectedDropoffStationId = parsedDropoffs.isNotEmpty
              ? _toInt(
                  parsedDropoffs.first['station_id'] ??
                      parsedDropoffs.first['id'],
                )
              : null;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = body?['message']?.toString() ?? 'Failed to load bike data.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Network error: $e';
      });
    }
  }

  */

  @override
  Widget build(BuildContext context) {
    // Material wrapper avoids "No Material widget found" in deeply nested cases.
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _loadConfirmData,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxContentWidth = constraints.maxWidth > 900
                  ? 860.0
                  : constraints.maxWidth;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_loading)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: LinearProgressIndicator(minHeight: 4),
                            ),
                          if (_error.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                _error,
                                style: const TextStyle(
                                  color: AppBrandColors.redYellowStart,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          _sectionA(),
                          const SizedBox(height: 12),
                          _sectionB(),
                          const SizedBox(height: 12),
                          _sectionC(),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _sectionA() {
    final bike = _bike ?? {};
    final pickup = _pickupStation ?? {};

    final bikeCode = '${bike['bike_code'] ?? '-'}';
    final bikeName = '${bike['bike_name'] ?? 'Bike'}';
    final bikeImage = '${bike['bike_image'] ?? ''}';
    final battery = _toInt(bike['battery_level']);
    final stationName = '${pickup['station_name'] ?? 'Unknown station'}';
    final pickupPrice = _toDouble(
      pickup['transport_price'] ??
          pickup['pickup_price'] ??
          pickup['base_price'],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Section A • Confirm Bike',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: bikeImage.isNotEmpty
                      ? Image.network(
                          bikeImage,
                          width: 92,
                          height: 92,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholderBikeImage(),
                        )
                      : _placeholderBikeImage(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    runSpacing: 6,
                    children: [
                      Text(
                        bikeName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text('Code: $bikeCode'),
                      Text('Battery: $battery%'),
                      Text('Pickup station: $stationName'),
                      Text(
                        'Pickup price: GHS ${pickupPrice.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionB() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Section B • Select Arrival (Dropoff) Station',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (_dropoffStations.isEmpty)
              const Text(
                'No dropoff stations with valid transport price for this route.',
                style: TextStyle(color: AppBrandColors.whiteMuted),
              )
            else
              ..._dropoffStations.map((station) {
                final id = _toInt(station['station_id'] ?? station['id']);
                final name = '${station['station_name'] ?? 'Unnamed station'}';
                final price = _toDouble(
                  station['transport_price'] ?? station['price'],
                );

                return RadioListTile<int>(
                  value: id,
                  groupValue: _selectedDropoffStationId,
                  onChanged: (value) {
                    setState(() {
                      _selectedDropoffStationId = value;
                    });
                  },
                  title: Text(name),
                  subtitle: Text(
                    'Transport price: GHS ${price.toStringAsFixed(2)}',
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _sectionC() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Section C • Other Places (My Own Location)',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _useOtherPlace = !_useOtherPlace;
                });
              },
              icon: const Icon(Icons.place_outlined),
              label: Text(
                _useOtherPlace
                    ? 'Using My Own Location (Enabled)'
                    : 'Other Places (My Own Location)',
              ),
            ),
            if (_useOtherPlace) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _arrivalNoteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Arrival note',
                  hintText: 'Describe where you will end the ride...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(0.45)),
                ),
                child: const Text(
                  'Caution: Admin-defined banned zones apply. '
                  'Ending a ride in a banned zone may trigger penalties or account restrictions.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _placeholderBikeImage() {
    return Container(
      width: 92,
      height: 92,
      color: Colors.black12,
      child: const Icon(Icons.pedal_bike_rounded, size: 38),
    );
  }
}
*/
