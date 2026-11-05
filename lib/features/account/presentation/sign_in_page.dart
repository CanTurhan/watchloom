import 'package:flutter/material.dart';
import 'package:watchloom/core/localization/app_strings.dart';
import 'package:watchloom/core/localization/app_account_strings.dart';
import 'package:watchloom/core/localization/app_settings_strings.dart';
import 'package:watchloom/core/theme/app_colors.dart';
import 'package:watchloom/features/account/presentation/auth_controller.dart';
import 'package:watchloom/features/settings/presentation/legal_page.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({required this.auth, super.key});
  final AuthController auth;
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _create = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final strings = AppStrings.of(context);
    await widget.auth.email(
      email: _email.text,
      password: _password.text,
      create: _create,
      language: strings.languageCode,
    );
    // The session root removes this route once authentication succeeds.
  }

  Future<void> _reset() async {
    final strings = AppStrings.of(context);
    if (!_email.text.trim().contains('@')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.emailInvalid)));
      return;
    }
    final sent = await widget.auth.resetPassword(
      _email.text,
      strings.languageCode,
    );
    if (sent && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.resetSent)));
    }
  }

  void _legal(bool privacy) {
    final s = AppStrings.of(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalPage(
          title: privacy ? s.privacyPolicy : s.termsOfUse,
          body: privacy ? s.privacyBody : s.termsBody,
          links: privacy ? LegalPage.privacyLinks(s) : LegalPage.termsLinks(s),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Watchloom')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.auth,
          builder: (context, _) {
            final auth = widget.auth;
            final enabled = auth.available && !auth.busy;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.live_tv_rounded,
                          size: 38,
                          color: AppColors.accentSoft,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      s.signInTitle,
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.signInBody,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    OutlinedButton.icon(
                      onPressed: enabled ? auth.apple : null,
                      icon: const Icon(Icons.apple, size: 24),
                      label: Text(s.appleSignIn),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: enabled ? auth.google : null,
                      icon: const GoogleBrandIcon(),
                      label: Text(s.googleSignIn),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: const Color(0xff131314),
                        foregroundColor: const Color(0xffe3e3e3),
                        side: const BorderSide(color: Color(0xff8e918f)),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 22),
                      child: Divider(),
                    ),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(value: false, label: Text(s.signIn)),
                        ButtonSegment(
                          value: true,
                          label: Text(s.createAccount),
                        ),
                      ],
                      selected: {_create},
                      onSelectionChanged: auth.busy
                          ? null
                          : (value) {
                              setState(() {
                                _create = value.single;
                              });
                            },
                    ),
                    const SizedBox(height: 20),
                    AutofillGroup(
                      child: Form(
                        key: _form,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _email,
                              enabled: !auth.busy,
                              decoration: InputDecoration(
                                labelText: s.emailLabel,
                                prefixIcon: const Icon(
                                  Icons.alternate_email_rounded,
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textCapitalization: TextCapitalization.none,
                              autocorrect: false,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: TextInputAction.next,
                              validator: (value) =>
                                  RegExp(
                                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                  ).hasMatch(value?.trim() ?? '')
                                  ? null
                                  : s.emailInvalid,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _password,
                              enabled: !auth.busy,
                              obscureText: _obscure,
                              autocorrect: false,
                              enableSuggestions: false,
                              decoration: InputDecoration(
                                labelText: s.passwordLabel,
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() {
                                    _obscure = !_obscure;
                                  }),
                                  tooltip: s.value(
                                    en: 'Show or hide password',
                                    tr: 'Parolayı göster veya gizle',
                                  ),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              autofillHints: [
                                _create
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password,
                              ],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (enabled) _submit();
                              },
                              validator: (value) => (value ?? '').isEmpty
                                  ? s.passwordRequired
                                  : _create && value!.length < 8
                                  ? s.passwordInvalid
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!_create)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: enabled ? _reset : null,
                          child: Text(s.forgotPassword),
                        ),
                      ),
                    const SizedBox(height: 14),
                    if (!auth.available)
                      Text(
                        s.authUnavailable,
                        style: const TextStyle(color: AppColors.orange),
                      ),
                    if (auth.errorCode != null && auth.available)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            s.authError(auth.errorCode),
                            style: const TextStyle(color: AppColors.orange),
                          ),
                        ),
                      ),
                    FilledButton(
                      onPressed: enabled ? _submit : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: auth.busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_create ? s.createAccount : s.signIn),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      s.authConsent,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => _legal(true),
                          child: Text(s.privacyPolicy),
                        ),
                        TextButton(
                          onPressed: () => _legal(false),
                          child: Text(s.termsOfUse),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: auth.busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(s.guestContinue),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Official GoogleSignIn SDK asset; original geometry and colours are preserved.
class GoogleBrandIcon extends StatelessWidget {
  const GoogleBrandIcon({super.key});
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/branding/google.png',
    width: 20,
    height: 20,
    excludeFromSemantics: true,
  );
}
