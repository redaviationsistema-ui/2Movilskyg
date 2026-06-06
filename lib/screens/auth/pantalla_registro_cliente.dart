import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/cliente_api.dart';
import '../../providers/proveedor_autenticacion.dart';
import '../../services/servicio_ocr_registro.dart';
import '../marketplace/pantalla_inicio_mercado.dart';

class ClientRegisterScreen extends StatefulWidget {
  const ClientRegisterScreen({super.key});

  @override
  State<ClientRegisterScreen> createState() => _ClientRegisterScreenState();
}

class _ClientRegisterScreenState extends State<ClientRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _api = ApiClient.instance;
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
  int _currentStep = 0;
  bool _scanningDocument = false;
  bool _validatingSelfie = false;
  bool _passwordVisible = false;
  bool _passwordConfirmationVisible = false;
  bool _selfieHasFace = false;
  bool _biometricImageSaved = false;
  bool? _faceOccluded;
  int _facesCount = 0;
  double? _faceConfidence;
  double? _qualityBrightness;
  double? _qualitySharpness;
  double? _poseYaw;
  double? _posePitch;
  double? _poseRoll;
  String _biometricCapturedAt = '';
  String _biometricProvider = 'aws_rekognition';
  String _biometricTemplateType = 'selfie-photo';
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
    final selected = await _selectDocumentImage('INE frente');
    if (selected == null) return;

    setState(() {
      _ineFront = selected;
      _documentScanMessage = 'Escaneando datos de la INE en el dispositivo...';
    });
    await _scanIneLocally();
  }

  Future<void> _pickIneBack() async {
    final selected = await _selectDocumentImage('INE reverso');
    if (selected == null) return;
    setState(() {
      _ineBack = selected;
      _documentScanMessage = 'Combinando frente y reverso de la INE...';
    });
    await _scanIneLocally();
  }

  Future<File?> _selectDocumentImage(String title) async {
    final source = await showModalBottomSheet<_DocumentImageSource>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded),
                  title: const Text('Tomar foto'),
                  subtitle: Text('Usar la camara para capturar $title'),
                  onTap:
                      () => Navigator.pop(context, _DocumentImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_open_rounded),
                  title: const Text('Elegir de archivos'),
                  subtitle: const Text('Seleccionar una imagen guardada'),
                  onTap:
                      () => Navigator.pop(context, _DocumentImageSource.files),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
    if (source == null) return null;

    if (source == _DocumentImageSource.camera) {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 96,
      );
      return picked == null ? null : File(picked.path);
    }

    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    return path == null ? null : File(path);
  }

  Future<void> _scanIneLocally() async {
    final images = <File>[
      if (_ineFront != null) _ineFront!,
      if (_ineBack != null) _ineBack!,
    ];
    if (images.isEmpty) return;

    setState(() => _scanningDocument = true);
    try {
      final result = await RegistrationOcrService.scanIne(images);
      _applyLocalIneResult(result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ineScanStatus = 'pending_manual_review';
        _documentScanMessage =
            'No se pudo leer la INE localmente. Usa una foto clara o completa los datos manualmente.';
      });
    } finally {
      if (mounted) setState(() => _scanningDocument = false);
    }
  }

  void _applyLocalIneResult(RegistrationOcrResult result) {
    final data = result.fields;
    setState(() {
      _ineScanRaw = result.rawText;
      _ineScanStatus =
          data.values.any((value) => value.trim().isNotEmpty)
              ? 'scanned'
              : 'partial';
      _setIfPresent(_nameController, data['name']);
      _setIfPresent(_birthDateController, data['birth_date']);
      _setIfPresent(_nationalityController, data['nationality']);
      _setIfPresent(_documentNumberController, data['document_number']);
      _setIfPresent(_documentExpirationController, data['document_expiration']);
      _setIfPresent(_ineCurpController, data['curp']);
      _setIfPresent(_ineCicController, data['cic']);
      _setIfPresent(_ineOcrController, data['ocr']);
      _documentStatusController.text = _documentStatus(
        _documentExpirationController.text,
      );
      final detected = [
        if (_documentNumberController.text.isNotEmpty) 'documento',
        if (_ineCurpController.text.isNotEmpty) 'CURP',
        if (_nameController.text.isNotEmpty) 'nombre',
        if (_documentExpirationController.text.isNotEmpty) 'vigencia',
      ];
      _documentScanMessage =
          detected.isEmpty
              ? 'No se detectaron datos claros. Intenta con fotos derechas, completas y sin reflejos.'
              : 'Escaneo ${result.method} completado: ${detected.join(', ')}. Revisa los datos.';
    });
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
      _selfieMessage = 'Selfie capturada. Validando rostro en backend...';
    });

    try {
      final result = await _api.validateBiometricSelfie(_selfie!);
      final quality = _map(result['quality']);
      final pose = _map(result['pose']);
      final verified = _asBool(
        result['identityVerified'] ?? result['identity_verified'],
      );
      final detected = _asBool(
        result['faceDetected'] ?? result['face_detected'],
      );
      setState(() {
        _selfieHasFace = verified;
        _facesCount = _asInt(result['facesCount'] ?? result['faces_count']);
        _faceConfidence = _asDouble(
          result['faceConfidence'] ?? result['face_confidence'],
        );
        _qualityBrightness = _asDouble(
          quality['brightness'] ?? result['quality_brightness'],
        );
        _qualitySharpness = _asDouble(
          quality['sharpness'] ?? result['quality_sharpness'],
        );
        _poseYaw = _asDouble(pose['yaw'] ?? result['pose_yaw']);
        _posePitch = _asDouble(pose['pitch'] ?? result['pose_pitch']);
        _poseRoll = _asDouble(pose['roll'] ?? result['pose_roll']);
        _faceOccluded = _asNullableBool(
          result['faceOccluded'] ?? result['face_occluded'],
        );
        _biometricImageSaved = _asBool(
          result['biometricImageSaved'] ??
              result['biometric_image_saved'] ??
              true,
        );
        _biometricCapturedAt = DateTime.now().toIso8601String();
        _biometricProvider =
            (result['biometricProvider'] ??
                    result['biometric_provider'] ??
                    'aws_rekognition')
                .toString();
        _biometricTemplateType =
            (result['biometricTemplateType'] ??
                    result['biometric_template_type'] ??
                    'selfie-photo')
                .toString();
        _identityVerificationStatus =
            (result['identityVerificationStatus'] ??
                    result['identity_verification_status'] ??
                    (verified ? 'approved' : 'rejected'))
                .toString();
        _identityVerificationMessage =
            (result['message'] ??
                    (verified
                        ? 'Rostro validado correctamente.'
                        : 'La selfie fue analizada, pero no quedo aprobada.'))
                .toString();
        _selfieMessage =
            detected
                ? _identityVerificationMessage
                : 'No se detecto un rostro valido. Captura una nueva selfie.';
      });
    } on ApiException catch (error) {
      setState(() {
        _selfieHasFace = false;
        _identityVerificationStatus = 'rejected';
        _identityVerificationMessage = error.message;
        _selfieMessage = '${error.message} Captura una nueva selfie.';
      });
    } finally {
      if (mounted) {
        setState(() => _validatingSelfie = false);
      }
    }
  }

  Future<void> _submit() async {
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
      qualityBrightness: _qualityBrightness,
      qualitySharpness: _qualitySharpness,
      poseYaw: _poseYaw,
      posePitch: _posePitch,
      poseRoll: _poseRoll,
      faceOccluded: _faceOccluded,
      biometricImageSaved: _biometricImageSaved,
      biometricCapturedAt: _biometricCapturedAt,
      biometricProvider: _biometricProvider,
      biometricTemplateType: _biometricTemplateType,
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
      return;
    }

    final auth = context.read<AuthProvider>();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => MarketplaceHomeScreen(role: auth.role)),
      (route) => false,
    );
  }

  void _continueToAccess() {
    if (!_formKey.currentState!.validate()) return;
    if (_ineFront == null || _ineBack == null) {
      _showMessage('Sube frente y reverso de la INE.');
      return;
    }
    if (_selfie == null || !_selfieHasFace) {
      _showMessage(
        _identityVerificationMessage.isNotEmpty
            ? _identityVerificationMessage
            : 'Valida la selfie biometrica antes de continuar.',
      );
      return;
    }
    setState(() => _currentStep = 1);
  }

  void _generatePassword() {
    const alphabet =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$%*';
    final random = Random.secure();
    final password =
        List.generate(
          14,
          (_) => alphabet[random.nextInt(alphabet.length)],
        ).join();
    setState(() {
      _passwordController.text = password;
      _passwordConfirmationController.text = password;
      _passwordVisible = true;
      _passwordConfirmationVisible = true;
    });
    _showMessage('Contrasena segura generada. Puedes editarla.');
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
              const SizedBox(height: 18),
              _RegistrationProgress(currentStep: _currentStep),
              const SizedBox(height: 22),
              if (_currentStep == 0) ..._profileStep(),
              if (_currentStep == 1) ..._accessStep(),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (_currentStep > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            auth.isLoading
                                ? null
                                : () => setState(() => _currentStep = 0),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                        child: const Text('Regresar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          auth.isLoading
                              ? null
                              : (_currentStep == 0
                                  ? _continueToAccess
                                  : () {
                                    if (_formKey.currentState!.validate()) {
                                      _submit();
                                    }
                                  }),
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
                              : Text(
                                _currentStep == 0
                                    ? 'Continuar'
                                    : 'Crear cuenta',
                              ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _profileStep() {
    return [
      const _SectionLabel(
        icon: Icons.person_pin_rounded,
        title: 'Datos del usuario',
      ),
      const _HintText(
        'Completa tus datos, escanea la INE y valida la selfie antes de continuar.',
      ),
      _field(_nameController, 'Nombre completo'),
      _field(_phoneController, 'Telefono', keyboard: TextInputType.phone),
      _field(_birthDateController, 'Fecha de nacimiento', hint: 'AAAA-MM-DD'),
      _field(_nationalityController, 'Nacionalidad'),
      _field(_baseController, 'Ciudad/base', requiredField: false),
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
      if (_documentScanMessage.isNotEmpty) _HintText(_documentScanMessage),
      const SizedBox(height: 10),
      _FileButton(
        title: 'INE reverso',
        value: _ineBack?.path.split(Platform.pathSeparator).last,
        onTap: _pickIneBack,
      ),
      if (_ineFront != null && _ineBack != null) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _scanningDocument ? null : _scanIneLocally,
          icon: const Icon(Icons.document_scanner_rounded),
          label: const Text('Reescanear INE'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: const Color(0xFF0E2338),
            side: const BorderSide(color: Color(0xFFE0B86E)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
      const SizedBox(height: 10),
      _field(_documentTypeController, 'Identificacion'),
      _field(_documentNumberController, 'Numero de documento'),
      _field(
        _documentIssueDateController,
        'Fecha de emision',
        hint: 'AAAA-MM-DD',
        requiredField: false,
      ),
      _field(
        _documentExpirationController,
        'Vigencia del documento',
        hint: 'AAAA-MM-DD',
        onChanged:
            () =>
                _documentStatusController.text = _documentStatus(
                  _documentExpirationController.text,
                ),
      ),
      _field(
        _documentStatusController,
        'Estado del documento',
        requiredField: false,
      ),
      _field(_ineCurpController, 'CURP', requiredField: false),
      _field(_ineCicController, 'CIC', requiredField: false),
      _field(_ineOcrController, 'OCR', requiredField: false),
      const SizedBox(height: 14),
      const _SectionLabel(
        icon: Icons.verified_user_rounded,
        title: 'Validacion biometrica',
      ),
      _FileButton(
        title:
            _selfie == null
                ? 'Abrir camara y capturar selfie'
                : 'Repetir selfie',
        value: _selfie?.path.split(Platform.pathSeparator).last,
        loading: _validatingSelfie,
        onTap: _captureSelfie,
      ),
      if (_selfieMessage.isNotEmpty) _HintText(_selfieMessage),
      if (_selfie != null)
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:
                _selfieHasFace
                    ? const Color(0xFFEAF7EF)
                    : const Color(0xFFFFF3E8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                _selfieHasFace ? Icons.verified_rounded : Icons.pending_rounded,
                color:
                    _selfieHasFace
                        ? const Color(0xFF237A49)
                        : const Color(0xFF9A5A16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _selfieHasFace
                      ? 'Aprobado por backend. Confianza: ${_faceConfidence?.toStringAsFixed(1) ?? '-'}%'
                      : 'Validacion pendiente o rechazada.',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _accessStep() {
    return [
      const _SectionLabel(
        icon: Icons.lock_outline_rounded,
        title: 'Correo / Contrasena',
      ),
      _field(_emailController, 'Correo', keyboard: TextInputType.emailAddress),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _generatePassword,
          icon: const Icon(Icons.password_rounded),
          label: const Text('Generar contrasena'),
        ),
      ),
      _field(
        _passwordController,
        'Contrasena',
        obscure: !_passwordVisible,
        minLength: 8,
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Mostrar contrasena'),
        value: _passwordVisible,
        onChanged: (value) => setState(() => _passwordVisible = value),
      ),
      _field(
        _passwordConfirmationController,
        'Confirmar contrasena',
        obscure: !_passwordConfirmationVisible,
        minLength: 8,
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Mostrar confirmacion'),
        value: _passwordConfirmationVisible,
        onChanged:
            (value) => setState(() => _passwordConfirmationVisible = value),
      ),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF1F7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Al terminar tendras acceso inmediato a una cotizacion gratis y despues podras activar la membresia mensual de USD \$115.',
          style: TextStyle(height: 1.4, fontWeight: FontWeight.w700),
        ),
      ),
    ];
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    bool obscure = false,
    int minLength = 1,
    bool requiredField = true,
    TextInputType? keyboard,
    VoidCallback? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        onChanged: (_) => onChanged?.call(),
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

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    return ['1', 'true', 'yes'].contains(value?.toString().toLowerCase());
  }

  bool? _asNullableBool(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    return _asBool(value);
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  void _setIfPresent(TextEditingController controller, dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) controller.text = text;
  }
}

enum _DocumentImageSource { camera, files }

class _RegistrationProgress extends StatelessWidget {
  const _RegistrationProgress({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const labels = ['Perfil / Biometria', 'Correo / Contrasena'];
    return Row(
      children: List.generate(labels.length, (index) {
        final active = index <= currentStep;
        return Expanded(
          child: Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor:
                    active ? const Color(0xFFE0B86E) : const Color(0xFFD9E1E8),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Color(0xFF07121D),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  labels[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color:
                        active
                            ? const Color(0xFF0E2338)
                            : const Color(0xFF7A8792),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
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
