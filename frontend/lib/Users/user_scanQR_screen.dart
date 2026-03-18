import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../admin_ip.dart';
import '../log_session.dart';
import '../theme_settings.dart';

class UserScanQrScreen extends StatefulWidget {
  // THE NEW PORT: Accepts the command from the Dashboard
  final VoidCallback? onRideStarted;

  const UserScanQrScreen({super.key, this.onRideStarted});

  @override
  State<UserScanQrScreen> createState() => _UserScanQrScreenState();
}

class _UserScanQrScreenState extends State<UserScanQrScreen> {
  final TextEditingController _bikeCodeController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _bikeCodeController.dispose();
    super.dispose();
  }

  Future<void> _processBikeCode(String code) async {
    final bikeCode = code.trim();
    if (bikeCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppBrandColors.redYellowStart,
          content: Text("Please enter or scan a valid Bike Code."),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final res = await http.post(
        Uri.parse('${AdminIp.baseUrl}/api/scan/start-ride'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': LogSession.instance.userId,
          'bike_code': bikeCode,
        }),
      );

      if (!mounted) return;
      final body = jsonDecode(res.body);

      if (res.statusCode == 200) {
        _showUnlockSuccessDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppBrandColors.redYellowStart,
            content: Text(body['message'] ?? 'Failed to unlock bike.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppBrandColors.redYellowStart,
          content: Text("Network error. Could not connect to bike."),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showUnlockSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppBrandColors.blackEnd,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppBrandColors.greenMid, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppBrandColors.greenMid.withOpacity(0.3),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_open_rounded,
                color: AppBrandColors.greenMid,
                size: 64,
              ),
              const SizedBox(height: 20),
              const Text(
                "BIKE UNLOCKED",
                style: TextStyle(
                  color: AppBrandColors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Your wallet has been charged. Ride safely!",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppBrandColors.whiteMuted),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close Dialog

                    // THE TRIGGER: Tell the Dashboard to flip to Tab 3 (Ride Mode)
                    if (widget.onRideStarted != null) {
                      widget.onRideStarted!();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppBrandColors.greenMid,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "ENTER RIDE MODE",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 120),
          children: [
            const Text(
              "Unlock Your Ride",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppBrandColors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Locate the QR Code on the handlebars or rear fender of the e-bike.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppBrandColors.whiteMuted, fontSize: 14),
            ),
            const SizedBox(height: 40),

            // MOCK CAMERA FRAME
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: AppBrandColors.blackStart,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppBrandColors.redYellowMid,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppBrandColors.redYellowMid.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 100,
                      color: AppBrandColors.whiteMuted.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // MVP MANUAL ENTRY
            const Text(
              "Camera unavailable? Enter code manually:",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppBrandColors.whiteMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppBrandColors.blackEnd,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppBrandColors.white.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.numbers_rounded,
                    color: AppBrandColors.whiteMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _bikeCodeController,
                      style: const TextStyle(
                        color: AppBrandColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: "e.g. BK-001",
                        hintStyle: TextStyle(color: Color(0xFF4A4A4A)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ACTION BUTTON
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isProcessing
                    ? null
                    : () => _processBikeCode(_bikeCodeController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppBrandColors.greenMid,
                  foregroundColor: AppBrandColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: AppBrandColors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text(
                        "UNLOCK BIKE",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
