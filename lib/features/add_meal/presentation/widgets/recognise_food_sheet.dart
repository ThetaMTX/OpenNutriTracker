import 'package:flutter/material.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/features/add_meal/data/food_photo_recognizer.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// What the user did with the guesses.
class RecognitionChoice {
  /// Text to search for, or null for [askAi] / type it yourself.
  final String? query;

  /// The user wants the cloud "Snap meal" reading instead.
  final bool askAi;

  const RecognitionChoice.search(String this.query) : askAi = false;
  const RecognitionChoice.typeInstead() : query = null, askAi = false;
  const RecognitionChoice.askAi() : query = null, askAi = true;
}

/// Lists what the photo probably shows; picking one searches for it, so the
/// user then chooses the exact product or food from the normal results.
Future<RecognitionChoice?> showRecogniseFoodSheet(
  BuildContext context,
  FoodRecognition result, {
  required bool showAi,
}) {
  return showModalBottomSheet<RecognitionChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final s = S.of(sheetContext);
      final theme = Theme.of(sheetContext);
      final packText = result.packText;
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
                s.recogniseFoodSheetTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: Dimens.spacing4),
              Text(s.recogniseFoodSheetHint, style: theme.textTheme.bodySmall),
              const SizedBox(height: Dimens.spacing8),
              if (packText != null)
                Semantics(
                  identifier: 'recognise-pack-text',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.text_fields_rounded),
                    title: Text(packText),
                    subtitle: Text(s.recogniseFoodPackTextLabel),
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(RecognitionChoice.search(packText)),
                  ),
                ),
              for (final guess in result.dishes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.restaurant_rounded),
                  title: Text(guess.name),
                  trailing: Text(
                    s.recogniseFoodMatchPercent(
                      (guess.confidence * 100).round(),
                    ),
                    style: theme.textTheme.labelMedium,
                  ),
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(RecognitionChoice.search(guess.name)),
                ),
              if (result.modelMissing)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: Dimens.spacing8,
                  ),
                  child: Text(
                    s.recogniseFoodModelMissing,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              const Divider(),
              Semantics(
                identifier: 'recognise-type-instead',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.keyboard_rounded),
                  title: Text(s.recogniseFoodTypeInstead),
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(const RecognitionChoice.typeInstead()),
                ),
              ),
              if (showAi)
                Semantics(
                  identifier: 'recognise-ask-ai',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.auto_awesome_rounded),
                    title: Text(s.recogniseFoodAskAi),
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(const RecognitionChoice.askAi()),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
