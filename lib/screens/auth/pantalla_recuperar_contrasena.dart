import 'package:flutter/material.dart';

import '../../core/cliente_api.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key, this.email = '', this.token = ''});

  final String email;
  final String token;

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _message;
  Map<String, dynamic> _fieldErrors = const {};

  bool get _isReset => widget.token.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.email);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
      _fieldErrors = const {};
    });
    try {
      final response =
          _isReset
              ? await ApiClient.instance.resetPassword(
                email: _email.text,
                token: widget.token,
                password: _password.text,
              )
              : await ApiClient.instance.forgotPassword(_email.text);
      if (!mounted) return;
      setState(() {
        _message =
            response['message']?.toString() ??
            (_isReset
                ? 'Contraseña actualizada correctamente.'
                : 'Si el correo existe, recibirás instrucciones.');
      });
      if (_isReset) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message;
        _fieldErrors =
            error.payload?['errors'] is Map
                ? Map<String, dynamic>.from(error.payload!['errors'] as Map)
                : const {};
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _backendError(String field) {
    final value = _fieldErrors[field];
    if (value is List && value.isNotEmpty) return value.first.toString();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isReset ? 'Nueva contraseña' : 'Recuperar acceso'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              _isReset
                  ? 'Crea una contraseña nueva para tu cuenta.'
                  : 'Te enviaremos instrucciones si el correo está registrado.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _email,
                    readOnly: _isReset && widget.email.isNotEmpty,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Correo electrónico',
                      errorText: _backendError('email'),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (!RegExp(r'^.+@.+\..+$').hasMatch(text)) {
                        return 'Ingresa un correo válido.';
                      }
                      return null;
                    },
                  ),
                  if (_isReset) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Nueva contraseña',
                        errorText: _backendError('password'),
                      ),
                      validator:
                          (value) =>
                              (value?.length ?? 0) < 8
                                  ? 'Usa al menos 8 caracteres.'
                                  : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmation,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar contraseña',
                      ),
                      validator:
                          (value) =>
                              value != _password.text
                                  ? 'Las contraseñas no coinciden.'
                                  : null,
                    ),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 18),
                    Semantics(liveRegion: true, child: Text(_message!)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(
                        _busy
                            ? 'Procesando…'
                            : _isReset
                            ? 'Restablecer contraseña'
                            : 'Enviar instrucciones',
                      ),
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
