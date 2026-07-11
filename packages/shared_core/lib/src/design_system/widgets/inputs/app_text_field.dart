import 'package:flutter/material.dart';
import '../../theme/design_system_context.dart';
import '../../tokens/app_typography.dart';
import '_app_field_chrome.dart';

/// Campo de texto do Design System — único campo de texto do produto,
/// substitui todo `TextFormField`/`TextField` cru numa tela de feature.
///
/// **Não sabe nada sobre domínio.** Validação (CPF, e-mail, obrigatório
/// etc.) é responsabilidade de quem usa o campo, via [validator] — mesmo
/// contrato do `TextFormField` do Flutter, então participa normalmente de
/// um `Form`/`GlobalKey<FormState>` já existente.
///
/// Exemplo:
/// ```dart
/// AppTextField(
///   label: 'CPF',
///   controller: _cpfController,
///   validator: (v) => isValidCPF(v) ? null : 'CPF inválido',
/// )
/// ```
class AppTextField extends FormField<String> {
  AppTextField({
    super.key,
    required String label,
    TextEditingController? controller,
    String? hintText,
    String? helperText,
    IconData? prefixIcon,
    bool obscureText = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    super.enabled,
    ValueChanged<String>? onChanged,
    super.validator,
    AutovalidateMode autovalidateMode = AutovalidateMode.onUserInteraction,
  }) : super(
         initialValue: controller?.text,
         autovalidateMode: autovalidateMode,
         builder: (field) {
           return Builder(
             builder: (context) {
               final colors = context.colors;
               return _FocusTrackingField(
                 builder: (isFocused) => AppFieldChrome(
                   label: label,
                   errorText: field.errorText,
                   helperText: helperText,
                   prefixIcon: prefixIcon,
                   focused: isFocused,
                   enabled: enabled,
                   child: TextField(
                     controller: controller,
                     enabled: enabled,
                     obscureText: obscureText,
                     maxLines: maxLines,
                     keyboardType: keyboardType,
                     style: AppTypography.bodyMedium.copyWith(color: colors.text),
                     cursorColor: colors.primary,
                     decoration: InputDecoration(
                       border: InputBorder.none,
                       isDense: true,
                       isCollapsed: true,
                       hintText: hintText,
                       hintStyle: AppTypography.bodyMedium.copyWith(color: colors.textFaint),
                     ),
                     onChanged: (value) {
                       field.didChange(value);
                       onChanged?.call(value);
                     },
                   ),
                 ),
               );
             },
           );
         },
       );

  @override
  FormFieldState<String> createState() => FormFieldState<String>();
}

/// Rastreia foco pra acender a borda no tom de marca — sem isso, o
/// `AppFieldChrome` nunca saberia que o `TextField` interno ganhou foco.
class _FocusTrackingField extends StatefulWidget {
  final Widget Function(bool isFocused) builder;

  const _FocusTrackingField({required this.builder});

  @override
  State<_FocusTrackingField> createState() => _FocusTrackingFieldState();
}

class _FocusTrackingFieldState extends State<_FocusTrackingField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: widget.builder(_isFocused),
    );
  }
}
