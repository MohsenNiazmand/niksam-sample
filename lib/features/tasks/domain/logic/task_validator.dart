enum TitleError { empty, tooLong }

abstract final class TaskValidator {
  static const int maxTitleLength = 120;

  static TitleError? validateTitle(String rawTitle) {
    final trimmed = rawTitle.trim();
    if (trimmed.isEmpty) {
      return TitleError.empty;
    }
    if (trimmed.length > maxTitleLength) {
      return TitleError.tooLong;
    }
    return null;
  }
}
