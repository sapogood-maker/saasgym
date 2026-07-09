import '../common/sexo.dart';
import '../common/user_status.dart';

class Aluno {
  const Aluno({
    required this.id,
    required this.fotoUrl,
    required this.nome,
    required this.cpf,
    required this.rg,
    required this.dataNascimento,
    required this.sexo,
    required this.telefone,
    required this.whatsapp,
    required this.email,
    required this.endereco,
    required this.cidade,
    required this.estado,
    required this.cep,
    required this.observacoes,
    required this.status,
    required this.createdAt,
  });

  factory Aluno.fromJson(Map<String, dynamic> json) {
    return Aluno(
      id: json['id'] as String,
      fotoUrl: json['fotoUrl'] as String?,
      nome: json['nome'] as String,
      cpf: json['cpf'] as String,
      rg: json['rg'] as String?,
      dataNascimento: DateTime.parse(json['dataNascimento'] as String),
      sexo: Sexo.fromJson(json['sexo'] as String),
      telefone: json['telefone'] as String,
      whatsapp: json['whatsapp'] as String?,
      email: json['email'] as String?,
      endereco: json['endereco'] as String?,
      cidade: json['cidade'] as String?,
      estado: json['estado'] as String?,
      cep: json['cep'] as String?,
      observacoes: json['observacoes'] as String?,
      status: UserStatus.fromJson(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String? fotoUrl;
  final String nome;
  final String cpf;
  final String? rg;
  final DateTime dataNascimento;
  final Sexo sexo;
  final String telefone;
  final String? whatsapp;
  final String? email;
  final String? endereco;
  final String? cidade;
  final String? estado;
  final String? cep;
  final String? observacoes;
  final UserStatus status;
  final DateTime createdAt;
}
