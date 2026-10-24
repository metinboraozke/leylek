import 'package:flutter/material.dart';

import '../../../../core/theme/leylek_colors.dart';
import '../../../../core/ui/leylek_mark.dart';
import '../widgets/results_view.dart';
import '../widgets/search_form.dart';

/// Uygulamanın tek ekranı: üstte form, altta sonuçlar.
///
/// Cubit'ler bu sayfanın üstünde sağlanır (bkz. `LeylekApp`); sayfa
/// onları oluşturmaz, böylece testte hazır durumlarla açılabilir.
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Row(
                children: [
                  const LeylekMark(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Leylek',
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        Text('Uç, sonra yürü: aktarmalı ucuz rotalar',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: LeylekColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const SearchForm(),
              const SizedBox(height: 16),
              const ResultsView(),
            ],
          ),
        ),
      ),
    );
  }
}
