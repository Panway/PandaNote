//
//  NSAttributedString+Markdown.m
//  Tot
//
//  Created by Craig Hockenberry on 12/14/19.
//  Copyright © 2020 The Iconfactory. All rights reserved.
//
/*
	Copyright (c) 2020 The Iconfactory, Inc. <https://iconfactory.com>

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
 */

// NOTE: Since the parser makes a pass over the source Markdown for each marker, turning off the ALLOW configuration items
// below will improve performance slightly.
#define SHOW_ORIGINAL_TEXT 1    //增加样式也显示原始文本，比如显示`[BAIDU](https://baidu.com)`而不是蓝色的`BAIDU`
#define ALLOW_LINKS 1			// CONFIGURATION - 启用后，Markdown中的内联和自动链接将转换为富文本属性.
#define ALLOW_ALTERNATES 1		// CONFIGURATION - When enabled, alternate Markdown such as * for single emphasis and __ for double will be converted.

#define LOG_CONVERSIONS 1		// CONFIGURATION - When enabled, debug logging will include string conversion details.

#import "NSAttributedString+Markdown.h"

#if TARGET_OS_OSX

#define FONT_CLASS NSFont
#define FONT_DESCRIPTOR_CLASS NSFontDescriptor
#define FONT_DESCRIPTOR_SYMBOLIC_TRAITS NSFontDescriptorSymbolicTraits
#define FONT_DESCRIPTOR_TRAIT_BOLD NSFontDescriptorTraitBold
#define FONT_DESCRIPTOR_TRAIT_ITALIC NSFontDescriptorTraitItalic
#define FONT_DESCRIPTOR_CLASS_SYMBOLIC NSFontDescriptorClassSymbolic
#define FONT_DESCRIPTOR_FAMILY_ATTRIBUTE NSFontFamilyAttribute

#else

#define FONT_CLASS UIFont
#define FONT_DESCRIPTOR_CLASS UIFontDescriptor
#define FONT_DESCRIPTOR_SYMBOLIC_TRAITS UIFontDescriptorSymbolicTraits
#define FONT_DESCRIPTOR_TRAIT_BOLD UIFontDescriptorTraitBold
#define FONT_DESCRIPTOR_TRAIT_ITALIC UIFontDescriptorTraitItalic
#define FONT_DESCRIPTOR_CLASS_SYMBOLIC UIFontDescriptorClassSymbolic
#define FONT_DESCRIPTOR_FAMILY_ATTRIBUTE UIFontDescriptorFamilyAttribute

#endif

#ifdef DEBUG
	#define DebugLog(...) NSLog(__VA_ARGS__)
#else
	#define DebugLog(...) do {} while (0)
#endif

MarkdownStyleKey MarkdownStyleEmphasisSingle = @"MarkdownStyleEmphasisSingle";
MarkdownStyleKey MarkdownStyleEmphasisDouble = @"MarkdownStyleEmphasisDouble";
MarkdownStyleKey MarkdownStyleEmphasisBoth = @"MarkdownStyleEmphasisBoth";

#if ALLOW_CODE_MARKERS
MarkdownStyleKey MarkdownStyleCode = @"MarkdownStyleCode";
#endif

@implementation NSAttributedString (Markdown)

NSString *const visualLineBreak = @"\n\n";

NSString *const linkInlineStart = @"[";
NSString *const linkInlineStartDivider = @"]";
NSString *const linkInlineEndDivider = @"(";
NSString *const linkInlineEnd = @")";

NSString *const linkAutomaticStart = @"<";
NSString *const linkAutomaticEnd = @">";

NSString *const emphasisSingleStart = @"_";
NSString *const emphasisSingleEnd = @"_";
#if ALLOW_ALTERNATES
NSString *const emphasisSingleAlternateStart = @"*";
NSString *const emphasisSingleAlternateEnd = @"*";
#endif

NSString *const emphasisDoubleStart = @"**";
NSString *const emphasisDoubleEnd = @"**";
#if ALLOW_ALTERNATES
NSString *const emphasisDoubleAlternateStart = @"__";
NSString *const emphasisDoubleAlternateEnd = @"__";
#endif

#if ALLOW_CODE_MARKERS
NSString *const codeStart = @"`";
NSString *const codeEnd = @"`";
#endif

NSString *const escape = @"\\";
NSString *const literalAsterisk = @"*";
NSString *const literalUnderscore = @"_";

const unichar escapeCharacter = '\\';/// `\\`
const unichar spaceCharacter = ' ';
const unichar tabCharacter = '\t';
const unichar newlineCharacter = '\n';

typedef enum {
    MarkdownSpanUnknown = -1,
    MarkdownSpanEmphasisSingle = 0,
    MarkdownSpanEmphasisDouble,
    MarkdownSpanLinkInline,
    MarkdownSpanLinkAutomatic,
    MarkdownSpanCode, // not supported
} MarkdownSpanType;
/// 第range.location + offset 个字符是不是等于character，即某个位置的前或后offset个是不是等于character
static BOOL hasCharacterRelative(NSString *string, NSRange range, NSUInteger offset, unichar character)
{
	BOOL hasCharacter = NO;
	
	NSUInteger index = range.location + offset;
	if (index >= 0 && index < string.length) {
		if ([string characterAtIndex:index] == character) {
			hasCharacter = YES;//string左边第`-offset`个字符的话如果是character
		}
	}
	
	return hasCharacter;
}

static void addTrait(FONT_DESCRIPTOR_SYMBOLIC_TRAITS newFontTrait, NSMutableAttributedString *result, NSRange replacementRange)
{
	[result enumerateAttribute:NSFontAttributeName inRange:replacementRange options:(0) usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		FONT_CLASS *font = value;
		
		NSString *familyName = font.familyName;
		CGFloat fontSize = font.pointSize;
		FONT_DESCRIPTOR_CLASS *familyFontDescriptor = [FONT_DESCRIPTOR_CLASS fontDescriptorWithFontAttributes:@{ FONT_DESCRIPTOR_FAMILY_ATTRIBUTE: familyName}];
		
		FONT_DESCRIPTOR_SYMBOLIC_TRAITS currentSymbolicTraits = font.fontDescriptor.symbolicTraits;
		FONT_DESCRIPTOR_SYMBOLIC_TRAITS newSymbolicTraits = currentSymbolicTraits | newFontTrait;
		
		FONT_DESCRIPTOR_CLASS *replacementFontDescriptor = [familyFontDescriptor fontDescriptorWithSymbolicTraits:newSymbolicTraits];
		FONT_CLASS *replacementFont = [FONT_CLASS fontWithDescriptor:replacementFontDescriptor size:fontSize];
		
		[result removeAttribute:NSFontAttributeName range:range];
		if (replacementFont) {
			[result addAttribute:NSFontAttributeName value:replacementFont range:range];
		}
	}];
}

static void replaceAttributes(MarkdownSpanType spanType, NSDictionary<MarkdownStyleKey, NSDictionary<NSAttributedStringKey, id> *> *styleAttributes, NSMutableAttributedString *result, NSRange replacementRange)
{
	[result enumerateAttributesInRange:replacementRange options:(0) usingBlock:^(NSDictionary<NSAttributedStringKey, id> *attributes, NSRange range, BOOL * _Nonnull stop) {
		
		NSDictionary<NSAttributedStringKey, id> *replacementAttributes = nil;
		
		MarkdownStyleKey checkKey = nil;
		MarkdownStyleKey replacementKey = nil;
		
		if (spanType == MarkdownSpanEmphasisSingle) {
			checkKey = MarkdownStyleEmphasisDouble;
			replacementKey = MarkdownStyleEmphasisSingle;
		}
		else  if (spanType == MarkdownSpanEmphasisDouble) {
			checkKey = MarkdownStyleEmphasisSingle;
			replacementKey = MarkdownStyleEmphasisDouble;
		}

		if (checkKey && replacementKey) {
			NSDictionary<NSAttributedStringKey, id> *checkAttributes = styleAttributes[checkKey];
			BOOL hasExistingAttributes = YES;
			for (NSAttributedStringKey key in checkAttributes.allKeys) {
				if (! [checkAttributes[key] isEqual:attributes[key]]) {
					hasExistingAttributes = NO;
				}
			}
			if (hasExistingAttributes) {
				// check attributes are present, replace with attributes for both kinds of emphasis
				replacementAttributes = styleAttributes[MarkdownStyleEmphasisBoth];
			}
			else {
				replacementAttributes = styleAttributes[replacementKey];
			}
			
			if (replacementAttributes) {
				for (NSAttributedStringKey key in replacementAttributes.allKeys) {
					[result removeAttribute:key range:range];
				}
				[result addAttributes:replacementAttributes range:range];
			}
		}
	}];
}

/// 更新AttributedString
/// @param result 完整的原始字符串
/// @param beginMarker `[`
/// @param dividerMarker `](`
/// @param endMarker `)`
/// @param spanType 类型
/// @param MarkdownStyleKey` _ or * __ or **`
/// @param NSAttributedStringKey ？？？
/// @param styleAttributes 样式，eg：代码、加粗、链接等
static void updateAttributedString(NSMutableAttributedString *result, NSString *beginMarker, NSString *dividerMarker, NSString *endMarker, MarkdownSpanType spanType, NSDictionary<MarkdownStyleKey, NSDictionary<NSAttributedStringKey, id> *> *styleAttributes)
{
	NSStringCompareOptions options = 0;

	// 请参阅下面有关这两个变量的注释（废话）
	NSString *scanString = [result.string copy];
	NSUInteger mutationOffset = 0;
	
	// 检查输入中的水平规则(horizontal rules)，忽略出现在其行范围内的标记（markers）
	NSMutableArray *horizontalRuleRangeValues = [NSMutableArray array];
	NSString *rulerString = [beginMarker substringToIndex:1];//[
	if ([rulerString isEqual:literalAsterisk] || [rulerString isEqual:literalUnderscore]) {
		NSRange checkRange = NSMakeRange(0, 1);
		while (checkRange.location + checkRange.length < scanString.length) {
			NSRange lineRange = [scanString lineRangeForRange:checkRange];
			NSString *lineString = [scanString substringWithRange:lineRange];
			
			// NOTE: The Markdown syntax specifies three or more characters, but for our purposes, it's more than one of an asterisk or underline.
			NSString *compressedString = [lineString stringByReplacingOccurrencesOfString:rulerString withString:@""];
			NSString *trimmedString = [compressedString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
			if (trimmedString.length == 0) {
				[horizontalRuleRangeValues addObject:[NSValue valueWithRange:lineRange]];
			}
			
			checkRange = NSMakeRange(lineRange.location + lineRange.length, 1);
		}
	}

#if LOG_CONVERSIONS
	DebugLog(@"%s <<<< ---- '%@ %@ %@' start", "NSAttributedString+Markdown", (beginMarker ? beginMarker : @""), (dividerMarker ? dividerMarker : @""), (endMarker ? endMarker : @""));
#endif
		
	BOOL abortScan = NO;
	NSUInteger scanIndex = 0;
	while ((! abortScan) && (scanIndex < scanString.length)) {
		NSRange beginRange = [scanString rangeOfString:beginMarker options:options range:NSMakeRange(scanIndex, scanString.length - scanIndex)];//先找到`[`字符所在的位置，length=1
		if (beginRange.length > 0) {
			// 找到潜在的开始标记
			
			BOOL skipEscapedMarker = hasCharacterRelative(scanString, beginRange, -1, escapeCharacter);//前一个字符是不是"\"
			BOOL skipLiteralOrListMarker = NO;
			if (beginRange.length == 1) {//有[这个字符
				BOOL hasPrefixStartOfLine = beginRange.location == 0 || hasCharacterRelative(scanString, beginRange, -1, newlineCharacter);//前一个字符是换行
				BOOL hasPrefixSpace = hasCharacterRelative(scanString, beginRange, -1, spaceCharacter);//前一个字符是空格
				BOOL hasSuffixSpace = hasCharacterRelative(scanString, beginRange, +1, spaceCharacter);//后一个字符是空格
				BOOL hasPrefixTab = hasCharacterRelative(scanString, beginRange, -1, tabCharacter);
				BOOL hasSuffixTab = hasCharacterRelative(scanString, beginRange, +1, tabCharacter);
				if ((hasPrefixStartOfLine || hasPrefixSpace || hasPrefixTab) && (hasSuffixSpace || hasSuffixTab)) {
					skipLiteralOrListMarker = YES;//跳过文字或列表标记（前一个字符是换行啥的，就不给它样式）
				}
			}
			BOOL skipLinkedText = NO;
			NSUInteger mutatedIndex = beginRange.location - mutationOffset;//x-0=x
			if (mutatedIndex >= 0 && mutatedIndex < result.length) {
				if ([result attribute:NSLinkAttributeName atIndex:mutatedIndex effectiveRange:nil] != nil) {//返回给定索引处字符的属性
					skipLinkedText = YES;
				}
			}
			BOOL skipHorizontalRule = NO;
			if (horizontalRuleRangeValues.count > 0) {
				for (NSValue *horizontalRuleRangeValue in horizontalRuleRangeValues) {
					NSRange horizontalRuleRange = horizontalRuleRangeValue.rangeValue;
					if (NSLocationInRange(beginRange.location, horizontalRuleRange)) {
						skipHorizontalRule = YES;
					}
				}
			}

			if (skipEscapedMarker || skipLiteralOrListMarker || skipLinkedText || skipHorizontalRule) {
				scanIndex = beginRange.location + beginRange.length;
			}
			else {
				NSUInteger beginIndex = beginRange.location + beginRange.length;//x+1
				
				BOOL foundEndMarker = NO;
				NSRange endRange = emptyRange();
				
				BOOL abortEndScan = NO;
				NSUInteger scanEndIndex = beginIndex;
				if (scanEndIndex >= scanString.length) {
#if LOG_CONVERSIONS
					DebugLog(@"%s <<<< .... end marker at end of string", "NSAttributedString+Markdown");
#endif
					abortScan = YES;
				}
				while ((! abortEndScan) && (scanEndIndex < scanString.length)) {
					BOOL continueScan = NO;
					// 在到第一个视觉换行符（即两个换行符`\n\n`）或文本结尾的剩余范围内寻找结束标记)。
					NSRange remainingRange = NSMakeRange(scanEndIndex, scanString.length - scanEndIndex);//从`]`的下一个字符到最后
					NSRange visualLineRange = [scanString rangeOfString:visualLineBreak options:options range:remainingRange];
					if (visualLineRange.location != NSNotFound) {
						remainingRange = NSMakeRange(scanEndIndex, visualLineRange.location - scanEndIndex);//如果有`\n\n`的话
					}
					endRange = [scanString rangeOfString:endMarker options:options range:remainingRange];//`)`的位置
					if (endRange.length > 0) {
						// 找到潜在的结束标记，即`)`
						BOOL dividerMissing = NO;
						if (dividerMarker) {
							// 如果指定了分隔符`](`，请确保我们刚刚捕获的range包含它
							NSRange dividerRange = [scanString rangeOfString:dividerMarker options:options range:NSMakeRange(scanEndIndex, endRange.location - scanEndIndex)];//`](`的位置
							if (dividerRange.location == NSNotFound) {
								dividerMissing = YES;
							}
						}
						if (! dividerMissing) {
							BOOL hasEscapeMarker = hasCharacterRelative(scanString, endRange, -1, escapeCharacter);//前一个是`\\`
							BOOL hasPrefixSpace = hasCharacterRelative(scanString, endRange, -1, spaceCharacter);
							BOOL hasSuffixSpace = hasCharacterRelative(scanString, endRange, +1, spaceCharacter);
							if (! hasEscapeMarker && ! (hasPrefixSpace && hasSuffixSpace)) {
								foundEndMarker = YES;
								break;
							}
							if (endRange.location + endRange.length < scanString.length) {
								continueScan = YES;
								//scanEndIndex = endRange.location + endRange.length;
								scanEndIndex = endRange.location + 1;
							}
						}
						else {
							// no divider in range, abort scanning for end marker, but continue scanning for begin marker at the end of the remaining range
#if LOG_CONVERSIONS
							DebugLog(@"%s <<<< .... no divider marker in \"...%@...\"", "NSAttributedString+Markdown", [scanString substringWithRange:NSMakeRange(scanEndIndex, endRange.location - scanEndIndex)]);
#endif
						}
					}
					else {
						// no end marker, abort scanning for end marker, but continue scanning for begin marker at the end of the remaining range
#if DEBUG
#if LOG_CONVERSIONS
						NSString *textString = [scanString substringWithRange:NSMakeRange(beginIndex - beginMarker.length, (beginIndex + 10 < scanString.length ? 10 : scanString.length - beginIndex))];
						NSString *logString = [textString stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
						DebugLog(@"%s <<<< .... no end marker to match begin marker at \"%@...\"", "NSAttributedString+Markdown", logString);
#endif
#endif
					}
					
					if (! continueScan) {
						abortEndScan = YES;
						scanIndex = remainingRange.location + remainingRange.length;
					}
				}
				
				if (foundEndMarker) {
					NSUInteger endIndex = endRange.location;

#if DEBUG
#if LOG_CONVERSIONS
					NSString *textString = [scanString substringWithRange:NSMakeRange(beginIndex, endIndex - beginIndex)];//eg:`BAIDU](https://baidu.com`
					NSString *logString = [textString stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
					DebugLog(@"%s <<<<      \"%@\" (%ld)", "NSAttributedString+Markdown", logString, textString.length);
#endif
#endif

					// NOTE: 这段代码本身可能有点过于复杂: we're mutating the attributed
					// result while keeping a copy of the unattributed original in scanString. For performance reasons,
					// an attributed string's backing store is exposed through its string property, which makes
					// scanning the raw string problematic.
					//
					// To compensate for this mutation, there is a mutationOffset that keeps a count of the number of
					// characters removed in the result. This offset is applied to all ranges within the result.

					BOOL replaceMarkers = NO;//是否替换了标记符号`[]()`等
					BOOL replaceStyleAttributes = NO;
					NSString *replacementString = nil;
					NSDictionary<NSAttributedStringKey,id> *replacementAttributes = nil;
					
					NSRange mutatedMatchTextRange = NSMakeRange(beginIndex - mutationOffset, endIndex - beginIndex);
					switch (spanType) {
						default:
							break;
						case MarkdownSpanEmphasisSingle:
							if (beginIndex != endIndex) { // leave ** and __ alone, the intent was probably not emphasis with zero width
								replaceStyleAttributes = YES;
								replaceMarkers = YES;
							}
							break;
						case MarkdownSpanEmphasisDouble:
							if (beginIndex != endIndex) { // leave ** and __ alone, the intent was probably not emphasis with zero width
								replaceStyleAttributes = YES;
								replaceMarkers = YES;
							}
							break;
						case MarkdownSpanLinkInline: {//解析类似`[BAIDU](https://baidu.com)`这样的
							NSString *linkText = nil;
							NSString *inlineLink = nil;
							NSString *matchString = [result.string substringWithRange:mutatedMatchTextRange];//BAIDU](https://baidu.com
							NSRange linkTextMarkerRange = [matchString rangeOfString:linkInlineStartDivider options:0 range:NSMakeRange(0, matchString.length)];//`]`的位置
							if (linkTextMarkerRange.length > 0) {
								NSRange linkTextRange = NSMakeRange(0, linkTextMarkerRange.location);
								linkText = [matchString substringWithRange:linkTextRange];//链接文本，eg：BAIDU
								NSRange inlineLinkMarkerRange = [matchString rangeOfString:linkInlineEndDivider options:NSBackwardsSearch range:NSMakeRange(0, matchString.length)];//`(`
								if (inlineLinkMarkerRange.length > 0) {
									if (inlineLinkMarkerRange.location == linkTextMarkerRange.location + linkTextMarkerRange.length) {
										NSUInteger markerIndex = inlineLinkMarkerRange.location + 1;
										NSRange inlineLinkRange = NSMakeRange(markerIndex, matchString.length - markerIndex);
										inlineLink = [matchString substringWithRange:inlineLinkRange];//https://baidu.com
									}
								}
							}
							if (linkText && inlineLink) {
								NSURL *URL = [NSURL URLWithString:inlineLink];
								if (URL) {
									//replacementString = linkText;//PPCHANGE，不把`BAIDU](https://baidu.com`变成`BAIDU`
									replacementAttributes = @{ NSLinkAttributeName: URL };
									replaceMarkers = YES;
								}
							}
							break;
						}
						case MarkdownSpanLinkAutomatic: {
							NSString *string = [result.string substringWithRange:mutatedMatchTextRange];
							NSURL *URL = [NSURL URLWithString:string];
							if (URL) {
								if (URL.scheme) {
									// use URL as-is (could be tel: or ftp: or something else that's not specified in Markdown syntax)
									replacementAttributes = @{ NSLinkAttributeName: URL };
									replaceMarkers = YES;
								}
								else {
									NSURL *synthesizedURL = nil;
									// check if it's an email address
									NSString *pattern = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}";
									NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", pattern];
									BOOL result = [predicate evaluateWithObject:string];
									if (result) {
										// create mailto: link
										NSString *mailtoString = [NSString stringWithFormat:@"mailto:%@", string];
										synthesizedURL = [NSURL URLWithString:mailtoString];
									}
									else {
										// check if it's a domain name
										NSString *pattern = @"[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}";
										NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", pattern];
										BOOL result = [predicate evaluateWithObject:string];
										if (result) {
											// prepend https: to the string
											NSString *httpString = [NSString stringWithFormat:@"https://%@", string];
											synthesizedURL = [NSURL URLWithString:httpString];
										}
									}
									if (synthesizedURL) {
										replacementAttributes = @{ NSLinkAttributeName: synthesizedURL };
										replaceMarkers = YES;
									}
								}
							}
							break;
						}
						case MarkdownSpanCode:
#if ALLOW_CODE_MARKERS
							// NOTE: This is a simplistic implementation that only adjusts the visual aspects of the inline code. It's a much harder problem
							// when you think about how stuff between the code markers doesn't get modified (e.g. with emphasis or literals.)
							replacementAttributes = @{ NSForegroundColorAttributeName: UIColor.lightGrayColor, NSBackgroundColorAttributeName: [UIColor.lightGrayColor colorWithAlphaComponent:0.1], NSFontAttributeName: [UIFont systemFontOfSize:16.0], @"NSMarkedClauseSegmentAttributeName": @(1) };
							replaceMarkers = YES;
#else
							NSCAssert(NO, @"Not implemented");
#endif
							break;
					}
                     
					if (replaceMarkers) {
#if !SHOW_ORIGINAL_TEXT
						NSRange mutatedBeginRange = NSMakeRange(beginRange.location - mutationOffset, beginRange.length);
						[result replaceCharactersInRange:mutatedBeginRange withString:@""];//eg：去掉链接的`[`
						mutationOffset += beginRange.length;
#endif
						NSRange mutatedTextRange = NSMakeRange(beginIndex - mutationOffset, endIndex - beginIndex);

						if (replaceStyleAttributes) {
							if (spanType == MarkdownSpanEmphasisSingle) {
								if (styleAttributes[MarkdownStyleEmphasisSingle]) {
									replaceAttributes(spanType, styleAttributes, result, mutatedTextRange);
								}
								else {
									addTrait(FONT_DESCRIPTOR_TRAIT_ITALIC, result, mutatedTextRange);
								}
							}
							else if (spanType == MarkdownSpanEmphasisDouble) {
								if (styleAttributes[MarkdownStyleEmphasisDouble]) {
									replaceAttributes(spanType, styleAttributes, result, mutatedTextRange);
								}
								else {
									addTrait(FONT_DESCRIPTOR_TRAIT_BOLD, result, mutatedTextRange);
								}
							}
						}
						
						if (replacementAttributes) {//给富文本增加样式
							[result addAttributes:replacementAttributes range:mutatedTextRange];
						}
						if (replacementString) {
							[result replaceCharactersInRange:mutatedTextRange withString:replacementString];//把BAIDU](https://baidu.com变成BAIDU)
							mutationOffset += mutatedTextRange.length - replacementString.length;
						}
#if !SHOW_ORIGINAL_TEXT
						NSRange mutatedEndRange = NSMakeRange(endRange.location - mutationOffset, endRange.length);
						[result replaceCharactersInRange:mutatedEndRange withString:@""];//去掉`BAIDU)`里的`)`
						mutationOffset += endRange.length;
#endif
					}
					
					scanIndex = endRange.location + endRange.length;
				}
			}
		}
		else {
			// no begin marker
			//DebugLog(@"%s <<<< .... no begin marker", "NSAttributedString+Markdown");
			abortScan = YES;
		}
	}

#if LOG_CONVERSIONS
	DebugLog(@"%s <<<< ---- '%@ %@ %@' end", "NSAttributedString+Markdown", (beginMarker ? beginMarker : @""), (dividerMarker ? dividerMarker : @""), (endMarker ? endMarker : @""));
	DebugLog(@"%s", "NSAttributedString+Markdown");
#endif
}

static void removeEscapesInAttributedString(NSMutableAttributedString *result, NSString *replacement)
{
	NSString *match = [escape stringByAppendingString:replacement];

	NSUInteger scanStart = 0;
	BOOL needsScan = YES;
	while (needsScan) {
		NSString *scanString = result.string;
		NSRange range = [scanString rangeOfString:match options:0 range:NSMakeRange(scanStart, scanString.length - scanStart)];
		if (range.length > 0) {
			// found match, remove the escape with its replacement
			[result replaceCharactersInRange:range withString:replacement];
			
			// NOTE: Since we're mutating the string as we scan it, range.location is the first character after the escape character and
			// where we'll start our next scan. Like the mutationOffset above, this is some tricky stuff, in both senses of the word.
			scanStart = range.location;
		}
		else {
			needsScan = NO;
		}
	}
}

- (instancetype)initWithMarkdownRepresentation:(NSString *)markdownString attributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
{
	return [self initWithMarkdownRepresentation:markdownString baseAttributes:attributes styleAttributes:nil];
}

- (instancetype)initWithMarkdownRepresentation:(NSString *)markdownString baseAttributes:(nonnull NSDictionary<NSAttributedStringKey, id> *)baseAttributes styleAttributes:(nullable NSDictionary<MarkdownStyleKey, NSDictionary<NSAttributedStringKey, id> *> *)styleAttributes;
{
	NSAssert(baseAttributes[NSFontAttributeName] != nil, @"A font attribute is required");
	
	// NOTE: 这些操作的顺序很重要. 比如：如果检测到 link 属性，则不会应用强调emphasis
	
	// 首先创建一个包含带有基本属性的 Markdown 语法的字符串:
    // 该字符串将应用属性，因为Markdown语法由updateAttributedString()处理.
	NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:markdownString attributes:baseAttributes];

#if ALLOW_LINKS
    // 用链接属性替换[]和()标记
	NSString *linkInlineDividerMarker = [linkInlineStartDivider stringByAppendingString:linkInlineEndDivider];//"]("
    updateAttributedString(result, linkInlineStart, linkInlineDividerMarker, linkInlineEnd, MarkdownSpanLinkInline, styleAttributes);

    // replace < and > markers with a link attribute
    updateAttributedString(result, linkAutomaticStart, nil, linkAutomaticEnd, MarkdownSpanLinkAutomatic, styleAttributes);
#endif
	
#if ALLOW_CODE_MARKERS
    updateAttributedString(result, codeStart, nil, codeEnd, MarkdownSpanCode, styleAttributes);
#endif
	
	// replace ** and __ markers with bold font traits or MarkdownStyleEmphasisDouble style attributes
	updateAttributedString(result, emphasisDoubleStart, nil, emphasisDoubleEnd, MarkdownSpanEmphasisDouble, styleAttributes);
#if ALLOW_ALTERNATES
	updateAttributedString(result, emphasisDoubleAlternateStart, nil, emphasisDoubleAlternateEnd, MarkdownSpanEmphasisDouble, styleAttributes);
#endif
	
	// replace _ and _ markers with italic font traits or MarkdownStyleEmphasisSingle style attributes
	updateAttributedString(result, emphasisSingleStart, nil, emphasisSingleEnd, MarkdownSpanEmphasisSingle, styleAttributes);
#if ALLOW_ALTERNATES
	updateAttributedString(result, emphasisSingleAlternateStart, nil, emphasisSingleAlternateEnd, MarkdownSpanEmphasisSingle, styleAttributes);
#endif

	// remove backslashes from any escaped markers
	removeEscapesInAttributedString(result, literalAsterisk);
	removeEscapesInAttributedString(result, literalUnderscore);

	return result;
}

#pragma mark -

NS_INLINE NSRange emptyRange()
{
	return NSMakeRange(NSNotFound, 0);
}

static BOOL adjustRangeForWhitespace(NSRange range, NSString *string, NSRange *prefixRange, NSRange *textRange, NSRange *suffixRange)
{
	BOOL rangeAdjusted = NO;
	
	NSUInteger length = string.length;

	// TODO: This code would be simpler...
	//NSCharacterSet *characterSet = NSCharacterSet.whitespaceAndNewlineCharacterSet;
	//trimmed [string stringByTrimmingCharactersInSet:characterSet];
	//range = [string rangeOfString:trimmed];
	
	// startIndex is first character in range that's not whitespace
	NSUInteger startIndex = range.location;
	while (startIndex < length &&
			([string characterAtIndex:startIndex] == spaceCharacter ||  [string characterAtIndex:startIndex] == tabCharacter || [string characterAtIndex:startIndex] == newlineCharacter)) {
		startIndex += 1;
		rangeAdjusted = YES;
	}
	
	// endIndex is last character in range that's not whitespace
	NSUInteger endIndex = range.location + range.length - 1;
	while (endIndex > 0 &&
		   ([string characterAtIndex:endIndex] == spaceCharacter || [string characterAtIndex:endIndex] == tabCharacter || [string characterAtIndex:endIndex] == newlineCharacter)) {
		endIndex -= 1;
		rangeAdjusted = YES;
	}
	endIndex += 1;
	
	//DebugLog(@"%s startIndex = %ld, endIndex = %ld", , "NSAttributedString+Markdown", startIndex, endIndex);
	
	if (startIndex < endIndex) {
		// prefixRange specifies whitespace before textRange, suffixRange specifies whitespace after
		*prefixRange = NSMakeRange(range.location, startIndex - range.location);
		*textRange = NSMakeRange(startIndex, endIndex - startIndex);
		*suffixRange = NSMakeRange(endIndex, range.location + range.length - endIndex);
	}
	else {
		// if endIndex >= startIndex, there was nothing but whitespace
		*prefixRange = emptyRange();
		*textRange = range;
		*suffixRange = emptyRange();
	}
	
	return rangeAdjusted;
}

static void addEscapesInMarkdownString(NSMutableString *text, NSString *marker)
{
	BOOL needsScan = YES;
	NSUInteger scanIndex = 0;
	while (needsScan) {
		NSRange range = [text rangeOfString:marker options:0 range:NSMakeRange(scanIndex, text.length - scanIndex)];
		if (range.length > 0) {
			// found marker
			BOOL insertEscape = NO;

			if (marker.length == 1) {
				// check if marker is a single character surrounded by spaces
				BOOL hasPrefixSpace = hasCharacterRelative(text, range, -1, spaceCharacter);
				BOOL hasSuffixSpace = hasCharacterRelative(text, range, +1, spaceCharacter);
			
				if (! (hasPrefixSpace && hasSuffixSpace)) {
					insertEscape = YES;
				}
			}
			else {
				insertEscape = YES;
			}
			
			if (insertEscape) {
				[text insertString:escape atIndex:range.location];
				scanIndex = range.location + range.length + escape.length;
			}
			else {
				scanIndex = range.location + range.length;
			}
		}
		else {
			needsScan = NO;
		}
	}
}

static void updateMarkdownString(NSMutableString *result, NSString *string, NSString *prefixString, NSRange prefixRange, NSRange textRange, NSString *suffixString, NSRange suffixRange, BOOL needsEscaping)
{
	if (prefixRange.location != NSNotFound) {
		NSString *prefix = [string substringWithRange:prefixRange];
		[result appendString:prefix];
	}
	
	if (prefixString) {
		[result appendString:prefixString];
	}
	
	NSMutableString *text = [NSMutableString stringWithString:[string substringWithRange:textRange]];
	// escaping literals in an automatic link will break it
	if (needsEscaping) {
		addEscapesInMarkdownString(text, literalAsterisk);
		addEscapesInMarkdownString(text, literalUnderscore);
	}
	[result appendString:[text copy]];

	if (suffixString) {
		[result appendString:suffixString];
	}
	
	if (suffixRange.location != NSNotFound) {
		NSString *suffix = [string substringWithRange:suffixRange];
		[result appendString:suffix];
	}
#if DEBUG
#if LOG_CONVERSIONS
	NSString *logString = [text stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
	DebugLog(@"%s >>>> '%@'(%ld) '%@'(%ld) '%@'(%ld)", "NSAttributedString+Markdown", (prefixString ? prefixString : @""), prefixString.length, logString, text.length, (suffixString ? suffixString : @""), suffixString.length);
#endif
#endif
}

static FONT_DESCRIPTOR_SYMBOLIC_TRAITS symbolicTraitsForAttributes(NSDictionary<NSAttributedStringKey, id> *attributes)
{
	FONT_DESCRIPTOR_SYMBOLIC_TRAITS result = 0;
	
	FONT_CLASS *font = attributes[NSFontAttributeName];
	if (font) {
		FONT_DESCRIPTOR_CLASS *fontDescriptor = font.fontDescriptor;
		if (fontDescriptor) {
			result = fontDescriptor.symbolicTraits;
		}
		else {
#if LOG_CONVERSIONS
			DebugLog(@"%s >>>> no symbolic traits", "NSAttributedString+Markdown");
#endif
		}
	}
	
	return result;
}

// 使用如下所示的属性字符串:
//
//   This {0:normal} is an {1:bold} example {2:bold+italic} of how {3:italic} traits {4:bold} can {5:bold+italic} overlap {6:bold}
//
// 将创建以下markdownRepresentation:
//
//   This **is an _example** of how_ **traits _can_ overlap**
//
// Here is the text that is emitted for each attribute range (numbered 0 to 6 above.)
//
// 0: This
//
// 1:      ** (prefix, inBoldRun = YES)
// 1:        is an
//
// 2:              _ (prefix, inItalicRun = YES)
// 2:               example
// 2:                      ** (suffix, inBoldRun = NO)
//
// 3:                         of how
// 3:                               _ (suffix, inItalicRun = NO)
//
// 4:                                 ** (prefix, inBoldRun = YES)
// 4:                                   traits
//
// 5:                                          _ (prefix, inItalicRun = YES)
// 5:                                           can
// 5:                                              _ (suffix, inItalicRun = NO)
//
// 6:                                                overlap
// 6:                                                       ** (suffix, inBoldRun = NO)

static void emitMarkdown(NSMutableString *result, NSString *normalizedString, NSString *currentString, NSRange currentRange, NSDictionary<NSAttributedStringKey, id> *currentAttributes, NSDictionary<NSAttributedStringKey, id> *nextAttributes, BOOL *inBoldRun, BOOL *inItalicRun)
{
	NSCharacterSet *characterSet = NSCharacterSet.whitespaceCharacterSet;
	if ([currentString stringByTrimmingCharactersInSet: characterSet].length == 0) {
		// 当前字符串只有空格，所以我们可以忽略它
#if DEBUG
#if LOG_CONVERSIONS
		NSString *logString = [currentString stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
		FONT_CLASS *logFont = currentAttributes[NSFontAttributeName];
		DebugLog(@"%s >>>> %s %s %s (%@) [%@] %@", "NSAttributedString+Markdown", ".", ".", ".", logString, logFont.fontName, NSStringFromRange(currentRange));
#endif
#endif
		updateMarkdownString(result, normalizedString, nil, emptyRange(), currentRange, nil, emptyRange(), NO);
	}
	else {
		BOOL currentRangeHasLink = NO;
		NSURL *currentRangeURL = nil;
		if (currentAttributes[NSLinkAttributeName]) {
			NSURL *currentAttributeURL = nil;
			id currentLinkAttribute = currentAttributes[NSLinkAttributeName];
			if ([currentLinkAttribute isKindOfClass:[NSURL class]]) {
				currentAttributeURL = (NSURL *)currentLinkAttribute;
			}
			else if ([currentLinkAttribute isKindOfClass:[NSString class]]) {
				currentAttributeURL = [NSURL URLWithString:(NSString *)currentLinkAttribute];
			}
			if (currentAttributeURL) {
				currentRangeHasLink = YES;
				if ([currentAttributeURL.scheme isEqual:@"mailto"]) {
					// a nil currentRangeURL indicates an automatic link
				}
				else {
					if (! [currentAttributeURL.absoluteString isEqual:currentString]) {
						currentRangeURL = currentAttributeURL;
					}
					else {
						// a nil currentRangeURL indicates an automatic link
					}
				}
			}
		}
		
#if ALLOW_CODE_MARKERS
		BOOL currentRangeHasCode = NO;
		if (currentAttributes[@"NSMarkedClauseSegmentAttributeName"]) {
			currentRangeHasCode = YES;
		}
#endif
		
		// compare current traits to previous states
		NSString *prefixString = @"";
		NSString *suffixString = @"";
		
		FONT_DESCRIPTOR_SYMBOLIC_TRAITS currentSymbolicTraits = symbolicTraitsForAttributes(currentAttributes);
		
		FONT_DESCRIPTOR_SYMBOLIC_TRAITS nextSymbolicTraits;
		if (nextAttributes) {
			nextSymbolicTraits = symbolicTraitsForAttributes(nextAttributes);
		}
		else {
			// we're at the last attribute range: clear the traits so the correct suffixString is emitted
			nextSymbolicTraits = 0;
		}
		
		// check the symbolic traits for the font used in this and the next range
		BOOL currentRangeHasBold = (currentSymbolicTraits & FONT_DESCRIPTOR_TRAIT_BOLD) != 0;
		BOOL currentRangeHasItalic = (currentSymbolicTraits & FONT_DESCRIPTOR_TRAIT_ITALIC) != 0;
		
		BOOL nextRangeHasBold = (nextSymbolicTraits & FONT_DESCRIPTOR_TRAIT_BOLD) != 0;
		BOOL nextRangeHasItalic = (nextSymbolicTraits & FONT_DESCRIPTOR_TRAIT_ITALIC) != 0;
		
#if DEBUG
#if LOG_CONVERSIONS
		BOOL currentRangeHasSymbolic = (currentSymbolicTraits & FONT_DESCRIPTOR_CLASS_SYMBOLIC) != 0;
		NSString *logString = [currentString stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
		FONT_CLASS *logFont = currentAttributes[NSFontAttributeName];
		DebugLog(@"%s >>>> %s %s %s (%@) [%@] %@", "NSAttributedString+Markdown", (currentRangeHasBold ? "B" : " "), (currentRangeHasItalic ? "I" : " "), (currentRangeHasSymbolic ? "S" : " "), logString, logFont.fontName, NSStringFromRange(currentRange));
#endif
#endif
		
		BOOL needsEscaping = NO;
		
		if (currentRangeHasBold) {
			if (! *inBoldRun) {
				// emit start of bold run
				prefixString = [prefixString stringByAppendingString:emphasisDoubleStart];
				*inBoldRun = YES;
				needsEscaping = YES;
			}
		}
		if (currentRangeHasItalic) {
			if (! *inItalicRun) {
				// emit start of italic run
				prefixString = [prefixString stringByAppendingString:emphasisSingleStart];
				*inItalicRun = YES;
				needsEscaping = YES;
			}
		}
		
		if (currentRangeHasLink) {
			if (currentRangeURL) {
				prefixString = [prefixString stringByAppendingString:linkInlineStart];
				suffixString = [[[[suffixString stringByAppendingString:linkInlineStartDivider] stringByAppendingString:linkInlineEndDivider] stringByAppendingString:currentRangeURL.absoluteString] stringByAppendingString:linkInlineEnd];
			}
			else {
				prefixString = [prefixString stringByAppendingString:linkAutomaticStart];
				suffixString = [suffixString stringByAppendingString:linkAutomaticEnd];
			}
		}
		
#if ALLOW_CODE_MARKERS
		if (currentRangeHasCode) {
			prefixString = [prefixString stringByAppendingString:codeStart];
			suffixString = [suffixString stringByAppendingString:codeEnd];
		}
#endif
		
		if (! nextRangeHasItalic) {
			if (*inItalicRun) {
				// emit end of italic run
				suffixString = [suffixString stringByAppendingString:emphasisSingleEnd];
				*inItalicRun = NO;
				needsEscaping = YES;
			}
		}
		if (! nextRangeHasBold) {
			if (*inBoldRun) {
				// emit end of bold run
				suffixString = [suffixString stringByAppendingString:emphasisDoubleEnd];
				*inBoldRun = NO;
				needsEscaping = YES;
			}
		}
		
		NSRange prefixRange;
		NSRange textRange;
		NSRange suffixRange;
		adjustRangeForWhitespace(currentRange, normalizedString, &prefixRange, &textRange, &suffixRange);
		updateMarkdownString(result, normalizedString, prefixString, prefixRange, textRange, suffixString, suffixRange, needsEscaping);
	}
}

- (NSString *)markdownRepresentation
{
	NSMutableString *result = [NSMutableString string];

	// TODO: 我们是否需要确保使用规范映射或兼容性映射对结果进行归一化？
	// https://developer.apple.com/documentation/foundation/nsstring/1412645-precomposedstringwithcanonicalma?language=objc
	// https://unicode.org/reports/tr15/#Norm_Forms
	
	NSMutableAttributedString *cleanAttributedString = [self mutableCopy];
	// 删除可能会破坏我们感兴趣的范围的属性（例如UITextView中的编辑中的段落样式）
	[cleanAttributedString removeAttribute:NSForegroundColorAttributeName range:NSMakeRange(0, cleanAttributedString.length)];
	[cleanAttributedString removeAttribute:NSParagraphStyleAttributeName range:NSMakeRange(0, cleanAttributedString.length)];
	// 用转义序列替换源代码中出现的Markdown (otherwise ¯\_(ツ)_/¯ will lose an arm during conversion)
	[cleanAttributedString.mutableString replaceOccurrencesOfString:@"\\_" withString:@"\\\\_" options:(0) range:NSMakeRange(0, cleanAttributedString.length)];
	[cleanAttributedString.mutableString replaceOccurrencesOfString:@"\\*" withString:@"\\\\*" options:(0) range:NSMakeRange(0, cleanAttributedString.length)];

	NSAttributedString *normalizedAttributedString = [cleanAttributedString copy];
	NSString *normalizedString = normalizedAttributedString.string;
	NSUInteger normalizedLength = normalizedAttributedString.length;

	BOOL inBoldRun = NO;
	BOOL inItalicRun = NO;
	
	NSUInteger index = 0;
	while (index < normalizedLength) {
		NSRange currentRange;
		NSDictionary<NSAttributedStringKey, id> *currentAttributes = [normalizedAttributedString attributesAtIndex:index effectiveRange:&currentRange];
		NSString *currentString = [normalizedString substringWithRange:currentRange];
		
		NSDictionary<NSAttributedStringKey, id> *nextAttributes = nil;
		NSUInteger nextIndex = currentRange.location + currentRange.length;
		if (nextIndex < normalizedLength) {
			nextAttributes = [normalizedAttributedString attributesAtIndex:nextIndex effectiveRange:NULL];
		}
		else {
			// 将nextAttributes保留为nil表示我们处于最后一个范围 (in emitMarkdown)
		}

		// 检查当前范围是否包含一个或多个视觉中断(visual breaks)，如果包含，则将单独发出（emitted）每个片段
		if ([currentString containsString:visualLineBreak]) {

			NSArray<NSString *> *currentStringComponents = [currentString componentsSeparatedByString:visualLineBreak];
			
#if DEBUG
#if LOG_CONVERSIONS
			NSUInteger componentCount = 1;
			for (NSString *currentStringComponent in currentStringComponents) {
				NSString *logString = [currentStringComponent stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
				DebugLog(@"%s >>>> %s %s %s [%ld of %ld] (%@)", "NSAttributedString+Markdown", "-", "-", "-", componentCount, currentStringComponents.count, logString);
				componentCount += 1;
			}
#endif
#endif
			
			// NOTE: The first component doesn't include the visual line break sequence (\n\n) but subsequent components do by adjusting the visualLineBreakOffset.
			NSUInteger visualLineBreakOffset = 0;
			NSRange currentComponentRange = NSMakeRange(currentRange.location, 0);
			for (NSString *currentStringComponent in currentStringComponents) {
				currentComponentRange.length = currentStringComponent.length + visualLineBreakOffset;
				emitMarkdown(result, normalizedString, currentStringComponent, currentComponentRange, currentAttributes, nextAttributes, &inBoldRun, &inItalicRun);
				currentComponentRange.location = currentComponentRange.location + currentStringComponent.length + visualLineBreakOffset;
				
				visualLineBreakOffset = visualLineBreak.length;
			}
		}
		else {
			emitMarkdown(result, normalizedString, currentString, currentRange, currentAttributes, nextAttributes, &inBoldRun, &inItalicRun);
		}
		
		index = currentRange.location + currentRange.length;
	}
	
	return [result copy];
}

// NOTE: The tests use this method to build a simple representation of the attributed string that can be checked against an expected result.

- (NSString *)markdownDebug
{
	NSMutableString *result = [NSMutableString string];
	
	[self enumerateAttributesInRange:NSMakeRange(0, self.length) options:(0) usingBlock:^(NSDictionary<NSAttributedStringKey, id> *attributes, NSRange range, BOOL *stop) {
		
		BOOL rangeHasBold = NO;
		BOOL rangeHasItalic = NO;
		FONT_CLASS *font = (FONT_CLASS *)attributes[NSFontAttributeName];
		if (font) {
			FONT_DESCRIPTOR_CLASS *fontDescriptor = font.fontDescriptor;
			if (fontDescriptor) {
				FONT_DESCRIPTOR_SYMBOLIC_TRAITS symbolicTraits = fontDescriptor.symbolicTraits;
				
				rangeHasBold = (symbolicTraits & FONT_DESCRIPTOR_TRAIT_BOLD) != 0;
				rangeHasItalic = (symbolicTraits & FONT_DESCRIPTOR_TRAIT_ITALIC) != 0;
			}
		}

		BOOL rangeHasLink = NO;
		NSString *linkString = @"";
		id link = attributes[NSLinkAttributeName];
		if (link) {
			rangeHasLink = YES;
			if ([link isKindOfClass:[NSURL class]]) {
				NSURL *URL = (NSURL *)link;
				linkString = [NSString stringWithFormat:@"<%@>", URL.absoluteString];
			}
			else if ([link isKindOfClass:[NSString class]]) {
				NSString *string = (NSString *)link;
				linkString = [NSString stringWithFormat:@"<%@>", string];
			}
		}
		
		NSString *rangeString = [NSString stringWithFormat:@"[%@](%s%s)%@", [self.string substringWithRange:range], (rangeHasBold ? "B" : " "), (rangeHasItalic ? "I" : " "), linkString];
		[result appendString:rangeString];
	}];
	
	[result replaceOccurrencesOfString:@"\n" withString:@"\\n" options:(0) range:NSMakeRange(0, result.length)];
	[result replaceOccurrencesOfString:@"\t" withString:@"\\t" options:(0) range:NSMakeRange(0, result.length)];

	return [result copy];
}

@end
