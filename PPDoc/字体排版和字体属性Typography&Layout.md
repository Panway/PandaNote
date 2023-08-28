在字体排版中，有许多术语用于描述各种属性和技术。以下是一些常见的中英文术语列表，涵盖了字体、排版和排版属性等方面：

1. **字体术语（Typography Terms）：**
   - Typeface（字体）: 字体家族的整体设计，包括各种字形、粗细、大小等。
   - Font（字形）: 字体家族中的具体单个样式，例如宋体、黑体等。
   - Glyph（字形、字符图形）: 字体中的每个字符的视觉表示。
   - Character（字符）: 文本中的单个字母、数字、标点或符号。
   - Serif（衬线）: 字形末端的小装饰线，如宋体字中的“横头”。
   - Sans-serif（无衬线）: 没有末端装饰线的字形，如黑体字。
   - Script（手写体）: 类似手写的字体样式。
   - Decorative（装饰性字体）: 具有艺术性或装饰性质的字体。
   - Italic（斜体）: 字体的倾斜样式。
   - Bold（粗体）: 字体的加粗样式。
   - Oblique（倾斜体）: 字体的斜体样式，与斜体有细微区别。

2. **排版术语（Layout Terms）：**
   - Kerning（字距调整）: 调整字符之间的水平距离，以改善字符间的均衡。
   - Leading（行距）: 行基线之间的垂直距离，通常用于定义段落的行高。
   - Tracking（字间距调整）: 调整整个文本块中字符的水平间距。
   - Alignment（对齐）: 文本或元素的水平或垂直对齐方式，如左对齐、居中对齐等。
   - Justification（分散对齐）: 调整文本的字符间距以填满一行，以获得均匀的左右边距。
   - Hyphenation（断字）: 自动在单词中插入连字符，以避免行尾溢出。
   - Widows and Orphans（孤行孤字）: 在排版中，指行尾只有一行或一部分的情况。
   - Ligatures（连字）: 字体中特定字母组合的连写形式，以提高可读性和美观性。

3. **字体属性术语（Font Property Terms）：**
   - Weight（粗细）: 字体的粗细属性，例如粗体、正常、细体等。
   - Style（样式）: 字体的风格，例如正常、斜体等。
   - Size（大小）: 字体的大小，通常以点数（pt）表示。
   - Line Height（行高）: 行基线之间的垂直距离，通常以行距的倍数表示。
   - Baseline（基线）: 字符在行内的基准线，用于对齐字符。
   - Cap Height（大写字母高度）: 大写字母在 x 轴上的高度。
   - X-Height（小写字母高度）: 小写字母 x 在 x 轴上的高度。
   - Descender（下行高度）: 字符部分低于基线的部分，如小写字母 g。

这只是字体排版领域中的一些常见术语。随着技术和设计的不断发展，可能会出现新的术语或变化。如果你在具体的排版工作中遇到了特定的术语，最好参考相关的排版资源和文档，以确保你理解正确。

## Down

```swift
// 绘制引用条形 characterRange 表示字符范围，origin 表示起始点。
private func drawQuoteStripeIfNeeded(in characterRange: NSRange, at origin: CGPoint) {
    guard let context = context else { return }
    push(context: context)
    defer { popContext() }

    textStorage?.enumerateAttributes(for: .quoteStripe,
                                     in: characterRange) { (attr: QuoteStripeAttribute, quoteRange) in

        context.setFillColor(attr.color.cgColor)
//根据字符范围 quoteRange 计算对应的字形范围 glyphRangeOfQuote
        let glyphRangeOfQuote = self.glyphRange(forCharacterRange: quoteRange, actualCharacterRange: nil)
//枚举所有行片段。对于每个行片段，执行闭包。
//闭包的参数包括 lineRect 表示行的矩形区域，container 表示文本容器等信息。
        enumerateLineFragments(forGlyphRange: glyphRangeOfQuote) { lineRect, _, container, _, _ in
            let locations = attr.locations.map {
                CGPoint(x: $0 + container.lineFragmentPadding, y: 0)
                    .translated(by: lineRect.origin)
                    .translated(by: origin)
            }

            let stripeSize = CGSize(width: attr.thickness, height: lineRect.height)
            self.drawQuoteStripes(with: context, locations: locations, size: stripeSize)
        }
    }
}
```

