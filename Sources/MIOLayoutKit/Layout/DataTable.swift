//
//  DataTable.swift
//  MIOLayoutKit
//
//  A table of raw, typed data: the report table. Unlike `Table` (one Text item per cell,
//  values already formatted), a DataTable keeps its rows in a data source and formats each
//  cell at render time from its column's ValueFormat. Rows are never copied into layout
//  items, so a report with thousands of rows stays cheap, and sorting / filtering is just a
//  different `rowOrder`.
//
//  Row semantics follow the report scripts (dl/report.py) and the web manager:
//  sub rows break a root row down, so totals add root rows only, and rows flagged
//  `excludedFromTotals` are skipped too.
//

import Foundation

public struct DataColumn: Sendable {
    public var key: String
    public var title: String
    public var format: ValueFormat
    public var align: TextAlign
    public var hidden: Bool
    /// The column has a total (sum) in the totals footer.
    public var total: Bool

    public init ( key: String
                , title: String
                , format: ValueFormat = ValueFormat( .string )
                , align: TextAlign? = nil
                , hidden: Bool = false
                , total: Bool = false ) {
        self.key = key
        self.title = title
        self.format = format
        // numbers right-aligned unless told otherwise
        self.align = align ?? ( format.type.isNumeric ? .right : .left )
        self.hidden = hidden
        self.total = total
    }
}

extension ValueType {
    public var isNumeric: Bool {
        switch self {
        case .number, .integer, .percentage, .currency, .longCurrency: return true
        default: return false
        }
    }
}

public struct DataRowStyle: Sendable, Equatable {
    public var isSubRow: Bool
    public var excludedFromTotals: Bool
    /// One of the report colours: "red", "green", "yellow", "grey", "strong".
    public var color: String?

    public init ( isSubRow: Bool = false, excludedFromTotals: Bool = false, color: String? = nil ) {
        self.isSubRow = isSubRow
        self.excludedFromTotals = excludedFromTotals
        self.color = color
    }
}

public struct DataCellStyle: Sendable, Equatable {
    /// Replaces the column's format for this cell.
    public var format: ValueFormat?
    public var indentLevel: Int
    public var color: String?

    public init ( format: ValueFormat? = nil, indentLevel: Int = 0, color: String? = nil ) {
        self.format = format
        self.indentLevel = indentLevel
        self.color = color
    }
}

/// Where a DataTable reads its rows from. Rows are addressed by index (0..<rowCount).
public protocol DataTableSource: AnyObject {
    var rowCount: Int { get }
    func value ( row: Int, column: String ) -> Any?
    func rowStyle ( row: Int ) -> DataRowStyle
    func cellStyle ( row: Int, column: String ) -> DataCellStyle?
}

extension DataTableSource {
    public func rowStyle ( row: Int ) -> DataRowStyle { DataRowStyle( ) }
    public func cellStyle ( row: Int, column: String ) -> DataCellStyle? { nil }
}

/// A footer line: either the computed totals of the visible rows, or given values.
public struct DataFooter {
    public enum Kind {
        case totals
        case values( [String:Any] )
    }
    public var label: String?
    public var kind: Kind

    public init ( label: String? = nil, kind: Kind ) {
        self.label = label
        self.kind = kind
    }

    public static func totals ( label: String? = "TOTAL" ) -> DataFooter { DataFooter( label: label, kind: .totals ) }
}

public final class DataTable: LayoutItem {
    public var title: String?
    public var columns: [DataColumn]
    public var source: DataTableSource
    /// Rows to show, in order (indexes into the source). nil = every row in source order.
    /// Sorting and filtering change this, never the source.
    public var rowOrder: [Int]?
    public var footers: [DataFooter]
    public var showHeader: Bool

    public init ( title: String? = nil
                , columns: [DataColumn]
                , source: DataTableSource
                , footers: [DataFooter] = []
                , showHeader: Bool = true ) {
        self.title = title
        self.columns = columns
        self.source = source
        self.footers = footers
        self.showHeader = showHeader
        super.init( )
    }

    public var visibleColumns: [DataColumn] { columns.filter { !$0.hidden } }

    public var visibleRows: [Int] { rowOrder ?? Array( 0..<source.rowCount ) }

    /// Sum of each total column over the visible root rows (sub rows and rows excluded from
    /// totals do not add), as exact decimals.
    public func totals ( ) -> [String:Decimal] {
        var sums: [String:Decimal] = [:]
        let keys = columns.filter { $0.total }.map { $0.key }
        for key in keys { sums[ key ] = 0 }
        for row in visibleRows {
            let style = source.rowStyle( row: row )
            if style.isSubRow || style.excludedFromTotals { continue }
            for key in keys {
                if let v = source.value( row: row, column: key ), let d = ValueFormatter.decimal( from: v ) {
                    sums[ key ]! += d
                }
            }
        }
        return sums
    }

    /// The values of a footer line, by column key.
    public func footerValues ( _ footer: DataFooter ) -> [String:Any] {
        switch footer.kind {
        case .totals:             return totals( ).mapValues { $0 as Any }
        case .values( let v ):    return v
        }
    }

    /// The cell's display text and style, formatted with `formatter`.
    public func cellText ( row: Int, column: DataColumn, formatter: ValueFormatter ) -> ( text: String, style: DataCellStyle? ) {
        let style = source.cellStyle( row: row, column: column.key )
        let value = source.value( row: row, column: column.key )
        return ( formatter.string( value, format: style?.format ?? column.format ), style )
    }

    /// True for a numeric cell whose value is zero (the web greys those out).
    public func isZero ( row: Int, column: DataColumn ) -> Bool {
        let format = source.cellStyle( row: row, column: column.key )?.format ?? column.format
        guard format.type.isNumeric, let v = source.value( row: row, column: column.key ) else { return false }
        return ValueFormatter.decimal( from: v ) == 0
    }
}

// MARK: - Sources

/// Rows as dictionaries keyed by column, with the report v1 row keys for styles:
/// `__sub_row__`, `__no_subtotal__`, `__row_color__`, `__<key>__formatter__`,
/// `__<key>__indent_level__`, `__<key>__color__`.
public final class DictionaryRowsSource: DataTableSource {
    public var rows: [[String:Any]]

    public init ( rows: [[String:Any]] ) { self.rows = rows }

    public var rowCount: Int { rows.count }

    public func value ( row: Int, column: String ) -> Any? { rows[ row ][ column ] }

    public func rowStyle ( row: Int ) -> DataRowStyle {
        let r = rows[ row ]
        return DataRowStyle( isSubRow: ( r[ "__sub_row__" ] as? Bool ) == true
                           , excludedFromTotals: ( r[ "__no_subtotal__" ] as? Bool ) == true
                           , color: r[ "__row_color__" ] as? String )
    }

    public func cellStyle ( row: Int, column: String ) -> DataCellStyle? {
        let r = rows[ row ]
        let formatter = r[ "__\(column)__formatter__" ] as? String
        let indent = ( r[ "__\(column)__indent_level__" ] as? Int ) ?? 0
        let color = r[ "__\(column)__color__" ] as? String
        if formatter == nil && indent == 0 && color == nil { return nil }
        return DataCellStyle( format: formatter.map { ValueFormat( typeName: $0 ) }, indentLevel: indent, color: color )
    }
}

/// Rows stored column by column (the report v2 layout): one value list per column, every list
/// `rowCount` long, plus sparse row and cell styles.
public final class ColumnarRowsSource: DataTableSource {
    public let rowCount: Int
    public var columns: [String:[Any?]]
    public var rowStyles: [Int:DataRowStyle]
    public var cellStyles: [String:[Int:DataCellStyle]]

    public init ( rowCount: Int
                , columns: [String:[Any?]]
                , rowStyles: [Int:DataRowStyle] = [:]
                , cellStyles: [String:[Int:DataCellStyle]] = [:] ) {
        self.rowCount = rowCount
        self.columns = columns
        self.rowStyles = rowStyles
        self.cellStyles = cellStyles
    }

    public func value ( row: Int, column: String ) -> Any? {
        guard let values = columns[ column ], row < values.count else { return nil }
        return values[ row ]
    }

    public func rowStyle ( row: Int ) -> DataRowStyle { rowStyles[ row ] ?? DataRowStyle( ) }

    public func cellStyle ( row: Int, column: String ) -> DataCellStyle? { cellStyles[ column ]?[ row ] }
}
