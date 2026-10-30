import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/leylek_colors.dart';
import '../../domain/entities/recent_search.dart';
import '../cubit/recent_searches_cubit.dart';
import '../cubit/search_form_cubit.dart';

/// Arama kartının altındaki tek satırlık "Son arama" kartı:
/// saat simgesi, "İstanbul → Roma · 12 Kas", sağda ok. Dokununca form o
/// aramayla doldurulur. Kayıt yoksa hiç görünmez.
class RecentSearches extends StatelessWidget {
  const RecentSearches({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<RecentSearchesCubit>().state;
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: _RecentTile(key: const Key('recent-0'), item: items.first),
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
    return Material(
      color: LeylekColors.feather.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _restore(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
          child: Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 22,
                color: LeylekColors.muted,
              ),
              const SizedBox(width: 12),
              const Text(
                'Son arama',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: LeylekColors.muted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${item.fromName} → ${item.toName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: LeylekColors.ink,
                        ),
                      ),
                    ),
                    Text(
                      ' · ${Formatters.dayMonth(item.date)}',
                      style: const TextStyle(
                        fontSize: 15,
                        color: LeylekColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: LeylekColors.skyDeep,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
