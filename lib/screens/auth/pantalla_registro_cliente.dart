// ignore_for_file: unused_element, unused_element_parameter

import 'dart:ui';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'date_text_input_formatter.dart';
import 'nationality_options.dart';
import '../cliente/tema_cliente.dart';
import '../marketplace/pantalla_inicio_mercado.dart';

Map<String, Object> _optimizeImageBytesForProcessing(
  Map<String, Object> payload,
) {
  final bytes = payload['bytes'] as Uint8List;
  final maxDimension = payload['maxDimension'] as int;
  final quality = payload['quality'] as int;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return {'ok': false};
  }

  final resized =
      decoded.width > maxDimension || decoded.height > maxDimension
          ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? maxDimension : null,
            height: decoded.height > decoded.width ? maxDimension : null,
            interpolation: img.Interpolation.average,
          )
          : decoded;

  return {
    'ok': true,
    'bytes': Uint8List.fromList(img.encodeJpg(resized, quality: quality)),
  };
}

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
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _countryCodeController = TextEditingController(text: '+52');
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _nationalityController = TextEditingController(text: 'Mexicana');
  final _clientTypeController = TextEditingController(text: 'individual');
  final _companyNameController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _baseController = TextEditingController();
  final _documentTypeController = TextEditingController(text: 'INE');
  final _documentIssuingCountryController = TextEditingController(
    text: 'México',
  );
  final _documentNumberController = TextEditingController();
  final _ineCurpController = TextEditingController();
  final _ineCicController = TextEditingController();
  final _ineOcrController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  late final AnimationController _entryController;

  File? _ineFront;
  File? _ineBack;
  File? _registrationPdf;
  File? _selfie;
  String? _registrationIdentificationId;
  int _currentStep = 0;
  _IdentityDocumentMode? _documentMode;
  bool _scanningDocument = false;
  bool _processingDocumentImage = false;
  bool _validatingSelfie = false;
  bool _processingSelfie = false;
  bool _uploadingRegistrationPdf = false;
  bool _passwordVisible = false;
  bool _passwordConfirmationVisible = false;
  bool _acceptedTerms = false;
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
  String _submissionStatusMessage = '';

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6200),
    )..repeat();
    for (final controller in [
      _nameController,
      _lastNameController,
      _emailController,
      _countryCodeController,
      _phoneController,
      _birthDateController,
      _nationalityController,
      _clientTypeController,
      _companyNameController,
      _taxIdController,
      _baseController,
      _documentTypeController,
      _documentIssuingCountryController,
      _documentNumberController,
      _ineCurpController,
      _ineCicController,
      _ineOcrController,
      _passwordController,
      _passwordConfirmationController,
    ]) {
      controller.addListener(_refreshStepProgress);
    }
    _recoverLostPickerData();
  }

  @override
  void dispose() {
    _entryController.dispose();
    for (final controller in [
      _nameController,
      _lastNameController,
      _emailController,
      _countryCodeController,
      _phoneController,
      _birthDateController,
      _nationalityController,
      _clientTypeController,
      _companyNameController,
      _taxIdController,
      _baseController,
      _documentTypeController,
      _documentIssuingCountryController,
      _documentNumberController,
      _ineCurpController,
      _ineCicController,
      _ineOcrController,
      _passwordController,
      _passwordConfirmationController,
    ]) {
      controller.removeListener(_refreshStepProgress);
    }
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _countryCodeController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _nationalityController.dispose();
    _clientTypeController.dispose();
    _companyNameController.dispose();
    _taxIdController.dispose();
    _baseController.dispose();
    _documentTypeController.dispose();
    _documentIssuingCountryController.dispose();
    _documentNumberController.dispose();
    _ineCurpController.dispose();
    _ineCicController.dispose();
    _ineOcrController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  void _refreshStepProgress() {
    if (!mounted) return;
    setState(() {});
  }

  bool get _isDocumentBusy => _processingDocumentImage || _scanningDocument;

  bool get _isSelfieBusy => _processingSelfie || _validatingSelfie;

  bool get _isSelfieValidationConfirmed =>
      _selfieHasFace &&
      _biometricImageSaved &&
      _identityVerificationStatus.trim().toLowerCase() == 'approved';

  Future<void> _pickIneFront() async {
    if (_isDocumentBusy) return;
    _activateIdentityMode(_IdentityDocumentMode.ineScan);
    final selected = await _selectDocumentImage('INE');
    if (selected == null) {
      if (mounted) {
        _showMessage(
          'No se obtuvo una imagen desde la cámara. Intenta de nuevo o usa Subir archivo.',
        );
      }
      return;
    }
    await _logFileDiagnostics('INE selected', selected);
    final optimized = await _optimizeImageForProcessing(selected);
    if (!mounted) return;

    await _logFileDiagnostics('INE optimized', optimized);

    setState(() {
      _ineFront = optimized;
      _registrationPdf = null;
      _registrationIdentificationId = null;
      _documentTypeController.text = 'INE';
      _documentScanMessage = 'Escaneando datos de la INE en el dispositivo...';
    });
    await _scanIneLocally();
  }

  Future<void> _pickDocumentPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final selectedPath = result?.files.single.path;
    if (selectedPath == null || !mounted) return;
    setState(() {
      _documentMode = _IdentityDocumentMode.pdf;
      _registrationPdf = File(selectedPath);
      _registrationIdentificationId = null;
      _ineFront = null;
      _documentTypeController.text = 'INE';
      _ineScanRaw = '';
      _ineScanStatus = 'uploaded_pdf';
      _documentScanMessage =
          'PDF seleccionado. Completa o revisa tus datos y al finalizar lo guardaremos antes del registro.';
    });
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
      _documentMode = _IdentityDocumentMode.ineScan;
      _ineFront = optimized;
      _registrationPdf = null;
      _registrationIdentificationId = null;
      _documentScanMessage =
          'Se recupero la foto de la INE despues de volver de la camara.';
    });

    await _scanIneLocally();
  }

  void _onClientTypeChanged(String? value) {
    final normalized = (value ?? 'individual').trim();
    setState(() {
      _clientTypeController.text = normalized;
      if (normalized != 'company') {
        _companyNameController.clear();
        _taxIdController.clear();
      }
    });
  }

  void _onDocumentTypeChanged(String? value) {
    final normalized = (value ?? 'INE').trim();
    setState(() {
      _documentTypeController.text = normalized;
      _documentNumberController.clear();
      _ineCurpController.clear();
      _ineCicController.clear();
      _ineOcrController.clear();
      _ineScanRaw = '';
      _ineScanStatus = '';
      _registrationIdentificationId = null;
      _documentScanMessage = '';
      if (normalized == 'PASSPORT') {
        _documentIssuingCountryController.text =
            _documentIssuingCountryController.text.trim().isEmpty
                ? 'México'
                : _documentIssuingCountryController.text.trim();
        _ineBack = null;
      } else {
        _documentIssuingCountryController.text = 'México';
      }
    });
  }

  Future<void> _pickDocumentFrontFromCamera() async {
    await _pickDocumentImage(
      source: _DocumentImageSource.camera,
      backSide: false,
    );
  }

  Future<void> _pickDocumentFrontFromFiles() async {
    await _pickDocumentUpload(backSide: false);
  }

  Future<void> _pickDocumentBackFromCamera() async {
    await _pickDocumentImage(
      source: _DocumentImageSource.camera,
      backSide: true,
    );
  }

  Future<void> _pickDocumentBackFromFiles() async {
    await _pickDocumentUpload(backSide: true);
  }

  Future<void> _pickDocumentImage({
    required _DocumentImageSource source,
    required bool backSide,
  }) async {
    if (_isDocumentBusy) return;
    final sideLabel = backSide ? 'reverso del documento' : 'documento';
    File? selected;
    if (source == _DocumentImageSource.camera) {
      final hasPermission = await _ensureCameraPermission(
        contextLabel: 'capturar $sideLabel',
      );
      if (!hasPermission) return;
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 96,
      );
      if (picked == null) {
        if (mounted) {
          _showMessage(
            'La cámara no devolvió una imagen. Intenta nuevamente o usa Subir archivo.',
          );
        }
        return;
      }
      selected = File(picked.path);
    } else {
      final picked = await FilePicker.pickFiles(type: FileType.image);
      final selectedPath = picked?.files.single.path;
      if (selectedPath == null) return;
      selected = File(selectedPath);
    }
    final optimized = await _optimizeImageForProcessing(selected);
    if (!mounted) return;

    setState(() {
      _documentMode = _IdentityDocumentMode.ineScan;
      _registrationPdf = null;
      _registrationIdentificationId = null;
      if (backSide) {
        _ineBack = optimized;
        _documentScanMessage = 'Reverso del documento cargado.';
      } else {
        _ineFront = optimized;
        _documentScanMessage =
            _isIneDocument
                ? 'Escaneando datos de la INE en el dispositivo...'
                : 'Documento cargado. Completa o revisa los datos detectados.';
      }
    });

    if (!backSide && _isIneDocument) {
      await _scanIneLocally();
    }
  }

  Future<void> _pickDocumentUpload({required bool backSide}) async {
    if (_isDocumentBusy) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    final selectedPath = result?.files.single.path;
    if (selectedPath == null || !mounted) return;
    final selectedFile = File(selectedPath);
    final extension = path.extension(selectedPath).toLowerCase();
    final isPdf = extension == '.pdf';
    final resolvedFile =
        isPdf ? selectedFile : await _optimizeImageForProcessing(selectedFile);
    if (!mounted) return;

    setState(() {
      _registrationIdentificationId = null;
      if (isPdf) {
        _documentMode = _IdentityDocumentMode.pdf;
        _registrationPdf = resolvedFile;
        _ineFront = null;
        _ineBack = null;
        _documentScanMessage =
            'Archivo PDF cargado. Completa los datos del documento para continuar.';
      } else {
        _documentMode = _IdentityDocumentMode.ineScan;
        _registrationPdf = null;
        if (backSide) {
          _ineBack = resolvedFile;
          _documentScanMessage = 'Reverso del documento cargado.';
        } else {
          _ineFront = resolvedFile;
          _documentScanMessage =
              _isIneDocument
                  ? 'Escaneando datos de la INE en el dispositivo...'
                  : 'Documento cargado. Completa los datos del documento.';
        }
      }
    });

    if (!backSide && !isPdf && _isIneDocument) {
      await _scanIneLocally();
    }
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
      if (picked == null && mounted) {
        _showMessage(
          'La cámara no devolvió una imagen para $title. Intenta nuevamente o usa archivos.',
        );
      }
      return picked == null ? null : File(picked.path);
    }

    final result = await FilePicker.pickFiles(type: FileType.image);
    final selectedPath = result?.files.single.path;
    debugPrint('[INE] PATH IMAGEN: $selectedPath');
    return selectedPath == null ? null : File(selectedPath);
  }

  Future<void> _scanIneLocally() async {
    if (_scanningDocument) return;
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
      if (!mounted) return;
      debugPrint(
        '[INE] Resultado local: method=${result.method} rawTextLength=${result.rawText.length} fieldsCount=${result.fields.length}',
      );
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
      final detected = [
        if (_documentNumberController.text.isNotEmpty) 'documento',
        if (_ineCurpController.text.isNotEmpty) 'CURP',
        if (_nameController.text.isNotEmpty) 'nombre',
      ];
      _documentScanMessage =
          detected.isEmpty
              ? 'No se detectaron datos claros. Intenta con fotos derechas, completas y sin reflejos.'
              : 'Escaneo ${result.method} completado: ${detected.join(', ')}. Revisa los datos.';
    });
    debugPrint('[INE APPLY] final accepted keys=${data.keys.toList()}');
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
      debugPrint('[INE] OCR RESPONSE received keys=${response.keys.toList()}');
      _applyBackendIneResponse(response);
      if (_hasUsefulIneData()) {
        debugPrint(
          '[INE] Backend detecto datos utiles: document=${_documentNumberController.text} curp=${_ineCurpController.text} name=${_nameController.text}',
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
    debugPrint(
      '[INE] Backend parse: rawTextLength=${rawText.length} parsedFields=${parsedRaw.keys.toList()}',
    );
    final sanitized = _sanitizeIneData({
      if (rawText.isNotEmpty) 'raw': rawText,
      'name':
          parsedRaw['name'] ??
          data['name'] ??
          data['holder_name'] ??
          data['nombre'] ??
          data['nombre_completo'] ??
          data['full_name'],
      'last_name':
          parsedRaw['last_name'] ??
          data['last_name'] ??
          data['surname'] ??
          data['apellidos'] ??
          data['apellido'] ??
          data['paternal_surname'],
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
      _ineScanStatus = _hasUsefulIneData() ? 'scanned' : 'partial';
      _documentScanMessage =
          _hasUsefulIneData()
              ? 'Escaneo de INE completado. Revisa los datos detectados antes de continuar.'
              : 'Se leyo parcialmente la INE. Completa los campos faltantes manualmente.';
    });
    debugPrint('[INE APPLY] final accepted keys=${sanitized.keys.toList()}');
    _logControllerValues('post_backend_apply');
    debugPrint(
      '[INE] Estado final tras backend: status=$_ineScanStatus document=${_documentNumberController.text.isNotEmpty} curp=${_ineCurpController.text.isNotEmpty} cic=${_ineCicController.text.isNotEmpty} ocr=${_ineOcrController.text.isNotEmpty} name=${_nameController.text.isNotEmpty}',
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
        _nameController.text.isNotEmpty;
  }

  Future<void> _captureSelfie() async {
    if (_isSelfieBusy) return;
    setState(() {
      _processingSelfie = true;
      _selfieMessage = 'Abriendo camara para capturar selfie...';
    });
    final hasPermission = await _ensureCameraPermission(
      contextLabel: 'capturar la selfie',
    );
    if (!hasPermission) {
      if (mounted) {
        setState(() => _processingSelfie = false);
      }
      return;
    }
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 88,
    );
    if (picked == null) {
      if (mounted) {
        setState(() => _processingSelfie = false);
        _showMessage(
          'No se capturó la selfie. Intenta nuevamente con buena luz y el rostro centrado.',
        );
      }
      return;
    }
    final optimizedSelfie = await _optimizeImageForProcessing(
      File(picked.path),
      trackDocumentState: false,
    );
    if (!mounted) return;

    setState(() {
      _selfie = optimizedSelfie;
      _validatingSelfie = true;
      _selfieHasFace = false;
      _selfieMessage = 'Selfie capturada. Validando rostro...';
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
      final saved = _asBool(
        result['biometricImageSaved'] ?? result['biometric_image_saved'],
      );
      final status =
          (result['identityVerificationStatus'] ??
                  result['identity_verification_status'] ??
                  '')
              .toString()
              .trim();
      final approved =
          verified && detected && saved && status.toLowerCase() == 'approved';
      setState(() {
        _selfieHasFace = approved;
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
        _biometricImageSaved = saved;
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
        _identityVerificationStatus = status.isEmpty ? 'rejected' : status;
        _identityVerificationMessage =
            (result['message'] ??
                    (approved
                        ? 'Rostro validado correctamente.'
                        : 'La selfie fue analizada, pero no quedo aprobada.'))
                .toString();
        _selfieMessage =
            !detected
                ? 'No se detecto un rostro valido. Captura una nueva selfie.'
                : !saved
                ? 'El backend analizo la selfie, pero no confirmo su guardado. Intenta de nuevo.'
                : _identityVerificationMessage;
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
        setState(() {
          _validatingSelfie = false;
          _processingSelfie = false;
        });
      }
    }
  }

  Future<File> _optimizeImageForProcessing(
    File source, {
    bool trackDocumentState = true,
  }) async {
    if (trackDocumentState && mounted) {
      setState(() => _processingDocumentImage = true);
    }
    try {
      await _logFileDiagnostics('Image before optimization', source);
      final bytes = await source.readAsBytes();
      final optimized = await compute(_optimizeImageBytesForProcessing, {
        'bytes': bytes,
        'maxDimension': 1600,
        'quality': 85,
      });
      if (optimized['ok'] != true) return source;

      final output = optimized['bytes'] as Uint8List;
      final tempDir = await _processingDirectory();
      final fileName =
          '${path.basenameWithoutExtension(source.path)}_${DateTime.now().millisecondsSinceEpoch}_optimized.jpg';
      final optimizedFile = File(path.join(tempDir.path, fileName));
      await optimizedFile.writeAsBytes(output, flush: true);
      await _logFileDiagnostics('Image after optimization', optimizedFile);
      return optimizedFile;
    } catch (error) {
      debugPrint(
        '[IMAGE OPT] optimization failed path=${source.path} error=$error',
      );
      return source;
    } finally {
      if (trackDocumentState && mounted) {
        setState(() => _processingDocumentImage = false);
      }
    }
  }

  void _activateIdentityMode(_IdentityDocumentMode mode) {
    if (!mounted) return;
    setState(() {
      _documentMode = mode;
    });
  }

  String get _documentType =>
      _documentTypeController.text.trim().isEmpty
          ? 'INE'
          : _documentTypeController.text.trim();

  bool get _isCompanyClient =>
      _clientTypeController.text.trim().toLowerCase() == 'company';

  bool get _isIneDocument => _documentType == 'INE';

  bool get _usesScannedIdentity =>
      _documentMode == _IdentityDocumentMode.ineScan;

  bool get _usesPdfIdentity => _documentMode == _IdentityDocumentMode.pdf;

  bool get _hasDocumentFilesReady {
    if (_registrationPdf != null) return true;
    if (_ineFront == null) return false;
    if (_isIneDocument) return _ineBack != null;
    return true;
  }

  bool get _hasIdentityDocumentReady =>
      _documentNumberController.text.trim().isNotEmpty &&
      _documentIssuingCountryController.text.trim().isNotEmpty &&
      _hasDocumentFilesReady;

  String _identityPromptMessage() {
    if (!_hasDocumentFilesReady) {
      if (_registrationPdf == null && _ineFront == null) {
        return 'Sube tu documento o toma una foto para continuar.';
      }
      if (_isIneDocument && _ineBack == null) {
        return 'Agrega el reverso de la INE para continuar.';
      }
    }
    return 'Completa los datos del documento antes de continuar.';
  }

  Future<String?> _ensureRegistrationIdentificationUploaded() async {
    if (!_usesPdfIdentity) return null;
    final pdf = _registrationPdf;
    if (pdf == null) {
      _showMessage('Selecciona el PDF de tu identificación.');
      return null;
    }
    final existingId = _registrationIdentificationId?.trim() ?? '';
    if (existingId.isNotEmpty) return existingId;

    final missingFields = <String>[
      if (_nameController.text.trim().isEmpty) 'nombre',
      if (_lastNameController.text.trim().isEmpty) 'apellidos',
      if (_phoneController.text.trim().isEmpty) 'teléfono',
      if (_birthDateController.text.trim().isEmpty) 'fecha de nacimiento',
      if (_nationalityController.text.trim().isEmpty) 'nacionalidad',
      if (_documentNumberController.text.trim().isEmpty) 'número de documento',
      if (_documentIssuingCountryController.text.trim().isEmpty) 'país emisor',
      if (_isIneDocument && _ineCurpController.text.trim().isEmpty) 'CURP',
    ];
    if (missingFields.isNotEmpty) {
      _showMessage(
        'Para usar PDF completa estos datos primero: ${missingFields.join(', ')}.',
      );
      return null;
    }

    setState(() {
      _uploadingRegistrationPdf = true;
      _documentScanMessage = 'Guardando identificación oficial en PDF...';
    });

    try {
      final response = await _api.storeRegistrationIdentification(
        file: pdf,
        fullName: _resolvedFullNameForSubmission(),
        phone:
            '${_countryCodeController.text.trim()} ${_phoneController.text.trim()}'
                .trim(),
        birthDate: birthDateInputToIso(_birthDateController.text.trim()),
        documentNumber: _documentNumberController.text.trim(),
        nationality: _nationalityController.text.trim(),
        curp: _ineCurpController.text.trim(),
        documentType: _documentTypeController.text.trim(),
        documentIssuingCountry: _documentIssuingCountryController.text.trim(),
        replaceDocumentId: existingId,
      );
      final document = _map(response['document']);
      final documentId = (document['id'] ?? '').toString().trim();
      if (documentId.isEmpty) {
        throw const ApiException(
          'No recibimos el identificador del PDF guardado.',
        );
      }
      if (!mounted) return documentId;
      setState(() {
        _registrationIdentificationId = documentId;
        _documentScanMessage =
            'PDF guardado correctamente. Ya puedes completar el registro.';
      });
      return documentId;
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _documentScanMessage =
              'No se pudo guardar el PDF. Revisa los datos e inténtalo de nuevo.';
        });
      }
      _showMessage(error.message);
      return null;
    } finally {
      if (mounted) {
        setState(() => _uploadingRegistrationPdf = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_acceptedTerms) {
      _showMessage(
        'Acepta los términos y el aviso de privacidad para continuar.',
      );
      return;
    }
    if (_passwordController.text != _passwordConfirmationController.text) {
      _showMessage('Las contraseñas no coinciden.');
      return;
    }

    if (!_hasIdentityDocumentReady) {
      _showMessage(_identityPromptMessage());
      return;
    }

    if (_selfie == null) {
      _showMessage('Captura una selfie para validar identidad.');
      return;
    }

    if (!_isSelfieValidationConfirmed) {
      _showMessage(
        'La selfie debe quedar validada y confirmada por el backend antes de continuar.',
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();

    if (mounted) {
      setState(() {
        _submissionStatusMessage = 'Preparando registro...';
      });
    }

    final identificationDocumentId =
        _usesPdfIdentity
            ? await _ensureRegistrationIdentificationUploaded()
            : null;
    if (_usesPdfIdentity &&
        (identificationDocumentId == null ||
            identificationDocumentId.isEmpty)) {
      return;
    }

    if (mounted) {
      setState(() {
        _submissionStatusMessage =
            'Creando cuenta y subiendo documentos verificados...';
      });
    }

    final ok = await authProvider.registerClient(
      name: _resolvedGivenNamesForSubmission(),
      fullName: _resolvedFullNameForSubmission(),
      lastName: _resolvedLastNameForSubmission(),
      email: _emailController.text,
      phone:
          '${_countryCodeController.text.trim()} ${_phoneController.text.trim()}'
              .trim(),
      birthDate: birthDateInputToIso(_birthDateController.text),
      nationality: _nationalityController.text,
      base: _baseController.text,
      documentType: _documentTypeController.text,
      documentIssuingCountry: _documentIssuingCountryController.text,
      documentNumber: _documentNumberController.text,
      clientType: _clientTypeController.text,
      companyName: _companyNameController.text,
      taxId: _taxIdController.text,
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
      identityValidationRequired: true,
      identificationDocumentId: identificationDocumentId ?? '',
      password: _passwordController.text,
      passwordConfirmation: _passwordConfirmationController.text,
      ineFront: _usesScannedIdentity ? _ineFront : null,
      ineBack: _usesScannedIdentity && _isIneDocument ? _ineBack : null,
      selfieBiometric: _selfie,
    );

    if (!mounted) return;
    if (!ok) {
      setState(() {
        _submissionStatusMessage = '';
      });
      _showMessage(
        authProvider.errorMessage ?? 'No fue posible crear la cuenta.',
      );
      return;
    }

    setState(() {
      _submissionStatusMessage = '';
    });
    final auth = context.read<AuthProvider>();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => MarketplaceHomeScreen(role: auth.role)),
      (route) => false,
    );
  }

  bool get _isPersonalDataReady =>
      _nameController.text.trim().isNotEmpty &&
      _lastNameController.text.trim().isNotEmpty &&
      _emailController.text.trim().isNotEmpty &&
      _phoneController.text.trim().isNotEmpty &&
      _birthDateController.text.trim().isNotEmpty &&
      _nationalityController.text.trim().isNotEmpty &&
      _clientTypeController.text.trim().isNotEmpty;

  bool get _isAccountDataReady =>
      _passwordController.text.length >= 8 &&
      _passwordController.text == _passwordConfirmationController.text &&
      _acceptedTerms;

  List<bool> get _stepCompletion => [
    _isPersonalDataReady,
    _hasIdentityDocumentReady,
    _isSelfieValidationConfirmed,
    _isAccountDataReady,
  ];

  int get _completedStepCount => _stepCompletion.where((done) => done).length;

  double get _progressValue =>
      _stepCompletion.isEmpty
          ? 0
          : _completedStepCount / _stepCompletion.length;

  String get _progressLabel => 'Paso ${_currentStep + 1} de 4';

  String get _progressSubtitle =>
      '${(_progressValue * 100).round()}% completado';

  String get _currentStepTitle {
    switch (_currentStep) {
      case 0:
        return 'Datos personales';
      case 1:
        return 'Verifica tu identidad';
      case 2:
        return 'Verificacion facial';
      case 3:
        return 'Cuenta';
      default:
        return 'Crear cuenta';
    }
  }

  String get _currentStepDescription {
    switch (_currentStep) {
      case 0:
        return 'Completa tu perfil base antes de validar identidad.';
      case 1:
        return 'Sube tu documento y define los datos oficiales que validaremos.';
      case 2:
        return 'Necesitamos confirmar que el documento pertenece a la persona que está creando la cuenta.';
      case 3:
        return 'Configura tu acceso final para entrar al portal privado.';
      default:
        return '';
    }
  }

  String get _primaryButtonLabel {
    switch (_currentStep) {
      case 0:
      case 1:
        return 'Continuar';
      case 2:
        return _isSelfieValidationConfirmed ? 'Continuar' : 'Tomar selfie';
      case 3:
        return 'Crear cuenta';
      default:
        return 'Continuar';
    }
  }

  bool _isStepUnlocked(int stepIndex) {
    if (stepIndex <= 0) return true;
    final completion = _stepCompletion;
    for (var index = 0; index < stepIndex; index++) {
      if (!completion[index]) return false;
    }
    return true;
  }

  void _handlePremiumStepTap(int targetStep) {
    if (!_isStepUnlocked(targetStep)) {
      if (targetStep == 1) {
        _showMessage('Completa primero los datos personales.');
      } else if (targetStep == 2) {
        _showMessage(
          'Completa la verificación de identidad antes de abrir la selfie.',
        );
      } else if (targetStep == 3) {
        _showMessage('Valida la selfie antes de configurar tu cuenta.');
      }
      return;
    }
    setState(() => _currentStep = targetStep);
  }

  void _continueFromPersonalStep() {
    if (!_formKey.currentState!.validate()) return;
    if (!_isPersonalDataReady) {
      _showMessage('Completa todos los datos personales requeridos.');
      return;
    }
    setState(() => _currentStep = 1);
  }

  void _continueFromIdentityStep() {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasIdentityDocumentReady) {
      _showMessage(_identityPromptMessage());
      return;
    }
    setState(() => _currentStep = 2);
  }

  Future<void> _continueFromSelfieStep() async {
    if (!_isSelfieValidationConfirmed) {
      await _captureSelfie();
      if (!_isSelfieValidationConfirmed || !mounted) return;
    }
    setState(() => _currentStep = 3);
  }

  Future<void> _handlePrimaryAction() async {
    switch (_currentStep) {
      case 0:
        _continueFromPersonalStep();
        break;
      case 1:
        _continueFromIdentityStep();
        break;
      case 2:
        await _continueFromSelfieStep();
        break;
      case 3:
        if (_formKey.currentState!.validate()) {
          await _submit();
        }
        break;
    }
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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final footerStatusMessage =
        auth.isLoading
            ? (_submissionStatusMessage.isNotEmpty
                ? _submissionStatusMessage
                : 'Creando cuenta...')
            : '';

    return Scaffold(
      backgroundColor: const Color(0xFF030813),
      extendBody: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF04101D), Color(0xFF06111B), Color(0xFF03070D)],
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
                        primary: const Color(0xFF0D2135),
                        accent: const Color(0xFFD8B15D),
                        isDark: true,
                      ),
                    ),
              ),
            ),
            Positioned(
              top: 120,
              right: -20,
              child: _PremiumGlow(size: 220, color: const Color(0x22D8B15D)),
            ),
            Positioned(
              top: 320,
              left: -50,
              child: _PremiumGlow(size: 220, color: const Color(0x143E6DAA)),
            ),
            SafeArea(
              bottom: false,
              child: Form(
                key: _formKey,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        14,
                        20,
                        172 + bottomInset,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          Row(
                            children: [
                              _PremiumCircleButton(
                                onTap: () => Navigator.maybePop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _currentStepTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _currentStepDescription,
                            style: const TextStyle(
                              color: Color(0xFFC0C8D2),
                              fontSize: 18,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _ClientRegisterPremiumHero(
                            currentStep: _currentStep,
                            progressPercent: (_progressValue * 100).round(),
                          ),
                          const SizedBox(height: 18),
                          _PremiumStepper(
                            activeStep: _currentStep,
                            isStepUnlocked: _isStepUnlocked,
                            onStepTap: _handlePremiumStepTap,
                          ),
                          const SizedBox(height: 18),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder:
                                (child, animation) => FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(.04, 0),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                            child: _buildStepSection(),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _ClientRegisterFooter(
        progressLabel: _progressLabel,
        progressSubtitle: _progressSubtitle,
        progress: _progressValue,
        loading: auth.isLoading,
        statusMessage: footerStatusMessage,
        buttonLabel: _primaryButtonLabel,
        onPressed: auth.isLoading ? null : () => _handlePrimaryAction(),
      ),
    );
  }

  Widget _buildStepSection() {
    switch (_currentStep) {
      case 0:
        return _PremiumGlassSection(
          key: const ValueKey('step-personal'),
          title: '1. Datos',
          icon: Icons.person_outline_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PremiumInlineNote(
                message:
                    'Usaremos estos datos únicamente para gestionar tu cuenta y tu validación inicial.',
              ),
              const SizedBox(height: 14),
              _clientTypeField(),
              _field(_nameController, 'Nombre(s)'),
              _field(_lastNameController, 'Apellidos'),
              _field(
                _emailController,
                'Correo',
                keyboard: TextInputType.emailAddress,
              ),
              Row(
                children: [
                  SizedBox(width: 112, child: _countryCodeField()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      _phoneController,
                      'Telefono',
                      keyboard: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              _field(
                _birthDateController,
                'Fecha de nacimiento',
                hint: 'DD / MM / AAAA',
              ),
              _nationalityField('Nacionalidad'),
              _field(
                _baseController,
                'Ciudad de residencia',
                requiredField: false,
              ),
              if (_isCompanyClient) ...[
                _field(
                  _companyNameController,
                  'Empresa / razon social',
                  requiredField: false,
                ),
                _field(_taxIdController, 'RFC / Tax ID', requiredField: false),
              ],
              const SizedBox(height: 4),
              _PrivacyCompactNotice(onTap: _showPrivacyNotice),
            ],
          ),
        );
      case 1:
        return _PremiumGlassSection(
          key: const ValueKey('step-identity'),
          title: '2. Identidad',
          icon: Icons.badge_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PremiumInlineNote(
                message:
                    'Selecciona tu documento, completa sus datos y carga evidencia clara en foto o archivo.',
              ),
              const SizedBox(height: 14),
              _documentTypeField(),
              _field(_documentNumberController, 'Numero de documento'),
              _documentCountryField(),
              if (_isIneDocument)
                _field(_ineCurpController, 'CURP', requiredField: false),
              const SizedBox(height: 6),
              _DocumentUploadPanel(
                title:
                    _isIneDocument
                        ? 'INE / identificación nacional'
                        : 'Pasaporte',
                subtitle:
                    _isIneDocument
                        ? 'Carga frente y reverso. Puedes tomar foto o subir archivo.'
                        : 'Carga la página principal con foto. Puedes tomar foto o subir archivo.',
                showBackSide: _isIneDocument,
                frontLabel:
                    _registrationPdf != null
                        ? _pdfFileLabel()
                        : (_ineFront == null ? '' : _ineFileLabel()),
                backLabel:
                    _ineBack == null ? '' : path.basename(_ineBack!.path),
                pdfLabel: _registrationPdf == null ? '' : _pdfFileLabel(),
                onFrontCamera: _pickDocumentFrontFromCamera,
                onFrontFile: _pickDocumentFrontFromFiles,
                onBackCamera: _pickDocumentBackFromCamera,
                onBackFile: _pickDocumentBackFromFiles,
              ),
              if (_documentScanMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                _PremiumInlineNote(message: _documentScanMessage),
              ],
            ],
          ),
        );
      case 2:
        return _PremiumGlassSection(
          key: const ValueKey('step-selfie'),
          title: '3. Selfie',
          icon: Icons.face_retouching_natural_outlined,
          child: _BiometricValidationCard(
            ready: _isSelfieValidationConfirmed,
            loading: _isSelfieBusy,
            message: _selfieMessage,
            onTap: _captureSelfie,
          ),
        );
      case 3:
        return _PremiumGlassSection(
          key: const ValueKey('step-account'),
          title: '4. Cuenta',
          icon: Icons.lock_outline_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AccountReadyBanner(verified: _isSelfieValidationConfirmed),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _generatePassword,
                  icon: const Icon(Icons.auto_fix_high_rounded),
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
                title: const Text(
                  'Mostrar contrasena',
                  style: TextStyle(color: Colors.white),
                ),
                activeThumbColor: const Color(0xFFD8B15D),
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
                title: const Text(
                  'Mostrar confirmacion',
                  style: TextStyle(color: Colors.white),
                ),
                activeThumbColor: const Color(0xFFD8B15D),
                value: _passwordConfirmationVisible,
                onChanged:
                    (value) =>
                        setState(() => _passwordConfirmationVisible = value),
              ),
              CheckboxListTile(
                value: _acceptedTerms,
                onChanged:
                    (value) => setState(() => _acceptedTerms = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFFD8B15D),
                checkColor: const Color(0xFF12161D),
                title: const Text(
                  'Acepto los términos y condiciones y el aviso de privacidad.',
                  style: TextStyle(color: Colors.white, height: 1.35),
                ),
                subtitle: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _showPrivacyNotice,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    child: const Text('Aviso de privacidad'),
                  ),
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _clientTypeField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue:
            _clientTypeController.text.trim().isEmpty
                ? null
                : _clientTypeController.text.trim(),
        isExpanded: true,
        isDense: true,
        iconSize: 18,
        items: const [
          DropdownMenuItem(value: 'individual', child: Text('Particular')),
          DropdownMenuItem(value: 'company', child: Text('Empresa')),
        ],
        onChanged: _onClientTypeChanged,
        dropdownColor: const Color(0xFF101B29),
        iconEnabledColor: const Color(0xFFD8B15D),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: 'Tipo de cliente',
          hintText: 'Selecciona el tipo de cuenta',
          prefixIcon: _iconForLabel('Tipo de cliente'),
          labelStyle: const TextStyle(color: Color(0xFFD0D6DF)),
          hintStyle: const TextStyle(color: Color(0xFF6F7B8A)),
          filled: true,
          fillColor: const Color(0x70101B29),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: Color(0x2AFFFFFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: Color(0xFFD8B15D)),
          ),
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) return 'Completa Tipo de cliente.';
          return null;
        },
      ),
    );
  }

  Widget _countryCodeField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue:
            _countryCodeController.text.trim().isEmpty
                ? null
                : _countryCodeController.text.trim(),
        isExpanded: true,
        isDense: true,
        iconSize: 18,
        items:
            const ['+52', '+1', '+34', '+57', '+54', '+55', '+507']
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
        onChanged: (value) {
          _countryCodeController.text = value?.trim() ?? '+52';
          _refreshStepProgress();
        },
        dropdownColor: const Color(0xFF101B29),
        iconEnabledColor: const Color(0xFFD8B15D),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: 'Codigo',
          hintText: '+52',
          labelStyle: const TextStyle(color: Color(0xFFD0D6DF)),
          hintStyle: const TextStyle(color: Color(0xFF6F7B8A)),
          filled: true,
          fillColor: const Color(0x70101B29),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: Color(0x2AFFFFFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: Color(0xFFD8B15D)),
          ),
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) return 'Completa Codigo.';
          return null;
        },
      ),
    );
  }

  Widget _documentTypeField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: _documentType,
        isExpanded: true,
        isDense: true,
        iconSize: 18,
        items: const [
          DropdownMenuItem(value: 'INE', child: Text('INE')),
          DropdownMenuItem(value: 'PASSPORT', child: Text('Pasaporte')),
        ],
        onChanged: _onDocumentTypeChanged,
        dropdownColor: const Color(0xFF101B29),
        iconEnabledColor: const Color(0xFFD8B15D),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: 'Tipo de documento',
          hintText: 'Selecciona una opción',
          prefixIcon: _iconForLabel('Tipo de documento'),
          labelStyle: const TextStyle(color: Color(0xFFD0D6DF)),
          hintStyle: const TextStyle(color: Color(0xFF6F7B8A)),
          filled: true,
          fillColor: const Color(0x70101B29),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: Color(0x2AFFFFFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: Color(0xFFD8B15D)),
          ),
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) return 'Completa Tipo de documento.';
          return null;
        },
      ),
    );
  }

  Widget _documentCountryField() {
    final options =
        {
            'México',
            ...kNationalityOptions.map((option) {
              if (option == 'Mexicana') return 'México';
              return option.replaceAll(RegExp(r'[aeiou]na$'), '');
            }),
            _documentIssuingCountryController.text.trim(),
          }.where((item) => item.trim().isNotEmpty).toList()
          ..sort();
    return _dropdownField(
      label: 'Pais emisor',
      value:
          _documentIssuingCountryController.text.trim().isEmpty
              ? null
              : _documentIssuingCountryController.text.trim(),
      items: options,
      onChanged: (value) {
        _documentIssuingCountryController.text = value?.trim() ?? '';
        _refreshStepProgress();
      },
      hint: 'Selecciona el país emisor',
    );
  }

  Widget _dropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? hint,
    bool requiredField = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        isDense: true,
        iconSize: 18,
        items:
            items
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
        onChanged: onChanged,
        dropdownColor: const Color(0xFF101B29),
        iconEnabledColor: const Color(0xFFD8B15D),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: _iconForLabel(label),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          labelStyle: const TextStyle(color: Color(0xFFD0D6DF)),
          hintStyle: const TextStyle(color: Color(0xFF6F7B8A)),
          filled: true,
          fillColor: const Color(0x70101B29),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: Color(0x2AFFFFFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: Color(0xFFD8B15D)),
          ),
        ),
        validator: (selected) {
          if (!requiredField) return null;
          final text = selected?.trim() ?? '';
          if (text.isEmpty) return 'Completa $label.';
          return null;
        },
      ),
    );
  }

  Future<void> _showPrivacyNotice() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0D1724),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aviso de privacidad',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tus datos están protegidos y se utilizan únicamente para gestionar tu cuenta, verificar tu identidad y habilitar el acceso a tus vuelos.',
                    style: TextStyle(color: Color(0xFFC7CFD8), height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD8B15D),
                        foregroundColor: const Color(0xFF12161D),
                      ),
                      child: const Text('Entendido'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  List<_RegisterChecklistItem> _registrationChecklist() {
    return [
      _RegisterChecklistItem(
        icon: Icons.badge_rounded,
        label: 'Identidad',
        ready: _hasIdentityDocumentReady,
      ),
      _RegisterChecklistItem(
        icon: Icons.face_retouching_natural_rounded,
        label: 'Selfie',
        ready: _selfieHasFace,
      ),
      _RegisterChecklistItem(
        icon: Icons.person_rounded,
        label: 'Datos',
        ready: _isPersonalDataReady,
      ),
      _RegisterChecklistItem(
        icon: Icons.lock_rounded,
        label: 'Acceso',
        ready: _isAccountDataReady,
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
        loading: _isDocumentBusy,
        onTap: _isDocumentBusy ? () {} : _pickIneFront,
      ),
      if (_documentScanMessage.isNotEmpty) _HintText(_documentScanMessage),
      if (_ineFront != null) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _isDocumentBusy ? null : _scanIneLocally,
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
      _field(
        _birthDateController,
        'Fecha de nacimiento',
        hint: 'DD / MM / AAAA',
      ),
      _nationalityField('Nacionalidad'),
      _field(_baseController, 'Ciudad/base', requiredField: false),

      const SizedBox(height: 10),
      _field(_documentTypeController, 'Identificacion'),
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
        loading: _isSelfieBusy,
        onTap: _isSelfieBusy ? () {} : _captureSelfie,
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
    final isDateField = identical(controller, _birthDateController);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: isDateField ? TextInputType.number : keyboard,
        inputFormatters:
            isDateField
                ? const <TextInputFormatter>[BirthDateTextInputFormatter()]
                : null,
        onChanged: (_) => onChanged?.call(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: _iconForLabel(label),
          labelStyle: const TextStyle(color: Color(0xFFD0D6DF)),
          hintStyle: const TextStyle(color: Color(0xFF6F7B8A)),
          filled: true,
          fillColor: const Color(0x70101B29),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: Color(0x2AFFFFFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: Color(0xFFD8B15D)),
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

  Widget _nationalityField(String label, {bool requiredField = true}) {
    final options =
        {
            ...kNationalityOptions,
            if (_nationalityController.text.trim().isNotEmpty)
              _nationalityController.text.trim(),
          }.toList()
          ..sort();

    final currentValue = _nationalityController.text.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: currentValue.isEmpty ? null : currentValue,
        isExpanded: true,
        isDense: true,
        iconSize: 18,
        items:
            options
                .map(
                  (option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(
                      option,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
        onChanged: (value) {
          _nationalityController.text = value?.trim() ?? '';
          _refreshStepProgress();
        },
        dropdownColor: const Color(0xFF101B29),
        iconEnabledColor: const Color(0xFFD8B15D),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Selecciona una nacionalidad',
          prefixIcon: _iconForLabel(label),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          labelStyle: const TextStyle(color: Color(0xFFD0D6DF)),
          hintStyle: const TextStyle(color: Color(0xFF6F7B8A)),
          filled: true,
          fillColor: const Color(0x70101B29),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: Color(0x2AFFFFFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: Color(0xFFD8B15D)),
          ),
        ),
        validator: (value) {
          if (!requiredField) return null;
          final text = value?.trim() ?? '';
          if (text.isEmpty) return 'Completa $label.';
          return null;
        },
      ),
    );
  }

  Widget? _iconForLabel(String label) {
    final normalized = label.toLowerCase();
    const active = Color(0xFFD8B15D);
    if (normalized.contains('correo')) {
      return const Icon(Icons.alternate_email_rounded, color: active);
    }
    if (normalized.contains('telefono')) {
      return const Icon(Icons.phone_rounded, color: active);
    }
    if (normalized.contains('fecha')) {
      return const Icon(Icons.event_rounded, color: active);
    }
    if (normalized.contains('base') || normalized.contains('ciudad')) {
      return const Icon(Icons.location_on_outlined, color: active);
    }
    if (normalized.contains('nacionalidad')) {
      return const Icon(Icons.public_rounded, color: active);
    }
    if (normalized.contains('documento') ||
        normalized.contains('ine') ||
        normalized.contains('curp') ||
        normalized.contains('cic') ||
        normalized.contains('ocr') ||
        normalized.contains('identificacion')) {
      return const Icon(Icons.badge_rounded, color: active);
    }
    if (normalized.contains('contrasena')) {
      return const Icon(Icons.lock_rounded, color: active);
    }
    return const Icon(Icons.person_outline_rounded, color: active);
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
    _setIfPresent(_lastNameController, data['last_name']);
    _setIfPresent(_birthDateController, data['birth_date']);
    _setIfPresent(_nationalityController, data['nationality']);
    _setIfPresent(_baseController, data['base']);
    _setIfPresent(_documentNumberController, data['document_number']);
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
    final validName = _validatedName(data['name'] ?? '');
    final validLastName = _validatedLastName(data['last_name'] ?? '');
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
    if (validLastName.isNotEmpty) sanitized['last_name'] = validLastName;
    if (validBirthDate.isNotEmpty) sanitized['birth_date'] = validBirthDate;
    if (validBase.isNotEmpty) sanitized['base'] = validBase;
    if (validDocumentNumber.isNotEmpty) {
      sanitized['document_number'] = validDocumentNumber;
    }
    if (validCurp.isNotEmpty) sanitized['curp'] = validCurp;
    if (validCic.isNotEmpty) sanitized['cic'] = validCic;
    if (validOcr.isNotEmpty) sanitized['ocr'] = validOcr;

    final nationality = data['nationality'] ?? '';
    if (nationality.isNotEmpty && nationality.toLowerCase().contains('mex')) {
      sanitized['nationality'] = 'Mexicana';
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

  String _validatedName(String value) {
    final text = value.trim().toUpperCase();
    if (text.isEmpty) return '';
    if (_containsInvalidPersonNameContent(text)) {
      debugPrint('[INE VALIDATION] rejected name=$text reason=invalid_name');
      return '';
    }
    if (!_hasAtLeastWords(text, 2)) {
      debugPrint('[INE VALIDATION] rejected name=$text reason=missing_words');
      return '';
    }
    return text;
  }

  String _validatedLastName(String value) {
    final text = value.trim().toUpperCase();
    if (text.isEmpty) return '';
    if (_containsInvalidPersonNameContent(text)) {
      debugPrint(
        '[INE VALIDATION] rejected last_name=$text reason=invalid_name',
      );
      return '';
    }
    return text;
  }

  bool _containsInvalidPersonNameContent(String text) {
    if (RegExp(r'\d').hasMatch(text) ||
        _containsAddressKeyword(text) ||
        RegExp(
          r'\b(MEX|MEX\.|DOMICILIO|SECCI[O0]N|VIGENCIA|FECHA|CURP|CLAVE|LERMA)\b',
        ).hasMatch(text) ||
        !RegExp(r'^[A-Z ,.]+$').hasMatch(text)) {
      return true;
    }
    return false;
  }

  bool _hasAtLeastWords(String text, int minimumWords) {
    return text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length >=
        minimumWords;
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

  String _normalizePersonNameValue(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _personNameComparisonKey(String value) {
    const replacements = <String, String>{
      'Á': 'A',
      'À': 'A',
      'Ä': 'A',
      'Â': 'A',
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'É': 'E',
      'È': 'E',
      'Ë': 'E',
      'Ê': 'E',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'Í': 'I',
      'Ì': 'I',
      'Ï': 'I',
      'Î': 'I',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'Ó': 'O',
      'Ò': 'O',
      'Ö': 'O',
      'Ô': 'O',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'Ú': 'U',
      'Ù': 'U',
      'Ü': 'U',
      'Û': 'U',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'Ñ': 'N',
      'ñ': 'n',
    };

    final normalized = _normalizePersonNameValue(value);
    return normalized
        .split('')
        .map((char) => replacements[char] ?? char)
        .join()
        .toUpperCase();
  }

  String _resolvedLastNameForSubmission() {
    return _normalizePersonNameValue(_lastNameController.text);
  }

  String _resolvedGivenNamesForSubmission() {
    final rawGivenNames = _normalizePersonNameValue(_nameController.text);
    final lastName = _resolvedLastNameForSubmission();
    if (rawGivenNames.isEmpty || lastName.isEmpty) return rawGivenNames;

    final givenTokens = rawGivenNames.split(RegExp(r'\s+'));
    final lastNameTokens = lastName.split(RegExp(r'\s+'));
    final normalizedGivenTokens =
        givenTokens.map(_personNameComparisonKey).toList();
    final normalizedLastNameTokens =
        lastNameTokens.map(_personNameComparisonKey).toList();

    final startsWithLastName =
        normalizedGivenTokens.length >= normalizedLastNameTokens.length &&
        _listEquals(
          normalizedGivenTokens.take(normalizedLastNameTokens.length).toList(),
          normalizedLastNameTokens,
        );
    if (startsWithLastName) {
      return _normalizePersonNameValue(
        givenTokens.skip(lastNameTokens.length).join(' '),
      );
    }

    final endsWithLastName =
        normalizedGivenTokens.length >= normalizedLastNameTokens.length &&
        _listEquals(
          normalizedGivenTokens
              .skip(
                normalizedGivenTokens.length - normalizedLastNameTokens.length,
              )
              .toList(),
          normalizedLastNameTokens,
        );
    if (endsWithLastName) {
      return _normalizePersonNameValue(
        givenTokens.take(givenTokens.length - lastNameTokens.length).join(' '),
      );
    }

    return _personNameComparisonKey(rawGivenNames) ==
            _personNameComparisonKey(lastName)
        ? ''
        : rawGivenNames;
  }

  String _resolvedFullNameForSubmission() {
    final givenNames = _resolvedGivenNamesForSubmission();
    final lastName = _resolvedLastNameForSubmission();
    return _normalizePersonNameValue('$givenNames $lastName');
  }

  bool _listEquals(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  void _setIfPresent(TextEditingController controller, dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      final resolvedText =
          identical(controller, _birthDateController)
              ? normalizeBirthDateForInput(text)
              : text;
      debugPrint(
        '[INE] Controller update target=${_controllerLabel(controller)} old="${controller.text}" new="$resolvedText"',
      );
      controller.text = resolvedText;
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
    if (_isDocumentBusy) return 'Procesando INE...';
    return 'INE cargada';
  }

  String _selfieFileLabel() {
    if (_selfie == null) return '';
    if (_isSelfieBusy) return 'Validando selfie...';
    if (_selfieHasFace) return 'Selfie validada';
    return 'Selfie cargada';
  }

  String _pdfFileLabel() {
    final pdf = _registrationPdf;
    if (pdf == null) return '';
    if (_uploadingRegistrationPdf) return 'Guardando PDF...';
    if ((_registrationIdentificationId ?? '').isNotEmpty) {
      return 'PDF guardado y vinculado';
    }
    return path.basename(pdf.path);
  }
}

enum _DocumentImageSource { camera, files }

enum _IdentityDocumentMode { ineScan, pdf }

class _PremiumGlow extends StatelessWidget {
  const _PremiumGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _PremiumCircleButton extends StatelessWidget {
  const _PremiumCircleButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: Colors.white.withValues(alpha: .05),
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x30FFFFFF)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientRegisterPremiumHero extends StatelessWidget {
  const _ClientRegisterPremiumHero({
    required this.currentStep,
    required this.progressPercent,
  });

  final int currentStep;
  final int progressPercent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0x24FFFFFF)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/login/image.png',
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xEF030B16),
                    Color(0xD605101C),
                    Color(0x70040D17),
                  ],
                  stops: [0, .48, 1],
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD8B15D).withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x66D8B15D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paso ${currentStep + 1}',
                      style: TextStyle(
                        color: Color(0xFFF5D89A),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$progressPercent%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RED SKY GROUP',
                    style: TextStyle(
                      color: Color(0xFFF4D38B),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    currentStep < 3 ? 'Cabina Privada' : 'Cuenta verificada',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.6,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    currentStep < 3
                        ? 'Registro seguro para clientes.'
                        : 'Último paso para activar tu acceso privado.',
                    style: TextStyle(
                      color: Color(0xFFD0D7E0),
                      fontSize: 14.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumStepper extends StatelessWidget {
  const _PremiumStepper({
    required this.activeStep,
    required this.isStepUnlocked,
    required this.onStepTap,
  });

  final int activeStep;
  final bool Function(int stepIndex) isStepUnlocked;
  final ValueChanged<int> onStepTap;

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('Datos', Icons.person_outline_rounded),
      ('Identidad', Icons.badge_outlined),
      ('Selfie', Icons.face_retouching_natural_outlined),
      ('Cuenta', Icons.lock_outline_rounded),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0x99111924),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x24FFFFFF)),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            final connectorActive = index ~/ 2 < activeStep;
            return Expanded(
              child: Container(
                height: 1.5,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color:
                    connectorActive
                        ? const Color(0xFFD8B15D)
                        : const Color(0x28FFFFFF),
              ),
            );
          }
          final stepIndex = index ~/ 2;
          final isActive = stepIndex == activeStep;
          final isDone = stepIndex < activeStep;
          final isUnlocked = isStepUnlocked(stepIndex);
          final step = steps[stepIndex];
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: isUnlocked ? () => onStepTap(stepIndex) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            isActive
                                ? const Color(0x1AD8B15D)
                                : Colors.white.withValues(alpha: .02),
                        border: Border.all(
                          color:
                              isActive || isDone
                                  ? const Color(0xFFD8B15D)
                                  : isUnlocked
                                  ? const Color(0x2CFFFFFF)
                                  : const Color(0x16FFFFFF),
                        ),
                      ),
                      child: Icon(
                        isDone
                            ? Icons.check_rounded
                            : isUnlocked
                            ? step.$2
                            : Icons.lock_outline_rounded,
                        color:
                            isActive || isDone
                                ? const Color(0xFFD8B15D)
                                : isUnlocked
                                ? const Color(0x7DFFFFFF)
                                : const Color(0x46FFFFFF),
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      step.$1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            isActive
                                ? const Color(0xFFF3D38A)
                                : isUnlocked
                                ? const Color(0x95FFFFFF)
                                : const Color(0x46FFFFFF),
                        fontSize: 13,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PremiumGlassSection extends StatelessWidget {
  const _PremiumGlassSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          decoration: BoxDecoration(
            color: const Color(0x80101925),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0x24FFFFFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: const Color(0xFFD8B15D), size: 24),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFD8B15D),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumSubsectionTitle extends StatelessWidget {
  const _PremiumSubsectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _UploadOptionCard extends StatelessWidget {
  const _UploadOptionCard({
    required this.title,
    required this.icon,
    required this.buttonLabel,
    required this.accent,
    required this.selected,
    required this.loaded,
    required this.loadedLabel,
    required this.onTap,
    this.secondary = false,
  });

  final String title;
  final IconData icon;
  final String buttonLabel;
  final Color accent;
  final bool selected;
  final bool loaded;
  final String loadedLabel;
  final VoidCallback onTap;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            selected
                ? accent.withValues(alpha: .08)
                : Colors.white.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              selected
                  ? accent.withValues(alpha: .50)
                  : const Color(0x24FFFFFF),
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 30),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (loaded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0x185FD07D),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x455FD07D)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF89E39A),
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  const Flexible(
                    child: Text(
                      'Documento cargado',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF89E39A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  backgroundColor:
                      secondary
                          ? Colors.transparent
                          : accent.withValues(alpha: .92),
                  foregroundColor: secondary ? accent : const Color(0xFF0D1218),
                  side:
                      secondary
                          ? BorderSide(color: accent.withValues(alpha: .55))
                          : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          if (loadedLabel.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              loadedLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .68),
                fontSize: 11.5,
                height: 1.25,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PremiumInlineNote extends StatelessWidget {
  const _PremiumInlineNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFC3CBD7),
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }
}

class _PrivacyCompactNotice extends StatelessWidget {
  const _PrivacyCompactNotice({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.lock_outline_rounded, color: Color(0xFFD8B15D)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tus datos están protegidos y se utilizan únicamente para gestionar tu cuenta y tus vuelos.',
                  style: TextStyle(
                    color: Color(0xFFC3CBD7),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Aviso de privacidad'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentUploadPanel extends StatelessWidget {
  const _DocumentUploadPanel({
    required this.title,
    required this.subtitle,
    required this.showBackSide,
    required this.frontLabel,
    required this.backLabel,
    required this.pdfLabel,
    required this.onFrontCamera,
    required this.onFrontFile,
    required this.onBackCamera,
    required this.onBackFile,
  });

  final String title;
  final String subtitle;
  final bool showBackSide;
  final String frontLabel;
  final String backLabel;
  final String pdfLabel;
  final VoidCallback onFrontCamera;
  final VoidCallback onFrontFile;
  final VoidCallback onBackCamera;
  final VoidCallback onBackFile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFFB7C0CB),
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        _DocumentEvidenceCard(
          title: showBackSide ? 'Frente del documento' : 'Documento',
          value: frontLabel,
          onCamera: onFrontCamera,
          onFile: onFrontFile,
        ),
        if (showBackSide) ...[
          const SizedBox(height: 12),
          _DocumentEvidenceCard(
            title: 'Reverso del documento',
            value: backLabel,
            onCamera: onBackCamera,
            onFile: onBackFile,
          ),
        ],
        if (pdfLabel.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _PremiumInlineNote(message: pdfLabel),
        ],
      ],
    );
  }
}

class _DocumentEvidenceCard extends StatelessWidget {
  const _DocumentEvidenceCard({
    required this.title,
    required this.value,
    required this.onCamera,
    required this.onFile,
  });

  final String title;
  final String value;
  final VoidCallback onCamera;
  final VoidCallback onFile;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 320;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x24FFFFFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.badge_rounded, color: Color(0xFFD8B15D)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (value.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF89E39A),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (compact) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onCamera,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD8B15D),
                      foregroundColor: const Color(0xFF0E131A),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Tomar foto'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onFile,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      foregroundColor: const Color(0xFFD8B15D),
                      side: const BorderSide(color: Color(0x55D8B15D)),
                    ),
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Subir archivo'),
                  ),
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onCamera,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFD8B15D),
                          foregroundColor: const Color(0xFF0E131A),
                          minimumSize: const Size.fromHeight(44),
                        ),
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text('Tomar foto'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onFile,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          foregroundColor: const Color(0xFFD8B15D),
                          side: const BorderSide(color: Color(0x55D8B15D)),
                        ),
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('Subir archivo'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BiometricValidationCard extends StatelessWidget {
  const _BiometricValidationCard({
    required this.ready,
    required this.loading,
    required this.message,
    required this.onTap,
  });

  final bool ready;
  final bool loading;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ready ? const Color(0x445FD07D) : const Color(0x24FFFFFF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      ready ? const Color(0x185FD07D) : const Color(0x14D8B15D),
                ),
                child: Icon(
                  ready ? Icons.verified_user_rounded : Icons.face_rounded,
                  color:
                      ready ? const Color(0xFF89E39A) : const Color(0xFFD8B15D),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verificacion facial',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Necesitamos confirmar que el documento pertenece a la persona que está creando la cuenta.',
                      style: TextStyle(
                        color: Color(0xFFB7C0CB),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: loading ? null : onTap,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                backgroundColor: const Color(0xFFD8B15D),
                foregroundColor: const Color(0xFF0E131A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                ready
                    ? 'Selfie verificada'
                    : message.isNotEmpty
                    ? 'Intentar de nuevo'
                    : 'Tomar selfie',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                color:
                    ready ? const Color(0xFF89E39A) : const Color(0xFFC8D0DA),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountReadyBanner extends StatelessWidget {
  const _AccountReadyBanner({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            verified
                ? const Color(0x165FD07D)
                : Colors.white.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: verified ? const Color(0x445FD07D) : const Color(0x1FFFFFFF),
        ),
      ),
      child: Row(
        children: [
          Icon(
            verified ? Icons.verified_user_rounded : Icons.pending_rounded,
            color: verified ? const Color(0xFF89E39A) : const Color(0xFFD8B15D),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              verified
                  ? 'Cuenta verificada. Solo define tu contraseña para terminar.'
                  : 'La cuenta se habilitará cuando tu identidad quede verificada.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientRegisterFooter extends StatelessWidget {
  const _ClientRegisterFooter({
    required this.progressLabel,
    required this.progressSubtitle,
    required this.progress,
    required this.loading,
    required this.statusMessage,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String progressLabel;
  final String progressSubtitle;
  final double progress;
  final bool loading;
  final String statusMessage;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: EdgeInsets.fromLTRB(18, 16, 18, 14 + bottomInset),
          decoration: BoxDecoration(
            color: const Color(0xE6101925),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: .06)),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stackVertically = constraints.maxWidth < 390;
              final button = SizedBox(
                width: stackVertically ? double.infinity : 186,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF4DA96), Color(0xFFD8B15D)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: FilledButton(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(58),
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      foregroundColor: const Color(0xFF12161D),
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child:
                        loading
                            ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Color(0xFF12161D),
                              ),
                            )
                            : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    buttonLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded),
                              ],
                            ),
                  ),
                ),
              );

              final progressBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    progressLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    progressSubtitle,
                    style: const TextStyle(
                      color: Color(0xFFAEB8C4),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: .08),
                      color: const Color(0xFFD8B15D),
                    ),
                  ),
                ],
              );

              if (stackVertically) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (loading && statusMessage.trim().isNotEmpty) ...[
                      _LoadingStatusChip(message: statusMessage),
                      const SizedBox(height: 12),
                    ],
                    progressBlock,
                    const SizedBox(height: 16),
                    button,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (loading && statusMessage.trim().isNotEmpty) ...[
                          _LoadingStatusChip(message: statusMessage),
                          const SizedBox(height: 12),
                        ],
                        progressBlock,
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  button,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoadingStatusChip extends StatelessWidget {
  const _LoadingStatusChip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFD9E2EC),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
