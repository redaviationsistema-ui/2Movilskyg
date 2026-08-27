// ignore_for_file: unused_element

import 'dart:ui';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/cliente_api.dart';
import '../../models/aeropuerto.dart';
import '../../providers/proveedor_autenticacion.dart';
import '../../services/servicio_aeropuertos.dart';
import '../../services/servicio_ocr_registro.dart';
import 'date_text_input_formatter.dart';
import 'nationality_options.dart';
import '../marketplace/pantalla_inicio_mercado.dart';

class CrewRegisterScreen extends StatefulWidget {
  const CrewRegisterScreen({super.key});

  @override
  State<CrewRegisterScreen> createState() => _CrewRegisterScreenState();
}

class _CrewRegisterScreenState extends State<CrewRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _api = ApiClient.instance;
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

  List<Airport> _airports = const [];
  Airport? _selectedBaseAirport;
  File? _document;
  int _currentStep = 0;
  bool _readingDocument = false;
  bool _loadingAirports = false;
  bool _passwordVisible = false;
  bool _passwordConfirmationVisible = false;
  String _scanRaw = '';
  String _scanStatus = '';
  String _documentMessage = '';

  @override
  void initState() {
    super.initState();
    _loadAirports();
  }

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

  Future<void> _loadAirports() async {
    setState(() => _loadingAirports = true);
    try {
      final airports = await AirportService.getAirports();
      if (!mounted) return;
      setState(() {
        _airports = airports;
        _selectedBaseAirport = _resolveAirportFromText(_baseController.text);
      });
    } catch (error) {
      debugPrint('[CREW BASE] Failed to load airports error=$error');
    } finally {
      if (mounted) {
        setState(() => _loadingAirports = false);
      }
    }
  }

  Future<void> _pickDocument() async {
    final selected = await _selectDocumentImage();
    if (selected == null) return;
    await _logFileDiagnostics('Crew document selected', selected);
    final optimized = await _optimizeImageForProcessing(selected);
    await _logFileDiagnostics('Crew document optimized', optimized);

    setState(() {
      _document = optimized;
      _readingDocument = true;
      _documentMessage = 'Analizando licencia...';
    });

    var localOcrDetected = false;

    try {
      final localText = await RegistrationOcrService.scanTextFile(optimized);
      if (localText.trim().isNotEmpty) {
        _applyDocumentText(localText);
        localOcrDetected = _hasUsefulLicenseData();
      }
    } catch (error) {
      debugPrint(
        '[CREW DOC] Local OCR failed path=${optimized.path} error=$error',
      );
    }

    try {
      if (!localOcrDetected) {
        setState(() {
          _documentMessage = 'Escaneando licencia en backend...';
        });
        final response = await _api.scanRegistrationDocument(
          document: _document!,
          documentType: 'auto',
        );
        _applyDocumentResponse(response);
      } else {
        setState(() {
          _documentMessage =
              'Lectura local completada. Revisa y corrige los datos detectados si hace falta.';
        });
      }
    } on ApiException catch (error) {
      setState(() {
        _applyDocumentFallback(optimized);
        _documentMessage =
            localOcrDetected
                ? 'La licencia se cargo y se leyo parcialmente en el dispositivo. Revisa y completa los datos manualmente.'
                : '${error.message} La licencia ya quedo cargada; completa o corrige los datos manualmente.';
      });
    } catch (_) {
      setState(() {
        _applyDocumentFallback(optimized);
        _documentMessage =
            localOcrDetected
                ? 'La licencia se cargo y se leyo parcialmente en el dispositivo. Revisa y completa los datos manualmente.'
                : 'La licencia ya quedo cargada. No se pudo leer automaticamente, pero puedes completar los datos manualmente.';
      });
    } finally {
      if (mounted) setState(() => _readingDocument = false);
    }
  }

  Future<File> _optimizeImageForProcessing(File source) async {
    try {
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
      return optimizedFile;
    } catch (_) {
      return source;
    }
  }

  Future<void> _logFileDiagnostics(String label, File file) async {
    try {
      final bytes = await file.length();
      debugPrint(
        '[CREW DOC] $label path=${file.path} name=${path.basename(file.path)} bytes=$bytes platform=${Platform.operatingSystem}',
      );
    } catch (error) {
      debugPrint(
        '[CREW DOC] $label path=${file.path} name=${path.basename(file.path)} bytes=unavailable platform=${Platform.operatingSystem} error=$error',
      );
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
      path.join(directory.path, 'crew_registration_processing'),
    );
    if (!await processingDirectory.exists()) {
      await processingDirectory.create(recursive: true);
    }
    return processingDirectory;
  }

  Future<File?> _selectDocumentImage() async {
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
                  subtitle: const Text('Capturar la licencia con la camara'),
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
      final hasPermission = await _ensureCameraPermission(
        contextLabel: 'capturar la licencia',
      );
      if (!hasPermission) return null;
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 96,
      );
      return picked == null ? null : File(picked.path);
    }

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    final path = result?.files.single.path;
    return path == null ? null : File(path);
  }

  void _applyDocumentText(String rawText) {
    final parsed = _parseCrewLicenseText(rawText);
    final license = parsed['license_number'];
    final category = parsed['license_category'];
    final issueDate = parsed['issue_date'];
    final expiration = parsed['expiration_date'];
    final issuingCountry = parsed['issuing_country'];
    final nationality = parsed['nationality'];
    final fullName = parsed['name'];
    final birthDate = parsed['birth_date'];

    setState(() {
      _scanRaw = rawText;
      _scanStatus = rawText.trim().isEmpty ? 'pending' : 'scanned';
      if (fullName != null) _nameController.text = fullName;
      if (birthDate != null) {
        _birthDateController.text = normalizeBirthDateForInput(birthDate);
      }
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
      _syncBaseSelection();
      _licenseStatusController.text = _documentStatus(
        _licenseExpirationController.text,
      );
      _documentMessage =
          license == null
              ? 'Documento cargado. Completa los datos manualmente.'
              : 'Documento leido. Revisa licencia y vigencia.';
    });
  }

  Map<String, String> _parseCrewLicenseText(String rawText) {
    final lines =
        rawText
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
    final normalizedLines =
        lines
            .map((line) => _normalizeOcrLine(line))
            .where((line) => line.isNotEmpty)
            .toList();
    final normalizedText = normalizedLines.join('\n');

    final licenseNumber = _extractCrewLicenseNumber(normalizedLines);
    final category = _extractCrewCategory(normalizedLines);
    final fullName = _extractCrewName(normalizedLines);
    final birthDate = _extractCrewBirthDate(normalizedLines);
    final expirationDate = _extractCrewExpirationDate(normalizedLines);
    final issueDate = _extractCrewIssueDate(normalizedText);
    final nationality = _extractCrewNationality(normalizedLines);
    final issuingCountry = _extractCrewIssuingCountry(normalizedLines);

    return {
      if (licenseNumber.isNotEmpty) 'license_number': licenseNumber,
      if (category.isNotEmpty) 'license_category': category,
      if (fullName.isNotEmpty) 'name': fullName,
      if (birthDate.isNotEmpty) 'birth_date': birthDate,
      if (expirationDate.isNotEmpty) 'expiration_date': expirationDate,
      if (issueDate.isNotEmpty) 'issue_date': issueDate,
      if (nationality.isNotEmpty) 'nationality': nationality,
      if (issuingCountry.isNotEmpty) 'issuing_country': issuingCountry,
    };
  }

  void _applyDocumentResponse(Map<String, dynamic> response) {
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
            .toString();
    _applyDocumentText(rawText);

    setState(() {
      _setIfPresent(
        _nameController,
        data['name'] ??
            data['holder_name'] ??
            data['nombre'] ??
            data['nombre_completo'],
      );
      _setIfPresent(
        _licenseTypeController,
        data['tipo_documento'] ?? data['document_type'],
      );
      _setIfPresent(
        _licenseController,
        data['license_number'] ??
            data['document_number'] ??
            data['numero_licencia'] ??
            data['numeroLicencia'],
      );
      _setIfPresent(
        _licenseCategoryController,
        data['license_category'] ??
            data['categoria_cargo'] ??
            data['category'] ??
            data['categoria'] ??
            data['cargo'],
      );
      _setIfPresent(
        _birthDateController,
        data['birth_date'] ?? data['fecha_nacimiento'],
      );
      _setIfPresent(
        _nationalityController,
        data['nationality'] ?? data['nacionalidad'],
      );
      _setIfPresent(
        _licenseIssueDateController,
        data['document_issue_date'] ??
            data['issue_date'] ??
            data['fecha_emision'],
      );
      _setIfPresent(
        _licenseExpirationController,
        data['document_expiration'] ??
            data['expiration_date'] ??
            data['fecha_vencimiento'],
      );
      _setIfPresent(
        _issuingCountryController,
        data['issuing_country'] ?? data['country'] ?? data['pais_emisor'],
      );
      _licenseStatusController.text = _documentStatus(
        _licenseExpirationController.text,
      );
      _scanStatus = 'scanned';
      _documentMessage =
          'Escaneo completado. Revisa los datos detectados antes de continuar.';
    });
  }

  void _applyDocumentFallback(File document) {
    _scanStatus = 'pending_manual_review';
    _scanRaw = _scanRaw.trim().isEmpty ? '' : _scanRaw;
    if (_licenseTypeController.text.trim().isEmpty) {
      _licenseTypeController.text = 'Licencia de sobrecargo';
    }
    final fileName = document.path.split(Platform.pathSeparator).last;
    if (_licenseController.text.trim().isEmpty) {
      final normalizedName = fileName.toUpperCase();
      final inferred = RegExp(
        r'\b[A-Z]{2,5}-?\d{4,12}\b',
      ).firstMatch(normalizedName)?.group(0);
      if (inferred != null && inferred.isNotEmpty) {
        _licenseController.text = inferred;
      }
    }
  }

  bool _hasUsefulLicenseData() {
    return _licenseController.text.trim().isNotEmpty ||
        _licenseCategoryController.text.trim().isNotEmpty ||
        _licenseIssueDateController.text.trim().isNotEmpty ||
        _licenseExpirationController.text.trim().isNotEmpty ||
        _nationalityController.text.trim().isNotEmpty;
  }

  Future<void> _submit() async {
    if (_passwordController.text != _passwordConfirmationController.text) {
      _showMessage('Las contraseñas no coinciden.');
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
      base: _baseLabelForBackend(),
      baseAirportCode: _selectedBaseAirportCode(),
      birthDate: birthDateInputToIso(_birthDateController.text),
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
    if (_document == null) {
      _showMessage('Sube la licencia de sobrecargo.');
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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isProfileStep = _currentStep == 0;
    final progressLabel = isProfileStep ? 'Paso 1 de 4' : 'Paso 2 de 4';
    final progressSubtitle =
        isProfileStep ? '25% completado' : '50% completado';
    final progressValue = isProfileStep ? .25 : .50;

    return Scaffold(
      backgroundColor: const Color(0xFF030913),
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
            Positioned(
              top: 120,
              right: -30,
              child: _CrewGlow(size: 220, color: const Color(0x1FD9A84F)),
            ),
            Positioned(
              top: 320,
              left: -50,
              child: _CrewGlow(size: 220, color: const Color(0x143E6DAA)),
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
                              _CrewCircleBackButton(
                                onTap: () => Navigator.maybePop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            isProfileStep
                                ? 'Registro sobrecargo'
                                : 'Cuenta operativa',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isProfileStep
                                ? 'Crea tu acceso operativo y valida tu licencia profesional.'
                                : 'Define tu correo y credenciales para entrar al panel operativo.',
                            style: const TextStyle(
                              color: Color(0xFFC0C8D2),
                              fontSize: 17,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _CrewPremiumHero(
                            progress: progressValue,
                            progressText: 'Registro',
                          ),
                          const SizedBox(height: 18),
                          _CrewPremiumStepper(
                            activeStep: isProfileStep ? 0 : 1,
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
                            child:
                                isProfileStep
                                    ? _CrewGlassCard(
                                      key: const ValueKey('crew-profile'),
                                      title: 'Datos del tripulante',
                                      subtitle:
                                          'Informacion personal para generar tu acceso operativo.',
                                      icon: Icons.person_outline_rounded,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _field(
                                            _nameController,
                                            'Nombre completo',
                                          ),
                                          _field(
                                            _phoneController,
                                            'Telefono',
                                            keyboard: TextInputType.phone,
                                          ),
                                          _baseField(),
                                          _field(
                                            _birthDateController,
                                            'Fecha de nacimiento',
                                            hint: 'DD / MM / AAAA',
                                          ),
                                          _nationalityField('Nacionalidad'),
                                          const SizedBox(height: 18),
                                          const _CrewSubsectionTitle(
                                            title: 'Licencia de sobrecargo',
                                          ),
                                          const SizedBox(height: 12),
                                          _CrewUploadZone(
                                            loaded: _document != null,
                                            loading: _readingDocument,
                                            fileName:
                                                _document?.path
                                                    .split(
                                                      Platform.pathSeparator,
                                                    )
                                                    .last,
                                            onTap: _pickDocument,
                                          ),
                                          if (_documentMessage.isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            _CrewInlineNote(_documentMessage),
                                          ],
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _field(
                                                  _licenseTypeController,
                                                  'Tipo de licencia',
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: _field(
                                                  _licenseController,
                                                  'Numero',
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _field(
                                                  _licenseCategoryController,
                                                  'Categoria',
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: _field(
                                                  _licenseIssueDateController,
                                                  'Fecha emision',
                                                  hint: 'AAAA-MM-DD',
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _field(
                                                  _licenseExpirationController,
                                                  'Vigencia',
                                                  hint: 'AAAA-MM-DD',
                                                  onChanged:
                                                      () =>
                                                          _licenseStatusController
                                                                  .text =
                                                              _documentStatus(
                                                                _licenseExpirationController
                                                                    .text,
                                                              ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: _field(
                                                  _issuingCountryController,
                                                  'Pais emisor',
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _field(
                                                  _licenseStatusController,
                                                  'Estado',
                                                  requiredField: false,
                                                ),
                                              ),
                                              const Expanded(child: SizedBox()),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          const _CrewValidationCard(),
                                          const SizedBox(height: 16),
                                          const _CrewBenefitsRow(),
                                        ],
                                      ),
                                    )
                                    : _CrewGlassCard(
                                      key: const ValueKey('crew-access'),
                                      title: 'Cuenta',
                                      subtitle:
                                          'Correo y contrasena para tu acceso privado.',
                                      icon: Icons.lock_outline_rounded,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _field(
                                            _emailController,
                                            'Correo',
                                            keyboard:
                                                TextInputType.emailAddress,
                                          ),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton.icon(
                                              onPressed: _generatePassword,
                                              icon: const Icon(
                                                Icons.auto_fix_high_rounded,
                                              ),
                                              label: const Text(
                                                'Generar contrasena',
                                              ),
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
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            activeThumbColor: const Color(
                                              0xFFD8B15D,
                                            ),
                                            value: _passwordVisible,
                                            onChanged:
                                                (value) => setState(
                                                  () =>
                                                      _passwordVisible = value,
                                                ),
                                          ),
                                          _field(
                                            _passwordConfirmationController,
                                            'Confirmar contrasena',
                                            obscure:
                                                !_passwordConfirmationVisible,
                                            minLength: 8,
                                          ),
                                          SwitchListTile.adaptive(
                                            contentPadding: EdgeInsets.zero,
                                            title: const Text(
                                              'Mostrar confirmacion',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            activeThumbColor: const Color(
                                              0xFFD8B15D,
                                            ),
                                            value: _passwordConfirmationVisible,
                                            onChanged:
                                                (value) => setState(
                                                  () =>
                                                      _passwordConfirmationVisible =
                                                          value,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
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
      bottomNavigationBar: _CrewFooterBar(
        progressLabel: progressLabel,
        progressSubtitle: progressSubtitle,
        progress: progressValue,
        loading: auth.isLoading,
        buttonLabel: isProfileStep ? 'Continuar' : 'Crear cuenta',
        onPressed:
            auth.isLoading
                ? null
                : () {
                  if (isProfileStep) {
                    _continueToAccess();
                  } else if (_formKey.currentState!.validate()) {
                    _submit();
                  }
                },
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
        'Captura tus datos, sube la licencia y revisa la informacion detectada.',
      ),
      _field(_nameController, 'Nombre completo'),
      _field(_phoneController, 'Telefono', keyboard: TextInputType.phone),
      _baseField(),
      _field(
        _birthDateController,
        'Fecha de nacimiento',
        hint: 'DD / MM / AAAA',
      ),
      _nationalityField('Nacionalidad del titular'),
      const SizedBox(height: 14),
      const _SectionLabel(
        icon: Icons.workspace_premium_rounded,
        title: 'Licencia de sobrecargo',
      ),
      _FileButton(
        title:
            _document == null
                ? 'Subir licencia de sobrecargo'
                : 'Cambiar licencia',
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
        onChanged:
            () =>
                _licenseStatusController.text = _documentStatus(
                  _licenseExpirationController.text,
                ),
      ),
      _field(_issuingCountryController, 'Pais emisor'),
      _field(
        _licenseStatusController,
        'Estado del documento',
        requiredField: false,
      ),
    ];
  }

  List<Widget> _accessStep() {
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
    ];
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    bool obscure = false,
    int minLength = 1,
    TextInputType? keyboard,
    bool requiredField = true,
    VoidCallback? onChanged,
  }) {
    final isBirthDateField = identical(controller, _birthDateController);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: isBirthDateField ? TextInputType.number : keyboard,
        inputFormatters:
            isBirthDateField
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
          filled: true,
          fillColor: const Color(0x70101925),
          prefixIcon: _iconForLabel(label),
          labelStyle: const TextStyle(color: Color(0xFFD0D6DF)),
          hintStyle: const TextStyle(color: Color(0xFF6F7B8A)),
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
            borderSide: const BorderSide(color: Color(0xFFD8B15D), width: 1.4),
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
        items:
            options
                .map(
                  (option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
        onChanged: (value) {
          _nationalityController.text = value?.trim() ?? '';
        },
        dropdownColor: const Color(0xFF101925),
        iconEnabledColor: const Color(0xFFD8B15D),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Selecciona una nacionalidad',
          filled: true,
          fillColor: const Color(0x70101925),
          prefixIcon: _iconForLabel(label),
          labelStyle: const TextStyle(color: Color(0xFFD0D6DF)),
          hintStyle: const TextStyle(color: Color(0xFF6F7B8A)),
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
            borderSide: const BorderSide(color: Color(0xFFD8B15D), width: 1.4),
          ),
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (!requiredField) return null;
          if (text.isEmpty) return 'Completa $label.';
          return null;
        },
      ),
    );
  }

  Widget _baseField() {
    if (_airports.isEmpty) {
      return _field(
        _baseController,
        'Base operativa',
        hint:
            _loadingAirports
                ? 'Cargando bases operativas...'
                : 'Escribe la base operativa',
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Autocomplete<Airport>(
        optionsBuilder: (textEditingValue) {
          final query = textEditingValue.text.trim().toLowerCase();
          if (query.isEmpty) {
            return _airports.take(8);
          }
          return _airports
              .where((airport) {
                return airport.city.toLowerCase().contains(query) ||
                    airport.name.toLowerCase().contains(query) ||
                    (airport.state ?? '').toLowerCase().contains(query) ||
                    (airport.iata ?? '').toLowerCase().contains(query) ||
                    (airport.icao ?? '').toLowerCase().contains(query);
              })
              .take(12);
        },
        displayStringForOption: _airportDisplayLabel,
        onSelected: (airport) {
          _selectedBaseAirport = airport;
          _baseController.text = _airportDisplayLabel(airport);
        },
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          if (controller.text != _baseController.text) {
            controller.value = TextEditingValue(
              text: _baseController.text,
              selection: TextSelection.collapsed(
                offset: _baseController.text.length,
              ),
            );
          }
          return TextFormField(
            controller: controller,
            focusNode: focusNode,
            onChanged: (value) {
              _baseController.text = value;
              _selectedBaseAirport = _resolveAirportFromText(value);
            },
            decoration: InputDecoration(
              labelText: 'Base operativa',
              hintText: 'Buscar aeropuerto, ciudad o codigo',
              filled: true,
              fillColor: const Color(0x70101925),
              prefixIcon: _iconForLabel('Base operativa'),
              labelStyle: const TextStyle(color: Color(0xFFD0D6DF)),
              hintStyle: const TextStyle(color: Color(0xFF6F7B8A)),
              suffixIcon:
                  _loadingAirports
                      ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                      : null,
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
                borderSide: const BorderSide(
                  color: Color(0xFFD8B15D),
                  width: 1.4,
                ),
              ),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Completa Base operativa.';
              return null;
            },
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: const Color(0xF4101925),
              borderRadius: BorderRadius.circular(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 280,
                  minWidth: 280,
                  maxWidth: 520,
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final airport = options.elementAt(index);
                    final code =
                        airport.iata?.trim().isNotEmpty == true
                            ? airport.iata!.trim().toUpperCase()
                            : airport.icao?.trim().toUpperCase() ?? '';
                    return ListTile(
                      leading: const Icon(Icons.flight_rounded),
                      title: Text(
                        airport.city,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        [
                          airport.name,
                          if ((airport.state ?? '').trim().isNotEmpty)
                            airport.state!.trim(),
                          if (code.isNotEmpty) code,
                        ].join(' • '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFFB7C0CB)),
                      ),
                      onTap: () => onSelected(airport),
                    );
                  },
                ),
              ),
            ),
          );
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
    if (normalized.contains('base')) {
      return const Icon(Icons.flight_land_rounded, color: active);
    }
    if (normalized.contains('fecha')) {
      return const Icon(Icons.event_rounded, color: active);
    }
    if (normalized.contains('licencia') || normalized.contains('numero')) {
      return const Icon(Icons.badge_rounded, color: active);
    }
    if (normalized.contains('pais') || normalized.contains('nacionalidad')) {
      return const Icon(Icons.public_rounded, color: active);
    }
    if (normalized.contains('contrasena')) {
      return const Icon(Icons.lock_rounded, color: active);
    }
    return const Icon(Icons.person_outline_rounded, color: active);
  }

  String _airportDisplayLabel(Airport airport) {
    final code =
        airport.iata?.trim().isNotEmpty == true
            ? airport.iata!.trim().toUpperCase()
            : airport.icao?.trim().toUpperCase() ?? '';
    if (code.isNotEmpty) {
      return '${airport.city} - $code';
    }
    return '${airport.city} - ${airport.name}';
  }

  String _selectedBaseAirportCode() {
    final icao = _selectedBaseAirport?.icao?.trim().toUpperCase() ?? '';
    if (icao.isNotEmpty) return icao;
    return _selectedBaseAirport?.iata?.trim().toUpperCase() ?? '';
  }

  String _baseLabelForBackend() {
    if (_selectedBaseAirport == null) {
      return _baseController.text.trim();
    }
    final city = _selectedBaseAirport!.city.trim();
    if (city.isNotEmpty) return city;
    return _baseController.text.trim();
  }

  void _syncBaseSelection() {
    _selectedBaseAirport = _resolveAirportFromText(_baseController.text);
  }

  Airport? _resolveAirportFromText(String text) {
    final query = _normalizeAirportSearch(text);
    if (query.isEmpty || _airports.isEmpty) return null;

    for (final airport in _airports) {
      final icao = airport.icao?.trim().toUpperCase() ?? '';
      final iata = airport.iata?.trim().toUpperCase() ?? '';
      final city = airport.city.trim().toUpperCase();
      final name = airport.name.trim().toUpperCase();
      final label = _airportDisplayLabel(airport).toUpperCase();

      if (query == icao ||
          query == iata ||
          query == city ||
          query == label ||
          query == '$city - $icao' ||
          query == '$city - $iata' ||
          query == name) {
        return airport;
      }
    }

    for (final airport in _airports) {
      final haystack = [
        airport.city,
        airport.name,
        airport.state ?? '',
        airport.iata ?? '',
        airport.icao ?? '',
        _airportDisplayLabel(airport),
      ].map(_normalizeAirportSearch).join(' ');
      if (haystack.contains(query)) return airport;
    }

    return null;
  }

  String _normalizeAirportSearch(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  void _showMessage(String message) {
    final lower = message.toLowerCase();
    final isError =
        lower.contains('no ') ||
        lower.contains('sube') ||
        lower.contains('completa') ||
        lower.contains('coinciden');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
          backgroundColor:
              isError ? const Color(0xFFC55252) : const Color(0xFF101925),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
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

  String _normalizeOcrLine(String value) {
    const replacements = {
      'Á': 'A',
      'É': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ú': 'U',
      'Ü': 'U',
      'Ñ': 'N',
    };
    var normalized = value.toUpperCase();
    replacements.forEach((source, target) {
      normalized = normalized.replaceAll(source, target);
    });
    return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _extractCrewLicenseNumber(List<String> lines) {
    for (final line in lines) {
      final match = RegExp(
        r'\b\d{6,}(?:-\d{2,})?\b',
      ).firstMatch(line)?.group(0);
      if (match != null && !_looksLikeDate(match)) {
        return match;
      }
    }
    return '';
  }

  String _extractCrewCategory(List<String> lines) {
    for (final line in lines) {
      if (line.contains('SOBRECARGO') || line.contains('CABIN CREW MEMBER')) {
        return _toTitle(
          line
              .replaceAll(RegExp(r'[^A-Z/ ]'), ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim(),
        );
      }
    }
    return '';
  }

  String _extractCrewName(List<String> lines) {
    final blacklist = <String>{
      'COMUNICACIONES',
      'AFAC',
      'LICENCIA',
      'FEDERAL',
      'AVIACION',
      'ESTADOS',
      'UNIDOS',
      'MEXICANOS',
      'PERSONAL',
      'TECNICO',
      'AERONAUTICO',
      'MEXICO',
      'MEXICANO',
      'MEXICAN',
      'VIGENCIA',
      'EXPIRATION',
      'CAMSCANNER',
      'FIRMA',
      'TITULAR',
      'CIUDAD',
    };

    final categoryIndex = lines.indexWhere(
      (line) =>
          line.contains('SOBRECARGO') || line.contains('CABIN CREW MEMBER'),
    );
    if (categoryIndex != -1) {
      for (var index = categoryIndex + 1; index < lines.length; index++) {
        final candidate = lines[index];
        if (_looksLikePersonName(candidate, blacklist)) {
          return _toTitle(candidate);
        }
      }
    }

    for (final line in lines) {
      if (_looksLikePersonName(line, blacklist)) {
        return _toTitle(line);
      }
    }
    return '';
  }

  bool _looksLikePersonName(String line, Set<String> blacklist) {
    if (line.length < 8) return false;
    if (RegExp(r'\d').hasMatch(line)) return false;
    final words = line.split(' ').where((word) => word.isNotEmpty).toList();
    if (words.length < 2 || words.length > 5) return false;
    if (words.any((word) => blacklist.contains(word))) return false;
    return words.every((word) => word.length > 1);
  }

  String _extractCrewBirthDate(List<String> lines) {
    for (final line in lines) {
      if (line.contains('VIGENCIA') || line.contains('EXPIRATION')) continue;
      final match = RegExp(
        r'\b(\d{2}/\d{2}/\d{4})\b',
      ).firstMatch(line)?.group(1);
      if (match != null) return match;
    }
    return '';
  }

  String _extractCrewExpirationDate(List<String> lines) {
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (line.contains('VIGENCIA') || line.contains('EXPIRATION')) {
        final sameLine = RegExp(
          r'\b(\d{2}/\d{2}/\d{4})\b',
        ).firstMatch(line)?.group(1);
        if (sameLine != null) return sameLine;
        if (index + 1 < lines.length) {
          final nextLine = RegExp(
            r'\b(\d{2}/\d{2}/\d{4})\b',
          ).firstMatch(lines[index + 1])?.group(1);
          if (nextLine != null) return nextLine;
        }
      }
    }
    return '';
  }

  String _extractCrewIssueDate(String text) {
    final slashDate = RegExp(
      r'(?:EXPEDICION|EMISION|ISSUE)[:\s-]*(\d{2}/\d{2}/\d{4})',
    ).firstMatch(text)?.group(1);
    if (slashDate != null) return slashDate;

    final writtenDate = RegExp(
      r'A\s+(\d{1,2})\s+DE\s+([A-Z]+)\s+DE\s+(\d{4})',
    ).firstMatch(text);
    if (writtenDate == null) return '';

    const months = {
      'ENERO': '01',
      'FEBRERO': '02',
      'MARZO': '03',
      'ABRIL': '04',
      'MAYO': '05',
      'JUNIO': '06',
      'JULIO': '07',
      'AGOSTO': '08',
      'SEPTIEMBRE': '09',
      'SETIEMBRE': '09',
      'OCTUBRE': '10',
      'NOVIEMBRE': '11',
      'DICIEMBRE': '12',
    };
    final day = writtenDate.group(1)!.padLeft(2, '0');
    final month = months[writtenDate.group(2)!];
    final year = writtenDate.group(3)!;
    if (month == null) return '';
    return '$year-$month-$day';
  }

  String _extractCrewNationality(List<String> lines) {
    for (final line in lines) {
      if (line.contains('MEXICANO') || line.contains('MEXICAN')) {
        return 'Mexicana';
      }
    }
    return '';
  }

  String _extractCrewIssuingCountry(List<String> lines) {
    for (final line in lines) {
      if (line.contains('ESTADOS UNIDOS MEXICANOS')) {
        return 'Mexico';
      }
    }
    for (final line in lines) {
      if (line == 'MEXICO') return 'Mexico';
    }
    return '';
  }

  bool _looksLikeDate(String value) {
    return RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(value) ||
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  void _setIfPresent(TextEditingController controller, dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) controller.text = text;
  }
}

enum _DocumentImageSource { camera, files }

class _CrewGlow extends StatelessWidget {
  const _CrewGlow({required this.size, required this.color});

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

class _CrewCircleBackButton extends StatelessWidget {
  const _CrewCircleBackButton({required this.onTap});

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

class _CrewPremiumHero extends StatelessWidget {
  const _CrewPremiumHero({
    required this.progress,
    this.progressText = 'Registro',
  });

  final double progress;
  final String progressText;

  @override
  Widget build(BuildContext context) {
    final progressPercent = (progress * 100).round().clamp(0, 100);
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
              alignment: Alignment.center,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xEF030B16),
                    Color(0xD4050F1A),
                    Color(0x6A040E18),
                  ],
                  stops: [0, .48, 1],
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: .24),
                  border: Border.all(color: const Color(0x44D8B15D), width: 5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$progressPercent%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      progressText,
                      style: TextStyle(
                        color: Color(0xFFD8E2EA),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Positioned(
              left: 18,
              right: 130,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ALTA OPERACIONAL',
                    style: TextStyle(
                      color: Color(0xFFF4D38B),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Sobrecargo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.7,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Registro profesional para operaciones privadas.',
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

class _CrewPremiumStepper extends StatelessWidget {
  const _CrewPremiumStepper({required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    const steps = ['Perfil', 'Cuenta', 'Verificacion', 'Listo'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0x99101924),
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
          return Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isActive
                          ? const Color(0x1AD8B15D)
                          : Colors.white.withValues(alpha: .03),
                  border: Border.all(
                    color:
                        isActive || isDone
                            ? const Color(0xFFD8B15D)
                            : const Color(0x28FFFFFF),
                  ),
                ),
                child: Center(
                  child: Text(
                    '${stepIndex + 1}',
                    style: TextStyle(
                      color:
                          isActive || isDone
                              ? const Color(0xFFD8B15D)
                              : const Color(0x88FFFFFF),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                steps[stepIndex],
                style: TextStyle(
                  color:
                      isActive
                          ? const Color(0xFFF4D38B)
                          : const Color(0x95FFFFFF),
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _CrewGlassCard extends StatelessWidget {
  const _CrewGlassCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: const Color(0xFFD8B15D), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFFC0C8D2),
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                      ],
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

class _CrewSubsectionTitle extends StatelessWidget {
  const _CrewSubsectionTitle({required this.title});

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

class _CrewUploadZone extends StatelessWidget {
  const _CrewUploadZone({
    required this.loaded,
    required this.loading,
    required this.fileName,
    required this.onTap,
  });

  final bool loaded;
  final bool loading;
  final String? fileName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0x66D8B15D),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.upload_file_rounded,
            color: Color(0xFFD8B15D),
            size: 38,
          ),
          const SizedBox(height: 12),
          Text(
            loaded ? 'Licencia cargada' : 'Subir licencia',
            style: const TextStyle(
              color: Color(0xFFD8B15D),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            loaded
                ? (fileName ?? 'Archivo listo')
                : 'Acepta JPG, PNG o PDF\nMaximo 10 MB.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFC0C8D2),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: loading ? null : onTap,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: const Color(0xFFD8B15D),
              foregroundColor: const Color(0xFF10141B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child:
                loading
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF10141B),
                      ),
                    )
                    : Text(
                      loaded ? 'Cambiar archivo' : 'Subir licencia',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
          ),
        ],
      ),
    );
  }
}

class _CrewInlineNote extends StatelessWidget {
  const _CrewInlineNote(this.message);

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

class _CrewValidationCard extends StatelessWidget {
  const _CrewValidationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x24FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.verified_user_outlined,
                color: Color(0xFFD8B15D),
                size: 22,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'La informacion sera validada automaticamente.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CrewBadge(label: 'OCR'),
              _CrewBadge(label: 'Validacion'),
              _CrewBadge(label: 'Seguridad'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CrewBadge extends StatelessWidget {
  const _CrewBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x14D8B15D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x45D8B15D)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFF4D38B),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CrewBenefitsRow extends StatelessWidget {
  const _CrewBenefitsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _CrewBenefitCard(title: 'Acceso operativo')),
        SizedBox(width: 10),
        Expanded(child: _CrewBenefitCard(title: 'Misiones privadas')),
        SizedBox(width: 10),
        Expanded(child: _CrewBenefitCard(title: 'Disponibilidad de vuelos')),
      ],
    );
  }
}

class _CrewBenefitCard extends StatelessWidget {
  const _CrewBenefitCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_rounded, color: Color(0xFFD8B15D), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
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

class _CrewFooterBar extends StatelessWidget {
  const _CrewFooterBar({
    required this.progressLabel,
    required this.progressSubtitle,
    required this.progress,
    required this.loading,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String progressLabel;
  final String progressSubtitle;
  final double progress;
  final bool loading;
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
          child: Row(
            children: [
              Expanded(
                child: Column(
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
                ),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: 186,
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
                              children: [
                                Text(
                                  buttonLabel,
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded),
                              ],
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
}

class _RegistrationProgress extends StatelessWidget {
  const _RegistrationProgress({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const labels = ['Perfil / Licencia', 'Correo / Contraseña'];
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
