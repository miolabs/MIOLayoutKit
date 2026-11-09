//
//  TextDataTable.swift
//  MIOLayoutText
//
//  DataTable as a character grid: borders around the header, the body and the footer
//  (not between every row, so long reports stay compact). Column width = the longest
//  title / value; indented cells get two spaces per level.
//

import Foundation
import MIOLayoutKit

extension TextRender {

    /// The table's lines, ready to write.
    public func dataTableLines ( _ table: DataTable ) -> [String] {
        let formatter = valueFormatter
        let columns = table.visibleColumns
        let rows = table.rowsToDraw

        var body: [[String]] = []
        for row in rows {
            body.append( columns.map { c in
                let ( text, style ) = table.cellText( row: row, column: c, formatter: formatter )
                let indent = style?.indentLevel ?? 0
                return String( repeating: "  ", count: max( 0, indent ) ) + text
            } )
        }
        let header = columns.map { localizedString( $0.title ) }
        let footers: [[String]] = table.footersToDraw.map { footer in
            let values = table.footerValues( footer )
            return columns.enumerated( ).map { ( i, c ) in
                if i == 0, let label = footer.label, values[ c.key ] == nil { return localizedString( label ) }
                return formatter.string( values[ c.key ], format: c.format )
            }
        }

        var widths = columns.map { _ in 0 }
        for line in ( table.showHeader ? [ header ] : [] ) + body + footers {
            for ( i, cell ) in line.enumerated( ) { widths[ i ] = max( widths[ i ], cell.count ) }
        }

        func border ( ) -> String { "+" + widths.map { String( repeating: "-", count: $0 ) }.joined( separator: "+" ) + "+" }
        func line ( _ cells: [String] ) -> String {
            "|" + zip( cells, zip( widths, columns ) ).map { cell, wc in
                let ( width, column ) = wc
                let space = max( 0, width - cell.count )
                switch column.align {
                case .left:   return cell + String( repeating: " ", count: space )
                case .right:  return String( repeating: " ", count: space ) + cell
                case .center: return String( repeating: " ", count: space / 2 ) + cell + String( repeating: " ", count: space - space / 2 )
                }
            }.joined( separator: "|" ) + "|"
        }

        var out: [String] = []
        if let title = table.title, !title.isEmpty { out.append( localizedString( title ) ) }
        out.append( border( ) )
        if table.showHeader { out.append( line( header ) ); out.append( border( ) ) }
        for cells in body { out.append( line( cells ) ) }
        if !body.isEmpty { out.append( border( ) ) }
        for cells in footers { out.append( line( cells ) ) }
        if !footers.isEmpty { out.append( border( ) ) }
        return out
    }
}
