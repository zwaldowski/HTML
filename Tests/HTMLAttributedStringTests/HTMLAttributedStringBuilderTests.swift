import XCTest
@testable import HTMLAttributedString

class HTMLAttributedStringBuilderTests: XCTestCase {

    func testFullSyntax() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .full)
        let text = AttributedString(html: #"""
                Neque <b>vestibulum,

            <i>turpis</i>!</b><br />
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            Neque vestibulum, turpis!

            """)
        XCTAssertEqual(text.runs[\.presentationIntent].map(\.0), [
            PresentationIntent(.paragraph, identity: 1)
        ])
        XCTAssertEqual(text.runs[\.inlinePresentationIntent].map(\.0), [
            nil,
            .stronglyEmphasized,
            [ .stronglyEmphasized, .emphasized ],
            .stronglyEmphasized,
            .lineBreak
        ])
    }

    func testSyntaxInlineOnly() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .inlineOnly)
        let text = AttributedString(html: #"""
                Neque <b>vestibulum,

            <i>turpis</i>!</b><br />
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            Neque vestibulum, turpis!

            """)
        XCTAssertEqual(text.runs[\.presentationIntent].map(\.0), [
            nil
        ])
        XCTAssertEqual(text.runs[\.inlinePresentationIntent].map(\.0), [
            nil,
            .stronglyEmphasized,
            [ .stronglyEmphasized, .emphasized ],
            .stronglyEmphasized,
            .lineBreak
        ])
    }

    func testSyntaxInlineOnlyPreservingWhitespace() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        let text = AttributedString(html: #"""
                Neque <b>vestibulum,

            <i>turpis</i>!</b><br />
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            Neque vestibulum,

            turpis!

            """)
        XCTAssertEqual(text.runs[\.presentationIntent].map(\.0), [
            nil
        ])
        XCTAssertEqual(text.runs[\.inlinePresentationIntent].map(\.0), [
            nil,
            .stronglyEmphasized,
            [ .stronglyEmphasized, .emphasized ],
            .stronglyEmphasized,
            .lineBreak
        ])
    }

    func testThatEntitiesParse() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .full)
        let text = AttributedString(html: #"""
            4 &lt; 5
            """#, options: options)

        XCTAssert(text.characters.elementsEqual("""
            4 < 5
            """))
    }

    func testThatCommentsAreIgnored() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .full)
        let text = AttributedString(html: #"""
                <p>Super. Computer.</p><!-- Blah blah blah. -->
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            Super. Computer.
            """)
        XCTAssertEqual(text.runs[\.presentationIntent].map(\.0), [
            PresentationIntent(.paragraph, identity: 1)
        ])
    }

    func testClearlyBrokenHTMLParses() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .full)
        let text = AttributedString(html: #"""
            <b FOO="BAR">Hello, <I>world</b></i>!<BR>
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            Hello, world!

            """)
        XCTAssertEqual(text.runs[\.inlinePresentationIntent].map(\.0), [
            .stronglyEmphasized,
            [ .stronglyEmphasized, .emphasized ],
            nil,
            .lineBreak
        ])
    }

    func testThatUnsupportedTagsAreIgnored() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .inlineOnly)
        let text = AttributedString(html: #"""
            <b>Hello, <br /><br /><i><font face="Times New Roman">world</font></i>!</b><br />
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            Hello,

            world!

            """)
    }

    func testThatLinksAreParsed() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .full)
        let text = AttributedString(html: #"""
            Super. Computer. <a href="http://www.apple.com/ipad-pro/" title="iPad Pro">Now in two sizes.</a>
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            Super. Computer. Now in two sizes.
            """)
        XCTAssertEqual(text.runs[\.link].map(\.0?.absoluteString), [
            nil,
            "http://www.apple.com/ipad-pro/"
        ])
    }

    func testThatInvalidLinksAreNotParsed() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .full)
        let text = AttributedString(html: #"""
            Super. Computer. <a>Now in two sizes.</a>
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            Super. Computer. Now in two sizes.
            """)
        XCTAssertEqual(text.runs[\.link].map(\.0?.absoluteString), [
            nil
        ])
    }

    func testLinksNotAllowed() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .full, allowsLinks: false)
        let text = AttributedString(html: #"""
            Super. Computer. <a href="http://www.apple.com/ipad-pro/" title="iPad Pro">Now in two sizes.</a>
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            Super. Computer. Now in two sizes.
            """)
        XCTAssertEqual(text.runs[\.link].map(\.0), [
            nil
        ])
    }

    func testWhitespaceStripping() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .inlineOnly)
        let text = AttributedString(html: #"""
            This&#9;tab should be stripped.&#10;This line should be spaced.&#13;And this one next.
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            This tab should be stripped. This line should be spaced. And this one next.
            """)
    }

    func testThatNonbreakingSpacesAreNotStripped() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .inlineOnly)
        let text = AttributedString(html: #"""
            Apple and Pay in Apple&nbsp;Pay should not be separated.
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            Apple and Pay in Apple Pay should not be separated.
            """)
    }

    func testOrderedList() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .full)
        let text = AttributedString(html: #"""
            <ol>
            <li>ol with closing tags</li>
            <li>item 2</li>
            <li>item 3</li>
            </ol>
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            ol with closing tagsitem 2item 3
            """)
        XCTAssertEqual(text.runs[\.presentationIntent].map(\.0), [
            PresentationIntent(.listItem(ordinal: 1), identity: 2, parent: PresentationIntent(.orderedList, identity: 1)),
            PresentationIntent(.listItem(ordinal: 2), identity: 3, parent: PresentationIntent(.orderedList, identity: 1)),
            PresentationIntent(.listItem(ordinal: 3), identity: 4, parent: PresentationIntent(.orderedList, identity: 1))
        ])
    }

    func testOrderedListWithoutClosingTags() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .full)
        let text = AttributedString(html: #"""
            <ol>
            <li>ol without closing tags
            <li>item 2
            <li>item 3
            </ol>
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            ol without closing tagsitem 2item 3
            """)
        XCTAssertEqual(text.runs[\.presentationIntent].map(\.0), [
            PresentationIntent(.listItem(ordinal: 1), identity: 2, parent: PresentationIntent(.orderedList, identity: 1)),
            PresentationIntent(.listItem(ordinal: 2), identity: 3, parent: PresentationIntent(.orderedList, identity: 1)),
            PresentationIntent(.listItem(ordinal: 3), identity: 4, parent: PresentationIntent(.orderedList, identity: 1))
        ])
    }

    func testOrderedListStart() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .full)
        let text = AttributedString(html: #"""
            <ol start="5"><li>a
            </li>
            <li>b</li></ol>
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            ab
            """)
        XCTAssertEqual(text.runs[\.presentationIntent].map(\.0), [
            PresentationIntent(.listItem(ordinal: 5), identity: 2, parent: PresentationIntent(.orderedList, identity: 1)),
            PresentationIntent(.listItem(ordinal: 6), identity: 3, parent: PresentationIntent(.orderedList, identity: 1))
        ])
    }

    func testOrderedListInlineOnly() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .inlineOnly)
        let text = AttributedString(html: #"""
            <ol>
            <li>ol with closing tags</li>
            <li>item 2</li>
            <li>item 3</li>
            </ol>
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            1. ol with closing tags
            2. item 2
            3. item 3
            """)
    }

    func testUnorderedList() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .full)
        let text = AttributedString(html: #"""
            <ul>
            <li>ul with closing tags</li>
            <li>item 2</li>
            <li>item 3</li>
            </ul>
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            ul with closing tagsitem 2item 3
            """)
        XCTAssertEqual(text.runs[\.presentationIntent].map(\.0), [
            PresentationIntent(.listItem(ordinal: 1), identity: 2, parent: PresentationIntent(.unorderedList, identity: 1)),
            PresentationIntent(.listItem(ordinal: 2), identity: 3, parent: PresentationIntent(.unorderedList, identity: 1)),
            PresentationIntent(.listItem(ordinal: 3), identity: 4, parent: PresentationIntent(.unorderedList, identity: 1))
        ])
    }

    func testUnorderedListWithoutClosingTags() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .full)
        let text = AttributedString(html: #"""
            <ul>
            <li>ul without closing tags
            <li>item 2
            <li>item 3
            </ul>
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            ul without closing tagsitem 2item 3
            """)
        XCTAssertEqual(text.runs[\.presentationIntent].map(\.0), [
            PresentationIntent(.listItem(ordinal: 1), identity: 2, parent: PresentationIntent(.unorderedList, identity: 1)),
            PresentationIntent(.listItem(ordinal: 2), identity: 3, parent: PresentationIntent(.unorderedList, identity: 1)),
            PresentationIntent(.listItem(ordinal: 3), identity: 4, parent: PresentationIntent(.unorderedList, identity: 1))
        ])
    }

    func testUnorderedListInlineOnly() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .inlineOnly)
        let text = AttributedString(html: #"""
            <ul>
            <li>ul with closing tags</li>
            <li>item 2</li>
            <li>item 3</li>
            </ul>
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            • ul with closing tags
            • item 2
            • item 3
            """)
    }

    func testListItemsNotInAList() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .full)
        let text = AttributedString(html: #"""
            <li>one</li>
            <li>two</li>
            <li>three</li>
            </ol>
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            onetwothree
            """)
        XCTAssertEqual(text.runs[\.presentationIntent].map(\.0), [
            PresentationIntent(.paragraph, identity: 1),
            PresentationIntent(.paragraph, identity: 2),
            PresentationIntent(.paragraph, identity: 3)
        ])
    }

    func testListWithOtherElements() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .full)
        let text = AttributedString(html: #"""
            <p>
                This is a test paragraph
            </p>
            <p>This is another test paragraph</p>
            <ul>
                <li>This is a test item</li>
                <li>This is another test item</li>
            </ul>
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            This is a test paragraphThis is another test paragraphThis is a test itemThis is another test item
            """)
        XCTAssertEqual(text.runs[\.presentationIntent].map(\.0), [
            PresentationIntent(.paragraph, identity: 1),
            PresentationIntent(.paragraph, identity: 2),
            PresentationIntent(.listItem(ordinal: 1), identity: 4, parent: PresentationIntent(.unorderedList, identity: 3)),
            PresentationIntent(.listItem(ordinal: 2), identity: 5, parent: PresentationIntent(.unorderedList, identity: 3))
        ])
    }

    func testNestedList() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .full)
        let text = AttributedString(html: #"""
            <ol>
                <li>  This is a list item.
                    <ul><li>This is a nested item.</li><li>This is another test item.</li></ul>
                    </li>
                <li>  This is another list item.  </li>
            </ol>
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            This is a list item.This is a nested item.This is another test item.This is another list item.
            """)
        XCTAssertEqual(text.runs[\.presentationIntent].map(\.0), [
            PresentationIntent(.listItem(ordinal: 1), identity: 2, parent: PresentationIntent(.orderedList, identity: 1)),
            PresentationIntent(.listItem(ordinal: 1), identity: 4, parent: PresentationIntent(.unorderedList, identity: 3, parent: PresentationIntent(.listItem(ordinal: 1), identity: 2, parent: PresentationIntent(.orderedList, identity: 1)))),
            PresentationIntent(.listItem(ordinal: 2), identity: 5, parent: PresentationIntent(.unorderedList, identity: 3, parent: PresentationIntent(.listItem(ordinal: 1), identity: 2, parent: PresentationIntent(.orderedList, identity: 1)))),
            PresentationIntent(.listItem(ordinal: 2), identity: 6, parent: PresentationIntent(.orderedList, identity: 1))
        ])
    }

    func testNestedListInlineOnly() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .inlineOnly)
        let text = AttributedString(html: #"""
            <ol>
                <li>  This is a list item.
                    <ul><li>This is a nested item.</li><li>This is another test item.</li></ul>
                    </li>
                <li>  This is another list item.  </li>
            </ol>
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            1. This is a list item.
             • This is a nested item.
             • This is another test item.
            2. This is another list item.
            """)
    }

    func testFullParagraphCentered() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .full)
        let text = AttributedString(html: #"""
            <center><p>Hello</p></center>
            """#, options: options)

        XCTAssertEqual(String(text.characters), "Hello")
        XCTAssertEqual(text.html.center, true)
        XCTAssertEqual(text.presentationIntent, PresentationIntent(.paragraph, identity: 2, parent: PresentationIntent(.paragraph, identity: 1)))
    }

    func testPartialParagraphCentered() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .full)
        let text = AttributedString(html: #"""
            <p>Hello <center>World</center>!</p>
            """#, options: options)

        XCTAssertEqual(String(text.characters), "HelloWorld!")
        XCTAssertEqual(text.runs[\.presentationIntent].map(\.0), [
            PresentationIntent(.paragraph, identity: 1),
            PresentationIntent(.paragraph, identity: 2),
            nil
        ])
        XCTAssertEqual(text.runs[\.center].map(\.0), [
            nil,
            true,
            nil
        ])
    }

    func testInsignificantNewlinesInlineOnly() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .inlineOnly)
        let text = AttributedString(html: #"""
            (91) 1800 4250 744

            09:00 to 21:00 (Monday through Friday)<br />
            10:00 to 18:00 (Saturday)
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            (91) 1800 4250 744 09:00 to 21:00 (Monday through Friday)
            10:00 to 18:00 (Saturday)
            """)
        XCTAssertEqual(text.runs[\.inlinePresentationIntent].map(\.0), [
            nil,
            .lineBreak,
            nil
        ])
    }

    func testInsignificantNewlinesPreservingWhitespace() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        let text = AttributedString(html: #"""
            (91) 1800 4250 744

            09:00 to 21:00 (Monday through Friday)<br />
            10:00 to 18:00 (Saturday)
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            (91) 1800 4250 744

            09:00 to 21:00 (Monday through Friday)

            10:00 to 18:00 (Saturday)
            """)
        XCTAssertEqual(text.runs[\.inlinePresentationIntent].map(\.0), [
            nil,
            .lineBreak,
            nil
        ])
    }

    func testParagraphs() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .full)
        let text = AttributedString(html: #"""
            <strong>It’s Not a Charge</strong>
            <p>This is a temporary hold to cover the replacement value of your product. It won’t affect your available balance.</p>
            <strong>How it is Released</strong>
            <p>Once you receive your replacement, just send your original back within 10 business days. Once it arrives at Apple, Apple will process your device then release the hold. Shipping and processing of your device tends to take 2-3 days total.</p>
            <strong>Shipping Delays</strong>
            <p>Once you ship your device, Apple will monitor its progress. You won’t be penalized for any shipping issues or delays.</p>
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            It’s Not a ChargeThis is a temporary hold to cover the replacement value of your product. It won’t affect your available balance.How it is ReleasedOnce you receive your replacement, just send your original back within 10 business days. Once it arrives at Apple, Apple will process your device then release the hold. Shipping and processing of your device tends to take 2-3 days total.Shipping DelaysOnce you ship your device, Apple will monitor its progress. You won’t be penalized for any shipping issues or delays.
            """)
        XCTAssertEqual(text.runs[\.presentationIntent].map(\.0), [
            nil,
            PresentationIntent(.paragraph, identity: 1),
            nil,
            PresentationIntent(.paragraph, identity: 2),
            nil,
            PresentationIntent(.paragraph, identity: 3)
        ])
    }

    func testHeadings() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .full)
        let text = AttributedString(html: #"""
            <h1>Sed Dui Tellus</h1>
            <p>Vestibulum venenatis in tortor sit amet imperdiet. Orci varius natoque penatibus et.</p>
            <h2>Nam Suscipit Tincidunt Nisl</h2>
            <p>Vivamus tempor ex neque, nec commodo mi sollicitudin id. Donec vestibulum vel.</p>
            <h3>In Hac Habitasse Platea</h3>
            <p>Sed viverra semper tellus a fermentum. Maecenas lacinia, metus non maximus egestas.</p>
            <h4>Class Aptent Taciti Sociosqu</h4>
            <p>Sed diam elit, fermentum nec tellus imperdiet, sodales sodales nisi. Etiam nec.</p>
            <h5>Maecenas Sit Amet Porttitor</h5>
            <p>Vivamus pharetra arcu vel dictum rutrum. Nulla at facilisis lectus, id porttitor.</p>
            <h6>Mauris Ac Dui Finibus</h6>
            <p>Donec eget fringilla eros. Sed nec arcu eget nibh euismod rhoncus a.</p>
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            Sed Dui TellusVestibulum venenatis in tortor sit amet imperdiet. Orci varius natoque penatibus et.Nam Suscipit Tincidunt NislVivamus tempor ex neque, nec commodo mi sollicitudin id. Donec vestibulum vel.In Hac Habitasse PlateaSed viverra semper tellus a fermentum. Maecenas lacinia, metus non maximus egestas.Class Aptent Taciti SociosquSed diam elit, fermentum nec tellus imperdiet, sodales sodales nisi. Etiam nec.Maecenas Sit Amet PorttitorVivamus pharetra arcu vel dictum rutrum. Nulla at facilisis lectus, id porttitor.Mauris Ac Dui FinibusDonec eget fringilla eros. Sed nec arcu eget nibh euismod rhoncus a.
            """)
        XCTAssertEqual(text.runs[\.presentationIntent].map(\.0), [
            PresentationIntent(.header(level: 1), identity: 1),
            PresentationIntent(.paragraph, identity: 2),
            PresentationIntent(.header(level: 2), identity: 3),
            PresentationIntent(.paragraph, identity: 4),
            PresentationIntent(.header(level: 3), identity: 5),
            PresentationIntent(.paragraph, identity: 6),
            PresentationIntent(.header(level: 4), identity: 7),
            PresentationIntent(.paragraph, identity: 8),
            PresentationIntent(.header(level: 5), identity: 9),
            PresentationIntent(.paragraph, identity: 10),
            PresentationIntent(.header(level: 6), identity: 11),
            PresentationIntent(.paragraph, identity: 12)
        ])
    }

    func testSearchHighlightingAndWhitespace() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .full, mark: .stronglyEmphasized)
        let text = AttributedString(html: #"""
            <bl>Forgot<lb> <bl>your<lb> <bl>iPhone<lb> <bl>passcode<lb>? Learn how to get <bl>your<lb> <bl>iPhone<lb> into recovery mode so <bl>you<lb> can erase it and set it up again.
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            Forgot your iPhone passcode? Learn how to get your iPhone into recovery mode so you can erase it and set it up again.
            """)
        XCTAssertEqual(text.runs[\.inlinePresentationIntent].map(\.0), [
            .stronglyEmphasized,
            nil,
            .stronglyEmphasized,
            nil,
            .stronglyEmphasized,
            nil,
            .stronglyEmphasized,
            nil,
            .stronglyEmphasized,
            nil,
            .stronglyEmphasized,
            nil,
            .stronglyEmphasized,
            nil
        ])
    }

    func testParagraphBreaks() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .full)
        let text = AttributedString(html: #"""
            If you receive a phishing email that’s designed to look like it’s from Apple, send it to <a href="mailto:reportphishing@apple.com">reportphishing@apple.com</a>. If you forward a message from Mail on your Mac, include the header information by selecting the message and choosing Forward as Attachment from the Message menu.<br><br>
            In the United States, you can report fraudulent tech support calls to the Federal Trade Commission at <a href="https://www.ftccomplaintassistant.gov" target="_blank">www.ftccomplaintassistant.gov</a> or to your local law enforcement agency.
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            If you receive a phishing email that’s designed to look like it’s from Apple, send it to reportphishing@apple.com. If you forward a message from Mail on your Mac, include the header information by selecting the message and choosing Forward as Attachment from the Message menu.

            In the United States, you can report fraudulent tech support calls to the Federal Trade Commission at www.ftccomplaintassistant.gov or to your local law enforcement agency.
            """)
    }

    func testImages() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .full)
        let text = AttributedString(html: #"""
            A <b>B</b> <img src="https://apple.com" alt="C"> <a href="https://apple.com">D</a>
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            A B C D
            """)
        XCTAssertEqual(text.runs[\.imageURL].map(\.0), [
            nil,
            URL(string: "https://apple.com"),
            nil
        ])
    }

    func testImagesWithoutAltText() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .full)
        let text = AttributedString(html: #"""
            A <b>B</b> <img src="https://apple.com"> <a href="https://apple.com">C</a>
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            A B \u{fffc} C
            """)
        XCTAssertEqual(text.runs[\.imageURL].map(\.0), [
            nil,
            URL(string: "https://apple.com"),
            nil
        ])
    }

    func testPlainText() {
        let text = String(html: #"""
            <p>
                This is a test paragraph
            </p>
            <p>This is another test paragraph</p>
            <ul>
                <li>This is a test item</li>
                <li>This is another test item</li>
            </ul>
            """#)
        XCTAssertEqual(text, """
            This is a test paragraph
            This is another test paragraph
            • This is a test item
            • This is another test item
            """)
    }

    func testPlainTextPreservingWhitespace() {
        let text = String(html: #"""
                Neque <b>vestibulum,

            <i>turpis</i>!</b><br />
            """#, preservingWhitespace: true)
        XCTAssertEqual(text, """
            Neque vestibulum,

            turpis!

            """)
    }

    // MARK: - UIKit

    #if canImport(UIKit)
    func testSyntaxUIKit() {
        let text = AttributedString(html: #"""
                Neque <b>vestibulum,

            <i>turpis</i>!</b><br />
            """#, options: .uiKit)

        XCTAssertEqual(String(text.characters), """
            Neque vestibulum, turpis!

            """)
        XCTAssertEqual(text.runs[\.presentationIntent].map(\.0), [
            nil
        ])
        XCTAssertEqual(text.runs[\.inlinePresentationIntent].map(\.0), [
            nil,
            .stronglyEmphasized,
            [ .stronglyEmphasized, .emphasized ],
            .stronglyEmphasized,
            .lineBreak
        ])
        XCTAssertEqual(text.runs[\.paragraphStyle].count, 1)
    }

    func testOrderedListUIKit() {
        let text = AttributedString(html: #"""
            <ol start="5"><li>a
            </li>
            <li>b</li></ol>
            """#, options: .uiKitParagraphs)

        XCTAssertEqual(String(text.characters), """
            5.\ta
            6.\tb
            """)
        let paragraphStyles = text.runs[\.paragraphStyle].map(\.0)
        XCTAssertEqual(paragraphStyles.count, 3)
        XCTAssertNotEqual(paragraphStyles[0]?.defaultTabInterval, 0)
        XCTAssertNil(paragraphStyles[1])
        XCTAssertNotEqual(paragraphStyles[2]?.defaultTabInterval, 0)
    }

    func testUnorderedListUIKit() {
        let text = AttributedString(html: #"""
            <ul><li>a</li><li>b</li></ul>
            """#, options: .uiKitParagraphs)

        XCTAssertEqual(String(text.characters), """
            •\ta
            •\tb
            """)
        let paragraphStyles = text.runs[\.paragraphStyle].map(\.0)
        XCTAssertEqual(paragraphStyles.count, 3)
        XCTAssertNotEqual(paragraphStyles[0]?.defaultTabInterval, 0)
        XCTAssertNil(paragraphStyles[1])
        XCTAssertNotEqual(paragraphStyles[2]?.defaultTabInterval, 0)
    }

    func testNestedListUIKit() {
        let text = AttributedString(html: #"""
            <ol>
                <li>  This is a list item.
                    <ul><li>This is a nested item.</li><li>This is another test item.</li></ul>
                    </li>
                <li>  This is another list item.  </li>
            </ol>
            """#, options: .uiKitParagraphs)

        XCTAssertEqual(String(text.characters), """
        1.\tThis is a list item.
        \t•\tThis is a nested item.
        \t•\tThis is another test item.
        2.\tThis is another list item.
        """)
    }

    func testFullParagraphCenteredUIKit() {
        let text = AttributedString(html: #"""
            <center><p>Hello</p></center>
            """#, options: .uiKitParagraphs)

        XCTAssertEqual(String(text.characters), "Hello")
        XCTAssertEqual(text.paragraphStyle?.alignment, .center)
    }

    func testKeyedArchivalOfBoldString() throws {
        let html = #"<b>All AppleCare NOC analysts are busy taking other chats. An AppleCare NOC analyst will join this chat shortly.</b><br><b>Thank you for your patience.</b><br>"#
        let text = NSAttributedString(html: html, options: .uiKit)
        let data = try NSKeyedArchiver.archivedData(withRootObject: text, requiringSecureCoding: false)
        XCTAssertFalse(data.isEmpty)
    }

    func testEncodingOfItalicString() throws {
        let html = #"All AppleCare <i>NOC</i> analysts are busy taking other chats. An AppleCare <i>NOC</i> analyst will join this chat shortly.<br>Thank you for your patience.<br>"#
        let text = NSAttributedString(html: html, options: .uiKit)
        let data = try NSKeyedArchiver.archivedData(withRootObject: text, requiringSecureCoding: false)
        XCTAssertFalse(data.isEmpty)
    }

    func testParagraphsUIKit() {
        let text = AttributedString(html: #"""
            <strong>It’s Not a Charge</strong>
            <p>This is a temporary hold to cover the replacement value of your product. It won’t affect your available balance.</p>
            <strong>How it is Released</strong>
            <p>Once you receive your replacement, just send your original back within 10 business days. Once it arrives at Apple, Apple will process your device then release the hold. Shipping and processing of your device tends to take 2-3 days total.</p>
            <strong>Shipping Delays</strong>
            <p>Once you ship your device, Apple will monitor its progress. You won’t be penalized for any shipping issues or delays.</p>
            """#, options: .uiKitParagraphs)

        XCTAssertEqual(String(text.characters), """
            It’s Not a Charge
            This is a temporary hold to cover the replacement value of your product. It won’t affect your available balance.

            How it is Released
            Once you receive your replacement, just send your original back within 10 business days. Once it arrives at Apple, Apple will process your device then release the hold. Shipping and processing of your device tends to take 2-3 days total.

            Shipping Delays
            Once you ship your device, Apple will monitor its progress. You won’t be penalized for any shipping issues or delays.
            """)
        XCTAssertEqual(text.runs[\.paragraphStyle].count, 11)
        XCTAssertEqual(text.runs[\.accessibilityHeadingLevel].map(\.0), [
            .unspecified,
            nil,
            .unspecified,
            nil,
            .unspecified,
            nil
        ])
    }

    func testParagraphHeadingsUIKitForMinifiedHTML_79338354() {
        let text = AttributedString(html: #"<strong>It’s Not a Charge</strong><p>This is a temporary hold to cover the replacement value of your product. It won’t affect your available balance.</p><strong>A Credit Card is Recommended</strong><p>It’s recommended that you use a credit card. If you use a debit card, it will appear as a temporary transaction, which could affect other transactions until the hold is released.</p><strong>How it is Released</strong><p>Once you receive your replacement, just send your original back within 10 business days of your request. Once it arrives at Apple, Apple will process your device, then release the hold. Shipping and processing of your device tends to take 2-3 days total.</p><strong>If Your Device is Ineligible for Service</strong><p>If your device is inoperable due to unauthorized modifications or severe damage, the temporary hold will be charged to your card.</p><strong>Shipping Delays</strong><p>Once you ship your device, Apple will monitor its progress. You won’t be penalized for any shipping issues or delays.</p>"#, options: .uiKitParagraphs)

        XCTAssertEqual(String(text.characters), """
            It’s Not a Charge
            This is a temporary hold to cover the replacement value of your product. It won’t affect your available balance.

            A Credit Card is Recommended
            It’s recommended that you use a credit card. If you use a debit card, it will appear as a temporary transaction, which could affect other transactions until the hold is released.

            How it is Released
            Once you receive your replacement, just send your original back within 10 business days of your request. Once it arrives at Apple, Apple will process your device, then release the hold. Shipping and processing of your device tends to take 2-3 days total.

            If Your Device is Ineligible for Service
            If your device is inoperable due to unauthorized modifications or severe damage, the temporary hold will be charged to your card.

            Shipping Delays
            Once you ship your device, Apple will monitor its progress. You won’t be penalized for any shipping issues or delays.
            """)
        XCTAssertEqual(text.runs[\.paragraphStyle].count, 19)
        XCTAssertEqual(text.runs[\.inlinePresentationIntent].map(\.0), [
            .stronglyEmphasized,
            nil,
            .stronglyEmphasized,
            nil,
            .stronglyEmphasized,
            nil,
            .stronglyEmphasized,
            nil,
            .stronglyEmphasized,
            nil
        ])
        XCTAssertEqual(text.runs[\.accessibilityHeadingLevel].map(\.0), [
            .unspecified,
            nil,
            .unspecified,
            nil,
            .unspecified,
            nil,
            .unspecified,
            nil,
            .unspecified,
            nil
        ])
    }

    func testHeadingsUIKit() {
        let text = AttributedString(html: #"""
            <h1>Sed Dui Tellus</h1>
            <p>Vestibulum venenatis in tortor sit amet imperdiet. Orci varius natoque penatibus et.</p>
            <h2>Nam Suscipit Tincidunt Nisl</h2>
            <p>Vivamus tempor ex neque, nec commodo mi sollicitudin id. Donec vestibulum vel.</p>
            <h3>In Hac Habitasse Platea</h3>
            <p>Sed viverra semper tellus a fermentum. Maecenas lacinia, metus non maximus egestas.</p>
            <h4>Class Aptent Taciti Sociosqu</h4>
            <p>Sed diam elit, fermentum nec tellus imperdiet, sodales sodales nisi. Etiam nec.</p>
            <h5>Maecenas Sit Amet Porttitor</h5>
            <p>Vivamus pharetra arcu vel dictum rutrum. Nulla at facilisis lectus, id porttitor.</p>
            <h6>Mauris Ac Dui Finibus</h6>
            <p>Donec eget fringilla eros. Sed nec arcu eget nibh euismod rhoncus a.</p>
            """#, options: .uiKitParagraphs)

        XCTAssertEqual(String(text.characters), """
            Sed Dui Tellus
            Vestibulum venenatis in tortor sit amet imperdiet. Orci varius natoque penatibus et.

            Nam Suscipit Tincidunt Nisl
            Vivamus tempor ex neque, nec commodo mi sollicitudin id. Donec vestibulum vel.

            In Hac Habitasse Platea
            Sed viverra semper tellus a fermentum. Maecenas lacinia, metus non maximus egestas.

            Class Aptent Taciti Sociosqu
            Sed diam elit, fermentum nec tellus imperdiet, sodales sodales nisi. Etiam nec.

            Maecenas Sit Amet Porttitor
            Vivamus pharetra arcu vel dictum rutrum. Nulla at facilisis lectus, id porttitor.

            Mauris Ac Dui Finibus
            Donec eget fringilla eros. Sed nec arcu eget nibh euismod rhoncus a.
            """)
        XCTAssertEqual(text.runs[\.paragraphStyle].count, 23)
        XCTAssertEqual(text.runs[\.inlinePresentationIntent].map(\.0), [
            .stronglyEmphasized, nil,
            .stronglyEmphasized, nil,
            .stronglyEmphasized, nil,
            .stronglyEmphasized, nil,
            .stronglyEmphasized, nil,
            .stronglyEmphasized, nil
        ])
        XCTAssertEqual(text.runs[\.accessibilityHeadingLevel].map(\.0), [
            .h1, nil,
            .h2, nil,
            .h3, nil,
            .h4, nil,
            .h5, nil,
            .h6, nil
        ])
    }

    func testSymbolsReplaceImageURLs() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .inlineOnly, image: .uiKitSymbols)
        let text = AttributedString(html: #"""
            <h3>Recommended forms of transportation</h3>
            <ul>
            <li><img src="bolt.car"> Electric vehicle</li>
            <li><img src="bus.fill"> Bus</li>
            <li><img src="bicycle"> Bike</li>
            </ul>
            """#, options: options)
        XCTAssertEqual(String(text.characters), """
            Recommended forms of transportation
            • \u{fffc} Electric vehicle
            • \u{fffc} Bus
            • \u{fffc} Bike
            """)
        XCTAssertEqual(text.runs[\.imageURL].map(\.0), [
            nil
        ])
        XCTAssertEqual(text.runs[\.attachment].map(\.0?.image), [
            nil,
            UIImage(systemName: "bolt.car"),
            nil,
            UIImage(systemName: "bus.fill"),
            nil,
            UIImage(systemName: "bicycle"),
            nil
        ])
    }

    func testSymbolsIgnoreInvalid() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .inlineOnly, image: .uiKitSymbols)
        let text = AttributedString(html: #"""
            <h3>Discouraged forms of transportation</h3>
            <ul>
            <li><img src="scooter"> Scooter</li>
            <li><img src="blimp.flammable"> Hydrogen-powered airship</li>
            </ul>
            """#, options: options)
        XCTAssertEqual(String(text.characters), """
            Discouraged forms of transportation
            • \u{fffc} Scooter
            • \u{fffc} Hydrogen-powered airship
            """)
        XCTAssertEqual(text.runs[\.attachment].map(\.0?.image), [
            nil,
            UIImage(systemName: "scooter"),
            nil
        ])
        XCTAssertEqual(text.runs[\.imageURL].map(\.0?.absoluteString), [
            nil,
            "blimp.flammable",
            nil
        ])
    }

    func testImagesReplacedWithAltText() {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: .inlineOnly, image: .uiKitSymbols)
        let text = AttributedString(html: #"""
            Tap the text field, then tap the <img src="https://support.apple.com/library/content/dam/edam/applecare/images/en_US/il/macos-big-sur-messages-emoji-icon.png" alt="Emoji button">.
            """#, options: options)
        XCTAssertEqual(String(text.characters), "Tap the text field, then tap the Emoji button.")
        XCTAssertEqual(text.runs[\.imageURL].map(\.0?.absoluteString), [
            nil,
            "https://support.apple.com/library/content/dam/edam/applecare/images/en_US/il/macos-big-sur-messages-emoji-icon.png",
            nil
        ])
    }

    func testSymbolsAlignedAtStartOfParagraph() {
        let options = AttributedString.HTMLParsingOptions.uiKit
            .set(\.image, .uiKitSymbols)
        let text = AttributedString(html: #"""
            <h3>Rare forms of transportation</h3>
            <p><img src="figure.wave"> Hitchhiking</p>
            <p><img src="cablecar"> Cablecar</p>
            """#, options: options)
        XCTAssertEqual(String(text.characters), """
            Rare forms of transportation
            \u{fffc}\tHitchhiking
            \u{fffc}\tCablecar
            """)
        XCTAssertEqual(text.runs[\.attachment].map(\.0?.image), [
            nil,
            UIImage(systemName: "figure.wave"),
            nil,
            UIImage(systemName: "cablecar"),
            nil
        ])
    }

    func testColorsUIKit() {
        let text = AttributedString(html: #"""
            <p style="color:primary">Lorem ipsum dolor sit amet.</p>
            <p style="color: secondary">Quisque condimentum egestas risus ac.</p>
            <p style="color:tertiary ">Morbi eros ex, gravida nec.</p>
            <p style="color:quaternary">Etiam pretium, erat a finibus.</p>
            <p style="color:red">Ut luctus nisi quis scelerisque.</p>
            <p style="color;text-decoration:underline">Donec eleifend accumsan eros, quis.</p>
            """#, options: .uiKit)

        XCTAssertEqual(String(text.characters), """
           Lorem ipsum dolor sit amet.
           Quisque condimentum egestas risus ac.
           Morbi eros ex, gravida nec.
           Etiam pretium, erat a finibus.
           Ut luctus nisi quis scelerisque.
           Donec eleifend accumsan eros, quis.
           """)
        XCTAssertEqual(text.runs[\.foregroundColor].map(\.0), [
            .label,
            nil,
            .secondaryLabel,
            nil,
            .tertiaryLabel,
            nil,
            .quaternaryLabel,
            nil
        ])
    }

    func testMarkUIKit() {
        let options = AttributedString.HTMLParsingOptions.uiKit
            .set(\.mark, .uiKitSecondaryColor)
        let text = AttributedString(html: #"""
            Pellentesque <mark>posuere</mark> risus <mark>vitae</mark> tortor commodo.
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            Pellentesque posuere risus vitae tortor commodo.
            """)
        XCTAssertEqual(text.runs[\.foregroundColor].map(\.0), [
            .secondaryLabel,
            nil,
            .secondaryLabel,
            nil,
            .secondaryLabel
        ])
    }
    #endif

    // MARK: - AppKit

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    func testSyntaxAppKit() {
        let text = AttributedString(html: #"""
                Neque <b>vestibulum,

            <i>turpis</i>!</b><br />
            """#, options: .appKit)

        XCTAssertEqual(String(text.characters), """
            Neque vestibulum, turpis!

            """)
        XCTAssertEqual(text.runs[\.presentationIntent].map(\.0), [
            nil
        ])
        XCTAssertEqual(text.runs[\.inlinePresentationIntent].map(\.0), [
            nil,
            .stronglyEmphasized,
            [ .stronglyEmphasized, .emphasized ],
            .stronglyEmphasized,
            .lineBreak
        ])
        XCTAssertEqual(text.runs[\.paragraphStyle].count, 1)
    }

    func testOrderedListAppKit() {
        let text = AttributedString(html: #"""
            <ol start="5"><li>a
            </li>
            <li>b</li></ol>
            """#, options: .appKitParagraphs)

        XCTAssertEqual(String(text.characters), """
            5.\ta
            6.\tb
            """)
        let paragraphStyles = text.runs[\.paragraphStyle].map(\.0)
        XCTAssertEqual(paragraphStyles.count, 3)
        XCTAssertNotEqual(paragraphStyles[0]?.defaultTabInterval, 0)
        XCTAssertNil(paragraphStyles[1])
        XCTAssertNotEqual(paragraphStyles[2]?.defaultTabInterval, 0)
    }

    func testUnorderedListAppKit() {
        let text = AttributedString(html: #"""
            <ul><li>a</li><li>b</li></ul>
            """#, options: .appKitParagraphs)

        XCTAssertEqual(String(text.characters), """
            •\ta
            •\tb
            """)
        let paragraphStyles = text.runs[\.paragraphStyle].map(\.0)
        XCTAssertEqual(paragraphStyles.count, 3)
        XCTAssertNotEqual(paragraphStyles[0]?.defaultTabInterval, 0)
        XCTAssertNil(paragraphStyles[1])
        XCTAssertNotEqual(paragraphStyles[2]?.defaultTabInterval, 0)
    }

    func testNestedListAppKit() {
        let text = AttributedString(html: #"""
            <ol>
                <li>  This is a list item.
                    <ul><li>This is a nested item.</li><li>This is another test item.</li></ul>
                    </li>
                <li>  This is another list item.  </li>
            </ol>
            """#, options: .appKitParagraphs)

        XCTAssertEqual(String(text.characters), """
        1.\tThis is a list item.
        \t•\tThis is a nested item.
        \t•\tThis is another test item.
        2.\tThis is another list item.
        """)
    }

    func testFullParagraphCenteredAppKit() {
        let text = AttributedString(html: #"""
            <center><p>Hello</p></center>
            """#, options: .appKitParagraphs)

        XCTAssertEqual(String(text.characters), "Hello")
        XCTAssertEqual(text.paragraphStyle?.alignment, .center)
    }

    func testParagraphsAppKit() {
        let text = AttributedString(html: #"""
            <strong>It’s Not a Charge</strong>
            <p>This is a temporary hold to cover the replacement value of your product. It won’t affect your available balance.</p>
            <strong>How it is Released</strong>
            <p>Once you receive your replacement, just send your original back within 10 business days. Once it arrives at Apple, Apple will process your device then release the hold. Shipping and processing of your device tends to take 2-3 days total.</p>
            <strong>Shipping Delays</strong>
            <p>Once you ship your device, Apple will monitor its progress. You won’t be penalized for any shipping issues or delays.</p>
            """#, options: .appKitParagraphs)

        XCTAssertEqual(String(text.characters), """
            It’s Not a Charge
            This is a temporary hold to cover the replacement value of your product. It won’t affect your available balance.

            How it is Released
            Once you receive your replacement, just send your original back within 10 business days. Once it arrives at Apple, Apple will process your device then release the hold. Shipping and processing of your device tends to take 2-3 days total.

            Shipping Delays
            Once you ship your device, Apple will monitor its progress. You won’t be penalized for any shipping issues or delays.
            """)
        XCTAssertEqual(text.runs[\.paragraphStyle].count, 11)
        XCTAssertEqual(text.runs[\.accessibilityHeadingLevel].map(\.0), [
            .unspecified,
            nil,
            .unspecified,
            nil,
            .unspecified,
            nil
        ])
    }

    func testHeadingsAppKit() {
        let text = AttributedString(html: #"""
            <h1>Sed Dui Tellus</h1>
            <p>Vestibulum venenatis in tortor sit amet imperdiet. Orci varius natoque penatibus et.</p>
            <h2>Nam Suscipit Tincidunt Nisl</h2>
            <p>Vivamus tempor ex neque, nec commodo mi sollicitudin id. Donec vestibulum vel.</p>
            <h3>In Hac Habitasse Platea</h3>
            <p>Sed viverra semper tellus a fermentum. Maecenas lacinia, metus non maximus egestas.</p>
            <h4>Class Aptent Taciti Sociosqu</h4>
            <p>Sed diam elit, fermentum nec tellus imperdiet, sodales sodales nisi. Etiam nec.</p>
            <h5>Maecenas Sit Amet Porttitor</h5>
            <p>Vivamus pharetra arcu vel dictum rutrum. Nulla at facilisis lectus, id porttitor.</p>
            <h6>Mauris Ac Dui Finibus</h6>
            <p>Donec eget fringilla eros. Sed nec arcu eget nibh euismod rhoncus a.</p>
            """#, options: .appKitParagraphs)

        XCTAssertEqual(String(text.characters), """
            Sed Dui Tellus
            Vestibulum venenatis in tortor sit amet imperdiet. Orci varius natoque penatibus et.

            Nam Suscipit Tincidunt Nisl
            Vivamus tempor ex neque, nec commodo mi sollicitudin id. Donec vestibulum vel.

            In Hac Habitasse Platea
            Sed viverra semper tellus a fermentum. Maecenas lacinia, metus non maximus egestas.

            Class Aptent Taciti Sociosqu
            Sed diam elit, fermentum nec tellus imperdiet, sodales sodales nisi. Etiam nec.

            Maecenas Sit Amet Porttitor
            Vivamus pharetra arcu vel dictum rutrum. Nulla at facilisis lectus, id porttitor.

            Mauris Ac Dui Finibus
            Donec eget fringilla eros. Sed nec arcu eget nibh euismod rhoncus a.
            """)
        XCTAssertEqual(text.runs[\.paragraphStyle].count, 23)
        XCTAssertEqual(text.runs[\.inlinePresentationIntent].map(\.0), [
            .stronglyEmphasized, nil,
            .stronglyEmphasized, nil,
            .stronglyEmphasized, nil,
            .stronglyEmphasized, nil,
            .stronglyEmphasized, nil,
            .stronglyEmphasized, nil
        ])
        XCTAssertEqual(text.runs[\.accessibilityHeadingLevel].map(\.0), [
            .h1, nil,
            .h2, nil,
            .h3, nil,
            .h4, nil,
            .h5, nil,
            .h6, nil
        ])
    }

    func testColorsAppKit() {
        let text = AttributedString(html: #"""
            <p style="color:primary">Lorem ipsum dolor sit amet.</p>
            <p style="color: secondary">Quisque condimentum egestas risus ac.</p>
            <p style="color:tertiary ">Morbi eros ex, gravida nec.</p>
            <p style="color:quaternary">Etiam pretium, erat a finibus.</p>
            <p style="color:red">Ut luctus nisi quis scelerisque.</p>
            <p style="color;text-decoration:underline">Donec eleifend accumsan eros, quis.</p>
            """#, options: .appKit)

        XCTAssertEqual(String(text.characters), """
           Lorem ipsum dolor sit amet.
           Quisque condimentum egestas risus ac.
           Morbi eros ex, gravida nec.
           Etiam pretium, erat a finibus.
           Ut luctus nisi quis scelerisque.
           Donec eleifend accumsan eros, quis.
           """)
        XCTAssertEqual(text.runs[\.foregroundColor].map(\.0), [
            .labelColor,
            nil,
            .secondaryLabelColor,
            nil,
            .tertiaryLabelColor,
            nil,
            .quaternaryLabelColor,
            nil
        ])
    }

    func testMarkAppKit() {
        let options = AttributedString.HTMLParsingOptions.appKit
            .set(\.mark, .appKitSecondaryColor)
        let text = AttributedString(html: #"""
            Pellentesque <mark>posuere</mark> risus <mark>vitae</mark> tortor commodo.
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            Pellentesque posuere risus vitae tortor commodo.
            """)
        XCTAssertEqual(text.runs[\.foregroundColor].map(\.0), [
            .secondaryLabelColor,
            nil,
            .secondaryLabelColor,
            nil,
            .secondaryLabelColor
        ])
    }
    #endif

    // MARK: - SwiftUI

    func testColorsSwiftUI() {
        let text = AttributedString(html: #"""
            <p style="color:primary">Lorem ipsum dolor sit amet.</p>
            <p style="color: secondary">Quisque condimentum egestas risus ac.</p>
            <p style="color:tertiary ">Morbi eros ex, gravida nec.</p>
            <p style="color:quaternary">Etiam pretium, erat a finibus.</p>
            <p style="color:red">Ut luctus nisi quis scelerisque.</p>
            <p style="color;text-decoration:underline">Donec eleifend accumsan eros, quis.</p>
            """#, options: .swiftUI)

        XCTAssertEqual(String(text.characters), """
           Lorem ipsum dolor sit amet.
           Quisque condimentum egestas risus ac.
           Morbi eros ex, gravida nec.
           Etiam pretium, erat a finibus.
           Ut luctus nisi quis scelerisque.
           Donec eleifend accumsan eros, quis.
           """)
        XCTAssertEqual(text.runs[\.foregroundColor].map(\.0), [
            .primary,
            nil,
            .secondary,
            nil
        ])
    }

    func testMarkSwiftUI() {
        let options = AttributedString.HTMLParsingOptions.swiftUI
            .set(\.mark, .swiftUISecondaryColor)
        let text = AttributedString(html: #"""
            Pellentesque <mark>posuere</mark> risus <mark>vitae</mark> tortor commodo.
            """#, options: options)

        XCTAssertEqual(String(text.characters), """
            Pellentesque posuere risus vitae tortor commodo.
            """)
        XCTAssertEqual(text.runs[\.foregroundColor].map(\.0), [
            .secondary,
            nil,
            .secondary,
            nil,
            .secondary
        ])
    }

    func testNativeParsingPerformance() {
        let data = Data(#"<b>Hello, <BR><BR><I>world</b></i>!<br />"#.utf8)
        let options = XCTMeasureOptions.default
        options.iterationCount = 100
        measure(metrics: [ XCTClockMetric(), XCTMemoryMetric() ], options: options) {
            _ = try? NSMutableAttributedString(data: data, options: [
                .documentType: NSAttributedString.DocumentType.html,
                // `rawValue` needed due to <https://bugs.swift.org/browse/SR-3177>
                .characterEncoding: String.Encoding.utf8.rawValue
            ], documentAttributes: nil)
        }
    }

    func testCustomParsingPerformance() {
        let options = XCTMeasureOptions.default
        options.iterationCount = 100
        measure(metrics: [ XCTClockMetric(), XCTMemoryMetric() ], options: options) {
            _ = AttributedString(html: #"<b>Hello, <BR><BR><I>world</b></i>!<br />"#, options: .swiftUI)
        }
    }

}
