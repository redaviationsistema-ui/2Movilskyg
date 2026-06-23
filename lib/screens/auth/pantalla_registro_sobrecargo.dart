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

import '../../core/cliente_api.dart';
import '../../models/aeropuerto.dart';
import '../../providers/proveedor_autenticacion.dart';
import '../../services/servicio_aeropuertos.dart';
import '../../services/servicio_ocr_registro.dart';
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
      type: FileType.image,
      allowMultiple: false,
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
        _birthDateController.text = _normalizeDate(birthDate);
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
        'Captura tus datos, sube la licencia y revisa la informacion detectada.',
      ),
      _field(_nameController, 'Nombre completo'),
      _field(_phoneController, 'Telefono', keyboard: TextInputType.phone),
      _baseField(),
      _field(_birthDateController, 'Fecha de nacimiento', hint: 'AAAA-MM-DD'),
      _field(_nationalityController, 'Nacionalidad del titular'),
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
          if (!requiredField) return null;
          if (text.length < minLength) return 'Completa $label.';
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
              fillColor: Colors.white,
              prefixIcon: _iconForLabel('Base operativa'),
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
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDDE6EE)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFE0B86E),
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
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
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
                      title: Text(airport.city),
                      subtitle: Text(
                        [
                          airport.name,
                          if ((airport.state ?? '').trim().isNotEmpty)
                            airport.state!.trim(),
                          if (code.isNotEmpty) code,
                        ].join(' • '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
