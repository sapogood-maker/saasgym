import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

class ProfessoresScreen extends ConsumerStatefulWidget {
  const ProfessoresScreen({super.key});

  @override
  ConsumerState<ProfessoresScreen> createState() => _ProfessoresScreenState();
}

class _ProfessoresScreenState extends ConsumerState<ProfessoresScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  String _search = '';
  UserStatus? _statusFiltro;
  int _pagina = 1;
  static const _tamanhoPagina = 20;

  Future<PaginatedResult<Professor>>? _future;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _carregar() {
    setState(() {
      _future = ref
          .read(professoresApiProvider)
          .list(
            search: _search,
            status: _statusFiltro,
            page: _pagina,
            pageSize: _tamanhoPagina,
          );
    });
  }

  void _aoBuscar(String valor) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search = valor;
      _pagina = 1;
      _carregar();
    });
  }

  void _aoFiltrarStatus(UserStatus? status) {
    setState(() {
      _statusFiltro = status;
      _pagina = 1;
    });
    _carregar();
  }

  void _irParaPagina(int pagina) {
    setState(() => _pagina = pagina);
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final criado = await context.push<bool>('/professores/novo');
          if (criado == true) {
            _carregar();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Novo professor'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Pesquisar por nome, CPF ou telefone',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: _aoBuscar,
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<UserStatus?>(
                  value: _statusFiltro,
                  hint: const Text('Status'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todos')),
                    DropdownMenuItem(
                      value: UserStatus.ativo,
                      child: Text('Ativos'),
                    ),
                    DropdownMenuItem(
                      value: UserStatus.inativo,
                      child: Text('Inativos'),
                    ),
                  ],
                  onChanged: _aoFiltrarStatus,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<PaginatedResult<Professor>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Não foi possível carregar os professores.'),
                    );
                  }
                  final resultado = snapshot.data!;
                  if (resultado.items.isEmpty) {
                    return const Center(
                      child: Text('Nenhum professor encontrado.'),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ListView.separated(
                          itemCount: resultado.items.length,
                          separatorBuilder: (context, indice) =>
                              const Divider(height: 1),
                          itemBuilder: (context, indice) {
                            final professor = resultado.items[indice];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: professor.fotoUrl != null
                                    ? NetworkImage(professor.fotoUrl!)
                                    : null,
                                child: professor.fotoUrl == null
                                    ? Text(
                                        professor.nome.isNotEmpty
                                            ? professor.nome[0].toUpperCase()
                                            : '?',
                                      )
                                    : null,
                              ),
                              title: Text(professor.nome),
                              subtitle: Text(
                                '${professor.cpf} · ${professor.telefone}'
                                '${professor.especialidade != null ? ' · ${professor.especialidade}' : ''}',
                              ),
                              trailing: Chip(
                                label: Text(
                                  professor.status == UserStatus.ativo
                                      ? 'Ativo'
                                      : 'Inativo',
                                ),
                              ),
                              onTap: () async {
                                final alterado = await context.push<bool>(
                                  '/professores/${professor.id}',
                                );
                                if (alterado == true) {
                                  _carregar();
                                }
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      _PaginacaoControles(
                        pagina: resultado.page,
                        totalPaginas: resultado.totalPaginas,
                        total: resultado.total,
                        onPaginaAnterior: resultado.page > 1
                            ? () => _irParaPagina(resultado.page - 1)
                            : null,
                        onProximaPagina: resultado.page < resultado.totalPaginas
                            ? () => _irParaPagina(resultado.page + 1)
                            : null,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginacaoControles extends StatelessWidget {
  const _PaginacaoControles({
    required this.pagina,
    required this.totalPaginas,
    required this.total,
    required this.onPaginaAnterior,
    required this.onProximaPagina,
  });

  final int pagina;
  final int totalPaginas;
  final int total;
  final VoidCallback? onPaginaAnterior;
  final VoidCallback? onProximaPagina;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onPaginaAnterior,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('Página $pagina de $totalPaginas · $total no total'),
        IconButton(
          onPressed: onProximaPagina,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
