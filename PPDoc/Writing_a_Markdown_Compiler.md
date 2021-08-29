# 前言

原文地址 [blog.beezwax.net](https://blog.beezwax.net/2017/07/07/writing-a-markdown-compiler/)

> 术语及翻译：
>
> Token：标记
>
> Tokenizing：标记化
>
> Abstract Syntax Tree, or AST：抽象语法树
>
> terminal：终结符
>
> Backus Normal Form，BNF：巴科斯范式，又称为巴科斯-诺尔范式，是一种用于表示上下文无关文法的语言，上下文无关文法描述了一类形式语言。它是由约翰·巴科斯（John Backus）和彼得·诺尔（Peter Naur）首先引入的用来描述计算机语言语法的符号集。

# Part1

Have you ever wanted to make your own programming language? Maybe a template engine? A JSON parser? If you have ever built any of those, you might have noticed it’s not exactly easy to get started. There are a lot of concepts to digest before you get going. That’s why lots of devs just give up. We’d like to help with that.
你想过创建自己的编程语言吗？或者一个模板引擎、一个 JSON 解析器？如果你构建过其中的任何一个，你可能已经注意到它不是那么容易开始。在开始之前，有很多概念需要理解。这就是为什么很多开发者会放弃。现在我们很乐意帮帮你。

At Beezwax, a few years ago we built [a WordPress plugin](https://github.com/beezwax/WP-Publish-to-Apple-News) which allows users to upload their blog posts to [the Apple News platform](https://www.apple.com/news/). In order to do this, we had to translate HTML to some particular format. What we wrote is, at its core, a compiler. Compilers are not only for programming languages, they are in many more places than you might think!
在 Beezwax，几年前我们建立了一个 WordPress 插件，允许用户将他们的博客文章上传到 Apple News 平台。为了做到这一点，我们必须将 HTML 翻译成某种特定的格式。我们写的核心是一个编译器，编译器不仅适用于编程语言，它们的使用场景比你想象的要多得多！

This series of blog posts will show you how to make a compiler from scratch. The techniques displayed here will not only help you write compilers, but will give you the tools to solve a whole type of similar problems which – in the programming world – happen quite frequently.

本系列博客文章将向您展示如何从头开始制作一个编译器。这里展示的技术不仅可以帮助您编写编译器，而且还可以为您提供工具来解决在编程世界中经常发生的类似问题。

What exactly is a compiler, anyways? 编译器到底是什么
------------------------------------

Let’s start from the beginning and define what a compiler is. A compiler is just a black box which translates input in a given language to output in another language. The input and output languages can be anything. If you’ve been in the Javascript world for the past few years you might have seen something called _transpiler_. A transpiler is actually a compiler, it transforms, for example, _Coffeescript_ source code into _Javascript_ source code or _SASS_ into _CSS_.

编译器就是一个黑盒子，它将给定的一种语言输入翻译成另一种语言输出。输入和输出语言可以是任何语言。如果你已经在 Javascript 世界呆了几年，你可能会看到一些叫做 _transpiler_ 的东西。Transpiler 实际上是一个编译器，例如它把 Coffeescript 源代码转换成 Javascript 源代码或者 SASS 转换成 CSS。

> **NOTE** Compilers can’t take any language as input. With these techniques, you cannot write an english-to-machine-code compiler. But for _simple_ languages, we can. Once we get into parsing we’ll learn more about those kind of languages, for now, just know that every programming language you know can be an input language for a compiler.
>
> **注意**：编译器不能将任何语言作为输入。您无法写一个英语到机器代码的编译器。但是对于*简单的*语言，我们可以。一旦我们开始解析，我们将了解更多关于这些类型的语言，现在，你只需知道每一种编程语言都可以作为编译器的输入语言。

What we’ll build 我们将构建什么
----------------

To keep things simple, I decided to make a simple compiler which translates a tiny subset of markdown to HTML. Here’s an example:

为了简单起见，我决定写一个简单的编译器，将 Markdown 的一个小子集翻译成 HTML。下面是一个例子：

```ruby
Markdown.to_html('_Foo_ **bar**') # => "<p><em>Foo<em> <strong>bar<strong></p>"
```

As you can see, we put markdown in, and get back HTML. For the implementation language, I’ve chosen Ruby, a language we love at Beezwax because of its focus on readability and programmer happiness. As I want to focus on concepts rather than a fully-optimized implementation, I think Ruby is the best fit for these tutorials.

如您所见，我们放入 Markdown，返回 HTML。实现语言我选择了 Ruby，因为它的可读性更好。因为我想专注于概念而不是完全优化的实现，所以我认为 Ruby 最适合这些教程。

You’ll learn about tokenization, parsing, and code-generation. Because I’ll talk about compilers, I won’t get into things like interpreters or optimizations. I just want to give the reader a solid base, so they can get a taste of this whole subject, and pursue their own more specific interests if they happen to like it.

您将了解标记化（tokenization）、解析和代码生成。因为我将讨论编译器，所以我不会讨论解释器（interpreters）或优化之类的东西。我只是想给读者一个坚实的基础，这样他们就可以了解整个主题，并在他们碰巧喜欢的情况下追求自己更具体的兴趣。

Some of the things you might want to do afterwards include making your own:

后续你可以搜索学习以下东西

*   Programming language 编程语言
*   Virtual machine 虚拟机
*   Template engine 模板引擎
*   Scripting language 脚本语言
*   DSL 领域特定语言
*   JSON parser JSON 解析器
*   Syntax checker 语法检查器
*   Synax highlighter 语法高亮器
*   Smart code renaming 智能代码重命名
*   Smart autocomplete… 智能自动补全
*   ..and more. The sky is the limit! 更多...

Overview of our compiler 编译器概述
------------------------

Our compiler will mimic the most common compiler structure out there, and we’ll boil it down to the very core of it. Our compiler will consist of three steps. The first step is transforming the input markdown string into a list of tokens.

我们的编译器将模仿最常见的编译器结构，我们会把它浓缩到最核心的部分。我们的编译器将包括三个步骤。第一步是将输入的 Markdown 字符串转换为token（标记）列表。

```
"_Hello,world!_" --> TOKENIZER --> [UNDERSCORE, TEXT="Hello,World!", UNDERSCORE]
```


A token is just a name for the basic building blocks of our language. For example an underscore, an asterisk, a new line, or just some words. This will make things easier for us later on.

token 只是我们语言的基本构建块的名称。例如下划线、星号、新行或只是一些单词。这将使我们以后的事情变得更容易。

```
[UNDERSCORE, TEXT="Hello,World!", UNDERSCORE] --> PARSER --> #<EmphasisText "Hello,World!">
```

Next, we take those tokens and pass them into a parser. That parser will give us a tree data-structure representing our tokens organized in certain way.

接下来，我们获取这些 token 并将它们传递给解析器。
解析器将为我们提供一个树数据结构，表示以某种方式组织的令牌。

```
#<EmphasisText "Hello,World!"> --> CODEGEN --> <em>Hello,World!</em>
```

Overall, the process looks like this:

总的来说，这个过程是这样的：

```ruby
"_Hello,world!_" --> TOKENIZER 
--> [UNDERSCORE, TEXT="Hello,World!", UNDERSCORE] --> PARSER 
--> #<EmphasisText "Hello,World!"> --> CODEGEN 
--> <em>Hello,World!</em>
```

You might think this is all quite complicated, but it’s actually the most standard way of writing compilers. With this structure, we not only divide the problem into smaller chunks so it’s easier to reason about and test, we can easily swap some parts around, for example, change the code generator to emit, for example, RTF documents instead of HTML documents. We could also write a new Tokenizer and Parser for a different language, and as long as the returned Abstract Syntax Tree is in the same format, we can still generate proper HTML.

您可能认为这一切都非常复杂，但它实际上是编写编译器的最标准方式。
使用这种结构，我们不仅将问题分成更小的块以便更容易推理和测试，我们还可以轻松交换一些部分，例如，更改代码生成器以导出RTF 文档而不是 HTML 文档。
我们也可以为不同的语言编写一个新的 Tokenizer 和 Parser，只要返回的抽象语法树是相同的格式，我们仍然可以生成正确的 HTML。

The Tokenizer 标记生成器
-------------

Let’s start implementing! The first step in our compiler process is _tokenizing_ – also called Lexical Analisys. Tokenizing is basically making sense of a bunch of characters by transforming them into Tokens. For example: `Hello_` could be transformed to `[<TEXT=HELLO>, <UNDERSCORE>]`, an array of plain old Ruby objects.

让我们开始实现它吧！第一步是*标记化*—— 也称为词法分析（Lexical Analisys）。
标记化基本上是通过将一堆字符转换为标记来理解它们。例如：`Hello_`可以转换为`[<TEXT=HELLO>, <UNDERSCORE>]`，一个普通的旧 Ruby 对象数组。

Because we want to recognize just a part of markdown, let’s start with some examples of the things we will match:

因为我们只想识别 markdown 的一部分，让我们从一些我们将匹配的例子开始：

```
A paragraph __with__ some *text*
```

As we are only going to match paragraphs, emphasized text and bold text — no links, lists, quotes, etc — it makes sense to have only the following tokens: `UNDERSCORE`; `STAR`; `NEWLINE`; `TEXT` and `EOF`.
So, for example, for the input `_Hello*` our tokenizer should return `[<UNDERSCORE>, <TEXT="Hello">, <STAR>]`.

由于我们只匹配段落、斜体强调文本和粗体文本，没有链接、列表、引号等，所以只有以下标记才有意义：`UNDERSCORE`; `STAR`; `NEWLINE`; `TEXT`和`EOF`。
因此对于输入`_Hello*`，我们的分词器应该返回`[<UNDERSCORE>, <TEXT="Hello">, <STAR>]`。

Let’s start with a test which defines what our Tokenizer should do. We’ll use [Minitest](https://github.com/seattlerb/minitest) for the specs.

The full source code for the compiler lives in [GitHub](https://github.com/beezwax/markdown-compiler); we encourage you to clone and play with it. The snippets displayed here won’t give you the whole picture of this particular compiler, they instead focus on explaining concepts so you can write your own.

让我们从定义 Tokenizer 应该做什么的测试开始。我们将使用[Minitest](https://github.com/seattlerb/minitest)作为规范。

编译器的完整源代码位于[GitHub 中](https://github.com/beezwax/markdown-compiler)；我们鼓励您克隆并使用它。此处显示的片段不会为您提供此特定编译器的全貌，而是专注于解释概念，以便您可以编写自己的编译器。

There are numerous ways to write tokenizers. Each one is different, tailored to specific needs. In this series I’ll use a rather simple, object-oriented approach with emphasis on readability and simplicity.

有很多方法可以编写标记生成器。每一种都是不同的，针对特定需求量身定制。在本系列中，我将使用一种相当简单的面向对象的方法，重点是可读性和简单性。

We’ll start by building a `Tokenizer` object, which will take a markdown input string and return a list of `Token` objects that have `type` and `value` attributes.

我们将从构建一个`Tokenizer`对象开始，该对象将 markdown 字符串作为输入并返回具有`type`和`value`属性的`Token`对象列表。

```ruby
class Token
  attr_reader :type, :value
  def initialize(type:, value:)
    @type = type
    @value = value
    raise InvalidTokenError if value.nil? || type.nil?
  end

  def self.null
    NullToken.new
  end

  def self.end_of_file
    Token.new(type: 'EOF', value: '')
  end

  def length
    value.length
  end

  def null?
    false
  end

  def present?
    true
  end

  def to_s
    "<type: #{type}, value: #{value}>"
  end
end
```

We’ll then use some `Scanner` objects to find tokens. Basically, we’ll register scanners that each match specific tokens. Then we run the text through all the scanners and collect what they return. We’ll stop when something could not be matched or everything has been consumed.

然后我们将使用一些`Scanner`对象来查找标记。我们将注册多个匹配特定标记的 Scanner。
然后我们让所有文本通过所有 Scanner 并收集它们返回的内容。当某些东西无法匹配或所有东西都被消耗掉时，我们将停止。

```ruby
class Tokenizer
  TOKEN_SCANNERS = [
    SimpleScanner, # Recognizes simple one-char tokens like `_` and `*`
    TextScanner    # Recognizes everything but a simple token
  ].freeze

  def tokenize(plain_markdown)
    tokens_array = tokens_as_array(plain_markdown)
    TokenList.new(tokens_array)
  end  

  private

  def tokens_as_array(plain_markdown)
    if plain_markdown.nil? || plain_markdown == ''
      [Token.end_of_file]
    else
      token = scan_one_token(plain_markdown)
      [token] + tokens_as_array(plain_markdown[token.length..-1])
    end
  end

  def scan_one_token(plain_markdown)
    TOKEN_SCANNERS.each do |scanner|
      token = scanner.from_string(plain_markdown)
      return token unless token.null?
    end
    raise "The scanners could not match the given input: #{plain_markdown}"
  end
end
```



The method of interest here is `scan_one_token`. It takes a plain markdown string and returns a single token, matching the first character of the input string. To do so, it iterates though the scanners, and if the token matched is not null — i.e., if it’s valid — it will return that token. Otherwise, it will keep trying scanners. We fail if we consume the whole array and return nothing.

这里有意思的方法是`scan_one_token`。它接受一个 Markdown 纯文本字符串并返回一个与输入字符串的第一个字符匹配的标记。为此，它通过扫描器进行迭代，如果匹配的标记不为空——也就是它有效——它将返回该标记。否则它将继续尝试扫描仪。如果我们处理了整个数组并且什么都不返回，我们就失败了。

The `tokens_as_array` method is a wrapper for our previous method. It’s a recursive function which calls `scan_one_token` until there’s no more string to send, or the `scan_one_token` method raises an error. This method also appends an end-of-file token, which will be used to mark the end of the token list.

`tokens_as_array`方法是我们之前方法的封装。这是一个递归函数，它会调用`scan_one_token`直到没有更多的字符串要发送，或者该`scan_one_token`方法引发错误。此方法还附加了一个文件结束标记，用于标记标记列表的末尾。

The `TokenList` class itself is just a convenient wrapper around a collection, so there’s not much point showing it here. Same for `Token` — it’s just a data object with two attributes, `type` and `value`.

该`TokenList`本身是集合的的封装，在这里展示也没有什么意义。它跟`Token`相同，只是一个具有`type`和`value`属性的数据对象.

What’s now left to show you are the scanners. Here’s the first one, which matches single characters — can’t get simpler than this!

现在要向您展示的是扫描器，它匹配单个字符，没有比这更简单的了！

```ruby
class SimpleScanner
  TOKEN_TYPES = {
    '_'  => 'UNDERSCORE',
    '*'  => 'STAR',
    "\n" => 'NEWLINE'
  }.freeze

  def self.from_string(plain_markdown)
    char = plain_markdown[0]
    Token.new(type: TOKEN_TYPES[char], value: char)
  rescue InvalidTokenError
    Token.null
  end
end
```



As you can see, all the work is performed in the `from_string` method. All scanners must implement this method. The method takes a plain markdown string as input and returns a single token, using some logic to determine whether it should match it or not. When matched, it returns a valid token. Otherwise, it returns a “null token”. Note that a token knows when it’s invalid — in this case when either the `type` or the `value` are empty — that’s the `InvalidTokenError` we are catching.

如您所见，所有工作都在`from_string`方法中执行。所有扫描器都必须实现此方法。该方法将一个普通的 markdown 字符串作为输入并返回一个单一的标记，使用一些逻辑来确定它是否应该匹配它。匹配时，它返回一个有效的标记。否则，它返回一个“空标记”。请注意，标记知道何时无效——在这种情况下，当 `type`或 `value`为空时——这就是`InvalidTokenError`我们要捕获的。

> **NOTE** Null objects are an object-oriented pattern which is used to get rid of unwanted `if` statements and avoid possible nil reference errors. If you’ve never heard of this before, you might want to check out [this other blog post](https://blog.beezwax.net/2016/03/25/avoid-nil-checks-code-confidently-be-happy/)
> 
> **注意**Null 对象是一种面向对象的模式，用于去除不需要的`if`语句并避免可能的 nil 引用错误。如果您以前从未听说过这个，您可能想查看[其他博客文章](https://blog.beezwax.net/2016/03/25/avoid-nil-checks-code-confidently-be-happy/)

Now onto the other scanner, `TextScanner`. This one is a bit more complicated but still quite simple:

现在看看另一台扫描器`TextScanner`：

```ruby
class TextScanner < SimpleScanner
  def self.from_string(plain_markdown)
    text = plain_markdown
           .each_char
           .take_while { |char| SimpleScanner.from_string(char).null? }
           .join('')
    Token.new(type: 'TEXT', value: text)
  rescue InvalidTokenError
    Token.null
  end
end

# tips：take_while用法：
# a = [1, 2, 3, 4, 5, 0]
# a.take_while {|i| i < 3}    #=> [1, 2]
```



We take advantage of Ruby functional-style list processing to fetch as many valid characters from the string as we can. We consider a character _valid_ when it’s not matched by the `SimpleScanner`.

利用 Ruby 函数式list处理，从字符串中获取尽可能多的有效字符。当一个字符没有被`SimpleScanner`匹配到时，我们把它视为有效的。

And that’s the gist of the Tokenizer! If you want to play around with it you should just `git clone git@github.com:beezwax/markdown-compiler.git` and play with it with your favorite editor.
Try running the tests with `rake test test/test_tokenizer.rb` and adding new characters to be recognized, like `(`, `)`, `[`, and `]`.

以上就是标记生成器的要点，你可以下载源代码查看：`git clone git@github.com:beezwax/markdown-compiler.git`
运行方法：`rake test test/test_tokenizer.rb`
你也可以增加新的字符来被识别，比如： `(`, `)`, `[`, and `]`。

You did it!

If you’ve followed along, congrats! You’ve taken the first step towards writing a compiler. For now, you can relax, pat yourself on the back and sip some coffee. Next time, we’ll talk about _Parsing_. We’ll learn about Grammars, Formal Languages and Abstract Syntax Trees. Don’t worry — they are not as scary as they sound.

如果你一直跟着做，恭喜！您已经迈出了编写编译器的第一步。接下来，我们将讨论如何解析。我们将学习语法、形式语言和抽象语法树。别担心——它们并不像听起来那么可怕。

Here are [Part 2, Parsing/Implementation](https://blog.beezwax.net/2017/08/10/writing-a-markdown-compiler-part-2/) and [Part 3, Code Generation](https://blog.beezwax.net/2018/05/25/writing-a-markdown-compiler-part-3/).



# Part2



Hello, and welcome to the second part of the Writing a Markdown Compiler series! In case you’ve need it, here is [Part 1, Intro/Tokenizer](https://blog.beezwax.net/2017/07/07/writing-a-markdown-compiler/) and [Part 3, Code Generation](https://blog.beezwax.net/2018/05/25/writing-a-markdown-compiler-part-3/).
欢迎来到编写Markdown编译器系列的第二部分! 

In this part we’ll talk about the second step in compiling: Parsing – also known as Syntactic Analysis. This part has a bit more theory, so it might take some time to digest. Sip some coffee, relax, take yout time, and as long as you don’t rush it you’ll find it’s not hard at all. 
在这部分，我们将讨论编译的第二步：解析，说高级点叫句法分析。
这一部分有更多的理论，所以可能需要一些时间来消化。喝杯奶茶，放松一下，慢慢来，不要慌。 

If you recall from our first part, we talked about Tokenizing, which is making sense of a bunch of characters by transforming them into tokens. Parsing is organizing those tokens into a tree data structure called **Abstract Syntax Tree**, or AST for short.
如果你还记得我们的第一部分，我们谈到了标记化（Tokenizing），也就是通过把一段字符串转化为Token对象。解析是将这些Token对象组织成一个树的数据结构，称为抽象语法树，简称AST。

For example, say were to design a language where you can assign a variable like this:
例如，假设要设计一种语言，你可以像这样分配一个变量：

```
foo = 1
```

译者注：张三 = 1

We could establish that assignment are made of a word token, an equals token, and a number token. The following are *invalid* assignments:
上面的也叫赋值，赋值是由一个单词标记、一个等号标记和一个数字标记组成。以下是无效的赋值：

```
foo = bar # expects a number on the right hand side of the equation
foo       # no equals, no number
foo =     # nothing here!
= foo     # nothing on the left hand side
```

You can see we only accept a small numbers of token sequences. In fact, the accepted sequences must be carefully ordered in order to be valid. A common solution to this problem – matching sequences – is regular expressions. A not-so-common solution is writing a Parser.
你可以看到我们只接受少量的标记序列。事实上，所接受的序列必须经过仔细的排序，才能有效。匹配序列的一个常见解决方案是用正则表达式匹配，一个更有逼格的解决方案是编写一个解析器。

The parser itself is just a program which returns true if a sequence is valid, and false otherwise. Our parser will also return a Node of an AST, we’ll learn more about that in a bit.
解析器本身只是一个程序，如果一个序列是有效的，就返回真，否则就返回假。我们的解析器也将返回AST的一个节点。

## Theory and Grammar 理论和语法

Now it’s time for a little theory. Don’t worry, I promise it won’t be that bad: A **grammar** is a set of rules which together define all possible valid character sequences. They look like this:
现在到了在下讲理论的时候了。别担心，我保证下面的猴子都能看懂。
语法是很多个规则的集合，它们共同定义了所有可能的有效字符序列。它们看起来像这样

```ruby
RuleName := SomeOtherRule A_TERMINAL
```

Rules can consist only of other rules and/or a terminal. For example, if we wanted to match a tiny language `L = { a, b, c }` we could write:
规则可以只由其他规则和/或一个终端组成。例如，如果我们想匹配一个微小的语言L = { a, b, c }，我们可以写：

```
Start := a
       | b
       | c
```

`L = { a, b, c }` can be read as “The language named L is made of 3 elements: `a`, `b`, and `c`“.
`L = { a, b, c }` 可以理解成 "名字叫L的语言由a、b、c 这3个元素组成"。

In this case, `a`, `b` and `c` are all terminals, they match themselves. We could use any symbol to represent *or*, we used `|` as it’s quite common. There is not an unified grammar representation – every library makes it’s own choices – nevertheless they all come from something called [Backus Naur Form](https://en.wikipedia.org/wiki/Backus–Naur_form).
a、b和c都是终结符，它们与自己匹配。我们可以用任何符号来表示*或*，在这里我们使用了`|`，因为很多编程语言也这样。虽然没有一个统一的语法表示，但是很多都来自一个叫Backus Naur Form的东西。

We’ll also use something called *Kleene star*:
我们还将使用一种叫做克莱尼星号的东西（注：Kleene 星号，或称Kleene 闭包，在数学上是一种适用于字符串或符号及字元的集合的一元运算。当 Kleene 星号被应用在一个集合`V`时，写法是`V*`。它被广泛用于正则表达式）

```c
A := a*
```

It simply means: Match this 0 or more times. It will match the empty string `""`, `a`, `aa`, `aaa` and so on. A very similar helper is *Kleen plus*, which means: Match this 1 or more times.
它的意思很简单。匹配这个字符0次或更多次。它将匹配空字符串`""`、`a`、`aa`、`aaa`，以此类推。一个非常类似的玩意儿是 *Kleen plus*，它的意思是匹配1次或更多次。

```
B := b+
```

Will match `b`, `bb`, `bbb` and so on, but not the empty string.
上面的将匹配b、bb、bbb等，但不匹配空字符串。

The order in which the grammar tries the rules is not formally defined, any possible match is a valid match. For example, consider the following grammar:
语法尝试的规则的顺序没有正式定义，任何可能的匹配都是有效的匹配？先看看下面的语法：

```
Start := "ab" A
       | "aba"
A     := "a"
```

In that grammar, we have two ways of generating ‘aba’, one is by using the first branch of the *or*, and the other is using the second brach.
在该语法中，我们有两种产生'aba'的方式，一种是使用or的第一个分支，另一种是使用第二个分支。

In our implementation we’ll use a top-down approach and just match the first branch. This means we would ignore the second branch, so be careful with your rules.
在我们的实现代码中，将使用自上而下的方法，只匹配第一个分支。这意味着我们会忽略第二个分支，所以要注意你的规则。

Languages generated by a grammar are called *formal languages*, you already know several formal languages, some of them are HTML, XML, CSS, JavaScript, Ruby, Swift, Java, and C.
由语法生成的语言被称为形式语言，比如HTML、XML、CSS、JavaScript、Ruby、Swift、Java和C。

Also, we won’t write just any grammar, we’ll limit our rules in the grammar a bit, that way we’ll only match Context-Free Languages. Why? Because they represent the best compromise between power of expression and ease of implementation. [You can learn more about grammars here](http://www.cs.nuim.ie/~jpower/Courses/Previous/parsing/node21.html).
我们也不会随便写语法，我们会对语法中的规则做一些限制，这样我们就只能匹配上下文无关（跟语境无关的）语言。为什么呢？因为它们代表了表达能力和易于实现之间的最佳妥协。你可以在这里了解更多关于语法的信息。

Which limitations are we talking about exactly? Not many really, we just need to avoid left-recursion:
到底是哪些限制呢？其实不多，我们只是需要避免左递归（左旋？）。

```
Foo := Foo "ab"
     | "ab"
```

A rule which calls itself before calling another rule or a terminal. Why this limitation? Well, one is because it’s harder to implement. Because we’ll use functions to implement rules, the implemenation of a left-recursive rule looks like this:
即一个规则在调用另一个规则或终结符之前调用自己。为什么有这种限制？嗯，一是因为它更难实现。因为我们要用函数来实现规则，所以左递归规则的实现看起来像这样。

```ruby
def my_rule
  if my_rule # infinite loop here 这里无限循环了
    do something
  else
    do something else
  end
end
```

We’ve got an infinite loop! The good news is that all grammars with left-recursion [can be written as a different equivalent grammar without left-recursion](http://www.csd.uwo.ca/~moreno/CS447/Lectures/Syntax.html/node8.html). In the next section we’ll convert a left-recursive grammar into a non-left-recursive one.
我们有了一个无限循环! 好消息是，所有含有左递归的语法都可以写成没有左递归的其他等价语法。在下一节中，我们将把一个左递归的语法转换成一个非左递归的语法。

Just one more thing before we move on, I just want to show you how to to evaluate a grammar *by hand*. Let’s this tiny grammar as an example:
在继续之前我想告诉你如何评估一个语法。以下面这个小小的语法为例：

```
Assign     := Identifier EQUALS Number
Identifier := WORD
Number     := NUMBER
```

In the grammar above, I want to match an Identifier rule, a token of type EQUALS (also known as terminal), and a Number. As you can see, we’ve defined them using some building blocks called Terminals or Tokens. In our code, we’ll tell the *WORD* token to match `[a-z]+` and the *NUMBER* token will match just [0-9].
在上面的语法中，我想匹配一个标识符规则、一个EQUALS（等号）类型的标记（也被称为终结符）和一个数字。正如你所看到的，我们使用一些被称为终结符或标记的构建块来定义它们。在我们的代码中，我们将告诉WORD标记匹配`[a-z]+`，NUMBER标记将只匹配`[0-9]`，达到跟正则表达式一样的效果。

To try out this grammar, all we need to know is the substitution model. We just replace rules with their definition until all we have are terminals. Let’s say I want to match `foo = 1`. We must start from the initial rule and see if we can get to that:
为了尝试这个语法，我们需要知道的是替代模型。我们只需用它们的定义来替换规则，直到我们所拥有的都是终结符。比如我想匹配`foo = 1`。我们必须从最初的规则开始，看看我们是否能达到这个目的。

```
Assign := Identifier EQUALS Number
       := WORD EQUALS NUMBER
       := foo EQUALS NUMBER # foo is a valid workd token, we can replace it
       := foo = NUMBER      # = is a valid equals token
       := foo = 1           # 1 is a valid number token
```

We were able to get to `foo = 1`, so it belongs to our language.
我们能够得到foo = 1，所以它属于我们的语言。

## On Abstract Syntax Trees 关于抽象语法树

Now, just some more theory before I let you go 🙂 The whole point of the grammar is to get an Abstract Syntax Tree representation – or AST for short, of our input. For example, a markdown grammar might parse `hello __world__.` as:
继续继续！语法的全部意义在于得到一个抽象语法树（简称AST）的表示，我们的输入。例如，一个markdown语法可能会把`hello __world__`解析为

```
               [PARAGRAPH]
                   |
                   v
      +-------[SENTENCES]-----------+
      |               |             |
      v               v             v
[TEXT="hello "] [BOLD="world"] [TEXT="."]
```

> **NOTE** If you’ve never seen a tree data structure before, you might [want to check that out](https://en.wikipedia.org/wiki/Tree_(data_structure)).
> **注意** 如果你不了解树这种数据结构，你可以看看这个。

Our parent node is PARAGRAPH. That node has a single child, SENTENCES, which in turn has 3 children nodes, TEXT, BOLD and another TEXT. The starting rule in our parser will be the top-most parent in our tree.
上面这棵树父节点是PARAGRAPH，该节点有一个儿子节点SENTENCES，它又有三个孙子节点TEXT、BOLD和另一个TEXT。我们解析器中的起始规则是树中最顶层的父节点。

The thing about getting a tree out of a grammar is that we can remove ambiguity. Consider the following grammar:
从语法中得到一棵树的好处是，我们可以消除歧义。看看下面的语法

```
Start    := Binop
Binop    := Binop Operator Binop
          | Number
Operator := + | - | * | /
Number   := 0 | 1 | 2 | ... | 9
```

If we were to manually build an AST for `2 + 2 - 4`, we get
如果我们手动构建`2 + 2 - 4`的AST，我们会得到

```
                +------[START]--------+
                |         |           |
                v         v           v
             [BINOP] [OPERATOR=-] [NUMBER=4]
                |
   +------------+----------+
   |            |          |
   v            v          v
[NUMBER=2] [OPERATOR=+] [NUMBER=2]
```

The way to read an AST is reading all the leafs of the tree – nodes without children – from left ro right. If we do that, you can see we matched `(2 + 2) - 4`. The problem, is that an equally valid representation could be:
阅读AST的方法是阅读树的所有叶子节点从左到右（叶子节点是没有子节点的节点）。如果按照这种阅读方法可以看到我们匹配了`(2 + 2)- 4`

> 译者注：有点像[垂序遍历](https://leetcode-cn.com/problems/vertical-order-traversal-of-a-binary-tree/)

```
   +------[START]----------+
   |          |            |
   v          v            v
[NUMBER=2] [OPERATOR=+] [BINOP]
                           |
              +------------+----------+
              |            |          |
              v            v          v
           [NUMBER=2] [OPERATOR=-] [NUMBER=4]
```

This time, we end up with `2 + (2 - 4)`. We have two possible ASTs to choose from! Because we want our programs to be deterministic (given the same input, always return the same output), looks like we have some issues.
这次我们的结果是`2 + (2 - 4)`，有了两个AST可以选择，但是我们希望我们的程序是确定性的（给定相同的输入，总是返回相同的输出），是不是我们有一些问题呢？

Well not really. Luckly for us, we happen to use left-recursive grammars. Those grammars have a nice property which is they never have ambiguity! Let’s transform the old grammar:
其实不然。我们很幸运，碰巧使用了左递归语法。这些语法有一个很好的特性，就是它们永远不会有歧义。让我们转换一下旧的语法：

```
Start          := Binop
Binop          := Subtraction
Subtraction    := Adition "-" Binop
                | Adition
Adition        := Division "+" Binop
                | Division
Division       := Multiplication "/" Binop
                | Multiplication
Multiplication := Number "*" Binop
                | Number
Number         := 0 | 1 | 2 | ... | 9
```

As you can see, we explicitly set the order of the operations to be performed, which in this case is multiplication, division, adition, and subtraction – just like C. The generated AST will now always be the same. Let’s see the way the grammar evaluates `2 + 2` so you get the hang of this trick:
在上面我们明确地设置了要执行的加减乘除操作符的顺序，在这种情况下是乘法、除法、加法和减法，就像C语言一样。让我们看看语法对`2 + 2`的求值方式，这样你就能掌握这个技巧了

```
;; Parsing 2 + 2
Start := Binop
      := Subtraction
      := Adition
      := Division "+" Binop
      := Multiplication "+" Binop
      := Number "+" Binop
      := 2 "+" Binop
      := 2 "+" Subtraction
      := 2 "+" Adition
      := 2 "+" Division
      := 2 "+" Multiplication
      := 2 "+" Number
      := 2 "+" 2
```

This trick of transforming a left-recursive grammar to a non-left-recursive grammar works for all grammars. [For more on this, you might want to check this article](http://www.csd.uwo.ca/~moreno/CS447/Lectures/Syntax.html/node8.html).
这种将左递归语法转换为非左递归语法的技巧对所有的语法都适用。更多信息请参考这篇文章。

## A simple Markdown grammar 一个简单的Markdown语法

Okay, enough theory, let’s start coding already! This is the grammar we’ll implement:
好了，理论够了，让我们开始编码吧！这是我们要实现的语法：

```
Body               := Paragraph*

Paragraph          := SentenceAndNewline
                    | SentenceAndEOF
                    
SentenceAndNewline := Sentence+ NEWLINE NEWLINE
SentencesAndEOF    := Sentence+ NEWLINE EOF
                    | Sentence+ EOF
                    
Sentence           := EmphasizedText
                    | BoldText
                    | Text
                    
EmphasizedText     := UNDERSCORE BoldText UNDERSCORE

BoldText           := UNDERSCORE UNDERSCORE TEXT UNDERSCORE UNDERSCORE
                    | STAR STAR TEXT STAR STAR
                    
Text               := TEXT
```

Our starting rule is `Body`, which just matches 0 or more Paragraphs. Each paragraph is made of either a `SentenceAndNewline` rule or a `SentenceAndEOF` rule. A Sentence is just text, bold text, or emphasized text.
我们的起始规则是Body，它只匹配0个或多个段落。每个段落都是由一个 `SentenceAndNewline` 规则或 `SentenceAndEOF` 规则组成。句子只是文本、粗体字或强调文字。

Note that the `Text` rule seems quite silly. It’s just so it makes the implementation easier, we could easily get rid of it and just replace it with `TEXT`.
请注意，文本规则似乎很傻。这只是为了使实现更容易，我们可以很容易地摆脱它，直接用TEXT来代替它。

## Implementation 实现

The approach we’ll take is creating several small objects, each matching a single rule in our grammar. We’ll call those objects `parsers`, each `parser` might call other parsers in order to match the rule, including itself.
我们将采取的方法是创建几个小对象，每个对象与我们语法中的一条规则相匹配。我们将这些对象称为解析器，每个解析器可能会调用其他解析器以匹配规则，包括它自己。

The source code for this whole compiler is [on GitHub](https://github.com/beezwax/markdown-compiler), feel free to clone it and see the parser files in your favorite editor as you read this, the snippets here are just for concept representation.
整个编译器的源代码在GitHub上，下面的核心片段只是为了阐述概念

Let’s tart with the `TEXT` rule, which matches a single `TEXT` token.
先说TEXT规则，它匹配一个单一的TEXT标记。

```ruby
class TextParser < BaseParser
  def match(tokens)
    return Node.null unless tokens.peek('TEXT')
    Node.new(type: 'TEXT', value: tokens.first.value, consumed: 1)
  end
end
```

All parsers behave very similarly. They take a list of `tokens` and peek the list to see if the sequence is correct. They then return the matched node, or an empty node (a null node). We call the result *node* because we want to build an abstract syntax tree.
所有解析器的行为都很相似。它们接受一个标记列表，并peek该列表，以确定其序列是否正确。然后它们会返回匹配的节点，或者一个空节点（NullNode）。我们称之为结果节点，因为我们想建立一个抽象的语法树。

Let’s see a parser a bit more complicated, `__bold__ **text**`:
让我们看看一个更复杂的解析器， `__bold__ **text**`:

```ruby
class BoldParser < BaseParser
  def match(tokens)
    return Node.null unless tokens.peek_or(%w(UNDERSCORE UNDERSCORE TEXT UNDERSCORE UNDERSCORE), %w(STAR STAR TEXT STAR STAR))
    Node.new(type: 'BOLD', value: tokens.third.value, consumed: 5)
  end
end
```

Once again, we just check the token sequence is valid and return a node. The `peek_or` method lives in a `TokenList` object, it takes any amount of arrays as input and tries the tokens defined in each array one by one. It stops whenever it finds a match, returning true, otherwise it returns false. As you might imagine, the order of the arrays are very important, as it’s first-in-first-matched.
再一次，我们只是检查token序列是否有效并返回一个节点。`peek_or是`TokenList`对象的方法，它接受任何数量的数组作为输入，并逐一尝试每个数组中定义的标记。只要找到一个匹配的，它就停止，返回true，否则就返回false。数组的顺序非常重要，因为它是先来的先匹配的。

The emphasis parser is quite similar to this one, so let’s move onto something more interesting: The sentence parser. Our rule is `Sentence := EmphasizedText | BoldText | Text`. Seems simple enough, `match_first` does the trick fos us:
强调文字解析器和这个解析器很相似，让我们看看更有趣的东西：句子分析器。我们的规则是 `Sentence := EmphasizedText | BoldText | Text`。看上去很简单，`match_first`方法能帮我们解决这个问题：

```ruby
class SentenceParser < BaseParser
  def match(tokens)
    match_first tokens, emphasis_parser, bold_parser, text_parser
  end
end
```

`match_first` is a concern which is included whenever needed. It’s somewhat like an *or*, it will try the given parsers and return the first valid node it finds. As usual, the order of the parsers is very important as they get tested in the given order.
`match_first`是一个concern，在需要的时候会被包含进去。它有点像一个or，它将尝试给定的分析器并返回它发现的第一个有效节点。像往常一样，分析器的顺序是非常重要的，因为它们会按照给定的顺序进行测试。

Now, onto the next rule: `SentenceAndNewline := Sentence+ NEWLINE NEWLINE`.
现在，进入下一条规则： `SentenceAndNewline := Sentence+ NEWLINE NEWLINE`

```ruby
class SentencesAndNewlineParser < BaseParser
  include MatchesStar

  def match(tokens)
    nodes, consumed = match_star tokens, with: sentence_parser
    return Node.null if nodes.empty?
    return Node.null unless tokens.peek_at(consumed, 'NEWLINE', 'NEWLINE')
    consumed += 2 # consume newlines

    ParagraphNode.new(sentences: nodes, consumed: consumed)
  end
end
```

Similar to `match_first`, we now have another concern, `match_star`, which matches something 0 or more times. Because we are matching a `+` (Kleen Plus), we want to match something once or more, so we error if we got nothing from our `match_star` method. Then we just match the two `NEWLINE` and return the node.
与`match_first`类似，我们现在有另一个concern，即`match_star`，它可以匹配0次或更多次。因为我们正在匹配一个`+`（Kleen Plus），我们想匹配一次或更多的东西，所以如果我们的`match_star`方法没有得到任何东西，我们会出错。然后我们只是匹配两个`NEWLINE`并返回节点。

> **NOTE** We could make a new helper, `match_plus` here. To keep things simple, I decided to do it “manually”. If you want to play around with the code, implementing `match_plus` is a good exercise.
> 注意 我们可以在这里做一个新的辅助工具，即 match_plus。为了使事情简单，我决定 "手动 "完成它。如果你想玩玩代码，实现 match_plus 是一个很好的练习。

Our little concerns take away most of the job, as the remaining parsers are quite trivial. For example, this is our `Body` parser:
我们的小concerns带走了大部分的工作，因为剩下的解析器是非常微不足道的。例如，这是我们的Body解析器。

```ruby
class BodyParser < BaseParser
  include MatchesStar

  def match(tokens)
    nodes, consumed = match_star tokens, with: paragraph_parser
    return Node.null if nodes.empty?
    BodyNode.new(paragraphs: nodes, consumed: consumed)
  end
end
```

Now what’s missing is something to start calling up parsers. Let’s wrap the whole parsing functionality into a `Parser` object which abstracts away all the complicated stuff into a simple API:
现在所缺少的是开始调用解析器的东西。让我们把整个解析功能包装成一个解析器对象，把所有复杂的东西抽象成一个简单的API

```ruby
class Parser
  def parse(tokens)
    body = body_parser.match(tokens)
    raise "Syntax error: #{tokens[body.consumed]}" unless tokens.count == body.consumed
    body
  end

  private

  def body_parser
    @body_parser ||= ParserFactory.build(:body_parser)
  end
end
```

That’s it! 就是这样!

We’ve made it a long way so far. We can now transform `__Foo__ and *bar*.\n\nAnother paragraph.` into a tree data structure:
到目前为止，我们已经做了很多。现在可以将 `__Foo__ and *bar*.\n\nAnother paragraph.` 转化为一个树形数据结构：

```ruby
Parser.new.parse("__Foo__ and *bar*.\n\nAnother paragraph.") 
  => #<BodyNode:0x007fc774abe008
     @consumed=14,
     @paragraphs=
      [#<ParagraphNode:0x007fc774eb25d8
        @consumed=12,
        @sentences=
         [#<Node:0x007fc774ea8150 @consumed=5, @type="BOLD", @value="Foo">,
          #<Node:0x007fc774ac5f60 @consumed=1, @type="TEXT", @value=" and ">,
          #<Node:0x007fc774ac6758 @consumed=3, @type="EMPHASIS", @value="bar">,
          #<Node:0x007fc774eb33e8 @consumed=1, @type="TEXT", @value=".">]>,
       #<ParagraphNode:0x007fc774eb0828 @consumed=2, @sentences=[#<Node:0x007fc774eb1610 @consumed=1, @type="TEXT", @value="Another paragraph.">]>]>

```

That is no easy feat! We’ve talked a lot about parsers, grammars, tokens and all that stuff. More than enough to sip in for a day. Remember the source code is [on GitHub](https://github.com/beezwax/markdown-compiler), feel free to clone and play around with it.
这可真不容易啊！我们已经谈了很多关于解析器、语法、标记等东西，源代码在GitHub上。
