
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'main.dart' show authService;

class InvitationScanScreen extends StatefulWidget {
  const InvitationScanScreen({super.key});

  @override
  State<InvitationScanScreen> createState() =>
      _InvitationScanScreenState();
}

class _InvitationScanScreenState extends State<InvitationScanScreen> {
  bool scanned = false;

  void _onDetect(BarcodeCapture capture) {
    if (scanned) return;

    final barcode = capture.barcodes.firstOrNull;
    final token = barcode?.rawValue?.trim();

    if (token == null || token.isEmpty) return;

    setState(() => scanned = true);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => InvitationActivationScreen(token: token),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Invitation')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Point your camera at the invitation QR code.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
          Expanded(
            child: MobileScanner(onDetect: _onDetect),
          ),
        ],
      ),
    );
  }
}

class InvitationActivationScreen extends StatefulWidget {
  final String token;

  const InvitationActivationScreen({
    super.key,
    required this.token,
  });

  @override
  State<InvitationActivationScreen> createState() =>
      _InvitationActivationScreenState();
}

class _InvitationActivationScreenState
    extends State<InvitationActivationScreen> {
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;
  String? error;

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final password = passwordController.text;
    final confirmation = confirmController.text;

    if (password.isEmpty || confirmation.isEmpty) {
      setState(() => error = 'Please fill in both password fields.');
      return;
    }

    if (password != confirmation) {
      setState(() => error = 'Passwords do not match.');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await authService.activateInvitation(
        token: widget.token,
        password: password,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Account activated'),
          content: const Text(
            'Your account is ready. You can now sign in using '
            'the username provided by the farm owner and your new password.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Text('GO TO LOGIN'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activate Account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 64,
                  color: Colors.blue,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Create your password',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a password for your shepherd account.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmController,
                  obscureText: obscurePassword,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _activate(),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: loading ? null : _activate,
                    child: loading
                        ? const CircularProgressIndicator()
                        : const Text('ACTIVATE ACCOUNT'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
