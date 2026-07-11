import 'package:flutter/widgets.dart' show IconData;
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Mapa de ícone semântico → Lucide, o único pacote de ícone do projeto.
/// Nunca importar `Icons.*` (Material) numa tela nova — se faltar um ícone
/// aqui, adicionar a entrada correspondente, não misturar pacote de ícone
/// (decisão explícita do produto: consistência visual de traço/peso).
abstract final class AppIcons {
  static const IconData dashboard = LucideIcons.layoutDashboard;
  static const IconData students = LucideIcons.users;
  static const IconData teachers = LucideIcons.graduationCap;
  static const IconData calendar = LucideIcons.calendar;
  static const IconData finance = LucideIcons.wallet;
  static const IconData profile = LucideIcons.circleUser;
  static const IconData search = LucideIcons.search;
  static const IconData bell = LucideIcons.bell;
  static const IconData chevronDown = LucideIcons.chevronDown;
  static const IconData chevronRight = LucideIcons.chevronRight;
  static const IconData chevronLeft = LucideIcons.chevronLeft;
  static const IconData logout = LucideIcons.logOut;
  static const IconData birthday = LucideIcons.cakeSlice;
  static const IconData activity = LucideIcons.activity;
  static const IconData trendingUp = LucideIcons.trendingUp;
  static const IconData trendingDown = LucideIcons.trendingDown;
  static const IconData arrowUp = LucideIcons.arrowUp;
  static const IconData arrowDown = LucideIcons.arrowDown;
  static const IconData menu = LucideIcons.menu;
  static const IconData close = LucideIcons.x;
  static const IconData alert = LucideIcons.triangleAlert;
  static const IconData pendingActions = LucideIcons.listChecks;
  static const IconData history = LucideIcons.history;
  static const IconData newStudent = LucideIcons.userPlus;
  static const IconData camera = LucideIcons.camera;
  static const IconData circleCheck = LucideIcons.circleCheck;
  static const IconData circleHelp = LucideIcons.circleHelp;
  static const IconData circleX = LucideIcons.circleX;
  static const IconData trash = LucideIcons.trash2;
  static const IconData sort = LucideIcons.arrowUpDown;
  static const IconData download = LucideIcons.download;
  static const IconData add = LucideIcons.plus;
  static const IconData edit = LucideIcons.pencil;
  static const IconData block = LucideIcons.ban;
  static const IconData enrollment = LucideIcons.clipboardList;
  static const IconData attendance = LucideIcons.calendarCheck;
  static const IconData assessment = LucideIcons.scale;
  static const IconData workout = LucideIcons.dumbbell;
  static const IconData files = LucideIcons.paperclip;
}
