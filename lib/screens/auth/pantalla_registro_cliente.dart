import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/proveedor_autenticacion.dart';

class ClientRegisterScreen extends StatefulWidget {
  const ClientRegisterScreen({super.key});

  @override
  State<ClientRegisterScreen> createState() => _ClientRegisterScreenState();
}

class _ClientRegisterScreenState extends State<ClientRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _nationalityController = TextEditingController(text: 'Mexicana');
  final _baseController = TextEditingController();
  final _documentTypeController = TextEditingController(text: 'INE');
  final _documentNumberController = TextEditingController();
  final _documentIssueDateController = TextEditingController();
  final _documentExpirationController = TextEditingController();
  final _documentStatusController = TextEditingController();
  final _ineCurpController = TextEditingController();
  final _ineCicController = TextEditingController();
  final _ineOcrController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();

  File? _ineFront;
  File? _ineBack;
  File? _selfie;
  bool _scanningDocument = false;
  bool _validatingSelfie = false;
  bool _selfieHasFace = false;
  int _facesCount = 0;
  double? _faceConfidence;
  String _ineScanRaw = '';
  String _ineScanStatus = '';
  String _identityVerificationStatus = '';
  String _identityVerificationMessage = '';
  String _documentScanMessage = '';
  String _selfieMessage = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _nationalityController.dispose();
    _baseController.dispose();
    _documentTypeController.dispose();
    _documentNumberController.dispose();
    _documentIssueDateController.dispose();
    _documentExpirationController.dispose();
    _documentStatusController.dispose();
    _ineCurpController.dispose();
    _ineCicController.dispose();
    _ineOcrController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _pickIneFront() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (picked == null) return;

    setState(() {
      _ineFront = File(picked.path);
      _documentScanMessage = 'Leyendo texto de la identificacion...';
      _scanningDocument = true;
    });

    try {
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final recognized = await textRecognizer.processImage(
        InputImage.fromFilePath(picked.path),
      );
      await textRecognizer.close();
      _applyDocumentText(recognized.text);
    } catch (_) {
      setState(() {
        _documentScanMessage =
            'Imagen cargada. No se pudo extraer texto automaticamente.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _scanningDocument = false;
        });
      }
    }
  }

  Future<void> _pickIneBack() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (picked == null) return;
    setState(() => _ineBack = File(picked.path));
  }

  Future<void> _captureSelfie() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 88,
    );
    if (picked == null) return;

    setState(() {
      _selfie = File(picked.path);
      _validatingSelfie = true;
      _selfieHasFace = false;
      _selfieMessage = 'Validando rostro...';
    });

    try {
      final detector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableClassification: true,
        ),
      );
      final faces = await detector.processImage(
        InputImage.fromFilePath(picked.path),
      );
      await detector.close();
      setState(() {
        _selfieHasFace = faces.isNotEmpty;
        _facesCount = faces.length;
        _faceConfidence =
            faces.isNotEmpty ? faces.first.smilingProbability : null;
        _identityVerificationStatus =
            faces.isNotEmpty ? 'approved' : 'capture_rejected';
        _identityVerificationMessage =
            faces.isNotEmpty
                ? 'Selfie validada localmente con ML Kit.'
                : 'No se detecto un rostro claro.';
        _selfieMessage =
            faces.isNotEmpty
                ? 'Selfie validada con rostro detectado.'
                : 'No se detecto un rostro claro. Toma otra selfie.';
      });
    } catch (_) {
      setState(() {
        _identityVerificationStatus = 'pending_backend_validation';
        _identityVerificationMessage =
            'Selfie capturada. Validacion local no disponible.';
        _selfieMessage =
            'Selfie capturada. La validacion facial local no pudo completarse.';
      });
    } finally {
      if (mounted) {
        setState(() => _validatingSelfie = false);
      }
    }
  }

  void _applyDocumentText(String rawText) {
    final normalized = rawText.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    final curp = RegExp(
      r'[A-Z][AEIOUX][A-Z]{2}\d{6}[HM][A-Z]{5}[A-Z0-9]\d',
    ).firstMatch(normalized)?.group(0);
    final electorKey = RegExp(
      r'CLAVE(?: DE)? ELECTOR[:\s-]*([A-Z0-9]{12,20})',
    ).firstMatch(normalized)?.group(1);
    final cic = RegExp(
      r'\bCIC[:\s-]*([0-9]{7,15})',
    ).firstMatch(normalized)?.group(1);
    final ocr = RegExp(
      r'\bOCR[:\s-]*([0-9]{8,15})',
    ).firstMatch(normalized)?.group(1);
    final issueDate = RegExp(
      r'(?:EMISION|EXPEDICION)[:\s-]*(\d{4}[-/]\d{2}[-/]\d{2})',
    ).firstMatch(normalized)?.group(1);
    final validity = RegExp(
      r'VIGENCIA[:\s-]*(20\d{2})',
    ).firstMatch(normalized)?.group(1);

    setState(() {
      _ineScanRaw = rawText;
      _ineScanStatus = rawText.trim().isEmpty ? 'pending' : 'scanned';
      if ((electorKey ?? '').isNotEmpty) {
        _documentNumberController.text = electorKey!;
      } else if ((curp ?? '').isNotEmpty) {
        _documentNumberController.text = curp!;
      }
      if ((curp ?? '').isNotEmpty) _ineCurpController.text = curp!;
      if ((cic ?? '').isNotEmpty) _ineCicController.text = cic!;
      if ((ocr ?? '').isNotEmpty) _ineOcrController.text = ocr!;
      if ((issueDate ?? '').isNotEmpty) {
        _documentIssueDateController.text = issueDate!.replaceAll('/', '-');
      }
      if ((validity ?? '').isNotEmpty) {
        _documentExpirationController.text = '$validity-12-31';
      }
      _documentStatusController.text = _documentStatus(
        _documentExpirationController.text,
      );
      _documentScanMessage =
          curp == null && electorKey == null
              ? 'Imagen cargada. Completa los datos del documento manualmente.'
              : 'Documento leido. Revisa los datos antes de crear la cuenta.';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _passwordConfirmationController.text) {
      _showMessage('Las contrasenas no coinciden.');
      return;
    }

    if (_ineFront == null || _ineBack == null) {
      _showMessage('Sube frente y reverso de la INE.');
      return;
    }

    if (_selfie == null) {
      _showMessage('Captura una selfie para validar identidad.');
      return;
    }

    if (!_selfieHasFace) {
      _showMessage('La selfie debe tener un rostro detectado.');
      return;
    }

    final ok = await context.read<AuthProvider>().registerClient(
      name: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      birthDate: _birthDateController.text,
      nationality: _nationalityController.text,
      base: _baseController.text,
      documentType: _documentTypeController.text,
      documentNumber: _documentNumberController.text,
      documentIssueDate: _documentIssueDateController.text,
      documentExpiration: _documentExpirationController.text,
      documentStatus: _documentStatusController.text,
      ineCurp: _ineCurpController.text,
      ineCic: _ineCicController.text,
      ineOcr: _ineOcrController.text,
      ineScanRaw: _ineScanRaw,
      ineScanStatus: _ineScanStatus,
      identityVerificationStatus: _identityVerificationStatus,
      identityVerificationMessage: _identityVerificationMessage,
      identityVerified: _selfieHasFace,
      faceDetected: _selfieHasFace,
      facesCount: _facesCount,
      faceConfidence: _faceConfidence,
      password: _passwordController.text,
      passwordConfirmation: _passwordConfirmationController.text,
      ineFront: _ineFront,
      ineBack: _ineBack,
      selfieBiometric: _selfie,
    );

    if (!mounted) return;
    if (!ok) {
      _showMessage(
        context.read<AuthProvider>().errorMessage ??
            'No fue posible crear la cuenta.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4F7),
      appBar: AppBar(
        title: const Text('Crear cuenta cliente'),
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
              const _ClientRegisterHero(),
              const SizedBox(height: 22),
              const _SectionLabel(
                icon: Icons.person_pin_rounded,
                title: 'Datos del cliente',
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
              _field(
                _birthDateController,
                'Fecha de nacimiento',
                hint: 'AAAA-MM-DD',
              ),
              _field(_nationalityController, 'Nacionalidad'),
              _field(_baseController, 'Ciudad/base'),
              _field(_documentTypeController, 'Identificacion'),
              const SizedBox(height: 14),
              const _SectionLabel(
                icon: Icons.contact_mail_rounded,
                title: 'Identificacion oficial',
              ),
              _FileButton(
                title: 'INE frente',
                value: _ineFront?.path.split(Platform.pathSeparator).last,
                loading: _scanningDocument,
                onTap: _pickIneFront,
              ),
              if (_documentScanMessage.isNotEmpty)
                _HintText(_documentScanMessage),
              const SizedBox(height: 10),
              _FileButton(
                title: 'INE reverso',
                value: _ineBack?.path.split(Platform.pathSeparator).last,
                onTap: _pickIneBack,
              ),
              const SizedBox(height: 10),
              _field(_documentNumberController, 'Numero de documento'),
              _field(
                _documentIssueDateController,
                'Fecha de emision',
                hint: 'AAAA-MM-DD',
              ),
              _field(
                _documentExpirationController,
                'Vigencia del documento',
                hint: 'AAAA-MM-DD',
              ),
              _field(_documentStatusController, 'Estado del documento'),
              _field(_ineCurpController, 'CURP', requiredField: false),
              _field(_ineCicController, 'CIC', requiredField: false),
              _field(_ineOcrController, 'OCR', requiredField: false),
              const SizedBox(height: 14),
              const _SectionLabel(
                icon: Icons.verified_user_rounded,
                title: 'Validacion biometrica',
              ),
              _FileButton(
                title: 'Selfie biometrica',
                value: _selfie?.path.split(Platform.pathSeparator).last,
                loading: _validatingSelfie,
                onTap: _captureSelfie,
              ),
              if (_selfieMessage.isNotEmpty) _HintText(_selfieMessage),
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
                        : const Text('Crear cuenta'),
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
    bool requiredField = true,
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
          prefixIcon: _iconForLabel(label),
          filled: true,
          fillColor: Colors.white,
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
          if (!requiredField) return null;
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
    if (normalized.contains('fecha')) return const Icon(Icons.event_rounded);
    if (normalized.contains('base') || normalized.contains('ciudad')) {
      return const Icon(Icons.flight_land_rounded);
    }
    if (normalized.contains('documento') ||
        normalized.contains('ine') ||
        normalized.contains('curp') ||
        normalized.contains('cic') ||
        normalized.contains('ocr') ||
        normalized.contains('identificacion')) {
      return const Icon(Icons.badge_rounded);
    }
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
}

class _ClientRegisterHero extends StatelessWidget {
  const _ClientRegisterHero();

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
                  Icons.airline_seat_flat_angled_rounded,
                  color: Color(0xFFE0B86E),
                ),
                SizedBox(width: 10),
                Text(
                  'Acceso cliente',
                  style: TextStyle(
                    color: Color(0xFFE0B86E),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            Text(
              'Cotizacion gratis y portal privado',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Completa perfil, identificacion y selfie para iniciar el flujo de reserva.',
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
