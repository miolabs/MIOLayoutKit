//
//  DecimalFormatting.swift
//  MIOLayoutKit
//
//  Locale-aware formatting of Decimal values without losing digits.
//
//  NumberFormatter on Linux (swift-corelibs-foundation) converts an NSDecimalNumber to Double
//  before formatting, so large amounts lose their cents. Here the formatter only formats the
//  integer part plus ".5" (exact in a Double below 2^52, about 4.5e15), which gives the locale's
//  grouping rules, separators, currency symbol position and sign. The ".5" is then replaced
//  with the real fraction digits taken from the Decimal.
//

import Foundation

package enum DecimalFormatting {

    private static let half = Decimal( sign: .plus, exponent: -1, significand: 5 )

    /// Formats `value` like `formatter` would, keeping every digit of the Decimal.
    package static func string ( from value: Decimal, using formatter: NumberFormatter ) -> String {
        let maxFraction = max( 0, formatter.maximumFractionDigits )
        let minFraction = max( 0, min( formatter.minimumFractionDigits, maxFraction ) )
        let rounded     = round( value, scale: maxFraction, mode: formatter.roundingMode )

        if maxFraction == 0 {
            return formatter.string( from: NSDecimalNumber( decimal: rounded ) ) ?? rounded.description
        }

        let negative = rounded < 0
        let magnitude = negative ? -rounded : rounded
        let plain    = magnitude.description      // "1234.5", "0.01", "12"
        let parts    = plain.split( separator: ".", omittingEmptySubsequences: false )
        let integer  = round( magnitude, scale: 0, mode: .down )

        var fraction = parts.count > 1 ? String( parts[1] ) : ""
        while fraction.count > minFraction && fraction.hasSuffix( "0" ) { fraction.removeLast( ) }
        if fraction.count < minFraction { fraction += String( repeating: "0", count: minFraction - fraction.count ) }

        let proxy  = negative ? -( integer + half ) : integer + half
        let output = formatter.string( from: NSDecimalNumber( decimal: proxy ) ) ?? plain

        let separator = formatter.numberStyle == .currency
            ? ( formatter.currencyDecimalSeparator ?? formatter.decimalSeparator ?? "." )
            : ( formatter.decimalSeparator ?? "." )
        let marker = separator + "5" + String( repeating: "0", count: max( 0, minFraction - 1 ) )

        guard let range = output.range( of: marker, options: .backwards ) else { return output }
        return output.replacingCharacters( in: range, with: fraction.isEmpty ? "" : separator + fraction )
    }

    /// Rounds like `mode` (the formatter's roundingMode; NumberFormatter's default is half-even).
    static func round ( _ value: Decimal, scale: Int, mode: NumberFormatter.RoundingMode = .halfEven ) -> Decimal {
        var source = value
        var result = Decimal( )
        let negative = value < 0
        let decimalMode: NSDecimalNumber.RoundingMode
        switch mode {
        case .halfEven:            decimalMode = .bankers
        case .halfUp, .halfDown:   decimalMode = .plain      // ties away from zero (half-down is rare: treated as half-up)
        case .up:                  decimalMode = negative ? .down : .up   // away from zero
        case .down:                decimalMode = negative ? .up : .down   // towards zero
        case .ceiling:             decimalMode = .up
        case .floor:               decimalMode = .down
        @unknown default:          decimalMode = .bankers
        }
        NSDecimalRound( &result, &source, scale, decimalMode )
        return result
    }
}
