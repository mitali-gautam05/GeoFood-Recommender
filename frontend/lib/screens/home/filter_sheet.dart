import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class FilterOptions {
  final double minBudget;
  final double maxBudget;
  final double minRating;
  final String? cuisine;

  const FilterOptions({
    this.minBudget = 0,
    this.maxBudget = 1500,
    this.minRating = 3.0,
    this.cuisine,
  });

  FilterOptions copyWith({
    double? minBudget,
    double? maxBudget,
    double? minRating,
    String? cuisine,
    bool clearCuisine = false,
  }) {
    return FilterOptions(
      minBudget: minBudget ?? this.minBudget,
      maxBudget: maxBudget ?? this.maxBudget,
      minRating: minRating ?? this.minRating,
      cuisine: clearCuisine ? null : (cuisine ?? this.cuisine),
    );
  }
}

class FilterSheet extends StatefulWidget {
  final FilterOptions initial;
  final ValueChanged<FilterOptions> onApply;

  const FilterSheet({
    super.key,
    required this.initial,
    required this.onApply,
  });

  static void show(
    BuildContext context,
    FilterOptions current,
    ValueChanged<FilterOptions> onApply,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FilterSheet(initial: current, onApply: onApply),
    );
  }

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late RangeValues _budget;
  late double _minRating;
  String? _cuisine;

  static const _cuisines = [
    'North Indian', 'South Indian', 'Chinese', 'Biryani',
    'Pizza', 'Burger', 'Momos', 'Chaat', 'Rolls',
    'Mughlai', 'Kebab', 'Paneer', 'Fast Food', 'Desserts',
  ];

  @override
  void initState() {
    super.initState();
    _budget = RangeValues(widget.initial.minBudget, widget.initial.maxBudget);
    _minRating = widget.initial.minRating;
    _cuisine = widget.initial.cuisine;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 20, 24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Text('Filters', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _budget = const RangeValues(0, 1500);
                    _minRating = 3.0;
                    _cuisine = null;
                  });
                },
                child: const Text('Reset'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Budget ─────────────────────────────────────────────────
          Text('Budget  ₹${_budget.start.toInt()} – ₹${_budget.end.toInt()}',
              style: theme.textTheme.labelLarge),
          RangeSlider(
            values: _budget,
            min: 0, max: 1500,
            divisions: 30,
            activeColor: AppTheme.primaryOrange,
            labels: RangeLabels(
              '₹${_budget.start.toInt()}',
              '₹${_budget.end.toInt()}',
            ),
            onChanged: (v) => setState(() => _budget = v),
          ),

          const SizedBox(height: 16),

          // ── Rating ─────────────────────────────────────────────────
          Text('Min Rating  ${_minRating.toStringAsFixed(1)} ★',
              style: theme.textTheme.labelLarge),
          Slider(
            value: _minRating,
            min: 1.0, max: 5.0,
            divisions: 8,
            activeColor: Colors.amber,
            label: '${_minRating.toStringAsFixed(1)} ★',
            onChanged: (v) => setState(() => _minRating = v),
          ),

          const SizedBox(height: 16),

          // ── Cuisine chips ──────────────────────────────────────────
          Text('Cuisine', style: theme.textTheme.labelLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _cuisines.map((c) {
              final selected = _cuisine == c;
              return FilterChip(
                label: Text(c),
                selected: selected,
                selectedColor: AppTheme.primaryOrange.withOpacity(0.2),
                checkmarkColor: AppTheme.primaryOrange,
                side: BorderSide(
                  color: selected
                      ? AppTheme.primaryOrange
                      : Colors.grey.shade300,
                ),
                onSelected: (_) =>
                    setState(() => _cuisine = selected ? null : c),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.pop(context);
                widget.onApply(FilterOptions(
                  minBudget: _budget.start,
                  maxBudget: _budget.end,
                  minRating: _minRating,
                  cuisine: _cuisine,
                ));
              },
              child: const Text('Apply Filters',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}