import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'data/repositories/match_repository_impl.dart';
import 'data/services/thesportsdb_service.dart';
import 'presentation/bloc/api_test_bloc.dart';
import 'presentation/pages/api_test_page.dart';

void main() {
  runApp(const FutbolArgentinoApp());
}

class FutbolArgentinoApp extends StatelessWidget {
  const FutbolArgentinoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prueba TheSportsDB',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
      ),
      home: BlocProvider(
        create: (_) => ApiTestBloc(MatchRepositoryImpl(TheSportsDbService())),
        child: const ApiTestPage(),
      ),
    );
  }
}
