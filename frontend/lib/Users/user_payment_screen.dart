import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../admin_ip.dart';
import '../log_session.dart';
import '../theme_settings.dart';

class UserPaymentScreen extends StatefulWidget {
  // THE PORTS: Tell the Dashboard where to navigate next
  final VoidCallback? onPaymentSuccess; // Moves forward to Scan Tab
  final VoidCallback? onBackPressed; // Moves backward to Confirm Tab

  const UserPaymentScreen({
    super.key,
    this.onPaymentSuccess,
    this.onBackPressed,
  });

  @override
  State<UserPaymentScreen> createState() => _UserPaymentScreenState();
}

class _UserPaymentScreenState extends State<UserPaymentScreen> {
  bool _isLoading = true;
  String _errorMessage = '';

  String _journeyText = "Loading route...";
  String _fareAmount = "0.00";

  // Section C State
  String? _selectedPhone;
  String _detectedNetwork = "Unknown Network";
  Color _networkColor = AppBrandColors.whiteMuted;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _selectedPhone = LogSession.instance.phone;
    _detectNetwork(_selectedPhone ?? '');
    _fetchPaymentDetails();
  }

  // ============================================================================
  // API INTEGRATION
  // ============================================================================

  Future<void> _fetchPaymentDetails() async {
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
      final res = await http.get(
        Uri.parse('${AdminIp.baseUrl}/api/payment/details?user_id=$userId'),
      );

      if (!mounted) return;
      final body = jsonDecode(res.body);

      if (res.statusCode == 200) {
        setState(() {
          _journeyText = body['data']['journey_text'];
          _fareAmount = body['data']['fare_amount'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = body['message'] ?? "No confirmed route found.";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Network error. Could not load details.";
        _isLoading = false;
      });
    }
  }

  void _detectNetwork(String phone) {
    if (phone.isEmpty || phone.length < 3) {
      setState(() {
        _detectedNetwork = "Enter valid number";
        _networkColor = AppBrandColors.whiteMuted;
      });
      return;
    }

    final prefix = phone.substring(0, 6);
    if ([
      '+23324',
      '+23325',
      '+23353',
      '+23354',
      '+23355',
      '+23359',
    ].contains(prefix)) {
      setState(() {
        _detectedNetwork = "MTN Mobile Money";
        _networkColor = const Color(0xFFFFCC00); // MTN Yellow
      });
    } else if (['+23320', '+23350'].contains(prefix)) {
      setState(() {
        _detectedNetwork = "Telecel Cash";
        _networkColor = const Color(0xFFE60000); // Telecel Red
      });
    } else if (['+23327', '+23357', '+23326', '+23356'].contains(prefix)) {
      setState(() {
        _detectedNetwork = "AT Money";
        _networkColor = const Color(0xFF0055A5); // AT Blue
      });
    } else {
      setState(() {
        _detectedNetwork = "Unknown Network";
        _networkColor = AppBrandColors.whiteMuted;
      });
    }
  }

  Future<void> _authorizePayment() async {
    if (_selectedPhone == null ||
        _selectedPhone!.isEmpty ||
        _detectedNetwork == "Unknown Network") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppBrandColors.redYellowStart,
          content: Text(
            "Please enter a valid Ghanaian MoMo number.",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final res = await http.post(
        Uri.parse('${AdminIp.baseUrl}/api/payment/authorize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': LogSession.instance.userId,
          'amount': _fareAmount,
          'phone': _selectedPhone,
          'network': _detectedNetwork,
        }),
      );

      if (!mounted) return;
      final body = jsonDecode(res.body);

      if (res.statusCode == 200) {
        _showSuccessDialog(); // Trigger the beautiful pop-up
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppBrandColors.redYellowStart,
            content: Text(
              body['message'] ?? 'Payment authorization failed.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppBrandColors.redYellowStart,
          content: Text(
            "Network error. Could not authorize payment.",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ============================================================================
  // THE BEAUTIFUL SUCCESS POP-UP
  // ============================================================================
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Forces user to click the button
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppBrandColors.blackStart, AppBrandColors.blackEnd],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppBrandColors.greenMid, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppBrandColors.greenMid.withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppBrandColors.greenMid.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppBrandColors.greenMid,
                  size: 64,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "AUTHORIZATION SECURED",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppBrandColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Your wallet funds have been locked for this ride. The asset is ready for deployment.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppBrandColors.whiteMuted,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // 1. Close the Dialog window
                    Navigator.of(context).pop();

                    // 2. Trigger the callback to swap to the Scan Tab
                    if (widget.onPaymentSuccess != null) {
                      widget.onPaymentSuccess!();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppBrandColors.greenMid,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    "PROCEED TO SCAN",
                    style: TextStyle(
                      color: AppBrandColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // BUILD METHODS
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppBrandColors.blackBackgroundGradient,
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppBrandColors.greenMid,
                ),
              )
            : _errorMessage.isNotEmpty
            ? Center(
                child: Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: AppBrandColors.redYellowStart,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  // THE NEW BACK BUTTON HEADER
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppBrandColors.white,
                        ),
                        onPressed: () {
                          if (widget.onBackPressed != null) {
                            widget
                                .onBackPressed!(); // Tells Dashboard to flip back
                          } else {
                            Navigator.of(
                              context,
                            ).pop(); // Failsafe for normal navigation
                          }
                        },
                      ),
                      const Text(
                        "Back to Details",
                        style: TextStyle(
                          color: AppBrandColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionA(),
                  const SizedBox(height: 24),
                  _buildSectionB(),
                  const SizedBox(height: 24),
                  _buildSectionC(),
                  const SizedBox(height: 40),
                  _buildSectionD(),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionA() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _networkBadge("MTN", const Color(0xFFFFCC00)),
        _networkBadge("Telecel", const Color(0xFFE60000)),
        _networkBadge("AT", const Color(0xFF0055A5)),
      ],
    );
  }

  Widget _networkBadge(String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSectionB() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppBrandColors.blackEnd,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppBrandColors.greenMid.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.route_rounded,
            color: AppBrandColors.greenMid,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            _journeyText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppBrandColors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Color(0xFF2B2B2B)),
          ),
          const Text(
            "Amount to Authorize",
            style: TextStyle(color: AppBrandColors.whiteMuted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            "GHS $_fareAmount",
            style: const TextStyle(
              color: AppBrandColors.greenMid,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionC() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Payment Number",
          style: TextStyle(
            color: AppBrandColors.whiteMuted,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppBrandColors.blackEnd,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2B2B2B)),
          ),
          child: TextFormField(
            initialValue: _selectedPhone,
            keyboardType: TextInputType.phone,
            style: const TextStyle(
              color: AppBrandColors.white,
              fontSize: 18,
              letterSpacing: 1.2,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              icon: Icon(Icons.phone_android, color: AppBrandColors.whiteMuted),
            ),
            onChanged: (value) {
              _selectedPhone = value;
              _detectNetwork(value);
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.check_circle_rounded, color: _networkColor, size: 16),
            const SizedBox(width: 8),
            Text(
              _detectedNetwork,
              style: TextStyle(
                color: _networkColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionD() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _authorizePayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppBrandColors.greenMid,
          foregroundColor: AppBrandColors.white,
          disabledBackgroundColor: AppBrandColors.whiteMuted.withOpacity(0.2),
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
                  strokeWidth: 2,
                ),
              )
            : const Text(
                "Authorize & Proceed to Scan",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
