//
//  DataTablePaginationTests.swift
//  MIOLayoutKitTests
//
//  DataTable across pages: fragments, repeated header, footers on the last page.
//

import XCTest
@testable import MIOLayoutKit
@testable import MIOLayoutText
#if canImport(MIOLayoutPDFLib)
@testable import MIOLayoutPDFLib
#endif

/// Text renderer with round metrics: title 2, header 1, row 1, footer 1.
private final class GridRender: TextRender {
    override func dataTableMetrics(_ table: DataTable) -> DataTableMetrics {
        DataTableMetrics(title: 2, header: 1, row: 1, footer: 1)
    }
    override func meassure(_ item: LayoutItem) -> Size {
        if let table = item as? DataTable { return Size(width: 10, height: dataTableMetrics(table).height(of: table)) }
        if item is Text { return Size(width: 10, height: 1) }
        return super.meassure(item)
    }
}

final class DataTablePaginationTests: XCTestCase {

    private func table(rows: Int, footers: Int = 1, title: String? = nil) -> DataTable {
        DataTable(title: title,
                  columns: [DataColumn(key: "n", title: "N", format: ValueFormat(.integer), total: true)],
                  source: DictionaryRowsSource(rows: (0..<rows).map { ["n": $0] }),
                  footers: Array(repeating: DataFooter.totals(), count: footers))
    }

    private func page(height: Float, _ items: LayoutItem...) -> Page {
        let p = Page(Size(width: 100, height: height))
        for i in items { p.add(i) }
        return p
    }

    private func fragments(_ page: Page) -> [DataTable] {
        page.children.compactMap { $0 as? DataTable }
    }

    func test_fitsOnOnePage_isNotSplit() {
        let p = page(height: 20, table(rows: 10))       // header 1 + 10 rows + footer 1 = 12
        Layout(p).render(GridRender(), withPagination: p)
        XCTAssertEqual(fragments(p).count, 1)
        XCTAssertNil(fragments(p)[0].pageRows)
    }

    func test_longTable_splitsPerPage_withHeaderRepeated() {
        let p = page(height: 10, Text("Title line"), table(rows: 20))
        Layout(p).render(GridRender(), withPagination: p)

        let f = fragments(p)
        // page 1: title text 1 + header 1 → 8 rows; page 2: header + 9 rows; page 3: header + 3 rows + footer
        XCTAssertEqual(f.map { $0.pageRows }, [0..<8, 8..<17, 17..<20])
        XCTAssertEqual(f.map { $0.showHeader }, [true, true, true])
        XCTAssertEqual(f.map { $0.showFooterRows }, [false, false, true])
        XCTAssertNotNil(f[0].fillHeight)
        XCTAssertNotNil(f[1].fillHeight)
        XCTAssertNil(f[2].fillHeight)
        // each fragment starts at the top of its page (after the first)
        XCTAssertEqual(f[1].absPosition().y, 10, accuracy: 0.05)
        XCTAssertEqual(f[2].absPosition().y, 20, accuracy: 0.05)
    }

    func test_footersThatDoNotFit_goToTheirOwnPage_withHeader() {
        // header 1 + 9 rows fills a 10-high page exactly: the 2 footers need the next page
        let p = page(height: 10, table(rows: 9, footers: 2))
        Layout(p).render(GridRender(), withPagination: p)

        let f = fragments(p)
        XCTAssertEqual(f.map { $0.pageRows }, [0..<9, 9..<9])
        XCTAssertEqual(f.map { $0.showFooterRows }, [false, true])
        XCTAssertTrue(f[1].showHeader)
    }

    func test_tableStartingNearThePageEnd_beginsOnTheNextPage() {
        // 9 lines of text leave 1 line: no room for header + a row
        let texts = (0..<9).map { _ in Text("x") as LayoutItem }
        let p = Page(Size(width: 100, height: 10))
        for t in texts { p.add(t) }
        p.add(table(rows: 3))
        Layout(p).render(GridRender(), withPagination: p)

        let f = fragments(p)
        XCTAssertEqual(f.map { $0.pageRows }, [0..<0, 0..<3])
        XCTAssertFalse(f[0].showHeader)             // nothing but a filler on the first page
        XCTAssertEqual(f[1].absPosition().y, 10, accuracy: 0.05)
    }

    func test_itemsAfterTheTable_moveBelowTheLastFragment() {
        let after = Text("after")
        let p = page(height: 10, table(rows: 15), after)
        Layout(p).render(GridRender(), withPagination: p)
        // page 1: header + 9 rows; page 2: header + 6 rows + footer = 8 → "after" at 18
        XCTAssertEqual(after.absPosition().y, 18, accuracy: 0.05)
    }

    func test_fragmentsShareTotalsOfTheWholeTable() {
        let p = page(height: 10, table(rows: 20))
        Layout(p).render(GridRender(), withPagination: p)
        let last = fragments(p).last!
        XCTAssertEqual(last.totals()["n"], Decimal((0..<20).reduce(0, +)))
    }

    #if canImport(MIOLayoutPDFLib) && PDFLib
    /// Counts pages and records the rows each page's fragment draws.
    private final class CountingPDF: PDFRender_PDFLib {
        var pages = 0
        var drawn: [[Int]] = []
        override func beginPage(_ page: Page) { pages += 1; super.beginPage(page) }
        override func renderItem(_ item: LayoutItem) {
            if let t = item as? DataTable { drawn.append(Array(t.rowsToDraw)) }
            super.renderItem(item)
        }
    }

    func test_pdf_longReport_spreadsOverPages_andRendersEveryRowOnce() {
        let rows = 300
        let t = DataTable(title: "Sales",
                          columns: [DataColumn(key: "name", title: "Product"),
                                    DataColumn(key: "total", title: "Total", format: ValueFormat(.currency), total: true)],
                          source: DictionaryRowsSource(rows: (0..<rows).map { ["name": "Product \($0)", "total": "\($0).25"] }),
                          footers: [.totals()])
        let p = A4()
        p.setMargins(Margin(20, 20, 20, 20))
        p.add(Text("Report header"))
        p.add(t)
        let render = CountingPDF()
        render.localeIdentifier = "en_US"

        Layout(p).render(render, withPagination: p)

        XCTAssertGreaterThan(render.pages, 4)                         // 300 rows of 14 pt on A4
        XCTAssertEqual(render.drawn.flatMap { $0 }, Array(0..<rows))   // every row once, in order
        XCTAssertEqual(render.drawn.count, render.pages)              // one fragment per page
        XCTAssertGreaterThan(render.output().count, 1000)
    }
    #endif
}
