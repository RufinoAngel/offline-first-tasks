import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.auth});
  final AuthService auth;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _loading = false;
  bool _register = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_register) {
        await widget.auth.register(_email.text, _password.text);
      } else {
        await widget.auth.signIn(_email.text, _password.text);
      }
    } on FirebaseAuthException catch (e) {
      _error = _friendly(e.code);
    } catch (e) {
      debugPrint('Error en autenticación/preparación de sesión: $e');
      _error = _register
          ? 'No se pudo preparar tu cuenta. Inténtalo de nuevo.'
          : 'No se pudo iniciar sesión. Revisa tu conexión e inténtalo de nuevo.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendly(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Correo inválido.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Ese correo ya está registrado.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'network-request-failed':
        return 'Sin conexión. Para crear la cuenta o iniciar sesión necesitas Internet.';
      case 'too-many-requests':
        return 'Hubo demasiados intentos. Espera un momento y vuelve a probar.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada. Contacta con soporte.';
      case 'operation-not-allowed':
        return 'El acceso con correo y contraseña no está habilitado.';
      default:
        return 'Error de autenticación ($code).';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned(
            top: -110,
            right: -80,
            child: _DecorativeCircle(size: 280, color: Color(0xFFE2EEE4)),
          ),
          const Positioned(
            bottom: -155,
            left: -120,
            child: _DecorativeCircle(size: 330, color: Color(0xFFE8F0E7)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _BrandHeader(),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(26),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xFFE8EDE7)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14183D31),
                              blurRadius: 32,
                              offset: Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                    value: false,
                                    label: Text('Iniciar sesión'),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    label: Text('Crear cuenta'),
                                  ),
                                ],
                                selected: {_register},
                                onSelectionChanged: _loading
                                    ? null
                                    : (selection) => setState(() {
                                          _register = selection.first;
                                          _error = null;
                                        }),
                                showSelectedIcon: false,
                              ),
                              const SizedBox(height: 26),
                              Text(
                                _register
                                    ? 'Empieza con calma.'
                                    : 'Qué gusto verte.',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: const Color(0xFF183D31),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                _register
                                    ? 'Crea tu espacio personal para organizar tus tareas.'
                                    : 'Organiza tus tareas y continúa justo donde lo dejaste.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF718078),
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                autocorrect: false,
                                enabled: !_loading,
                                decoration: const InputDecoration(
                                  labelText: 'Correo electrónico',
                                  prefixIcon: Icon(Icons.alternate_email),
                                ),
                                validator: (value) {
                                  final email = value?.trim() ?? '';
                                  if (email.isEmpty) {
                                    return 'Escribe tu correo.';
                                  }
                                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                      .hasMatch(email)) {
                                    return 'Escribe un correo válido.';
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) =>
                                    _passwordFocus.requestFocus(),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _password,
                                focusNode: _passwordFocus,
                                obscureText: !_showPassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: [
                                  _register
                                      ? AutofillHints.newPassword
                                      : AutofillHints.password,
                                ],
                                enabled: !_loading,
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _showPassword
                                        ? 'Ocultar contraseña'
                                        : 'Mostrar contraseña',
                                    onPressed: () => setState(
                                        () => _showPassword = !_showPassword),
                                    icon: Icon(_showPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined),
                                  ),
                                ),
                                validator: (value) {
                                  final password = value ?? '';
                                  if (password.isEmpty) {
                                    return 'Escribe tu contraseña.';
                                  }
                                  if (_register && password.length < 6) {
                                    return 'Usa al menos 6 caracteres.';
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) => _submit(),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colors.errorContainer,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.error_outline,
                                          color: colors.onErrorContainer,
                                          size: 20),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: TextStyle(
                                              color: colors.onErrorContainer),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 22),
                              FilledButton(
                                onPressed: _loading ? null : _submit,
                                child: _loading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(_register
                                        ? 'Crear mi cuenta'
                                        : 'Iniciar sesión'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.offline_bolt_outlined,
                              size: 17, color: Color(0xFF5C796A)),
                          SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              'Tus tareas se guardan primero en este dispositivo.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Color(0xFF718078), fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF1F5A45),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x291F5A45),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.spa_outlined, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 12),
        Text(
          'VERDE',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF1F5A45),
                fontWeight: FontWeight.w800,
                letterSpacing: 3.2,
              ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Tareas, a tu ritmo',
          style: TextStyle(
            color: Color(0xFF718078),
            fontSize: 13,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
