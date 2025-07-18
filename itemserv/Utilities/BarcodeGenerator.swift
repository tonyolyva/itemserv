import Foundation

func generateRandomEAN13() -> String {
    var digits = [0] + (0..<11).map { _ in Int.random(in: 0...9) }
    let checksum = calculateEAN13Checksum(for: digits)
    digits.append(checksum)
    return digits.map(String.init).joined()
}

private func calculateEAN13Checksum(for digits: [Int]) -> Int {
    guard digits.count == 12 else { return 0 }
    let sum = digits.enumerated().reduce(0) { result, pair in
        let (index, digit) = pair
        return result + digit * (index.isMultiple(of: 2) ? 1 : 3)
    }
    return (10 - (sum % 10)) % 10
}
