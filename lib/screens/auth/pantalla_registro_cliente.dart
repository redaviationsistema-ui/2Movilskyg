import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/cliente_api.dart';
import '../../providers/proveedor_autenticacion.dart';
import '../../services/servicio_ocr_registro.dart';
import '../cliente/tema_cliente.dart';
import '../marketplace/pantalla_inicio_mercado.dart';

class ClientRegisterScreen extends StatefulWidget {
  const ClientRegisterScreen({super.key});

  @override
  State<ClientRegisterScreen> createState() => _ClientRegisterScreenState();
}

class _ClientRegisterScreenState extends State<ClientRegisterScreen>
    with SingleTickerProviderStateMixin {
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
  late final AnimationController _entryController;

  File? _ineFront;
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
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6200),
    )..repeat();
    _recoverLostPickerData();
  }

  @override
  void dispose() {
    _entryController.dispose();
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
    final selected = await _selectDocumentImage('INE');
    if (selected == null) return;
    await _logFileDiagnostics('INE selected', selected);
    final optimized = await _optimizeImageForProcessing(selected);
    if (!mounted) return;

    await _logFileDiagnostics('INE optimized', optimized);

    setState(() {
      _ineFront = optimized;
      _documentScanMessage = 'Escaneando datos de la INE en el dispositivo...';
    });
    await _scanIneLocally();
  }

  Future<void> _recoverLostPickerData() async {
    if (!Platform.isAndroid) return;

    LostDataResponse response;
    try {
      response = await _picker.retrieveLostData();
    } on UnimplementedError {
      return;
    }

    if (!mounted || response.isEmpty) return;

    final recoveredFile = response.file;
    if (recoveredFile == null) {
      setState(() {
        _documentScanMessage =
            response.exception?.code != null
                ? 'No se pudo recuperar la foto de la INE.'
                : _documentScanMessage;
      });
      return;
    }

    final optimized = await _optimizeImageForProcessing(
      File(recoveredFile.path),
    );
    if (!mounted) return;
    await _logFileDiagnostics('INE recovered optimized', optimized);

    setState(() {
      _ineFront = optimized;
      _documentScanMessage =
          'Se recupero la foto de la INE despues de volver de la camara.';
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

    debugPrint(
      '[INE] Selector origen=$source platform=${Platform.operatingSystem} title=$title',
    );
    await _logIosMediaPermissions('before_select_$source');

    if (source == _DocumentImageSource.camera) {
      final hasPermission = await _ensureCameraPermission(
        contextLabel: 'capturar $title',
      );
      if (!hasPermission) return null;
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 96,
      );
      debugPrint('[INE] PATH IMAGEN: ${picked?.path}');
      return picked == null ? null : File(picked.path);
    }

    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final selectedPath = result?.files.single.path;
    debugPrint('[INE] PATH IMAGEN: $selectedPath');
    return selectedPath == null ? null : File(selectedPath);
  }

  Future<void> _scanIneLocally() async {
    final images = <File>[if (_ineFront != null) _ineFront!];
    if (images.isEmpty) return;

    debugPrint('[INE RESCAN] clearing controllers');
    setState(() {
      _clearIneControllersForRescan();
      _scanningDocument = true;
    });
    debugPrint(
      '[INE] Iniciando escaneo local platform=${Platform.operatingSystem} files=${images.map((file) => file.path).join(', ')}',
    );
    try {
      final result = await RegistrationOcrService.scanIne(images);
      debugPrint(
        '[INE] Resultado local: method=${result.method} rawTextLength=${result.rawText.length} fields=${result.fields}',
      );
      debugPrint('[INE] OCR TEXT: ${result.rawText}');
      debugPrint('[INE] DATOS EXTRAIDOS: ${result.fields}');
      _applyLocalIneResult(result);
    } catch (error) {
      debugPrint(
        '[INE] Error en escaneo local platform=${Platform.operatingSystem}: $error',
      );
    }

    if (!_hasUsefulIneData()) {
      debugPrint(
        '[INE] Escaneo local sin datos suficientes. Intentando backend.',
      );
      try {
        await _scanIneInBackend(images);
      } on ApiException catch (apiError) {
        if (!mounted) return;
        final normalizedError = _normalizeClientDocumentMessage(
          apiError.message,
        );
        setState(() {
          _applyIneFallback(images.first);
          _documentScanMessage =
              '$normalizedError La foto de la INE se guardo en este formulario; completa o corrige los datos manualmente.';
        });
        debugPrint(
          '[INE] Error backend platform=${Platform.operatingSystem} message=${apiError.message} payload=${jsonEncode(apiError.payload ?? const {})}',
        );
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _applyIneFallback(images.first);
          _documentScanMessage =
              'La foto de la INE se guardo en este formulario. No se pudo leer automaticamente, pero puedes completar los datos manualmente.';
        });
        debugPrint('[INE] Fallo backend sin detalle tipado: $error');
      }
    }

    if (mounted) setState(() => _scanningDocument = false);
  }

  void _applyLocalIneResult(RegistrationOcrResult result) {
    final data = _sanitizeIneData(result.fields);
    debugPrint('[INE] Aplicando resultado local method=${result.method}');
    setState(() {
      _ineScanRaw = result.rawText;
      _ineScanStatus =
          data.values.any((value) => value.trim().isNotEmpty)
              ? 'scanned'
              : 'partial';
      _applyAcceptedIneData(data);
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
    debugPrint('[INE APPLY] final accepted values=${jsonEncode(data)}');
    _logControllerValues('post_local_apply');
  }

  Future<void> _scanIneInBackend(List<File> images) async {
    for (final image in images) {
      await _logFileDiagnostics('INE backend upload', image);
      debugPrint(
        '[INE] Enviando imagen al backend: field=documento documentType=INE path=${image.path}',
      );
      final response = await _api.scanRegistrationDocument(
        document: image,
        documentType: 'INE',
      );
      debugPrint('[INE] OCR RESPONSE: ${jsonEncode(response)}');
      debugPrint('[INE] Respuesta backend completa: ${jsonEncode(response)}');
      _applyBackendIneResponse(response);
      if (_hasUsefulIneData()) {
        debugPrint(
          '[INE] Backend detecto datos utiles: document=${_documentNumberController.text} curp=${_ineCurpController.text} name=${_nameController.text} expiration=${_documentExpirationController.text}',
        );
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      if (!_hasUsefulIneData()) {
        _ineScanStatus = 'partial';
        _documentScanMessage =
            'Se intento leer la INE localmente y en backend, pero faltan datos claros. Puedes completar los campos manualmente.';
      }
    });
  }

  void _applyBackendIneResponse(Map<String, dynamic> response) {
    final data = _map(
      response['data'] ??
          response['document'] ??
          response['result'] ??
          response,
    );
    final rawText =
        (data['ocr_raw_text'] ??
                data['raw'] ??
                data['raw_text'] ??
                data['texto'] ??
                data['text'] ??
                '')
            .toString()
            .trim();
    final parsedRaw =
        rawText.isEmpty
            ? const <String, String>{}
            : RegistrationOcrService.parseIneText(rawText);
    debugPrint('[INE] OCR TEXT: $rawText');
    debugPrint('[INE] DATOS EXTRAIDOS: $parsedRaw');
    debugPrint(
      '[INE] Backend parse: rawTextLength=${rawText.length} parsedRaw=$parsedRaw',
    );
    final sanitized = _sanitizeIneData({
      if (rawText.isNotEmpty) 'raw': rawText,
      'name':
          data['name'] ??
          data['holder_name'] ??
          data['nombre'] ??
          data['nombre_completo'] ??
          parsedRaw['name'],
      'birth_date':
          data['birth_date'] ??
          data['fecha_nacimiento'] ??
          parsedRaw['birth_date'],
      'nationality':
          data['nationality'] ??
          data['nacionalidad'] ??
          parsedRaw['nationality'],
      'base':
          data['base'] ??
          data['city'] ??
          data['ciudad'] ??
          data['municipio'] ??
          parsedRaw['base'],
      'document_number':
          data['document_number'] ??
          data['numero_documento'] ??
          data['numero'] ??
          data['clave_elector'] ??
          parsedRaw['document_number'],
      'document_issue_date':
          data['document_issue_date'] ??
          data['issue_date'] ??
          data['fecha_emision'],
      'document_expiration':
          data['document_expiration'] ??
          data['expiration_date'] ??
          data['fecha_vencimiento'] ??
          data['vigencia'] ??
          parsedRaw['document_expiration'],
      'curp': data['curp'] ?? parsedRaw['curp'],
      'cic': data['cic'] ?? parsedRaw['cic'],
      'ocr':
          data['ocr'] ??
          data['ocr_number'] ??
          data['identificador_ocr'] ??
          parsedRaw['ocr'],
      'address': data['address'] ?? data['domicilio'] ?? parsedRaw['address'],
      'domicilio':
          data['domicilio'] ?? data['address'] ?? parsedRaw['domicilio'],
    });

    setState(() {
      if (rawText.isNotEmpty) {
        _ineScanRaw = rawText;
      }
      _applyAcceptedIneData(sanitized);
      _documentStatusController.text = _documentStatus(
        _documentExpirationController.text,
      );
      _ineScanStatus = _hasUsefulIneData() ? 'scanned' : 'partial';
      _documentScanMessage =
          _hasUsefulIneData()
              ? 'Escaneo de INE completado. Revisa los datos detectados antes de continuar.'
              : 'Se leyo parcialmente la INE. Completa los campos faltantes manualmente.';
    });
    debugPrint('[INE APPLY] final accepted values=${jsonEncode(sanitized)}');
    _logControllerValues('post_backend_apply');
    debugPrint(
      '[INE] Estado final tras backend: status=$_ineScanStatus document=${_documentNumberController.text} curp=${_ineCurpController.text} cic=${_ineCicController.text} ocr=${_ineOcrController.text} name=${_nameController.text} expiration=${_documentExpirationController.text}',
    );
  }

  void _applyIneFallback(File document) {
    _ineScanStatus = 'pending_manual_review';
    _ineScanRaw = '';
    if (_documentTypeController.text.trim().isEmpty) {
      _documentTypeController.text = 'INE';
    }
    final fileName = document.path.split(Platform.pathSeparator).last;
    if (_documentNumberController.text.trim().isEmpty) {
      final normalizedName = fileName.toUpperCase();
      final inferred = RegExp(r'\b[A-Z0-9]{8,20}\b')
          .allMatches(normalizedName)
          .map((match) {
            return match.group(0) ?? '';
          })
          .firstWhere((value) => value.length >= 10, orElse: () => '');
      if (inferred.isNotEmpty) {
        _documentNumberController.text = inferred;
      }
    }
    debugPrint(
      '[INE] Fallback manual aplicado: file=${document.path} inferredDocument=${_documentNumberController.text}',
    );
  }

  bool _hasUsefulIneData() {
    return _documentNumberController.text.isNotEmpty ||
        _ineCurpController.text.isNotEmpty ||
        _nameController.text.isNotEmpty ||
        _documentExpirationController.text.isNotEmpty;
  }

  Future<void> _captureSelfie() async {
    final hasPermission = await _ensureCameraPermission(
      contextLabel: 'capturar la selfie',
    );
    if (!hasPermission) return;
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 88,
    );
    if (picked == null) return;
    final optimizedSelfie = await _optimizeImageForProcessing(
      File(picked.path),
    );
    if (!mounted) return;

    setState(() {
      _selfie = optimizedSelfie;
      _validatingSelfie = true;
      _selfieHasFace = false;
      _selfieMessage = 'Selfie capturada. Validando rostro en ...';
    });

    try {
      final result = await _api.validateBiometricSelfie(_selfie!);
      if (!mounted) return;
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
      if (!mounted) return;
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

  Future<File> _optimizeImageForProcessing(File source) async {
    try {
      await _logFileDiagnostics('Image before optimization', source);
      final bytes = await source.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return source;

      const maxDimension = 1600;
      final resized =
          decoded.width > maxDimension || decoded.height > maxDimension
              ? img.copyResize(
                decoded,
                width: decoded.width >= decoded.height ? maxDimension : null,
                height: decoded.height > decoded.width ? maxDimension : null,
                interpolation: img.Interpolation.average,
              )
              : decoded;

      final output = img.encodeJpg(resized, quality: 85);
      final tempDir = await _processingDirectory();
      final fileName =
          '${path.basenameWithoutExtension(source.path)}_${DateTime.now().millisecondsSinceEpoch}_optimized.jpg';
      final optimizedFile = File(path.join(tempDir.path, fileName));
      await optimizedFile.writeAsBytes(output, flush: true);
      await _logFileDiagnostics('Image after optimization', optimizedFile);
      return optimizedFile;
    } catch (_) {
      return source;
    }
  }

  Future<void> _submit() async {
    if (_passwordController.text != _passwordConfirmationController.text) {
      _showMessage('Las contraseñas no coinciden.');
      return;
    }

    if (_ineFront == null) {
      _showMessage('Sube la INE.');
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
      ineBack: null,
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
    if (_ineFront == null) {
      _showMessage('Sube la INE.');
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
    _showMessage('Contraseña segura generada. Puedes editarla.');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final colors = context.appColors;
    final theme = Theme.of(context);
    final palette = context.clientPalette;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final checklist = _registrationChecklist();

    return Scaffold(
      backgroundColor: colors.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.background,
              Color.lerp(colors.background, colors.primary, 0.18) ??
                  colors.background,
              Color.lerp(colors.surfaceCard, Colors.white, 0.10) ??
                  colors.surfaceCard,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _entryController,
                builder:
                    (context, _) => CustomPaint(
                      painter: _RegisterRoutePainter(
                        progress: _entryController.value,
                        primary: colors.primary,
                        accent: colors.secondary,
                        isDark: context.isDarkMode,
                      ),
                    ),
              ),
            ),
            SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, 24 + bottomInset),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Volver',
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: palette.surface,
                            foregroundColor: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Crear cuenta cliente',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ClientRegisterHeroV2(
                      currentStep: _currentStep,
                      checklist: checklist,
                    ),
                    const SizedBox(height: 14),
                    _RegistrationProgressV2(
                      currentStep: _currentStep,
                      checklist: checklist,
                    ),
                    const SizedBox(height: 14),
                    _RegisterTrustStrip(
                      ineReady: _ineFront != null,
                      selfieReady: _selfieHasFace,
                      accessReady:
                          _emailController.text.trim().isNotEmpty &&
                          _passwordController.text.length >= 8,
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder:
                          (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.04, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                      child: _RegisterStepSurface(
                        key: ValueKey(_currentStep),
                        title:
                            _currentStep == 0
                                ? 'Identidad sin vueltas'
                                : 'Acceso seguro',
                        subtitle:
                            _currentStep == 0
                                ? 'INE, datos personales y selfie en un flujo guiado.'
                                : 'Crea tus credenciales para entrar a tu cabina privada.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_currentStep == 0) ..._profileStep(),
                            if (_currentStep == 1) ..._accessStep(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (_currentStep > 0) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  auth.isLoading
                                      ? null
                                      : () => setState(() => _currentStep = 0),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                                foregroundColor: palette.textPrimary,
                                side: BorderSide(color: palette.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              icon: const Icon(Icons.arrow_back_rounded),
                              label: const Text('Regresar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: FilledButton.icon(
                            onPressed:
                                auth.isLoading
                                    ? null
                                    : (_currentStep == 0
                                        ? _continueToAccess
                                        : () {
                                          if (_formKey.currentState!
                                              .validate()) {
                                            _submit();
                                          }
                                        }),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              backgroundColor: colors.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon:
                                auth.isLoading
                                    ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.colorScheme.onPrimary,
                                      ),
                                    )
                                    : Icon(
                                      _currentStep == 0
                                          ? Icons.arrow_forward_rounded
                                          : Icons.rocket_launch_rounded,
                                    ),
                            label: Text(
                              _currentStep == 0
                                  ? 'Continuar'
                                  : 'Entrar a la app',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_RegisterChecklistItem> _registrationChecklist() {
    return [
      _RegisterChecklistItem(
        icon: Icons.badge_rounded,
        label: 'INE',
        ready: _ineFront != null,
      ),
      _RegisterChecklistItem(
        icon: Icons.face_retouching_natural_rounded,
        label: 'Selfie',
        ready: _selfieHasFace,
      ),
      _RegisterChecklistItem(
        icon: Icons.person_rounded,
        label: 'Datos',
        ready:
            _nameController.text.trim().isNotEmpty &&
            _phoneController.text.trim().isNotEmpty &&
            _birthDateController.text.trim().isNotEmpty,
      ),
      _RegisterChecklistItem(
        icon: Icons.lock_rounded,
        label: 'Acceso',
        ready:
            _emailController.text.trim().isNotEmpty &&
            _passwordController.text.length >= 8 &&
            _passwordController.text == _passwordConfirmationController.text,
      ),
    ];
  }

  List<Widget> _profileStep() {
    final palette = context.clientPalette;
    final theme = Theme.of(context);
    return [
      const _SectionLabel(
        icon: Icons.person_pin_rounded,
        title: 'Datos del usuario',
      ),
      const _HintText(
        'Completa tus datos, escanea la INE y valida la selfie antes de continuar.',
      ),
      const SizedBox(height: 14),
      const _SectionLabel(
        icon: Icons.contact_mail_rounded,
        title: 'Identificacion oficial',
      ),
      _FileButton(
        title: 'ESCANEA TU INE ',
        value: _ineFront == null ? null : _ineFileLabel(),
        loading: _scanningDocument,
        onTap: _pickIneFront,
      ),
      if (_documentScanMessage.isNotEmpty) _HintText(_documentScanMessage),
      if (_ineFront != null) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _scanningDocument ? null : _scanIneLocally,
          icon: const Icon(Icons.document_scanner_rounded),
          label: const Text('Reescanear INE'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: palette.textPrimary,
            side: BorderSide(color: palette.accentBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
      const SizedBox(height: 10),

      _field(_nameController, 'Nombre completo'),
      _field(_phoneController, 'Telefono', keyboard: TextInputType.phone),
      _field(_birthDateController, 'Fecha de nacimiento', hint: 'AAAA-MM-DD'),
      _field(_nationalityController, 'Nacionalidad'),
      _field(_baseController, 'Ciudad/base', requiredField: false),

      const SizedBox(height: 10),
      _field(_documentTypeController, 'Identificacion'),
      _field(_documentNumberController, 'Numero de documento'),
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
        value: _selfie == null ? null : _selfieFileLabel(),
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
                    ? theme.colorScheme.secondary.withValues(alpha: 0.12)
                    : theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  _selfieHasFace
                      ? palette.accentBorder
                      : theme.colorScheme.error.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _selfieHasFace ? Icons.verified_rounded : Icons.pending_rounded,
                color:
                    _selfieHasFace ? palette.accent : theme.colorScheme.error,
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
    final colors = context.appColors;
    return [
      const _SectionLabel(
        icon: Icons.lock_outline_rounded,
        title: 'Correo / Contraseña',
      ),
      _field(_emailController, 'Correo', keyboard: TextInputType.emailAddress),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _generatePassword,
          icon: const Icon(Icons.password_rounded),
          label: const Text('Generar contraseña'),
        ),
      ),
      _field(
        _passwordController,
        'Contraseña',
        obscure: !_passwordVisible,
        minLength: 8,
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Mostrar contraseña'),
        value: _passwordVisible,
        onChanged: (value) => setState(() => _passwordVisible = value),
      ),
      _field(
        _passwordConfirmationController,
        'Confirmar contraseña',
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
          color:
              Color.lerp(colors.surfaceCard, colors.background, 0.20) ??
              colors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Text(
          'Al terminar tendras acceso inmediato a una cotizacion gratis y despues podras activar la membresia mensual de USD \$115.',
          style: TextStyle(
            height: 1.4,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
    final colors = context.appColors;
    final lower = message.toLowerCase();
    final isError =
        lower.contains('no ') ||
        lower.contains('revisa') ||
        lower.contains('sube') ||
        lower.contains('valida') ||
        lower.contains('debe');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
          backgroundColor:
              isError
                  ? Theme.of(context).colorScheme.error
                  : colors.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_rounded,
                color:
                    isError
                        ? Theme.of(context).colorScheme.onError
                        : colors.secondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color:
                        isError
                            ? Theme.of(context).colorScheme.onError
                            : colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
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

  void _clearIneControllersForRescan() {
    for (final controller in [
      _nameController,
      _birthDateController,
      _nationalityController,
      _baseController,
      _documentNumberController,
      _documentIssueDateController,
      _documentExpirationController,
      _documentStatusController,
      _ineCurpController,
      _ineCicController,
      _ineOcrController,
    ]) {
      controller.clear();
    }
    _ineScanRaw = '';
    _ineScanStatus = '';
  }

  void _applyAcceptedIneData(Map<String, String> data) {
    _setIfPresent(_nameController, data['name']);
    _setIfPresent(_birthDateController, data['birth_date']);
    _setIfPresent(_nationalityController, data['nationality']);
    _setIfPresent(_baseController, data['base']);
    _setIfPresent(_documentNumberController, data['document_number']);
    _setIfPresent(_documentIssueDateController, data['document_issue_date']);
    _setIfPresent(_documentExpirationController, data['document_expiration']);
    _setIfPresent(_ineCurpController, data['curp']);
    _setIfPresent(_ineCicController, data['cic']);
    _setIfPresent(_ineOcrController, data['ocr']);
  }

  Map<String, String> _sanitizeIneData(Map<String, dynamic> raw) {
    final data = <String, String>{
      for (final entry in raw.entries)
        entry.key: entry.value?.toString().trim() ?? '',
    };
    final sanitized = <String, String>{};
    final validCurp = _validatedCurp(data['curp'] ?? '');
    final validBirthDate = _validatedBirthDate(data['birth_date'] ?? '');
    final validExpiration = _validatedExpiration(
      data['document_expiration'] ?? '',
      birthDate: validBirthDate,
    );
    final validName = _validatedName(data['name'] ?? '');
    final validBase = _validatedBase(data['base'] ?? '');
    final validDocumentNumber = _validatedDocumentNumber(
      data['document_number'] ?? '',
      curp: validCurp,
    );
    final validCic = _validatedCic(
      data['cic'] ?? '',
      birthDate: validBirthDate,
    );
    final validOcr = _validatedOcr(
      data['ocr'] ?? '',
      birthDate: validBirthDate,
    );

    if (validName.isNotEmpty) sanitized['name'] = validName;
    if (validBirthDate.isNotEmpty) sanitized['birth_date'] = validBirthDate;
    if (validBase.isNotEmpty) sanitized['base'] = validBase;
    if (validDocumentNumber.isNotEmpty) {
      sanitized['document_number'] = validDocumentNumber;
    }
    if (validExpiration.isNotEmpty) {
      sanitized['document_expiration'] = validExpiration;
    }
    if (validCurp.isNotEmpty) sanitized['curp'] = validCurp;
    if (validCic.isNotEmpty) sanitized['cic'] = validCic;
    if (validOcr.isNotEmpty) sanitized['ocr'] = validOcr;

    final nationality = data['nationality'] ?? '';
    if (nationality.isNotEmpty && nationality.toLowerCase().contains('mex')) {
      sanitized['nationality'] = 'Mexicana';
    }

    final issueDate = data['document_issue_date'] ?? '';
    if (issueDate.isNotEmpty &&
        DateTime.tryParse(issueDate) != null &&
        issueDate != validBirthDate) {
      sanitized['document_issue_date'] = issueDate;
    }

    return sanitized;
  }

  String _validatedCurp(String value) {
    final text = value.trim().toUpperCase();
    if (text.isEmpty) return '';
    if (!RegistrationOcrService.isValidCurp(text)) {
      debugPrint('[INE VALIDATION] rejected curp=$text reason=invalid_curp');
      return '';
    }
    return text;
  }

  String _validatedDocumentNumber(String value, {required String curp}) {
    final text = value.trim().toUpperCase();
    if (text.isEmpty) return '';
    if (!RegistrationOcrService.isValidElectorKey(text)) {
      debugPrint(
        '[INE VALIDATION] rejected document_number=$text reason=invalid_elector_key',
      );
      return '';
    }
    if (curp.isNotEmpty && text == curp) {
      debugPrint(
        '[INE VALIDATION] rejected document_number=$text reason=same_as_curp',
      );
      return '';
    }
    return text;
  }

  String _validatedBirthDate(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';
    if (DateTime.tryParse(text) == null) {
      debugPrint(
        '[INE VALIDATION] rejected birth_date=$text reason=invalid_date',
      );
      return '';
    }
    return text;
  }

  String _validatedExpiration(String value, {required String birthDate}) {
    final text = value.trim();
    if (text.isEmpty) return '';
    final parsed = DateTime.tryParse(text);
    if (parsed == null) {
      debugPrint(
        '[INE VALIDATION] rejected expiration=$text reason=invalid_date',
      );
      return '';
    }
    if (birthDate.isNotEmpty && text == birthDate) {
      debugPrint(
        '[INE VALIDATION] rejected expiration=$text reason=matches_birth_date',
      );
      return '';
    }
    if (parsed.year < DateTime.now().year - 15) {
      debugPrint('[INE VALIDATION] rejected expiration=$text reason=too_old');
      return '';
    }
    return text;
  }

  String _validatedName(String value) {
    final text = value.trim().toUpperCase();
    if (text.isEmpty) return '';
    if (RegExp(r'\d').hasMatch(text) ||
        _containsAddressKeyword(text) ||
        RegExp(
          r'\b(MEX|MEX\.|DOMICILIO|SECCI[O0]N|VIGENCIA|FECHA|CURP|CLAVE|LERMA)\b',
        ).hasMatch(text) ||
        !RegExp(r'^[A-Z ,.]+$').hasMatch(text)) {
      debugPrint('[INE VALIDATION] rejected name=$text reason=invalid_name');
      return '';
    }
    return text;
  }

  String _validatedBase(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';
    final upper = text.toUpperCase();
    if (RegExp(r'[0-9/\\]').hasMatch(upper) ||
        RegExp(
          r'\b(CURP|OCR|CIC|CLAVE|VIGENCIA|SECCI[O0]N|DOMICILIO)\b',
        ).hasMatch(upper) ||
        !RegExp(r'^[A-Z .,-]{4,40}$').hasMatch(upper)) {
      debugPrint('[INE VALIDATION] rejected base=$text reason=invalid_base');
      return '';
    }
    if (RegExp(r'\bMEX\.?\b').hasMatch(upper) &&
        !RegExp(r'^[A-Z]+(?: [A-Z]+)*, [A-Z]{2,4}\.?$').hasMatch(upper)) {
      debugPrint('[INE VALIDATION] rejected base=$text reason=too_generic');
      return '';
    }
    return text;
  }

  bool _containsAddressKeyword(String value) {
    return RegExp(
      r'\b(AV|AVENIDA|CALLE|COL|COLONIA|CP|C\.P\.|NUM|NO|NRO|MANZANA|LOTE|DOMICILIO|INDEPENDENCIA)\b',
    ).hasMatch(value);
  }

  String _validatedCic(String value, {required String birthDate}) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    if (digits.length < 8 || digits.length > 12) {
      debugPrint('[INE VALIDATION] rejected cic=$digits reason=length');
      return '';
    }
    final birthDigits = _birthDateDigitsDmy(birthDate);
    if (birthDigits.isNotEmpty && digits == birthDigits) {
      debugPrint('[INE VALIDATION] rejected cic=$digits reason=matches_birth');
      return '';
    }
    return digits;
  }

  String _validatedOcr(String value, {required String birthDate}) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    if (digits.length < 10 || digits.length > 14) {
      debugPrint('[INE VALIDATION] rejected ocr=$digits reason=length');
      return '';
    }
    final birthDigits = _birthDateDigitsDmy(birthDate);
    if (birthDigits.isNotEmpty && digits.startsWith(birthDigits)) {
      debugPrint(
        '[INE VALIDATION] rejected ocr=$digits reason=starts_with_birth',
      );
      return '';
    }
    return digits;
  }

  String _birthDateDigitsDmy(String isoDate) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(isoDate);
    if (match == null) return '';
    return '${match.group(3)}${match.group(2)}${match.group(1)}';
  }

  void _setIfPresent(TextEditingController controller, dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      debugPrint(
        '[INE] Controller update target=${_controllerLabel(controller)} old="${controller.text}" new="$text"',
      );
      controller.text = text;
      return;
    }
    debugPrint(
      '[INE] Controller skip target=${_controllerLabel(controller)} value="$text"',
    );
  }

  String _controllerLabel(TextEditingController controller) {
    if (identical(controller, _nameController)) return 'name';
    if (identical(controller, _birthDateController)) return 'birth_date';
    if (identical(controller, _nationalityController)) return 'nationality';
    if (identical(controller, _baseController)) return 'base';
    if (identical(controller, _documentNumberController)) {
      return 'document_number';
    }
    if (identical(controller, _documentIssueDateController)) {
      return 'document_issue_date';
    }
    if (identical(controller, _documentExpirationController)) {
      return 'document_expiration';
    }
    if (identical(controller, _documentStatusController)) {
      return 'document_status';
    }
    if (identical(controller, _ineCurpController)) return 'ine_curp';
    if (identical(controller, _ineCicController)) return 'ine_cic';
    if (identical(controller, _ineOcrController)) return 'ine_ocr';
    return 'unknown';
  }

  void _logControllerValues(String stage) {
    debugPrint(
      '[INE] Controllers $stage: '
      'name="${_nameController.text}", '
      'birth_date="${_birthDateController.text}", '
      'nationality="${_nationalityController.text}", '
      'base="${_baseController.text}", '
      'document_number="${_documentNumberController.text}", '
      'document_issue_date="${_documentIssueDateController.text}", '
      'document_expiration="${_documentExpirationController.text}", '
      'document_status="${_documentStatusController.text}", '
      'curp="${_ineCurpController.text}", '
      'cic="${_ineCicController.text}", '
      'ocr="${_ineOcrController.text}"',
    );
  }

  Future<void> _logIosMediaPermissions(String stage) async {
    if (!Platform.isIOS) return;
    try {
      final camera = await Permission.camera.status;
      final photos = await Permission.photos.status;
      final photosAddOnly = await Permission.photosAddOnly.status;
      debugPrint(
        '[INE][iOS] Permisos $stage camera=$camera photos=$photos photosAddOnly=$photosAddOnly',
      );
    } catch (error) {
      debugPrint('[INE][iOS] Error consultando permisos $stage: $error');
    }
  }

  Future<bool> _ensureCameraPermission({required String contextLabel}) async {
    try {
      final status = await Permission.camera.request();
      if (status.isGranted) return true;

      if (!mounted) return false;

      final message =
          status.isPermanentlyDenied
              ? 'Activa el permiso de camara en Configuracion para $contextLabel.'
              : 'La app necesita permiso de camara para $contextLabel.';
      _showMessage(message);
      return false;
    } catch (error) {
      if (mounted) {
        _showMessage('No fue posible validar el permiso de camara: $error');
      }
      return false;
    }
  }

  Future<Directory> _processingDirectory() async {
    final directory = await getApplicationSupportDirectory();
    final processingDirectory = Directory(
      path.join(directory.path, 'registration_processing'),
    );
    if (!await processingDirectory.exists()) {
      await processingDirectory.create(recursive: true);
    }
    return processingDirectory;
  }

  Future<void> _logFileDiagnostics(String label, File file) async {
    try {
      final bytes = await file.length();
      debugPrint(
        '[INE] $label path=${file.path} name=${path.basename(file.path)} bytes=$bytes',
      );
    } catch (error) {
      debugPrint(
        '[INE] $label path=${file.path} name=${path.basename(file.path)} bytes=unavailable error=$error',
      );
    }
  }

  String _normalizeClientDocumentMessage(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return 'No fue posible procesar la INE.';

    return trimmed
        .replaceAll(RegExp('licencia', caseSensitive: false), 'INE')
        .replaceAll(RegExp('license', caseSensitive: false), 'INE');
  }

  String _ineFileLabel() {
    if (_ineFront == null) return '';
    if (_hasUsefulIneData()) return 'INE escaneada';
    if (_scanningDocument) return 'Procesando INE...';
    return 'INE cargada';
  }

  String _selfieFileLabel() {
    if (_selfie == null) return '';
    if (_validatingSelfie) return 'Validando selfie...';
    if (_selfieHasFace) return 'Selfie validada';
    return 'Selfie cargada';
  }
}

enum _DocumentImageSource { camera, files }

class _RegisterChecklistItem {
  const _RegisterChecklistItem({
    required this.icon,
    required this.label,
    required this.ready,
  });

  final IconData icon;
  final String label;
  final bool ready;
}

class _RegistrationProgressV2 extends StatelessWidget {
  const _RegistrationProgressV2({
    required this.currentStep,
    required this.checklist,
  });

  final int currentStep;
  final List<_RegisterChecklistItem> checklist;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final readyCount = checklist.where((item) => item.ready).length;
    final progress = checklist.isEmpty ? 0.0 : readyCount / checklist.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  currentStep == 0
                      ? 'Paso 1 de 2: identidad'
                      : 'Paso 2 de 2: acceso',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$readyCount/${checklist.length}',
                style: TextStyle(
                  color: palette.accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: palette.surfaceSoft,
              color: palette.accent,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                checklist
                    .map(
                      (item) => _ChecklistPillV2(
                        icon: item.icon,
                        label: item.label,
                        ready: item.ready,
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }
}

class _ChecklistPillV2 extends StatelessWidget {
  const _ChecklistPillV2({
    required this.icon,
    required this.label,
    required this.ready,
  });

  final IconData icon;
  final String label;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ready ? palette.accentSoft : palette.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: ready ? palette.accentBorder : palette.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ready ? Icons.check_circle_rounded : icon,
            size: 15,
            color:
                ready ? ClientThemeColors.textOnAccent : palette.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color:
                  ready ? ClientThemeColors.textOnAccent : palette.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterStepSurface extends StatelessWidget {
  const _RegisterStepSurface({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.accentSoft,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: ClientThemeColors.textOnAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: palette.textSecondary,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _RegisterTrustStrip extends StatelessWidget {
  const _RegisterTrustStrip({
    required this.ineReady,
    required this.selfieReady,
    required this.accessReady,
  });

  final bool ineReady;
  final bool selfieReady;
  final bool accessReady;

  @override
  Widget build(BuildContext context) {
    final items = [
      _TrustItem(
        icon: Icons.document_scanner_rounded,
        title: 'INE guiada',
        subtitle: ineReady ? 'Cargada' : 'Camara o archivo',
      ),
      _TrustItem(
        icon: Icons.face_rounded,
        title: 'Biometria',
        subtitle: selfieReady ? 'Validada' : 'Selfie segura',
      ),
      _TrustItem(
        icon: Icons.lock_outline_rounded,
        title: 'Acceso',
        subtitle: accessReady ? 'Listo' : 'Contrasena fuerte',
      ),
    ];

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder:
            (context, index) =>
                SizedBox(width: 168, child: _TrustTile(item: items[index])),
      ),
    );
  }
}

class _TrustItem {
  const _TrustItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class _TrustTile extends StatelessWidget {
  const _TrustTile({required this.item});

  final _TrustItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: palette.accent, size: 22),
          const SizedBox(height: 10),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientRegisterHeroV2 extends StatelessWidget {
  const _ClientRegisterHeroV2({
    required this.currentStep,
    required this.checklist,
  });

  final int currentStep;
  final List<_RegisterChecklistItem> checklist;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final readyCount = checklist.where((item) => item.ready).length;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
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
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: palette.headerGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: palette.accentBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: palette.surfaceStrong,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.accentBorder),
                  ),
                  child: Icon(
                    Icons.flight_takeoff_rounded,
                    color: palette.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    currentStep == 0 ? 'Tu pase a Red Sky' : 'Ultimo paso',
                    style: TextStyle(
                      color: palette.heroTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _HeroCounter(value: '$readyCount/${checklist.length}'),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Crea tu cabina privada',
              style: TextStyle(
                color: palette.heroTextPrimary,
                fontSize: 31,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Registro guiado, validacion de identidad y acceso listo para cotizar vuelos privados.',
              style: TextStyle(
                color: palette.heroTextSecondary,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCounter extends StatelessWidget {
  const _HeroCounter({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: ClientThemeColors.textOnAccent,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RegisterRoutePainter extends CustomPainter {
  const _RegisterRoutePainter({
    required this.progress,
    required this.primary,
    required this.accent,
    required this.isDark,
  });

  final double progress;
  final Color primary;
  final Color accent;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint =
        Paint()
          ..color = primary.withValues(alpha: isDark ? 0.14 : 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
    final accentPaint =
        Paint()
          ..color = accent.withValues(alpha: isDark ? 0.34 : 0.24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 5; i++) {
      final y = size.height * (0.12 + i * 0.18);
      final path =
          Path()
            ..moveTo(-20, y)
            ..cubicTo(
              size.width * 0.22,
              y - 36,
              size.width * 0.58,
              y + 42,
              size.width + 30,
              y - 18,
            );
      canvas.drawPath(path, basePaint);
    }

    final route =
        Path()
          ..moveTo(size.width * 0.08, size.height * 0.18)
          ..cubicTo(
            size.width * 0.26,
            size.height * 0.05,
            size.width * 0.68,
            size.height * 0.26,
            size.width * 0.92,
            size.height * 0.12,
          );
    canvas.drawPath(route, accentPaint);

    final metric = route.computeMetrics().first;
    final tangent = metric.getTangentForOffset(metric.length * progress);
    if (tangent == null) return;

    canvas.save();
    canvas.translate(tangent.position.dx, tangent.position.dy);
    canvas.rotate(tangent.angle);
    final planePaint = Paint()..color = accent.withValues(alpha: 0.88);
    final plane =
        Path()
          ..moveTo(10, 0)
          ..lineTo(-7, -5)
          ..lineTo(-3, 0)
          ..lineTo(-7, 5)
          ..close();
    canvas.drawPath(plane, planePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RegisterRoutePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primary != primary ||
        oldDelegate.accent != accent ||
        oldDelegate.isDark != isDark;
  }
}

class RegistrationProgressLegacy extends StatelessWidget {
  const RegistrationProgressLegacy({super.key, required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    const labels = ['Perfil / Biometría', 'Correo / Contraseña'];
    return Row(
      children: List.generate(labels.length, (index) {
        final active = index <= currentStep;
        return Expanded(
          child: Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: active ? palette.accent : palette.surfaceSoft,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: palette.textOnAccent,
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
                    color: active ? palette.textPrimary : palette.textSecondary,
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

class ClientRegisterHeroLegacy extends StatelessWidget {
  const ClientRegisterHeroLegacy({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
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
          gradient: LinearGradient(
            colors: palette.appGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: palette.accentBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 24,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.airline_seat_flat_angled_rounded,
                  color: palette.accent,
                ),
                const SizedBox(width: 10),
                Text(
                  'Acceso cliente',
                  style: TextStyle(
                    color: palette.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Cotizacion gratis y portal privado',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Completa perfil, identificacion y selfie para iniciar el flujo de reserva.',
              style: TextStyle(color: palette.textSecondary, height: 1.4),
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
    final palette = context.clientPalette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: palette.accent),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: palette.textPrimary,
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
    final palette = context.clientPalette;
    return OutlinedButton.icon(
      onPressed: loading ? null : onTap,
      icon:
          loading
              ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : const Icon(Icons.document_scanner_rounded),
      label: Text(value == null ? title : '$title: $value'),
      style: OutlinedButton.styleFrom(
        backgroundColor: palette.surface,
        foregroundColor: palette.textPrimary,
        minimumSize: const Size.fromHeight(52),
        alignment: Alignment.centerLeft,
        side: BorderSide(color: palette.accentBorder),
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
    final palette = context.clientPalette;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: palette.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
