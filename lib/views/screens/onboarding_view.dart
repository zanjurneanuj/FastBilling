import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../utils/app_colors.dart';
import '../../services/ProfileService.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});
  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _formKey = GlobalKey<FormState>();
  final _name    = TextEditingController();
  final _address = TextEditingController();
  final _gst     = TextEditingController();
  String _currency = 'INR';
  File?  _logo;
  bool   _saving = false;

  static const _currencies = ['INR', 'USD', 'EUR', 'GBP', 'AED'];
  static const _purple = Color(0xFF5B4FCF);

  @override
  void dispose() {
    _name.dispose(); _address.dispose(); _gst.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 512, imageQuality: 80);
    if (x != null) setState(() => _logo = File(x.path));
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ProfileService.save(
        name: _name.text.trim(),
        address: _address.text.trim(),
        gstNumber: _gst.text.trim(),
        currency: _currency,
        logoFile: _logo,
      );
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Column(
        children: [
          // ── Purple header ────────────────────────────────────────────────
          _Header(),

          // ── Scrollable form body ─────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Logo picker
                    Center(child: _LogoPicker(logo: _logo, onTap: _pickLogo)),
                    const SizedBox(height: 28),

                    // Name
                    _Label('Your name *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDec(hint: ''),
                      validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 18),

                    // Address
                    _Label('Address'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _address,
                      maxLines: 2,
                      decoration: _inputDec(hint: ''),
                    ),
                    const SizedBox(height: 18),

                    // GST + Currency row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Label('GST number · optional'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _gst,
                                decoration: _inputDec(hint: 'Skip if unregistered'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 118,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Label('Currency'),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _currency,
                                decoration: _inputDec(hint: ''),
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                                items: _currencies
                                    .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text('₹  $c',
                                        style: const TextStyle(fontSize: 14))))
                                    .toList(),
                                onChanged: (v) => setState(() => _currency = v!),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _continue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _purple,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                            : const Text('Continue',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Footer note
                    Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF9AA0AB), height: 1.5),
                          children: [
                            const TextSpan(text: 'No company registration needed.\n'),
                            TextSpan(
                              text: 'Edit anytime in Settings.',
                              style: TextStyle(
                                  color: _purple,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec({required String hint}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFBCC1C8), fontSize: 14),
    filled: true,
    fillColor: Colors.white,
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _purple, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
  );
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  static const _purple = Color(0xFF5B4FCF);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF5B4FCF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.of(context).padding.top + 24, 24, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Icon badge
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.receipt_long_rounded,
              color: Colors.white, size: 24),
        ),
        const SizedBox(height: 16),
        const Text('Welcome 👋',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1.2)),
        const SizedBox(height: 6),
        const Text(
            "Set up your details once — they'll appear on every invoice you send.",
            style: TextStyle(
                color: Colors.white70, fontSize: 14, height: 1.5)),
      ]),
    );
  }
}

// ─── Logo picker ──────────────────────────────────────────────────────────────

class _LogoPicker extends StatelessWidget {
  const _LogoPicker({required this.logo, required this.onTap});
  final File? logo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 88, height: 88,
          decoration: BoxDecoration(
            color: const Color(0xFFF0EEFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFB8B0F0),
              width: 1.5,
              // Dashed border via CustomPainter below
            ),
          ),
          child: logo == null
              ? const Icon(Icons.add_photo_alternate_outlined,
              color: Color(0xFF7C6FF0), size: 30)
              : ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(logo!, fit: BoxFit.cover)),
        ),
        const SizedBox(height: 8),
        const Text('Add your logo',
            style: TextStyle(
                color: Color(0xFF9AA0AB),
                fontSize: 13,
                fontWeight: FontWeight.w400)),
      ]),
    );
  }
}

// ─── Field label ──────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: Color(0xFF5B4FCF),
          fontSize: 13,
          fontWeight: FontWeight.w500));
}