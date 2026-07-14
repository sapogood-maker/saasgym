import 'package:flutter/material.dart';
import '../../theme/design_system_context.dart';
import '../../tokens/app_icons.dart';
import '../../tokens/app_typography.dart';
import '_app_field_chrome.dart';

/// Uma opção de [AppSelect].
class AppSelectOption<T> {
  final T value;
  final String label;

  const AppSelectOption({required this.value, required this.label});
}

/// Select/dropdown do Design System — genérico em `T`, não sabe nada sobre
/// domínio (status de aluno, sexo, ou qualquer enum futuro são só uma
/// lista de [AppSelectOption] que a tela decide).
///
/// Exemplo:
/// ```dart
/// AppSelect<UserStatus?>(
///   label: 'Status',
///   value: _statusFiltro,
///   options: const [
///     AppSelectOption(value: null, label: 'Todos'),
///     AppSelectOption(value: UserStatus.ativo, label: 'Ativos'),
///   ],
///   onChanged: (v) => setState(() => _statusFiltro = v),
/// )
/// ```
class AppSelect<T> extends FormField<T> {
  AppSelect({
    super.key,
    required String label,
    required List<AppSelectOption<T>> options,
    T? value,
    String? helperText,
    super.enabled,
    ValueChanged<T?>? onChanged,
    super.validator,
    AutovalidateMode autovalidateMode = AutovalidateMode.onUserInteraction,
  }) : super(
         initialValue: value,
         autovalidateMode: autovalidateMode,
         builder: (field) {
           return Builder(
             builder: (context) {
               final colors = context.colors;
               return AppFieldFocusTracker(
                 builder: (isFocused) => AppFieldChrome(
                   label: label,
                   errorText: field.errorText,
                   helperText: helperText,
                   focused: isFocused,
                   enabled: enabled,
                   child: DropdownButtonHideUnderline(
                     child: DropdownButton<T>(
                       value: field.value,
                       isExpanded: true,
                       isDense: true,
                       icon: Icon(AppIcons.chevronDown, size: 16, color: colors.textFaint),
                       dropdownColor: colors.card,
                       borderRadius: BorderRadius.circular(10),
                       style: AppTypography.bodyMedium.copyWith(color: colors.text),
                       items: [
                         for (final option in options)
                           DropdownMenuItem<T>(value: option.value, child: Text(option.label)),
                       ],
                       onChanged: enabled
                           ? (newValue) {
                               field.didChange(newValue);
                               onChanged?.call(newValue);
                             }
                           : null,
                     ),
                   ),
                 ),
               );
             },
           );
         },
       );

  @override
  FormFieldState<T> createState() => FormFieldState<T>();
}
