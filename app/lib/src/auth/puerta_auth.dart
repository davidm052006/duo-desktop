import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config_cloud.dart';
import '../pantallas/marco_app.dart';
import '../tema/paleta.dart';

class PuertaAuth extends StatefulWidget {
  const PuertaAuth({super.key});

  @override
  State<PuertaAuth> createState() => _PuertaAuthState();
}

class _PuertaAuthState extends State<PuertaAuth> {
  late final StreamSubscription<AuthState> _suscripcion;
  Session? _sesion;

  @override
  void initState() {
    super.initState();
    _sesion = Supabase.instance.client.auth.currentSession;
    _suscripcion = Supabase.instance.client.auth.onAuthStateChange.listen((evento) {
      if (!mounted) return;
      setState(() => _sesion = evento.session);
    });
  }

  @override
  void dispose() {
    unawaited(_suscripcion.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _sesion == null ? const _PantallaLogin() : const MarcoApp();
}

class _PantallaLogin extends StatefulWidget {
  const _PantallaLogin();

  @override
  State<_PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<_PantallaLogin> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _registro = false;
  bool _enviando = false;
  String? _error;
  String? _mensaje;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final email = _email.text.trim();
    final password = _password.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email y contraseña son obligatorios.');
      return;
    }

    setState(() {
      _enviando = true;
      _error = null;
      _mensaje = null;
    });

    try {
      if (_registro) {
        final respuesta = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: ConfigCloud.configurado
              ? ConfigCloud.endpoint('/auth/confirmed').toString()
              : null,
        );

        if (!mounted) return;
        if (respuesta.session == null) {
          setState(() {
            _mensaje =
                'Cuenta creada. Revisa tu email, confirma el acceso y luego vuelve a Duo Desktop para iniciar sesión.';
          });
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo completar el acceso: $e');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: paleta.panel,
                border: Border.all(color: paleta.rejilla),
                borderRadius: BorderRadius.circular(14),
              ),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.hub_outlined, color: paleta.acentoAlt),
                        const SizedBox(width: 10),
                        Text(
                          'DUO DESKTOP',
                          style: textos.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _registro ? 'Crear cuenta' : 'Iniciar sesión',
                      style: textos.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _registro
                          ? 'Crea tu identidad para participar en proyectos compartidos.'
                          : 'Accede a tus proyectos, tareas e historial compartido.',
                      style: textos.bodySmall?.copyWith(
                        color: paleta.tintaSecundaria,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _email,
                      enabled: !_enviando,
                      autofillHints: const [AutofillHints.email],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      enabled: !_enviando,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _enviando ? null : _enviar(),
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      _MensajeLogin(
                        texto: _error!,
                        icono: Icons.error_outline,
                        tono: paleta.critico,
                      ),
                    ],
                    if (_mensaje != null) ...[
                      const SizedBox(height: 14),
                      _MensajeLogin(
                        texto: _mensaje!,
                        icono: Icons.mark_email_read_outlined,
                        tono: paleta.bien,
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _enviando ? null : _enviar,
                      icon: _enviando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _registro
                                  ? Icons.person_add_alt_1
                                  : Icons.login,
                            ),
                      label: Text(
                        _enviando
                            ? 'Procesando…'
                            : (_registro ? 'Crear cuenta' : 'Entrar'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _enviando
                          ? null
                          : () => setState(() {
                              _registro = !_registro;
                              _error = null;
                              _mensaje = null;
                            }),
                      child: Text(
                        _registro
                            ? 'Ya tengo cuenta'
                            : 'Crear una cuenta nueva',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'La contraseña la gestiona Supabase Auth. Duo Desktop no la almacena.',
                      textAlign: TextAlign.center,
                      style: textos.bodySmall?.copyWith(
                        color: paleta.tintaTenue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MensajeLogin extends StatelessWidget {
  const _MensajeLogin({
    required this.texto,
    required this.icono,
    required this.tono,
  });

  final String texto;
  final IconData icono;
  final Color tono;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: tono.withValues(alpha: .08),
          border: Border.all(color: tono.withValues(alpha: .30)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 17, color: tono),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                texto,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
}
