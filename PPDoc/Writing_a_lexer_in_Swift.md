# 用 Swift 编写一个词法分析器

原文地址 [blog.matthewcheok.com](http://blog.matthewcheok.com/writing-a-lexer-in-swift/)



In this series, we'll attempt to write parts of a compiler for a simplified language, **Kaleidoscope**. If you're interested in following along in **C++** or **Objective Caml**, you can find the original tutorial [here](http://llvm.org/docs/tutorial/index.html) on the LLVM website.

在本系列中，我们将尝试为一个简单的语言 Kaleidoscope 编写部分编译器。如果你对 c + + 或 Objective Caml 感兴趣，你可以在 LLVM 网站上找到 [原始教程](http://llvm.org/docs/tutorial/index.html) 。

The goal here is not to write the most efficient implementation but how we can leverage features in Swift to make ourselves easily understood.

本篇文章的目标不是编写最高效的实现代码，而是利用 Swift 的特性使人更容易理解。

A compiler can typically be thought of as a series of modular steps including lexical analysis, parsing, semantic analysis, optimisation and code generation.

编译器通常可以被认为是一系列模块化的步骤，包括词法分析分析、语义分析、优化和代码生成。

In the lexical analysis phase, we simply try to break up the input (source code) into the small units called **lexemes**. These units carry specific meaning which we can categorise into groups of **tokens**.

在词法分析阶段，我们将输入(源代码)分解成称为词位（lexemes） 的小单元。这些单位具有特定的含义，我们可以将其分类为标记组。

Consider the following code snippet:

```python
# Compute the x'th fibonacci number.
def fib(x)  
  if x < 3 then
  else
    fib(x-1)+fib(x-2)

# This expression will compute the 40th number.
fib(40)
```

If you've seen any sort of programming language before, you'll immediately recognise the **keywords** such as `def`, `if`, `then`, and `else`. In addition, you might also notice `fib` and `x` are **identifiers**. Even though, they are not the same string, we see that they are names for things (namely functions and variables.)

如果您以前见过其他类型的编程语言，您将很快识别出 def、 If、 then 和 else 等关键字。此外，您还可能注意到 fib 和 x 是标识符。尽管它们不是相同的字符串，但我们看到它们是一些东西的名称(即函数和变量)

Here's a simpler snippet:

```python
def foo(x, y)  
  x + y * 2 + (4 + 5) / 3

foo(3, 4)
```

Our lexer should be able to scan through code and return a list of tokens that describe it. At this stage, it's not necessary to interpret the code in any way. We just want to identify different parts of the source and label them.

我们的 **词法分析器** 应该能够扫描整个代码并返回一个描述它的标记列表。在这个阶段，没有必要以任何方式解释代码。我们只是想识别源的不同部分，并给它们贴上标签。

Let's jump in and try to determine what tokens we need to describe the language:

先用枚举来描述这种语言:

```swift
enum Token {  
    case Define
    case Identifier(String)
    case Number(Float)
    case ParensOpen
    case ParensClose
    case Comma
    case Other(String)
}
```

Because each group of lexemes or token has a clear purpose, we can represent them via the `enum` in Swift. Not all tokens are equal, however. Certain structures like `Identifier`s and `Number`s, also carry additional information.

因为每一组词位或标记都有明确的目的，我们可以通过 Swift 中的枚举来表示它们。然而并不是所有的标记都是相等的。某些结构，如标识符和数字，也携带额外的信息。

Next, we'll try to write a program to turn the above snippet into the following output:
接下来我们将编写一个程序，将上面的代码片段转换成下面的输出:

```swift
[
.Define,
.Identifier("foo"),
.ParensOpen,
.Identifier("x"),
.Comma,
.Identifier("y"),
.ParensClose,
.Identifier("x"),
.Other("+"),
.Identifier("y"),
.Other("*"),
.Number(2.0),
.Other("+"),
.ParensOpen,
.Number(4.0),
.Other("+"),
.Number(5.0),
.ParensClose,
.Other("/"),
.Number(3.0),
.Identifier("foo"),
.ParensOpen,
.Number(3.0),
.Comma,
.Number(4.0),
.ParensClose,
]
```

One way we can try to do this is via **regular expressions**. Each token can be recognised by characters it is made out of. For instance, the `Define` token is always the characters `def` in that order. `Identifier`s, however, follow a rule such as 1) any sequence of alphanumeric characters 2) not beginning with a digit.

我们可以尝试的一种方法是通过正则表达式（比较耗费性能）。每个标记都可以被它所用的字符识别。例如，`Define` 标记始终是这个顺序中的字符 `def`。但是，标识符遵循的规则是: 1)任何字母数字字符的序列 2)不能以数字开头。

For each token, we'll write a regular expression capable of matching its corresponding lexeme. Next, we need to generate the `enum` that matches the token. We can put this all together rather concisely as an array of tuples.

对于每个标记，我们将编写一个能够匹配其对应词位的正则表达式。接下来，我们需要生成与标记匹配的枚举。我们可以非常简明地将它们放在一个元组数组中。

The first parameter in the tuple represents the regular expression we want to match at the beginning of the context and the second parameter is a closure that will generate the relevant token enumeration.

元组中的第一个参数表示我们希望在上下文开头匹配的正则表达式，第二个参数是一个闭包，它将生成相关的标记枚举。

```swift
typealias TokenGenerator = (String) -> Token?  
let tokenList: [(String, TokenGenerator)] = [  
    ("[ \t\n]", { _ in nil }),
    ("[a-zA-Z][a-zA-Z0-9]*", { $0 == "def" ? .Define : .Identifier($0) }),
    ("[0-9.]+", { (r: String) in .Number((r as NSString).floatValue) }),
    ("\\(", { _ in .ParensOpen }),
    ("\\)", { _ in .ParensClose }),
    (",", { _ in .Comma }),
]
```

The first rule captures whitespace which can be spaces, `\t` tabs or `\n` line breaks.

第一条规则捕获空格、 t 制表符或 n 换行符。

Finally, we are ready to write our lexer. We'll try to match against any of the rules in our `tokenList`, failing which we will just assign the character to `.Other`.

最后，我们准备编写词法分析器。我们将尝试匹配标记列表tokenList 中的任何规则，如果没有匹配，我们将只为其分配字符。其他。

Here's the method of interest:

```swift
func tokenize(input: String) -> [Token] {  
    var tokens = [Token]()
    var content = input

    while (content.characters.count > 0) {
        var matched = false

        for (pattern, generator) in tokenList {
            if let m = content.match(pattern) {
                if let t = generator(m) {
                    tokens.append(t)
                }

                content = content.substringFromIndex(content.startIndex.advancedBy(m.characters.count))
                matched = true
                break
            }
        }

        if !matched {
            let index = content.startIndex.advancedBy(1)
            tokens.append(.Other(content.substringToIndex(index)))
            content = content.substringFromIndex(index)
        }
    }
    return tokens
}
```

That's it for now! If you want to take a look at more code, this is all on [Github](https://github.com/matthewcheok/Kaleidoscope). In the next post, we'll look at parsing and how we can build the [AST](https://en.wikipedia.org/wiki/Abstract_syntax_tree).

目前就这些，如果你想了解更多的代码，这些都在 Github 上。在下一篇文章中，我们将研究解析以及如何构建 AST。

* * *

To keep things simple we used a `String` extension to provide regex functionality via `func match(String) -> String?`. This is simply syntactic sugar over the `NSRegularExpression` API in `Foundation`:

为了简单起见，我用了 `String` 扩展：`func match(String) -> String?`。这只是`Foundation`框架中 `NSRegularExpression` 的语法糖:

```swift
var expressions = [String: NSRegularExpression]()  
public extension String {  
    public func match(regex: String) -> String? {
        let expression: NSRegularExpression
        if let exists = expressions[regex] {
            expression = exists
        } else {
            expression = try! NSRegularExpression(pattern: "^\(regex)", options: [])
            expressions[regex] = expression
        }

        let range = expression.rangeOfFirstMatchInString(self, options: [], range: NSMakeRange(0, self.utf16.count))
        if range.location != NSNotFound {
            return (self as NSString).substringWithRange(range)
        }
        return nil
    }
}
```



接下来干点啥？

http://blog.matthewcheok.com/writing-a-parser-in-swift/