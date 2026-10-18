import SwiftUI

/// Draft text is never silently clamped or committed while a number is incomplete.
struct NumberDraftField: View {
    let title: String
    @Binding var text: String
    let range: ClosedRange<Double>
    var isOptional = false
    @FocusState private var focused: Bool
    static func value(_ text: String, range: ClosedRange<Double>) -> Double? {
        let formatter = NumberFormatter(); formatter.locale = .current; formatter.numberStyle = .decimal
        let decimal = Locale.current.decimalSeparator ?? "."
        let candidate = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Avoid NumberFormatter's acceptance of a numeric prefix followed by garbage.
        let digits = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: decimal))
        guard !candidate.isEmpty, candidate.unicodeScalars.allSatisfy({ digits.contains($0) }), candidate.components(separatedBy: decimal).count <= 2,
              let value = formatter.number(from: candidate)?.doubleValue, value.isFinite, range.contains(value) else { return nil }
        return value
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title); Spacer(minLength: 12)
                TextField(title, text: $text).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(minWidth: 70, maxWidth: 120).focused($focused)
            }
            if !(isOptional && text.isEmpty) && Self.value(text, range: range) == nil {
                Text("Enter a number from \(range.lowerBound.formatted()) to \(range.upperBound.formatted()).").font(.caption).foregroundStyle(.red)
            }
        }.padding(.vertical, 3).toolbar {
            ToolbarItemGroup(placement: .keyboard) { if focused { Spacer(); Button("Done") { focused = false } } }
        }
    }
}
