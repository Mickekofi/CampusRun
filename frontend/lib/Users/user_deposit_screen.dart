import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../admin_ip.dart';
import '../log_session.dart';
import '../theme_settings.dart';

class UserDepositScreen extends StatefulWidget {
  const UserDepositScreen({super.key});

  @override
  State<UserDepositScreen> createState() => _UserDepositScreenState();
}

class _UserDepositScreenState extends State<UserDepositScreen> {
  final TextEditingController _amountController = TextEditingController();

  String? _selectedPhone;
  String _detectedNetwork = "Unknown Network";
  Color _networkColor = AppBrandColors.whiteMuted;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _selectedPhone = LogSession.instance.phone;
    _detectNetwork(_selectedPhone ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
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
        _networkColor = const Color(0xFFFFCC00);
      });
    } else if (['+23320', '+23350'].contains(prefix)) {
      setState(() {
        _detectedNetwork = "Telecel Cash";
        _networkColor = const Color(0xFFE60000);
      });
    } else if (['+23327', '+23357', '+23326', '+23356'].contains(prefix)) {
      setState(() {
        _detectedNetwork = "AT Money";
        _networkColor = const Color(0xFF0055A5);
      });
    } else {
      setState(() {
        _detectedNetwork = "Unknown Network";
        _networkColor = AppBrandColors.whiteMuted;
      });
    }
  }

  Future<void> _processDeposit() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText) ?? 0.0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppBrandColors.redYellowStart,
          content: Text("Enter a valid amount to deposit."),
        ),
      );
      return;
    }

    if (_selectedPhone == null ||
        _selectedPhone!.isEmpty ||
        _detectedNetwork == "Unknown Network") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppBrandColors.redYellowStart,
          content: Text("Please enter a valid MoMo number."),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final res = await http.post(
        Uri.parse('${AdminIp.baseUrl}/api/deposit/topup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': LogSession.instance.userId,
          'amount': amount,
          'phone': _selectedPhone,
          'network': _detectedNetwork,
        }),
      );

      if (!mounted) return;
      final body = jsonDecode(res.body);

      if (res.statusCode == 200) {
        _amountController.clear();
        _showGamingSuccessDialog(body['new_balance']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppBrandColors.redYellowStart,
            content: Text(body['message'] ?? 'Deposit failed.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppBrandColors.redYellowStart,
          content: Text("Network error. Could not complete deposit."),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showGamingSuccessDialog(dynamic newBalance) {
    showDialog(
      context: context,
      barrierDismissible: false,
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
                "FUNDS SECURED",
                style: TextStyle(
                  color: AppBrandColors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Your wallet has been successfully credited.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppBrandColors.whiteMuted,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppBrandColors.blackStart,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppBrandColors.white.withOpacity(0.1),
                  ),
                ),
                child: Text(
                  "New Balance: GHS $newBalance",
                  style: const TextStyle(
                    color: AppBrandColors.greenMid,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    // NOTE: The Dashboard will need to be refreshed to show the new balance in the top strip.
                    // The user can hit the refresh icon in the AppBar.
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppBrandColors.greenMid,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    "CONTINUE",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 120.0),
          children: [
            // SECTION A: MOMO ICONS
            _buildSectionA(),
            const SizedBox(height: 32),

            // SECTION B: PHONE SELECTOR
            _buildSectionB(),
            const SizedBox(height: 32),

            // SECTION C: AMOUNT INPUT
            _buildSectionC(),
            const SizedBox(height: 40),

            // SECTION D: ACTION BUTTON
            _buildSectionD(),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // UI WIDGET BUILDERS
  // ============================================================================

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "MoMo Number",
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

  Widget _buildSectionC() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          "DEPOSIT AMOUNT (GHS)",
          style: TextStyle(
            color: AppBrandColors.whiteMuted,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: AppBrandColors.blackEnd,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppBrandColors.redYellowMid.withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppBrandColors.redYellowMid.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppBrandColors.white,
              fontSize: 48,
              fontWeight: FontWeight.w900,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: "0.00",
              hintStyle: TextStyle(color: Color(0xFF3B3B3B)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionD() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _processDeposit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppBrandColors.redYellowMid,
          foregroundColor: AppBrandColors.white,
          disabledBackgroundColor: AppBrandColors.whiteMuted.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          shadowColor: AppBrandColors.redYellowMid.withOpacity(0.5),
        ),
        child: _isProcessing
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: AppBrandColors.white,
                  strokeWidth: 3,
                ),
              )
            : const Text(
                "INITIATE DEPOSIT",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
      ),
    );
  }
}
