import 'package:flutter/material.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/nutrition_label_parser.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// What the user confirmed on the label check sheet.
class LabelReviewResult {
  final String name;

  /// Per 100 g, as corrected by the user.
  final NutritionLabelValues values;

  /// How much the user is adding, in grams.
  final double grams;

  /// Keep it as a custom food for next time.
  final bool saveForLater;

  const LabelReviewResult({
    required this.name,
    required this.values,
    required this.grams,
    required this.saveForLater,
  });
}

/// Shows a nutrition table read from a photo in plain English rows, per
/// 100 g, every value editable, with the amount to add and what that amount
/// comes to. Nothing is logged until the user confirms.
Future<LabelReviewResult?> showNutritionLabelReview(
  BuildContext context, {
  required NutritionLabelValues values,
  double? netWeightGrams,
  String? name,
}) {
  return showModalBottomSheet<LabelReviewResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _LabelReviewForm(
        values: values,
        netWeightGrams: netWeightGrams,
        name: name,
      ),
    ),
  );
}

class _LabelReviewForm extends StatefulWidget {
  final NutritionLabelValues values;
  final double? netWeightGrams;
  final String? name;

  const _LabelReviewForm({
    required this.values,
    required this.netWeightGrams,
    required this.name,
  });

  @override
  State<_LabelReviewForm> createState() => _LabelReviewFormState();
}

class _LabelReviewFormState extends State<_LabelReviewForm> {
  late final _name = TextEditingController(text: widget.name ?? '');
  late final _kcal = _field(widget.values.energyKcal);
  late final _fat = _field(widget.values.fat);
  late final _saturates = _field(widget.values.saturatedFat);
  late final _carbs = _field(widget.values.carbs);
  late final _sugars = _field(widget.values.sugars);
  late final _fiber = _field(widget.values.fiber);
  late final _protein = _field(widget.values.protein);
  late final _salt = _field(widget.values.salt);
  late final _grams = _field(widget.netWeightGrams ?? 100);
  bool _saveForLater = true;

  static TextEditingController _field(double? value) =>
      TextEditingController(text: value == null ? '' : _format(value));

  static String _format(double value) {
    final rounded = (value * 100).round() / 100;
    return rounded == rounded.roundToDouble()
        ? rounded.toInt().toString()
        : rounded.toString();
  }

  static double? _read(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    for (final controller in [
      _name,
      _kcal,
      _fat,
      _saturates,
      _carbs,
      _sugars,
      _fiber,
      _protein,
      _salt,
      _grams,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  NutritionLabelValues get _edited => NutritionLabelValues(
    energyKcal: _read(_kcal),
    fat: _read(_fat),
    saturatedFat: _read(_saturates),
    carbs: _read(_carbs),
    sugars: _read(_sugars),
    fiber: _read(_fiber),
    protein: _read(_protein),
    salt: _read(_salt),
  );

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final values = _edited;
    final grams = _read(_grams) ?? 0;
    final canAdd =
        grams > 0 &&
        values.energyKcal != null &&
        values.fat != null &&
        values.carbs != null &&
        values.protein != null;

    double scaled(double? per100) => (per100 ?? 0) * grams / 100;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Dimens.spacing16,
          0,
          Dimens.spacing16,
          Dimens.spacing16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.labelReviewTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: Dimens.spacing4),
            Text(s.labelReviewHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: Dimens.spacing12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: s.labelReviewNameLabel,
                hintText: s.labelReviewNameHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: Dimens.spacing12),
            Text(s.labelReviewPer100g, style: theme.textTheme.titleSmall),
            _row(s.labelReviewEnergy, _kcal, 'kcal'),
            _row(s.labelReviewFat, _fat, 'g'),
            _row(s.labelReviewSaturates, _saturates, 'g', indent: true),
            _row(s.labelReviewCarbs, _carbs, 'g'),
            _row(s.labelReviewSugars, _sugars, 'g', indent: true),
            _row(s.labelReviewFibre, _fiber, 'g'),
            _row(s.labelReviewProtein, _protein, 'g'),
            _row(s.labelReviewSalt, _salt, 'g'),
            if (!values.energyMatchesMacros)
              Padding(
                padding: const EdgeInsets.only(top: Dimens.spacing8),
                child: Text(
                  s.readNutritionLabelCheckEnergy,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const Divider(height: Dimens.spacing24),
            _row(s.labelReviewAmount, _grams, 'g', bold: true),
            if (canAdd)
              Padding(
                padding: const EdgeInsets.only(top: Dimens.spacing8),
                child: Text(
                  s.labelReviewTotal(
                    _format(grams),
                    scaled(values.energyKcal).round(),
                    _format(scaled(values.fat)),
                    _format(scaled(values.carbs)),
                    _format(scaled(values.protein)),
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _saveForLater,
              onChanged: (value) =>
                  setState(() => _saveForLater = value ?? true),
              title: Text(s.labelReviewSaveForLater),
            ),
            const SizedBox(height: Dimens.spacing8),
            Semantics(
              identifier: 'label-review-add',
              child: FilledButton.icon(
                onPressed: canAdd
                    ? () => Navigator.of(context).pop(
                        LabelReviewResult(
                          name: _name.text.trim(),
                          values: values,
                          grams: grams,
                          saveForLater: _saveForLater,
                        ),
                      )
                    : null,
                icon: const Icon(Icons.add_rounded),
                label: Text(s.labelReviewAddButton),
              ),
            ),
            if (!canAdd)
              Padding(
                padding: const EdgeInsets.only(top: Dimens.spacing8),
                child: Text(
                  s.labelReviewNeedsValues,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    TextEditingController controller,
    String unit, {
    bool indent = false,
    bool bold = false,
  }) {
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: bold ? FontWeight.w700 : null,
    );
    return Padding(
      padding: const EdgeInsets.only(top: Dimens.spacing8),
      child: Row(
        children: [
          if (indent) const SizedBox(width: Dimens.spacing16),
          Expanded(child: Text(label, style: textStyle)),
          SizedBox(
            width: 120,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.end,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                suffixText: unit,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
