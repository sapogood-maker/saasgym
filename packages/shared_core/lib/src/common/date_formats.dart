import 'package:intl/intl.dart';

/// `dd/MM/yyyy` cacheado — antes reconstruído a cada chamada em algumas
/// telas e duplicado como constante de módulo em outras 6; centralizado
/// aqui na Sprint de Consolidação do Módulo 4.
final DateFormat dataCurtaFormat = DateFormat('dd/MM/yyyy');
