import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/leylek_colors.dart';
import '../../domain/entities/search_result.dart';
import '../cubit/search_cubit.dart';
import 'route_card.dart';

/// Arama durumuna göre ipucu, yükleniyor, hata ya da sonuç listesi.
class ResultsView extends StatelessWidget {
  const ResultsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SearchCubit>().state;
    return switch (state) {
      SearchIdle() => const _Hint(),
      SearchInProgress() => const _Loading(),
      // Doğrulama hataları formdaki alanın altında gösteriliyor.
      SearchError(failure: ValidationFailure()) => const SizedBox.shrink(),
      SearchError(:final failure) => _ErrorBox(failure: failure),
      SearchSuccess(:final result) => _Results(result: result),
    };
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Doğrudan uçuş pahalıysa yakın bir havalimanına uçup kalan yolu '
          'trenle, otobüsle ya da feribotla tamamlayan rotaları buluruz. '
          'En ucuzdan en pahalıya en az üç seçenek gösteririz.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: LeylekColors.muted),
        ),
      );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Uçuşlar ve kara bağlantıları aranıyor'),
          ],
        ),
      );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.failure});

  final Failure failure;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(failure.message),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.read<SearchCubit>().retry(),
                child: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );
}

class _Results extends StatelessWidget {
  const _Results({required this.result});

  final SearchResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result.isSample)
          const _Notice('Örnek veri gösteriliyor: backend bağlı değil, fiyatlar gerçek değil.'),
        if (result.warnings.contains(SearchWarning.fewerThanThree))
          const _Notice('Bu varış için üçten az seçenek bulundu.'),
        if (result.options.isEmpty)
          const _Notice('Bu tarih için rota bulunamadı. Tarihi ya da yarıçapı değiştirmeyi dene.'),
        for (final option in result.options) ...[
          RouteCard(option: option),
          const SizedBox(height: 12),
        ],
        Text(
          'Uçuş fiyatları son 48 saatte görülen fiyatlardır ve değişmiş olabilir. '
          'Uçuş ve kara yolu ayrı biletlerdir; rötar olursa kara bileti yanabilir.',
          style: theme.textTheme.bodySmall?.copyWith(color: LeylekColors.muted),
        ),
        const SizedBox(height: 12),
        Text(
          'Veri: ${result.attribution.map((a) => a.name).join(' · ')}',
          style: theme.textTheme.bodySmall?.copyWith(color: LeylekColors.muted),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: LeylekColors.warningSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: const TextStyle(color: LeylekColors.warning)),
      );
}
