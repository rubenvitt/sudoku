import Foundation

/// Looks `key` up in the package's String Catalog. nil follows the app's language like any localized string;
/// a language code ("de", "en", …) forces that language, so tests don't depend on the machine's settings.
func localized(_ key: String.LocalizationValue, _ language: String?) -> String {
    String(localized: key, bundle: bundle(for: language))
}

private func bundle(for language: String?) -> Bundle {
    guard let language, let path = Bundle.module.path(forResource: language, ofType: "lproj"),
          let bundle = Bundle(path: path) else { return .module }
    return bundle
}
