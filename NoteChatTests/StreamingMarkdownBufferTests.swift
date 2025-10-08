import XCTest
@testable import NoteChat

final class StreamingMarkdownBufferTests: XCTestCase {

    func testPlainTextFoldsIntoStable() {
        var buffer = StreamingMarkdownBuffer()
        buffer.append("Hello world\n")
        XCTAssertEqual(buffer.tailRaw, "")
        XCTAssertTrue(buffer.stableMarkdown.contains("Hello"))
    }

    func testOpenCodeFenceStaysInTail() {
        var buffer = StreamingMarkdownBuffer()
        buffer.append("```swift\n")
        XCTAssertFalse(buffer.tailRaw.isEmpty)
        XCTAssertEqual(buffer.stableMarkdown, "")
        buffer.append("let x = 1\n")
        XCTAssertTrue(buffer.stableMarkdown.isEmpty)
        buffer.append("```\n")
        XCTAssertTrue(buffer.tailRaw.isEmpty)
        XCTAssertTrue(buffer.stableMarkdown.contains("let x = 1"))
    }

    func testMathBlockWaitsForClosingFence() {
        var buffer = StreamingMarkdownBuffer()
        buffer.append("$$\n")
        XCTAssertFalse(buffer.tailRaw.isEmpty)
        buffer.append("E = mc^2\n")
        XCTAssertFalse(buffer.tailRaw.isEmpty)
        buffer.append("$$\n")
        XCTAssertTrue(buffer.tailRaw.isEmpty)
        XCTAssertTrue(buffer.stableMarkdown.contains("E = mc^2"))
    }

    func testTableHeaderWaitsForAlignment() {
        var buffer = StreamingMarkdownBuffer()
        buffer.append("| Col |\n")
        XCTAssertEqual(buffer.tailRaw, "| Col |\n")
        buffer.append("| --- |\n")
        XCTAssertTrue(buffer.tailRaw.isEmpty)
        XCTAssertTrue(buffer.stableMarkdown.contains("Col"))
    }

    func testTableHeaderWithoutAlignmentFallsBackToPlainText() {
        var buffer = StreamingMarkdownBuffer()
        buffer.append("| Not Table |\n")
        XCTAssertFalse(buffer.tailRaw.isEmpty)
        buffer.append("Next line\n")
        XCTAssertTrue(buffer.tailRaw.isEmpty)
        XCTAssertTrue(buffer.stableMarkdown.contains("| Not Table |"))
        XCTAssertTrue(buffer.stableMarkdown.contains("Next line"))
    }

    func testFlushTailCommitsPendingContent() {
        var buffer = StreamingMarkdownBuffer()
        buffer.append("Partial")
        XCTAssertFalse(buffer.tailRaw.isEmpty)
        buffer.flushTail()
        XCTAssertTrue(buffer.tailRaw.isEmpty)
        XCTAssertEqual(buffer.stableMarkdown, "Partial")
    }

    func testInlineMathWaitsForClosingDelimiter() {
        var buffer = StreamingMarkdownBuffer()
        buffer.append("This is $E = mc^2")
        XCTAssertFalse(buffer.tailRaw.isEmpty, "Unclosed inline math should stay in tail")
        XCTAssertTrue(buffer.tailState.inlineMathOpen, "Tail state should track open inline math")
        buffer.append("$ in text\n")
        XCTAssertTrue(buffer.tailRaw.isEmpty, "Closed inline math should move to stable")
        XCTAssertTrue(buffer.stableMarkdown.contains("$E = mc^2$"))
    }

    func testInlineMathCompletesImmediately() {
        var buffer = StreamingMarkdownBuffer()
        buffer.append("The formula $E = mc^2$ is famous\n")
        XCTAssertTrue(buffer.tailRaw.isEmpty, "Complete inline math should be stable")
        XCTAssertTrue(buffer.stableMarkdown.contains("$E = mc^2$"))
    }

    func testMultipleInlineMathOnSameLine() {
        var buffer = StreamingMarkdownBuffer()
        buffer.append("We have $a = b$ and $c = d$ here\n")
        XCTAssertTrue(buffer.tailRaw.isEmpty)
        XCTAssertTrue(buffer.stableMarkdown.contains("$a = b$"))
        XCTAssertTrue(buffer.stableMarkdown.contains("$c = d$"))
    }

    func testEscapedDollarNotTreatedAsMath() {
        var buffer = StreamingMarkdownBuffer()
        buffer.append("Price is \\$100\n")
        XCTAssertTrue(buffer.tailRaw.isEmpty, "Escaped $ should not trigger math mode")
        XCTAssertFalse(buffer.tailState.inlineMathOpen)
    }

    func testInlineMathAcrossStreamingChunks() {
        var buffer = StreamingMarkdownBuffer()
        buffer.append("Here is $a + b")
        XCTAssertTrue(buffer.tailState.inlineMathOpen, "First chunk should hold open math")
        buffer.append(" = c")
        XCTAssertTrue(buffer.tailState.inlineMathOpen, "Still waiting for closing $")
        buffer.append("$ complete\n")
        XCTAssertFalse(buffer.tailState.inlineMathOpen)
        XCTAssertTrue(buffer.stableMarkdown.contains("$a + b = c$"))
    }

    func testApostropheFenceNormalizesToBackticks() {
        var buffer = StreamingMarkdownBuffer()
        buffer.append("'''swift\nlet x = 1\n'''")
        XCTAssertTrue(buffer.tailRaw.isEmpty)
        XCTAssertTrue(buffer.stableMarkdown.contains("```swift"))
    }

    func testHeadingWithoutSpaceGetsFixed() {
        var buffer = StreamingMarkdownBuffer()
        buffer.append("###Heading\nNext line\n")
        XCTAssertTrue(buffer.tailRaw.isEmpty)
        XCTAssertTrue(buffer.stableMarkdown.contains("### Heading"))
    }

    func testRunOnListInsertsLineBreak() {
        var buffer = StreamingMarkdownBuffer()
        buffer.append("Overview- Explain the problem\n")
        XCTAssertTrue(buffer.tailRaw.isEmpty)
        XCTAssertTrue(buffer.stableMarkdown.contains("Overview"))
        XCTAssertTrue(buffer.stableMarkdown.contains("- Explain the problem"))
    }

    func testInlineFenceSplitFromText() {
        var buffer = StreamingMarkdownBuffer()
        buffer.append("Title```swift\nlet x = 1\n```\n")
        XCTAssertTrue(buffer.tailRaw.isEmpty)
        XCTAssertTrue(buffer.stableMarkdown.contains("Title"))
        XCTAssertTrue(buffer.stableMarkdown.contains("```swift"))
    }

    func testCurrencyDoesNotTriggerInlineMath() {
        var buffer = StreamingMarkdownBuffer()
        buffer.append("The price is $5 today")
        XCTAssertFalse(buffer.tailState.inlineMathOpen)
        XCTAssertTrue(buffer.tailRaw.isEmpty)
        XCTAssertTrue(buffer.stableMarkdown.contains("$5"))
    }

    func testHeadingKeywordSplit() {
        var buffer = StreamingMarkdownBuffer()
        buffer.append("Inline Code and Code BlocksInline code: `print`\n")
        XCTAssertTrue(buffer.tailRaw.isEmpty)
        XCTAssertTrue(buffer.stableMarkdown.contains("Inline Code and Code Blocks"))
        XCTAssertTrue(buffer.stableMarkdown.contains("Inline code: `print`"))
    }

    func testTableBulletStripped() {
        var buffer = StreamingMarkdownBuffer()
        buffer.append("- | Col |\n| --- |\n")
        XCTAssertTrue(buffer.tailRaw.isEmpty)
        XCTAssertTrue(buffer.stableMarkdown.contains("| Col |"))
    }

    func testCompressedTableSplit() {
        var buffer = StreamingMarkdownBuffer()
        buffer.append("Tables| Feature | Support |\n")
        XCTAssertTrue(buffer.tailRaw.isEmpty)
        XCTAssertTrue(buffer.stableMarkdown.contains("Tables"))
        XCTAssertTrue(buffer.stableMarkdown.contains("| Feature | Support |"))
    }

    func testTaskCheckboxNormalization() {
        var buffer = StreamingMarkdownBuffer()
        buffer.append("-[] item one\n")
        XCTAssertTrue(buffer.tailRaw.isEmpty)
        XCTAssertTrue(buffer.stableMarkdown.contains("- [ ] item one"))
    }

    func testBlockMathInlineSplit() {
        var buffer = StreamingMarkdownBuffer()
        buffer.append("Math $$a^2$$Inline math: $b$\n")
        XCTAssertTrue(buffer.tailRaw.isEmpty)
        XCTAssertTrue(buffer.stableMarkdown.contains("Math"))
        XCTAssertTrue(buffer.stableMarkdown.contains("$$"))
    }
}
