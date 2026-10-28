import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/leylek_colors.dart';
import '../../domain/entities/recent_search.dart';
import '../cubit/recent_searches_cubit.dart';
import '../cubit/search_form_cubit.dart';

/// Arama kartının altındaki "Son aramalar": her kayıt ayrı, yüzen bir
/// kart. Dokununca form o aramayla doldurulur. Kayıt yoksa hiç görünmez.
class RecentSearches extends StatelessWidget {
  const RecentSearches({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<RecentSearchesCubit>().state;
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(6, 20, 6, 10),
          child: Text(
            'Son aramalar',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: LeylekColors.wingtip,
            ),
          ),
        ),
        for (final (i, item) in items.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          _RecentTile(key: Key('recent-$i'), item: item),
        ],
      ],
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.item, super.key});

  final RecentSearch item;

  void _restore(BuildContext context) {
    final now = DateTime.now();
    context.read<SearchFormCubit>().restore(
      item,
      today: DateTime(now.year, now.month, now.day),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stay = item.stopoverDays == 0
        ? 'Konaklamasız'
        : '${item.stopoverDays} gün konaklama';
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: LeylekColors.cardShadow,
      ),
      child: Material(
        color: LeylekColors.feather,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _restore(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: LeylekColors.skySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    size: 20,
                    color: LeylekColors.skyDeep,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.fromName} → ${item.toName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: LeylekColors.wingtip,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        Formatters.day(item.date),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: LeylekColors.muted,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${item.radiusKm} km · $stay',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: LeylekColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: LeylekColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
