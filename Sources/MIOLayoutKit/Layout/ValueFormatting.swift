//
//  ValueFormatting.swift
//  MIOLayoutKit
//
//  Formats raw values (numbers, dates) for display, driven by a format spec. The type
//  names are the report column types of the script server / web manager ("currency",
//  "long-currency", "date-time", …) and the defaults match the web manager's formatters,
//  so a value renders the same in a PDF, an HTML page and the web report table.
//
//  Decimals never go through Double (see DecimalFormatting). Dates given as strings are
//  read as local wall time ("2026-01-31", "2026-01-31 10:30:00", "10:30:00"), the way the
//  server sends them: no UTC conversion.
//

import Foundation

public enum ValueType: String, Sendable, CaseIterable {
    case string
    case localizedString = "localized-string"
    case number
    case integer
    case percentage
    case currency
    case longCurrency    = "long-currency"
    case date
    case time
    case dateTime        = "date-time"
    case longDate        = "long-date"
    case longDateTime    = "long-date-time"
    /// A measure-unit cell: the report sends {quantity, unit, isContainer, title}; shows `title`.
    case units
}

public struct ValueFormat: Sendable, Equatable {
    public var type: ValueType
    /// Overrides the type's default fraction digits (numeric types).
    public var minimumFractionDigits: Int?
    public var maximumFractionDigits: Int?
    /// ISO currency code ("EUR"); default: the locale's currency.
    public var currencyCode: String?
    /// "EUR 12,00" instead of "12,00 €" (the web manager's ISO-code currency style).
    public var currencyISOCodeStyle: Bool

    public init ( _ type: ValueType
                , minimumFractionDigits: Int? = nil
                , maximumFractionDigits: Int? = nil
                , currencyCode: String? = nil
                , currencyISOCodeStyle: Bool = false ) {
        self.type = type
        self.minimumFractionDigits = minimumFractionDigits
        self.maximumFractionDigits = maximumFractionDigits
        self.currencyCode = currencyCode
        self.currencyISOCodeStyle = currencyISOCodeStyle
    }

    /// From a report column type string; unknown types read as `.string`.
    public init ( typeName: String ) {
        self.init( ValueType( rawValue: typeName ) ?? .string )
    }

    /// The web manager's defaults: (min, max) fraction digits.
    var defaultFractionDigits: ( Int, Int ) {
        switch type {
        case .number:       return ( 0, 3 )
        case .integer:      return ( 0, 0 )
        case .percentage:   return ( 2, 4 )
        case .currency:     return ( 2, 2 )
        case .longCurrency: return ( 2, 6 )
        default:            return ( 0, 0 )
        }
    }
}

/// Not thread-safe (caches formatters): use one per render.
public final class ValueFormatter {

    public let locale: Locale
    public let timeZone: TimeZone
    public var translations: [String:String]

    private var numberFormatters: [String:NumberFormatter] = [:]
    private var dateFormatters: [String:DateFormatter] = [:]

    public init ( locale: Locale = Locale( identifier: "es_ES" )
                , timeZone: TimeZone = .current
                , translations: [String:String] = [:] ) {
        self.locale = locale
        self.timeZone = timeZone
        self.translations = translations
    }

    /// Display text for `value`; nil and unreadable values give "".
    public func string ( _ value: Any?, format: ValueFormat ) -> String {
        guard let value = value, !(value is NSNull) else { return "" }

        switch format.type {
        case .string:
            return "\(value)"
        case .localizedString:
            let key = "\(value)"
            return translations[ key ] ?? key
        case .units:
            if let dict = value as? [String:Any] { return ( dict[ "title" ] as? String ) ?? "" }
            return "\(value)"
        case .number, .integer, .percentage, .currency, .longCurrency:
            guard let decimal = ValueFormatter.decimal( from: value ) else { return "\(value)" }
            let text = DecimalFormatting.string( from: decimal, using: numberFormatter( format ) )
            return format.type == .percentage ? text + "%" : text
        case .date, .time, .dateTime, .longDate, .longDateTime:
            guard let date = date( from: value ) else { return "\(value)" }
            return dateFormatter( format.type ).string( from: date )
        }
    }

    // MARK: - Values

    static func decimal ( from value: Any ) -> Decimal? {
        switch value {
        case let d as Decimal:        return d
        case let d as NSDecimalNumber: return d.decimalValue
        case let i as Int:            return Decimal( i )
        case let i as Int64:          return Decimal( i )
        case let i as Int32:          return Decimal( Int( i ) )
        case let d as Double:         return d.isFinite ? Decimal( string: "\(d)" ) : nil   // shortest round-trip text
        case let f as Float:          return f.isFinite ? Decimal( string: "\(f)" ) : nil
        case let n as NSNumber:       return Decimal( string: n.stringValue )
        case let s as String:
            let t = s.trimmingCharacters( in: .whitespaces )
            return t.isEmpty ? nil : Decimal( string: t, locale: Locale( identifier: "en_US_POSIX" ) )
        default:                      return nil
        }
    }

    func date ( from value: Any ) -> Date? {
        if let d = value as? Date { return d }
        guard let s = value as? String else { return nil }
        let text = s.trimmingCharacters( in: .whitespaces )
        for pattern in [ "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd", "HH:mm:ss", "HH:mm" ] {
            if let d = parser( pattern ).date( from: text ) { return d }
        }
        return nil
    }

    // MARK: - Formatters

    private func numberFormatter ( _ format: ValueFormat ) -> NumberFormatter {
        let ( defMin, defMax ) = format.defaultFractionDigits
        let minF = format.minimumFractionDigits ?? defMin
        let maxF = max( minF, format.maximumFractionDigits ?? defMax )
        let isCurrency = format.type == .currency || format.type == .longCurrency
        let key = "\(isCurrency)|\(minF)|\(maxF)|\(format.currencyCode ?? "")|\(format.currencyISOCodeStyle)"
        if let f = numberFormatters[ key ] { return f }

        let f = NumberFormatter( )
        f.locale = locale
        if isCurrency {
            f.numberStyle = format.currencyISOCodeStyle ? .currencyISOCode : .currency
            if let code = format.currencyCode { f.currencyCode = code }
        } else {
            f.numberStyle = .decimal
        }
        f.minimumFractionDigits = minF
        f.maximumFractionDigits = maxF
        numberFormatters[ key ] = f
        return f
    }

    private func dateFormatter ( _ type: ValueType ) -> DateFormatter {
        if let f = dateFormatters[ type.rawValue ] { return f }
        let f = DateFormatter( )
        f.locale = locale
        f.timeZone = timeZone
        switch type {
        case .date:         f.dateStyle = .short; f.timeStyle = .none
        case .time:         f.dateStyle = .none;  f.timeStyle = .short
        case .dateTime:     f.dateStyle = .short; f.timeStyle = .short
        case .longDate:     f.dateStyle = .full;  f.timeStyle = .none
        default:            f.dateStyle = .full;  f.timeStyle = .short
        }
        dateFormatters[ type.rawValue ] = f
        return f
    }

    private func parser ( _ pattern: String ) -> DateFormatter {
        let key = "parse|" + pattern
        if let f = dateFormatters[ key ] { return f }
        let f = DateFormatter( )
        f.locale = Locale( identifier: "en_US_POSIX" )
        f.timeZone = timeZone          // wall time in the venue's zone, never UTC-pinned
        f.dateFormat = pattern
        dateFormatters[ key ] = f
        return f
    }
}

extension RenderContext {
    /// A value formatter for this render's locale and translations.
    public func makeValueFormatter ( timeZone: TimeZone = .current ) -> ValueFormatter {
        ValueFormatter( locale: Locale( identifier: localeIdentifier ), timeZone: timeZone, translations: translations )
    }
}
