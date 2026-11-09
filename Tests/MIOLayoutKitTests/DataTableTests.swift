//
//  DataTableTests.swift
//  MIOLayoutKitTests
//

import XCTest
@testable import MIOLayoutKit
@testable import MIOLayoutHTML
@testable import MIOLayoutText

final class DataTableTests: XCTestCase {

    /// Sales by category shape: root rows with sub rows, a no-total adjustment, a zero.
    private func salesRows() -> [[String:Any]] {
        [
            ["name": "Drinks",  "qty": 3, "total": "12.50"],
            ["name": "Water",   "qty": 2, "total": "3.00", "__sub_row__": true, "__name__indent_level__": 1],
            ["name": "Wine",    "qty": 1, "total": "9.50", "__sub_row__": true, "__name__indent_level__": 1],
            ["name": "Food",    "qty": 1, "total": "100.10", "__row_color__": "green"],
            ["name": "Adjust",  "qty": 0, "total": "-5", "__no_subtotal__": true, "__total__color__": "red"],
            ["name": "Promo <x> & co", "qty": 0, "total": 0],
        ]
    }

    private func salesTable(_ rows: [[String:Any]]? = nil) -> DataTable {
        DataTable(title: "Sales",
                  columns: [
                    DataColumn(key: "name", title: "Category"),
                    DataColumn(key: "qty", title: "Qty", format: ValueFormat(.integer), total: true),
                    DataColumn(key: "total", title: "Total", format: ValueFormat(.currency), total: true),
                    DataColumn(key: "id", title: "Id", hidden: true),
                  ],
                  source: DictionaryRowsSource(rows: rows ?? salesRows()),
                  footers: [.totals()])
    }

    private func html(_ table: DataTable, locale: String = "en_US") -> String {
        let r = HTMLRender()
        r.localeIdentifier = locale
        return r.dataTableHTML(table)
    }

    // MARK: - Totals

    func test_totals_addRootRowsOnly() {
        let totals = salesTable().totals()
        // 12.50 + 100.10 + 0 (sub rows and the excluded adjustment do not add)
        XCTAssertEqual(totals["total"], Decimal(string: "112.6"))
        XCTAssertEqual(totals["qty"], 4)
        XCTAssertNil(totals["name"])
    }

    func test_totals_followRowOrder() {
        let table = salesTable()
        table.rowOrder = [3, 0]          // filtered + sorted: Food, Drinks
        XCTAssertEqual(table.totals()["total"], Decimal(string: "112.6"))
        table.rowOrder = [3]
        XCTAssertEqual(table.totals()["total"], Decimal(string: "100.1"))
    }

    func test_totals_areExactDecimals() {
        let rows: [[String:Any]] = (0..<10).map { _ in ["total": 0.1] }   // 10 × 0.1 as Double = 0.9999…
        let table = DataTable(columns: [DataColumn(key: "total", title: "T", format: ValueFormat(.currency), total: true)],
                              source: DictionaryRowsSource(rows: rows))
        XCTAssertEqual(table.totals()["total"], 1)
    }

    // MARK: - Sources

    func test_dictionarySource_readsReportV1Keys() {
        let source = DictionaryRowsSource(rows: salesRows())
        XCTAssertEqual(source.rowStyle(row: 1), DataRowStyle(isSubRow: true))
        XCTAssertEqual(source.rowStyle(row: 3), DataRowStyle(color: "green"))
        XCTAssertEqual(source.rowStyle(row: 4), DataRowStyle(excludedFromTotals: true))
        XCTAssertEqual(source.cellStyle(row: 1, column: "name"), DataCellStyle(indentLevel: 1))
        XCTAssertEqual(source.cellStyle(row: 4, column: "total"), DataCellStyle(color: "red"))
        XCTAssertNil(source.cellStyle(row: 0, column: "name"))
    }

    func test_columnarSource_matchesDictionarySource() {
        let columnar = ColumnarRowsSource(
            rowCount: 3,
            columns: ["name": ["A", "B", nil], "total": [1, 2, 3]],
            rowStyles: [1: DataRowStyle(isSubRow: true)],
            cellStyles: ["name": [1: DataCellStyle(indentLevel: 1)]])
        let table = DataTable(columns: [DataColumn(key: "name", title: "N"),
                                        DataColumn(key: "total", title: "T", format: ValueFormat(.integer), total: true)],
                              source: columnar)
        XCTAssertEqual(table.totals()["total"], 4)            // row 1 is a sub row
        XCTAssertNil(columnar.value(row: 2, column: "name"))
        XCTAssertNil(columnar.value(row: 9, column: "name"))  // out of range: nil, no crash
    }

    // MARK: - HTML

    func test_html_divTableMarkup_rowsAndFooter() {
        let r = HTMLRender()
        r.localeIdentifier = "en_US"
        let table = salesTable()
        let rows = r.dataTableRowsHTML(table, range: 0..<table.visibleRows.count, markup: .divTable)
        XCTAssertFalse(rows.contains("<tr") || rows.contains("<td"), rows)
        XCTAssertTrue(rows.contains("<div class=\"tr sub\" data-row=\"1\"><div class=\"td align-left\" style=\"padding-left: 20px\">Water</div>"), rows)
        // the row colour goes on every cell, as the web's .td.green
        XCTAssertTrue(rows.contains("<div class=\"tr\" data-row=\"3\"><div class=\"td align-left green\">"), rows)
        XCTAssertTrue(rows.contains("<div class=\"td align-right red\">-$5.00</div>"), rows)
        XCTAssertTrue(rows.contains("<div class=\"td align-right zero\">$0.00</div>"), rows)

        let footer = r.dataTableFooterRowsHTML(table, markup: .divTable)
        XCTAssertTrue(footer.hasPrefix("<div class=\"tr footer\"><div class=\"td align-left\">TOTAL</div>"), footer)
        XCTAssertTrue(footer.contains("<div class=\"td align-right\">$112.60</div></div>"), footer)
        // default markup: the same rows as before
        XCTAssertTrue(r.dataTableFooterRowsHTML(table).hasPrefix("<tr class=\"data-footer\"><td class=\"align-left\">TOTAL</td>"))
    }

    func test_reportValues_roundTiesUp_likeTheWeb() {
        // 2193.725 is a tie: the web manager shows 2.193,73 € (half-up), not ,72 (half-even)
        let f = ValueFormatter(locale: Locale(identifier: "es_ES"))
        let plain = { (s: String) in s.replacingOccurrences(of: "\u{00a0}", with: " ") }
        XCTAssertEqual(plain(f.string(Decimal(string: "2193.725")!, format: ValueFormat(.currency))), "2193,73 €")
        XCTAssertEqual(plain(f.string(Decimal(string: "-509.925")!, format: ValueFormat(.currency))), "-509,93 €")
        XCTAssertEqual(plain(f.string(Decimal(string: "6684.424")!, format: ValueFormat(.currency))), "6684,42 €")
        // the layout formatters keep NumberFormatter's half-even (invoices unchanged)
        let render = HTMLRender()
        render.localeIdentifier = "en_US"
        XCTAssertEqual(render.stringCurrency(from: Decimal(string: "2.125")!), "$2.12")
    }

    func test_html_footerZeroCells() {
        let table = DataTable(columns: [DataColumn(key: "name", title: "N"),
                                        DataColumn(key: "qty", title: "Q", format: ValueFormat(.integer), total: true)],
                              source: DictionaryRowsSource(rows: [["name": "A", "qty": 0]]), footers: [.totals()])
        let footer = HTMLRender().dataTableFooterRowsHTML(table, markup: .divTable)
        XCTAssertTrue(footer.contains("<div class=\"td align-right zero\">0</div>"), footer)
        XCTAssertTrue(footer.contains("<div class=\"td align-left\">TOTAL</div>"), footer)
    }

    func test_html_linkRows() {
        // v1 rows with a segue, and a columnar row marked as a link
        let dict = DictionaryRowsSource(rows: [["name": "A", "__segue_identifier__": "ShowReportViewController"], ["name": "B"]])
        XCTAssertTrue(dict.rowStyle(row: 0).isLink)
        XCTAssertFalse(dict.rowStyle(row: 1).isLink)
        let table = DataTable(columns: [DataColumn(key: "name", title: "N")], source: dict)
        let rows = HTMLRender().dataTableRowsHTML(table, range: 0..<2)
        XCTAssertTrue(rows.contains("<tr class=\"data-row link\" data-row=\"0\">"), rows)
        XCTAssertTrue(rows.contains("<tr class=\"data-row\" data-row=\"1\">"), rows)

        let columnar = ColumnarRowsSource(rowCount: 1, columns: ["name": ["C"]], rowStyles: [0: DataRowStyle(isSubRow: true, isLink: true)])
        let t2 = DataTable(columns: [DataColumn(key: "name", title: "N")], source: columnar)
        XCTAssertTrue(HTMLRender().dataTableRowsHTML(t2, range: 0..<1).contains("class=\"data-row sub-row link\""))
    }

    func test_html_structureFormattingAndEscaping() {
        let out = html(salesTable())

        XCTAssertTrue(out.hasPrefix("<table class=\"data-table\">\n<caption>Sales</caption>"), out)
        XCTAssertTrue(out.contains("<th class=\"align-left\">Category</th>"), out)
        XCTAssertTrue(out.contains("<th class=\"align-right\">Total</th>"), out)
        XCTAssertFalse(out.contains(">Id<"), "hidden column must not render")
        XCTAssertTrue(out.contains("<td class=\"align-right\">$12.50</td>"), out)
        XCTAssertTrue(out.contains("<tr class=\"data-row sub-row\" data-row=\"1\"><td class=\"align-left\" style=\"padding-left: 20px\">Water</td>"), out)
        XCTAssertTrue(out.contains("<tr class=\"data-row row-green\" data-row=\"3\">"), out)
        XCTAssertTrue(out.contains("<td class=\"align-right cell-red\">-$5.00</td>"), out)
        XCTAssertTrue(out.contains("Promo &lt;x&gt; &amp; co"), out)
        XCTAssertTrue(out.contains("<td class=\"align-right zero\">$0.00</td>"), out)
        XCTAssertTrue(out.contains("<tfoot>\n<tr class=\"data-footer\">\n<td class=\"align-left\">TOTAL</td>"), out)
        XCTAssertTrue(out.contains("<td class=\"align-right\">$112.60</td>"), out)
    }

    func test_html_rowWindow() {
        let r = HTMLRender()
        r.localeIdentifier = "en_US"
        let table = salesTable()

        let window = r.dataTableRowsHTML(table, range: 3..<5)

        XCTAssertEqual(window.components(separatedBy: "<tr ").count - 1, 2)
        XCTAssertTrue(window.contains("data-row=\"3\""))
        XCTAssertTrue(window.contains("data-row=\"4\""))
        XCTAssertEqual(r.dataTableRowsHTML(table, range: 4..<99).components(separatedBy: "<tr ").count - 1, 2)   // clamped
    }

    func test_html_respectsRowOrder() {
        let table = salesTable()
        table.rowOrder = [3, 0]
        let out = html(table)
        let food = out.range(of: ">Food<")!.lowerBound
        let drinks = out.range(of: ">Drinks<")!.lowerBound
        XCTAssertLessThan(food, drinks)
        XCTAssertFalse(out.contains(">Water<"))
    }

    func test_html_insidePageLayout() {
        let page = A4()
        page.add(Text("Report"))
        page.add(salesTable())
        let r = HTMLRender()
        r.localeIdentifier = "en_US"
        Layout(page).render(r)
        let out = String(data: r.output(), encoding: .utf8)!
        XCTAssertTrue(out.contains(">Report</div>\n<table class=\"data-table\">"), out)
        XCTAssertEqual(r.issues, [])
    }

    // MARK: - Text

    func test_text_grid() {
        let r = TextRender()
        r.localeIdentifier = "en_US"
        let table = salesTable([
            ["name": "Drinks", "qty": 3, "total": "12.50"],
            ["name": "Water", "qty": 2, "total": "3", "__sub_row__": true, "__name__indent_level__": 1],
        ])

        XCTAssertEqual(r.dataTableLines(table), [
            "Sales",
            "+--------+---+------+",
            "|Category|Qty| Total|",
            "+--------+---+------+",
            "|Drinks  |  3|$12.50|",
            "|  Water |  2| $3.00|",
            "+--------+---+------+",
            "|TOTAL   |  3|$12.50|",
            "+--------+---+------+",
        ])
    }

    func test_text_insidePageLayout() {
        let page = Page(Size(width: 40, height: 0))
        page.add(salesTable([["name": "A", "qty": 1, "total": 1]]))
        let r = TextRender()
        r.localeIdentifier = "en_US"
        Layout(page).render(r)
        let out = String(data: r.output(), encoding: .utf8)!
        XCTAssertTrue(out.contains("|A       |  1|$1.00|"), out)
    }
}
