import 'package:flutter/material.dart';
import '../../theme/design_system_context.dart';
import '../../tokens/app_icons.dart';
import '../../tokens/app_typography.dart';
import '_app_field_chrome.dart';

/// Campo de data do Design System — mesma casca visual de [AppTextField]/
/// [AppSelect]; o que muda é só a interação (toca, abre o seletor nativo
/// de data do Flutter). Não sabe nada sobre domínio (data mínima/máxima,
/// obrigatoriedade são decisão de quem usa o campo).
///
/// Exemplo:
/// ```dart
/// AppDateField(
///   label: 'Data de nascimento',
///   value: _dataNascimento,
///   firstDate: DateTime(1900),
///   lastDate: DateTime.now(),
///   onChanged: (data) => setState(() => _dataNascimento = data),
///   validator: (v) => v == null ? 'Informe a data de nascimento' : null,
/// )
/// ```
class AppDateField extends FormField<DateTime> {
  AppDateField({
    super.key,
    required String label,
    required DateTime firstDate,
    required DateTime lastDate,
    DateTime? value,
    String dateFormatPattern = 'dd/MM/yyyy',
    String placeholder = 'Selecionar',
    super.enabled,
    ValueChanged<DateTime?>? onChanged,
    super.validator,
    AutovalidateMode autovalidateMode = AutovalidateMode.onUserInteraction,
  }) : super(
         initialValue: value,
         autovalidateMode: autovalidateMode,
         builder: (field) {
           return Builder(
             builder: (context) {
               final colors = context.colors;
               // Docs/27: mesmo critério de AppTextField/AppSelect —
               // `inputText` (16px) só em telas de toque.
               final textStyle = context.isTouch ? AppTypography.inputText : AppTypography.bodyMedium;
               return AppFieldFocusTracker(
                 builder: (isFocused) => AppFieldChrome(
                   label: label,
                   errorText: field.errorText,
                   prefixIcon: AppIcons.calendar,
                   focused: isFocused,
                   enabled: enabled,
                   child: InkWell(
                     onTap: enabled
                         ? () async {
                             final selecionada = await showDatePicker(
                               context: context,
                               initialDate: field.value ?? lastDate,
                               firstDate: firstDate,
                               lastDate: lastDate,
                             );
                             if (selecionada != null) {
                               field.didChange(selecionada);
                               onChanged?.call(selecionada);
                             }
                           }
                         : null,
                     child: Text(
                       field.value != null
                           ? _formatar(field.value!, dateFormatPattern)
                           : placeholder,
                       style: textStyle.copyWith(
                         color: field.value != null ? colors.text : colors.textFaint,
                       ),
                     ),
                   ),
                 ),
               );
             },
           );
         },
       );

  @override
  FormFieldState<DateTime> createState() => FormFieldState<DateTime>();

  // Formatação mínima e sem dependência de `intl` (o Design System não
  // depende de `intl`; quem precisar de padrões de data mais ricos formata
  // fora e usa outro componente) — só dd/MM/yyyy, o único formato pedido.
  static String _formatar(DateTime data, String pattern) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString().padLeft(4, '0');
    return pattern.replaceFirst('dd', dia).replaceFirst('MM', mes).replaceFirst('yyyy', ano);
  }
}
