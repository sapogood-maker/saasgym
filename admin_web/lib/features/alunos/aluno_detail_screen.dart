import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_core/shared_core.dart';

import '../../routing/back_navigation.dart';

/// Painel de detalhe do aluno — referência de composição para todo painel
/// de detalhe futuro (Professores, Turmas, ...): seções em `AppCard`,
/// pares rótulo/valor via `AppDetailRow` dentro de `AppFormRow` (mesmo
/// grid do formulário de edição da mesma entidade), seções ainda sem
/// funcionalidade como `EmptyState.comingSoon` com a tag da sprint
/// responsável — nunca dado inventado.
class AlunoDetailScreen extends ConsumerStatefulWidget {
  const AlunoDetailScreen({required this.alunoId, super.key});

  final String alunoId;

  @override
  ConsumerState<AlunoDetailScreen> createState() => _AlunoDetailScreenState();
}

class _AlunoDetailScreenState extends ConsumerState<AlunoDetailScreen> {
  Future<Aluno>? _future;
  bool _alterado = false;
  bool _processandoStatus = false;
  bool _removendo = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    setState(() {
      _future = ref.read(alunosApiProvider).get(widget.alunoId);
    });
  }

  void _voltar([bool? alterado]) {
    context.backToList('/alunos', result: alterado ?? _alterado);
  }

  Future<void> _alternarStatus(Aluno aluno) async {
    setState(() => _processandoStatus = true);
    try {
      final novoStatus = aluno.status == UserStatus.ativo ? UserStatus.inativo : UserStatus.ativo;
      await ref.read(alunosApiProvider).updateStatus(aluno.id, novoStatus);
      _alterado = true;
      _carregar();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagemErroApi(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _processandoStatus = false);
      }
    }
  }

  Future<void> _excluir(Aluno aluno) async {
    final confirmou = await AppConfirmDialog.show(
      context,
      variant: AppConfirmDialogVariant.danger,
      title: 'Remover aluno',
      description: 'Remover ${aluno.nome}? O cadastro fica inativo e preservado (nada é apagado permanentemente).',
      confirmLabel: 'Remover',
    );
    if (confirmou != true || !mounted) {
      return;
    }

    setState(() => _removendo = true);
    try {
      await ref.read(alunosApiProvider).remove(aluno.id);
      if (mounted) {
        _voltar(true);
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagemErroApi(e))));
      }
      if (mounted) {
        setState(() => _removendo = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _voltar();
        }
      },
      // Rota fora do ShellRoute (tela cheia) — precisa do próprio Scaffold,
      // igual ao AlunoFormScreen.
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: FutureBuilder<Aluno>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _AlunoPainelSkeleton(onBack: _voltar);
                }
                if (snapshot.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppBackLink(label: 'Alunos', onTap: _voltar),
                      const SizedBox(height: AppSpacing.lg),
                      EmptyState(
                        icon: AppIcons.alert,
                        title: 'Não foi possível carregar o aluno.',
                        actionLabel: 'Tentar novamente',
                        onAction: _carregar,
                      ),
                    ],
                  );
                }
                return _painel(context, snapshot.data!);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _painel(BuildContext context, Aluno aluno) {
    final colors = context.colors;
    final ativo = aluno.status == UserStatus.ativo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDetailHeader(
          listLabel: 'Alunos',
          onBack: _voltar,
          leading: AppAvatarPicker(imageUrl: aluno.fotoUrl, radius: 40, enabled: false),
          title: aluno.nome,
          trailing: AppBadge(
            ativo ? 'Ativo' : 'Inativo',
            tone: ativo ? AppBadgeTone.success : AppBadgeTone.neutral,
          ),
          actions: [
            AppButton(
              label: 'Editar',
              icon: AppIcons.edit,
              onPressed: (_processandoStatus || _removendo)
                  ? null
                  : () async {
                      final resultado = await context.push<bool>('/alunos/${aluno.id}/editar');
                      if (resultado == true) {
                        _alterado = true;
                        _carregar();
                      }
                    },
            ),
            AppButton(
              label: ativo ? 'Inativar' : 'Reativar',
              icon: ativo ? AppIcons.block : AppIcons.circleCheck,
              variant: AppButtonVariant.secondary,
              loading: _processandoStatus,
              onPressed: _removendo ? null : () => _alternarStatus(aluno),
            ),
            AppButton(
              label: 'Remover',
              icon: AppIcons.trash,
              variant: AppButtonVariant.danger,
              loading: _removendo,
              onPressed: _processandoStatus ? null : () => _excluir(aluno),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          title: 'Dados pessoais',
          child: Column(
            children: [
              AppFormRow(children: [
                AppDetailRow(label: 'Nome', value: aluno.nome),
                AppDetailRow(label: 'CPF', value: aluno.cpf),
              ]),
              const SizedBox(height: AppSpacing.md),
              AppFormRow(children: [
                AppDetailRow(label: 'RG', value: aluno.rg),
                AppDetailRow(
                  label: 'Data de nascimento',
                  value: dataCurtaFormat.format(aluno.dataNascimento),
                ),
                AppDetailRow(label: 'Sexo', value: _sexoLabel(aluno.sexo)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Contato',
          child: AppFormRow(children: [
            AppDetailRow(label: 'Telefone', value: aluno.telefone),
            AppDetailRow(label: 'WhatsApp', value: aluno.whatsapp),
            AppDetailRow(label: 'E-mail', value: aluno.email),
          ]),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Endereço',
          child: Column(
            children: [
              AppFormRow(children: [AppDetailRow(label: 'Endereço', value: aluno.endereco)]),
              const SizedBox(height: AppSpacing.md),
              AppFormRow(children: [
                AppDetailRow(label: 'Cidade', value: aluno.cidade),
                AppDetailRow(label: 'Estado', value: aluno.estado),
                AppDetailRow(label: 'CEP', value: aluno.cep),
              ]),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Observações',
          child: Text(
            (aluno.observacoes ?? '').trim().isNotEmpty ? aluno.observacoes! : '—',
            style: AppTypography.bodyMedium.copyWith(
              color: (aluno.observacoes ?? '').trim().isNotEmpty ? colors.text : colors.textFaint,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _MatriculasSection(alunoId: aluno.id),
        const SizedBox(height: AppSpacing.lg),
        _MensalidadesSection(alunoId: aluno.id),
        const SizedBox(height: AppSpacing.lg),
        _AvaliacoesFisicasSection(alunoId: aluno.id),
        const SizedBox(height: AppSpacing.lg),
        _FrequenciaSection(alunoId: aluno.id),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Treinos',
          child: const EmptyState.comingSoon(
            icon: AppIcons.workout,
            title: 'Fichas de treino',
            description: 'Exercícios, séries, repetições e carga.',
            sprintTag: 'EM BREVE',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Arquivos',
          child: const EmptyState.comingSoon(
            icon: AppIcons.files,
            title: 'Documentos e anexos',
            description: 'Atestados, contratos e outros arquivos do aluno.',
            sprintTag: 'EM BREVE',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Histórico',
          child: const EmptyState.comingSoon(
            icon: AppIcons.history,
            title: 'Linha do tempo do aluno',
            description: 'Mudanças de plano, status e eventos importantes.',
            sprintTag: 'EM BREVE',
          ),
        ),
      ],
    );
  }
}

class _AlunoPainelSkeleton extends StatelessWidget {
  const _AlunoPainelSkeleton({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppBackLink(label: 'Alunos', onTap: onBack),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            const LoadingSkeleton(width: 80, height: 80, shape: AppSkeletonShape.circle),
            const SizedBox(width: AppSpacing.lg),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                LoadingSkeleton(width: 220, height: 28),
                SizedBox(height: AppSpacing.sm),
                LoadingSkeleton(width: 90, height: 20),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        const AppCard(title: 'Dados pessoais', loading: true),
        const SizedBox(height: AppSpacing.lg),
        const AppCard(title: 'Contato', loading: true),
      ],
    );
  }
}

String _sexoLabel(Sexo sexo) {
  switch (sexo) {
    case Sexo.masculino:
      return 'Masculino';
    case Sexo.feminino:
      return 'Feminino';
    case Sexo.outro:
      return 'Outro';
  }
}

String _matriculaStatusLabel(MatriculaStatus status) => switch (status) {
  MatriculaStatus.ativa => 'Ativa',
  MatriculaStatus.trancada => 'Trancada',
  MatriculaStatus.cancelada => 'Cancelada',
  MatriculaStatus.encerrada => 'Encerrada',
};

AppBadgeTone _matriculaStatusTone(MatriculaStatus status) => switch (status) {
  MatriculaStatus.ativa => AppBadgeTone.success,
  MatriculaStatus.trancada => AppBadgeTone.warning,
  MatriculaStatus.cancelada => AppBadgeTone.error,
  MatriculaStatus.encerrada => AppBadgeTone.neutral,
};

/// Seção "Matrículas" do Detalhe do Aluno — só leitura (criar/trancar/
/// cancelar/renovar continuam exclusivos da tela de Matrículas, mesmo
/// motivo de `_AvaliacoesFisicasSection` não editar). Consome
/// `MatriculasApi.listMatriculas(alunoId: ...)`, já existente desde o
/// Módulo 2 — nenhum endpoint novo.
class _MatriculasSection extends ConsumerStatefulWidget {
  const _MatriculasSection({required this.alunoId});

  final String alunoId;

  @override
  ConsumerState<_MatriculasSection> createState() => _MatriculasSectionState();
}

class _MatriculasSectionState extends ConsumerState<_MatriculasSection> {
  Future<PaginatedResult<Matricula>>? _future;
  int _pagina = 1;
  static const _tamanhoPagina = 10;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    setState(() {
      _future = ref
          .read(matriculasApiProvider)
          .listMatriculas(alunoId: widget.alunoId, page: _pagina, pageSize: _tamanhoPagina);
    });
  }

  void _irParaPagina(int pagina) {
    setState(() => _pagina = pagina);
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'Matrículas',
      child: FutureBuilder<PaginatedResult<Matricula>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LoadingSkeleton(width: double.infinity, height: 16),
                SizedBox(height: AppSpacing.sm),
                LoadingSkeleton(width: double.infinity, height: 16),
              ],
            );
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: AppIcons.alert,
              title: 'Não foi possível carregar as matrículas.',
              actionLabel: 'Tentar novamente',
              onAction: _carregar,
            );
          }
          final resultado = snapshot.data!;
          if (resultado.items.isEmpty) {
            return const EmptyState(
              icon: AppIcons.enrollment,
              title: 'Nenhuma matrícula encontrada.',
            );
          }
          final colors = context.colors;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < resultado.items.length; i++) ...[
                if (i > 0) Divider(color: colors.borderSoft, height: 1),
                _MatriculaRow(matricula: resultado.items[i]),
              ],
              if (resultado.total > _tamanhoPagina) ...[
                const SizedBox(height: AppSpacing.lg),
                AppPagination(
                  page: resultado.page,
                  pageSize: resultado.pageSize,
                  total: resultado.total,
                  onPageChanged: _irParaPagina,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MatriculaRow extends StatelessWidget {
  const _MatriculaRow({required this.matricula});

  final Matricula matricula;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
      child: Row(
        children: [
          Icon(AppIcons.enrollment, size: 16, color: colors.textFaint),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(matricula.planoNome, style: AppTypography.titleMedium.copyWith(color: colors.text)),
                Text(
                  '${dataCurtaFormat.format(matricula.dataInicio)} — '
                  '${dataCurtaFormat.format(matricula.dataFim)}',
                  style: AppTypography.bodySmall.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AppBadge(
            _matriculaStatusLabel(matricula.status),
            tone: _matriculaStatusTone(matricula.status),
          ),
        ],
      ),
    );
  }
}

String _mensalidadeStatusLabel(Mensalidade mensalidade) {
  if (mensalidade.status == MensalidadeStatus.pendente && mensalidade.atrasada) {
    return 'Atrasada';
  }
  return switch (mensalidade.status) {
    MensalidadeStatus.pendente => 'Pendente',
    MensalidadeStatus.paga => 'Paga',
    MensalidadeStatus.cancelada => 'Cancelada',
  };
}

AppBadgeTone _mensalidadeStatusTone(Mensalidade mensalidade) {
  if (mensalidade.status == MensalidadeStatus.pendente && mensalidade.atrasada) {
    return AppBadgeTone.error;
  }
  return switch (mensalidade.status) {
    MensalidadeStatus.pendente => AppBadgeTone.warning,
    MensalidadeStatus.paga => AppBadgeTone.success,
    MensalidadeStatus.cancelada => AppBadgeTone.neutral,
  };
}

/// Seção "Financeiro" do Detalhe do Aluno — deliberadamente sem valor
/// monetário nenhum (nem `valor`, nem `valorFinal`): é um resumo de
/// situação (em dia, atrasada, paga), não um extrato — quem precisa do
/// valor vai à tela de Mensalidades. Consome
/// `MensalidadesApi.listMensalidades(alunoId: ...)`, já existente desde o
/// Módulo 3 — nenhum endpoint novo.
class _MensalidadesSection extends ConsumerStatefulWidget {
  const _MensalidadesSection({required this.alunoId});

  final String alunoId;

  @override
  ConsumerState<_MensalidadesSection> createState() => _MensalidadesSectionState();
}

class _MensalidadesSectionState extends ConsumerState<_MensalidadesSection> {
  Future<PaginatedResult<Mensalidade>>? _future;
  int _pagina = 1;
  static const _tamanhoPagina = 10;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    setState(() {
      _future = ref
          .read(mensalidadesApiProvider)
          .listMensalidades(alunoId: widget.alunoId, page: _pagina, pageSize: _tamanhoPagina);
    });
  }

  void _irParaPagina(int pagina) {
    setState(() => _pagina = pagina);
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'Financeiro',
      child: FutureBuilder<PaginatedResult<Mensalidade>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LoadingSkeleton(width: double.infinity, height: 16),
                SizedBox(height: AppSpacing.sm),
                LoadingSkeleton(width: double.infinity, height: 16),
              ],
            );
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: AppIcons.alert,
              title: 'Não foi possível carregar as mensalidades.',
              actionLabel: 'Tentar novamente',
              onAction: _carregar,
            );
          }
          final resultado = snapshot.data!;
          if (resultado.items.isEmpty) {
            return const EmptyState(
              icon: AppIcons.finance,
              title: 'Nenhuma mensalidade encontrada.',
            );
          }
          final colors = context.colors;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < resultado.items.length; i++) ...[
                if (i > 0) Divider(color: colors.borderSoft, height: 1),
                _MensalidadeRow(mensalidade: resultado.items[i]),
              ],
              if (resultado.total > _tamanhoPagina) ...[
                const SizedBox(height: AppSpacing.lg),
                AppPagination(
                  page: resultado.page,
                  pageSize: resultado.pageSize,
                  total: resultado.total,
                  onPageChanged: _irParaPagina,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MensalidadeRow extends StatelessWidget {
  const _MensalidadeRow({required this.mensalidade});

  final Mensalidade mensalidade;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final subtitulo = mensalidade.dataPagamento != null
        ? 'Pago em ${dataCurtaFormat.format(mensalidade.dataPagamento!)}'
        : 'Vencimento em ${dataCurtaFormat.format(mensalidade.dataVencimento)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
      child: Row(
        children: [
          Icon(AppIcons.finance, size: 16, color: colors.textFaint),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dataCurtaFormat.format(mensalidade.dataVencimento),
                  style: AppTypography.titleMedium.copyWith(color: colors.text),
                ),
                Text(subtitulo, style: AppTypography.bodySmall.copyWith(color: colors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AppBadge(
            _mensalidadeStatusLabel(mensalidade),
            tone: _mensalidadeStatusTone(mensalidade),
          ),
        ],
      ),
    );
  }
}

String _presencaLabel(PresencaStatus? presenca) => switch (presenca) {
  PresencaStatus.presente => 'Presente',
  PresencaStatus.ausente => 'Falta',
  PresencaStatus.justificada => 'Falta justificada',
  null => 'Não marcada',
};

AppBadgeTone _presencaTone(PresencaStatus? presenca) => switch (presenca) {
  PresencaStatus.presente => AppBadgeTone.success,
  PresencaStatus.ausente => AppBadgeTone.error,
  PresencaStatus.justificada => AppBadgeTone.warning,
  null => AppBadgeTone.neutral,
};

/// Seção "Frequência" do Detalhe do Aluno — histórico cross-turma (mesmo
/// propósito de `FrequenciaAluno`, docs/18 MS8): marcar presença continua
/// exclusivo do Calendário (`CalendarScreen._registrarPresenca`), esta
/// seção é só leitura. Consome `AulaAlunosApi.listPorAluno(alunoId)`, já
/// existente desde o Módulo 4 — nenhum endpoint novo.
class _FrequenciaSection extends ConsumerStatefulWidget {
  const _FrequenciaSection({required this.alunoId});

  final String alunoId;

  @override
  ConsumerState<_FrequenciaSection> createState() => _FrequenciaSectionState();
}

class _FrequenciaSectionState extends ConsumerState<_FrequenciaSection> {
  Future<PaginatedResult<FrequenciaAluno>>? _future;
  int _pagina = 1;
  static const _tamanhoPagina = 10;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    setState(() {
      _future = ref
          .read(aulaAlunosApiProvider)
          .listPorAluno(widget.alunoId, page: _pagina, pageSize: _tamanhoPagina);
    });
  }

  void _irParaPagina(int pagina) {
    setState(() => _pagina = pagina);
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'Frequência',
      child: FutureBuilder<PaginatedResult<FrequenciaAluno>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LoadingSkeleton(width: double.infinity, height: 16),
                SizedBox(height: AppSpacing.sm),
                LoadingSkeleton(width: double.infinity, height: 16),
              ],
            );
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: AppIcons.alert,
              title: 'Não foi possível carregar a frequência.',
              actionLabel: 'Tentar novamente',
              onAction: _carregar,
            );
          }
          final resultado = snapshot.data!;
          if (resultado.items.isEmpty) {
            return const EmptyState(
              icon: AppIcons.attendance,
              title: 'Nenhuma presença registrada.',
            );
          }
          final colors = context.colors;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < resultado.items.length; i++) ...[
                if (i > 0) Divider(color: colors.borderSoft, height: 1),
                _FrequenciaRow(item: resultado.items[i]),
              ],
              if (resultado.total > _tamanhoPagina) ...[
                const SizedBox(height: AppSpacing.lg),
                AppPagination(
                  page: resultado.page,
                  pageSize: resultado.pageSize,
                  total: resultado.total,
                  onPageChanged: _irParaPagina,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FrequenciaRow extends StatelessWidget {
  const _FrequenciaRow({required this.item});

  final FrequenciaAluno item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
      child: Row(
        children: [
          Icon(AppIcons.attendance, size: 16, color: colors.textFaint),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.turmaNome, style: AppTypography.titleMedium.copyWith(color: colors.text)),
                Text(
                  dataCurtaFormat.format(item.aulaData),
                  style: AppTypography.bodySmall.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AppBadge(_presencaLabel(item.presenca), tone: _presencaTone(item.presenca)),
        ],
      ),
    );
  }
}

/// Módulo 5 (Avaliação Física) — seção embutida, mesmo padrão de
/// `_AulasSection` (TurmaDetailScreen, Módulo 4): `AvaliacaoFisica` é fato
/// histórico imutável (docs/20, decisão 1), então cada linha só tem uma
/// ação (remover — correção de erro de cadastro), nunca editar.
class _AvaliacoesFisicasSection extends ConsumerStatefulWidget {
  const _AvaliacoesFisicasSection({required this.alunoId});

  final String alunoId;

  @override
  ConsumerState<_AvaliacoesFisicasSection> createState() => _AvaliacoesFisicasSectionState();
}

class _AvaliacoesFisicasSectionState extends ConsumerState<_AvaliacoesFisicasSection> {
  Future<PaginatedResult<AvaliacaoFisica>>? _future;
  int _pagina = 1;
  static const _tamanhoPagina = 10;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    setState(() {
      _future = ref
          .read(avaliacoesFisicasApiProvider)
          .list(widget.alunoId, page: _pagina, pageSize: _tamanhoPagina);
    });
  }

  void _irParaPagina(int pagina) {
    setState(() => _pagina = pagina);
    _carregar();
  }

  Future<void> _nova() async {
    final criada = await showAppDialog<bool>(
      context,
      maxWidth: 460,
      builder: (_) => _NovaAvaliacaoFisicaDialog(alunoId: widget.alunoId),
    );
    if (criada == true) {
      _pagina = 1;
      _carregar();
    }
  }

  Future<void> _remover(AvaliacaoFisica avaliacao) async {
    final confirmou = await AppConfirmDialog.show(
      context,
      variant: AppConfirmDialogVariant.danger,
      title: 'Remover avaliação física',
      description:
          'Remover a avaliação de ${dataCurtaFormat.format(avaliacao.data)}? '
          'Reservado a correção de erro de cadastro — uma avaliação nunca é editada.',
      confirmLabel: 'Remover',
    );
    if (confirmou != true) return;

    try {
      await ref.read(avaliacoesFisicasApiProvider).remove(widget.alunoId, avaliacao.id);
      _carregar();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagemErroApi(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'Avaliações',
      actions: [AppButton(label: 'Nova avaliação', icon: AppIcons.add, onPressed: _nova)],
      child: FutureBuilder<PaginatedResult<AvaliacaoFisica>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LoadingSkeleton(width: double.infinity, height: 16),
                SizedBox(height: AppSpacing.sm),
                LoadingSkeleton(width: double.infinity, height: 16),
              ],
            );
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: AppIcons.alert,
              title: 'Não foi possível carregar as avaliações.',
              actionLabel: 'Tentar novamente',
              onAction: _carregar,
            );
          }
          final resultado = snapshot.data!;
          if (resultado.items.isEmpty) {
            return EmptyState(
              icon: AppIcons.assessment,
              title: 'Nenhuma avaliação registrada',
              description: 'Peso, altura e IMC ao longo do tempo.',
              actionLabel: 'Nova avaliação',
              onAction: _nova,
            );
          }
          final colors = context.colors;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < resultado.items.length; i++) ...[
                if (i > 0) Divider(color: colors.borderSoft, height: 1),
                _AvaliacaoFisicaRow(avaliacao: resultado.items[i], onRemover: _remover),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppPagination(
                page: resultado.page,
                pageSize: resultado.pageSize,
                total: resultado.total,
                onPageChanged: _irParaPagina,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AvaliacaoFisicaRow extends StatelessWidget {
  const _AvaliacaoFisicaRow({required this.avaliacao, required this.onRemover});

  final AvaliacaoFisica avaliacao;
  final ValueChanged<AvaliacaoFisica> onRemover;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
      child: Row(
        children: [
          Icon(AppIcons.assessment, size: 16, color: colors.textFaint),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dataCurtaFormat.format(avaliacao.data),
                  style: AppTypography.titleMedium.copyWith(color: colors.text),
                ),
                Text(
                  '${avaliacao.peso.toStringAsFixed(1)} kg · '
                  '${avaliacao.altura.toStringAsFixed(0)} cm · '
                  'IMC ${avaliacao.imc.toStringAsFixed(1)}',
                  style: AppTypography.bodySmall.copyWith(color: colors.textMuted),
                ),
                if ((avaliacao.observacoes ?? '').trim().isNotEmpty)
                  Text(
                    avaliacao.observacoes!,
                    style: AppTypography.bodySmall.copyWith(color: colors.textFaint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          IconButton(
            icon: Icon(AppIcons.trash, size: 18, color: colors.textFaint),
            tooltip: 'Remover avaliação',
            onPressed: () => onRemover(avaliacao),
          ),
        ],
      ),
    );
  }
}

/// Diálogo de criação — data/peso/altura/observações. Sem contraparte de
/// edição (docs/20, decisão 1) — a única forma de corrigir um erro é
/// remover e criar de novo.
class _NovaAvaliacaoFisicaDialog extends ConsumerStatefulWidget {
  const _NovaAvaliacaoFisicaDialog({required this.alunoId});

  final String alunoId;

  @override
  ConsumerState<_NovaAvaliacaoFisicaDialog> createState() => _NovaAvaliacaoFisicaDialogState();
}

class _NovaAvaliacaoFisicaDialogState extends ConsumerState<_NovaAvaliacaoFisicaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pesoController = TextEditingController();
  final _alturaController = TextEditingController();
  final _observacoesController = TextEditingController();
  late DateTime _data;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _data = DateTime.now();
  }

  @override
  void dispose() {
    _pesoController.dispose();
    _alturaController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await ref.read(avaliacoesFisicasApiProvider).create(
            widget.alunoId,
            data: DateFormat('yyyy-MM-dd').format(_data),
            peso: double.parse(_pesoController.text.trim().replaceAll(',', '.')),
            altura: double.parse(_alturaController.text.trim().replaceAll(',', '.')),
            observacoes: _observacoesController.text.trim().isEmpty
                ? null
                : _observacoesController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      setState(() => _erro = mensagemErroApi(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nova avaliação física', style: AppTypography.titleLarge.copyWith(color: colors.text)),
          const SizedBox(height: AppSpacing.lg),
          AppDateField(
            label: 'Data',
            firstDate: DateTime.now().subtract(const Duration(days: 3650)),
            lastDate: DateTime.now(),
            value: _data,
            onChanged: (v) => setState(() => _data = v!),
            validator: (v) => v == null ? 'Informe a data' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          AppFormRow(children: [
            AppTextField(
              label: 'Peso (kg)',
              hintText: '70,0',
              controller: _pesoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Informe o peso';
                final numero = double.tryParse(v.trim().replaceAll(',', '.'));
                if (numero == null || numero <= 0) return 'Informe um peso válido';
                return null;
              },
            ),
            AppTextField(
              label: 'Altura (cm)',
              hintText: '175',
              controller: _alturaController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Informe a altura';
                final numero = double.tryParse(v.trim().replaceAll(',', '.'));
                if (numero == null || numero <= 0) return 'Informe uma altura válida';
                return null;
              },
            ),
          ]),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Observações',
            hintText: 'Opcional',
            controller: _observacoesController,
            maxLines: 2,
          ),
          if (_erro != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppFormErrorBanner(_erro!),
          ],
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton(
                label: 'Cancelar',
                variant: AppButtonVariant.secondary,
                onPressed: _salvando ? null : () => Navigator.of(context).pop(null),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(label: 'Salvar', loading: _salvando, onPressed: _salvar),
            ],
          ),
        ],
      ),
    );
  }
}

