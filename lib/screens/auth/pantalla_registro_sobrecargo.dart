import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/proveedor_autenticacion.dart';

class CrewRegisterScreen extends StatefulWidget {
  const CrewRegisterScreen({super.key});

  @override
  State<CrewRegisterScreen> createState() => _CrewRegisterScreenState();
}

class _CrewRegisterScreenState extends State<CrewRegisterScreen> {
  static const bool _localMlKitAvailable = false;
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _baseController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _licenseTypeController = TextEditingController(
    text: 'Licencia de sobrecargo',
  );
  final _licenseController = TextEditingController();
  final _licenseCategoryController = TextEditingController();
  final _licenseIssueDateController = TextEditingController();
  final _licenseExpirationController = TextEditingController();
  final _licenseStatusController = TextEditingController();
  final _issuingCountryController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();

  File? _document;
  bool _readingDocument = false;
  String _scanRaw = '';
  String _scanStatus = '';
  String _documentMessage = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _baseController.dispose();
    _birthDateController.dispose();
    _nationalityController.dispose();
    _licenseTypeController.dispose();
    _licenseController.dispose();
    _licenseCategoryController.dispose();
    _licenseIssueDateController.dispose();
    _licenseExpirationController.dispose();
    _licenseStatusController.dispose();
    _issuingCountryController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (picked == null) return;

    setState(() {
      _document = File(picked.path);
      _readingDocument = true;
      _documentMessage =
          _localMlKitAvailable
              ? 'Leyendo licencia/documento...'
              : 'Documento cargado. Completa licencia y vigencia manualmente.';
    });

    try {
      if (_localMlKitAvailable) {
        _applyDocumentText('');
      } else {
        setState(() {
          _scanStatus = 'pending_manual_review';
        });
      }
    } catch (_) {
      setState(() {
        _documentMessage =
            'Documento cargado. Completa licencia y vigencia manualmente.';
      });
    } finally {
      if (mounted) setState(() => _readingDocument = false);
    }
  }

  void _applyDocumentText(String rawText) {
    final normalized = rawText.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    final license =
        RegExp(
          r'(?:LICENCIA|LICENSE|CERTIFICADO)[:\s-]*([A-Z0-9-]{5,24})',
        ).firstMatch(normalized)?.group(1) ??
        RegExp(r'\b[A-Z]{2,5}-?\d{4,12}\b').firstMatch(normalized)?.group(0);
    final category = RegExp(
      r'(?:CATEGORIA|CARGO|CLASE|CATEGORY)[:\s-]*([A-Z0-9 /.-]{3,})',
    ).firstMatch(normalized)?.group(1);
    final issueDate = RegExp(
      r'(?:EXPEDICION|EMISION|ISSUE)[:\s-]*(\d{2,4}[-/]\d{2}[-/]\d{2,4})',
    ).firstMatch(normalized)?.group(1);
    final expiration = RegExp(
      r'(?:VIGENCIA|EXPIRA|VALID UNTIL)[:\s-]*(\d{2,4}[-/]\d{2}[-/]\d{2,4})',
    ).firstMatch(normalized)?.group(1);
    final issuingCountry = RegExp(
      r'(?:PAIS(?: EMISOR)?|COUNTRY(?: OF ISSUE)?)[:\s-]*([A-Z ]{3,})',
    ).firstMatch(normalized)?.group(1);
    final nationality = RegExp(
      r'(?:NACIONALIDAD|NATIONALITY)[:\s-]*([A-Z ]{3,})',
    ).firstMatch(normalized)?.group(1);

    setState(() {
      _scanRaw = rawText;
      _scanStatus = rawText.trim().isEmpty ? 'pending' : 'scanned';
      if (license != null) _licenseController.text = license;
      if (category != null) _licenseCategoryController.text = category.trim();
      if (issueDate != null) {
        _licenseIssueDateController.text = _normalizeDate(issueDate);
      }
      if (expiration != null) {
        _licenseExpirationController.text = _normalizeDate(expiration);
      }
      if (issuingCountry != null) {
        _issuingCountryController.text = _toTitle(issuingCountry);
      }
      if (nationality != null) {
        _nationalityController.text = _toTitle(nationality);
      }
      _licenseStatusController.text = _documentStatus(
        _licenseExpirationController.text,
      );
      _documentMessage =
          license == null
              ? 'Documento cargado. Completa los datos manualmente.'
              : 'Documento leido. Revisa licencia y vigencia.';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _passwordConfirmationController.text) {
      _showMessage('Las contrasenas no coinciden.');
      return;
    }
    if (_document == null) {
      _showMessage('Sube la licencia de sobrecargo.');
      return;
    }

    final ok = await context.read<AuthProvider>().registerCrew(
      name: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      base: _baseController.text,
      birthDate: _birthDateController.text,
      nationality: _nationalityController.text,
      licenseNumber: _licenseController.text,
      licenseType: _licenseTypeController.text,
      licenseCategory: _licenseCategoryController.text,
      licenseIssueDate: _licenseIssueDateController.text,
      licenseExpiration: _licenseExpirationController.text,
      licenseStatus: _licenseStatusController.text,
      issuingCountry: _issuingCountryController.text,
      scanRaw: _scanRaw,
      scanStatus: _scanStatus,
      password: _passwordController.text,
      passwordConfirmation: _passwordConfirmationController.text,
      documentFront: _document,
    );

    if (!mounted) return;
    if (!ok) {
      _showMessage(
        context.read<AuthProvider>().errorMessage ??
            'No fue posible crear la cuenta de sobrecargo.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4F7),
      appBar: AppBar(
        title: const Text('Registro sobrecargo'),
        backgroundColor: const Color(0xFF07121D),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const _CrewRegisterHero(),
              const SizedBox(height: 22),
              const _SectionLabel(
                icon: Icons.person_pin_rounded,
                title: 'Datos del usuario',
              ),
              _field(_nameController, 'Nombre completo'),
              _field(
                _emailController,
                'Correo',
                keyboard: TextInputType.emailAddress,
              ),
              _field(
                _phoneController,
                'Telefono',
                keyboard: TextInputType.phone,
              ),
              _field(_baseController, 'Base operativa'),
              _field(
                _birthDateController,
                'Fecha de nacimiento',
                hint: 'AAAA-MM-DD',
              ),
              _field(_nationalityController, 'Nacionalidad del titular'),
              const SizedBox(height: 14),
              const _SectionLabel(
                icon: Icons.workspace_premium_rounded,
                title: 'Licencia de sobrecargo',
              ),
              _FileButton(
                title: 'Licencia de sobrecargo',
                value: _document?.path.split(Platform.pathSeparator).last,
                loading: _readingDocument,
                onTap: _pickDocument,
              ),
              if (_documentMessage.isNotEmpty) _HintText(_documentMessage),
              const SizedBox(height: 10),
              _field(_licenseTypeController, 'Tipo de documento'),
              _field(_licenseController, 'Numero de licencia'),
              _field(_licenseCategoryController, 'Categoria / cargo'),
              _field(
                _licenseIssueDateController,
                'Fecha de emision',
                hint: 'AAAA-MM-DD',
              ),
              _field(
                _licenseExpirationController,
                'Vigencia de licencia',
                hint: 'AAAA-MM-DD',
              ),
              _field(_issuingCountryController, 'Pais emisor'),
              _field(_licenseStatusController, 'Estado del documento'),
              const SizedBox(height: 14),
              const _SectionLabel(
                icon: Icons.lock_outline_rounded,
                title: 'Acceso',
              ),
              _field(
                _passwordController,
                'Contrasena',
                obscure: true,
                minLength: 8,
              ),
              _field(
                _passwordConfirmationController,
                'Confirmar contrasena',
                obscure: true,
                minLength: 8,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: auth.isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: const Color(0xFF0E2338),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child:
                    auth.isLoading
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Text('Crear cuenta sobrecargo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    bool obscure = false,
    int minLength = 1,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          prefixIcon: _iconForLabel(label),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDE6EE)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE0B86E), width: 1.4),
          ),
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.length < minLength) return 'Completa $label.';
          return null;
        },
      ),
    );
  }

  Widget? _iconForLabel(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('correo')) return const Icon(Icons.alternate_email);
    if (normalized.contains('telefono')) return const Icon(Icons.phone_rounded);
    if (normalized.contains('base')) {
      return const Icon(Icons.flight_land_rounded);
    }
    if (normalized.contains('fecha')) return const Icon(Icons.event_rounded);
    if (normalized.contains('licencia')) return const Icon(Icons.badge_rounded);
    if (normalized.contains('pais')) return const Icon(Icons.public_rounded);
    if (normalized.contains('contrasena')) {
      return const Icon(Icons.lock_rounded);
    }
    return const Icon(Icons.person_outline_rounded);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _normalizeDate(String value) {
    final cleaned = value.trim().replaceAll('/', '-');
    final parts = cleaned.split('-');
    if (parts.length != 3) return cleaned;
    if (parts.first.length == 4) return cleaned;
    return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
  }

  String _documentStatus(String expirationDate) {
    final expiration = DateTime.tryParse(expirationDate);
    if (expiration == null) return '';
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final days = expiration.difference(normalizedToday).inDays;
    if (days < 0) return 'Vencida';
    if (days <= 30) return 'Por vencer';
    return 'Vigente';
  }

  String _toTitle(String value) {
    return value
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map(
          (word) =>
              word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}

class _CrewRegisterHero extends StatelessWidget {
  const _CrewRegisterHero();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF07121D), Color(0xFF102438), Color(0xFF173B55)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 24,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.airline_seat_recline_extra_rounded,
                  color: Color(0xFFE0B86E),
                ),
                SizedBox(width: 10),
                Text(
                  'Alta operacional',
                  style: TextStyle(
                    color: Color(0xFFE0B86E),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            Text(
              'Sobrecargo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Crea el acceso con licencia, base operativa y credenciales.',
              style: TextStyle(color: Color(0xFFD8E2EA), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF7A5A18)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0E2338),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FileButton extends StatelessWidget {
  const _FileButton({
    required this.title,
    required this.onTap,
    this.value,
    this.loading = false,
  });

  final String title;
  final String? value;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: loading ? null : onTap,
      icon:
          loading
              ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : const Icon(Icons.upload_file_rounded),
      label: Text(value == null ? title : '$title: $value'),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0E2338),
        minimumSize: const Size.fromHeight(52),
        alignment: Alignment.centerLeft,
        side: const BorderSide(color: Color(0xFFE0B86E)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _HintText extends StatelessWidget {
  const _HintText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF5F6975),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
