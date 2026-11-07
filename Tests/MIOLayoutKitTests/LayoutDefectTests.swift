//
//  LayoutDefectTests.swift
//  MIOLayoutKitTests
//
//  Regression tests for the defects listed in the P2 review (Specs/miolayoutkit_review.md).
//

import XCTest
@testable import MIOLayoutKit
@testable import MIOLayoutHTML
@testable import MIOLayoutText

final class LayoutDefectTests: XCTestCase {

    private func html(_ page: Page, _ render: HTMLRender = HTMLRender()) -> String {
        Layout(page).render(render)
        return String(data: render.output(), encoding: .utf8)!
    }

    // MARK: 1. VStack flex uses the height

    func test_vstack_setDimension_splitsHeightBetweenFlexChildren() {
        let stack = VStack<LayoutItem>()
        let a = LayoutItem(1)
        let b = LayoutItem(3)
        stack.add(a)
        stack.add(b)
        stack.meassure(TextRender())

        stack.setDimension(Size(width: 10, height: 100))

        XCTAssertEqual(a.dimensions.height, 25)
        XCTAssertEqual(b.dimensions.height, 75)
    }

    // MARK: 2. Cloning a LocalizedText keeps its key and class

    func test_localizedText_clone_keepsTranslationKey() {
        let text = LocalizedText("GREETING")
        text.apply_translation(["GREETING": "Hola"])

        let copy = text.clone()

        XCTAssertTrue(copy is LocalizedText)
        XCTAssertEqual(copy.original_text, "GREETING")
        XCTAssertEqual(copy.text, "Hola")
        (copy as? LocalizedText)?.apply_translation(["GREETING": "Hello"])
        XCTAssertEqual(copy.text, "Hello")
    }

    // MARK: 3. Measuring a table twice gives the same size

    func test_table_meassure_isRepeatable() {
        let table = Table()
        table.addColumn("a", "Alpha")
        table.addColumn("b", "Beta")
        table.addRow(["a": "1", "b": "two"])
        let context = TextRender()

        table.meassure(context)
        let first = table.size
        table.meassure(context)

        XCTAssertEqual(table.size.width, first.width)
        XCTAssertEqual(table.size.height, first.height)
    }

    // MARK: 4. HTML escapes text and renders the table footer

    func test_html_escapesText() {
        let page = A4()
        page.add(Text("Fish & Chips <b>\"x\"</b>"))

        let out = html(page)

        XCTAssertTrue(out.contains("Fish &amp; Chips &lt;b&gt;&quot;x&quot;&lt;/b&gt;"), out)
        XCTAssertFalse(out.contains("<b>"))
    }

    func test_html_escapesTableCells() {
        let page = A4()
        let table = Table()
        table.addColumn("a", "A & B")
        table.addRow(["a": "<script>"])
        page.add(table)

        let out = html(page)

        XCTAssertTrue(out.contains("A &amp; B"), out)
        XCTAssertTrue(out.contains("&lt;script&gt;"), out)
        XCTAssertFalse(out.contains("<script>"))
    }

    func test_html_rendersTableFooter() {
        let page = A4()
        let table = Table()
        table.addColumn("name", "Name")
        table.addColumn("total", "Total")
        table.addRow(["name": "Coffee", "total": "2,00"])
        table.addFooterRow(["name": "TOTAL", "total": "2,00"])
        page.add(table)

        let out = html(page)

        XCTAssertTrue(out.contains("<tfoot"), out)
        XCTAssertTrue(out.contains(">TOTAL</div>"), out)
    }

    // MARK: 5. Text renderer: balanced container stack and footer

    func test_textRender_keepsContainerStackBalanced() {
        let render = TextRender()
        let page = Page(Size(width: 40, height: 0))
        let table = Table()
        table.addColumn("a", "A")
        table.addRow(["a": "1"])
        page.add(table)

        Layout(page).render(render)

        // beginRender pushes the root; every begin/end pair must cancel out
        XCTAssertEqual(render.containerStack.count, 1)
    }

    func test_textRender_rendersTableFooter() {
        let render = TextRender()
        let page = Page(Size(width: 40, height: 0))
        let table = Table()
        table.addColumn("name", "Name")
        table.addColumn("total", "Total", align: .right)
        table.addRow(["name": "Coffee", "total": "2,00"])
        table.addFooterRow(["name": "TOTAL", "total": "2,00"])
        page.add(table)

        Layout(page).render(render)

        XCTAssertEqual(String(data: render.output(), encoding: .utf8), """
+------+-----+
|Name  |Total|
+------+-----+
|Coffee| 2,00|
+------+-----+
|TOTAL | 2,00|
+------+-----+
""")
    }

    // MARK: 7. Containers of a specific item type render

    func test_typedContainer_renders() {
        let page = A4()
        let row = HStack<Text>()
        row.add(Text("left"))
        row.add(Text("right"))
        page.add(row)

        let out = html(page)

        XCTAssertTrue(out.contains(">left</div>"), out)
        XCTAssertTrue(out.contains(">right</div>"), out)
    }

    // MARK: 8. Currency keeps Decimal precision

    func test_stringCurrency_keepsDecimalPrecision() {
        let render = HTMLRender()
        render.localeIdentifier = "en_US"

        // 17 significant digits: a Double cannot hold the cents
        let value = Decimal(string: "1234567890123456.78")!

        XCTAssertEqual(render.stringCurrency(from: value), "$1,234,567,890,123,456.78")
    }

    func test_stringCurrency_roundsTheExactDecimal() {
        let render = HTMLRender()
        render.localeIdentifier = "en_US"
        // As a Double this is 999999.99499…, which rounds down; the exact value is a tie
        // and rounds half-even (NumberFormatter's mode) up.
        XCTAssertEqual(render.stringCurrency(from: Decimal(string: "999999.995")!), "$1,000,000.00")
        // rounds to zero: no "-$0.00" (the Double path printed one)
        XCTAssertEqual(render.stringCurrency(from: Decimal(string: "-0.004")!), "$0.00")
    }

    func test_decimalFormatting_matchesNumberFormatterForOrdinaryAmounts() {
        // Same output as NumberFormatter wherever a Double is exact enough
        for locale in ["es_ES", "en_US", "de_DE", "fr_FR", "en_GB"] {
            let render = HTMLRender()
            render.localeIdentifier = locale
            for text in ["0", "1", "0.5", "12.345", "1234.5", "-1234.56", "-0.01", "100", "0.125", "1234567.891"] {
                let d = Decimal(string: text)!
                let viaDouble = render.currencyFromatter.string(from: NSNumber(value: NSDecimalNumber(decimal: d).doubleValue))!
                XCTAssertEqual(render.stringCurrency(from: d), viaDouble, "\(locale) \(text)")
                let numberViaDouble = render.numberFormatter.string(from: NSNumber(value: NSDecimalNumber(decimal: d).doubleValue))!
                XCTAssertEqual(render.stringNumber(from: d), numberViaDouble, "number \(locale) \(text)")
            }
        }
    }
}
