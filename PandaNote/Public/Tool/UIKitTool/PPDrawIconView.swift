//
//  PPDrawIconView.swift
//  PandaNote
//
//  Created by pan on 2024/1/31.
//  Copyright © 2024 Panway. All rights reserved.
//

import Foundation
import UIKit
// 写一个swift的UIView子类，要求传入不同的字符串，通过drawRect渲染不同的图片
class PPDrawIconView: UIView {
    var fillColor = UIColor.white
    var iconName: String = "" {
        didSet {
            // 当传入的字符串改变时，触发重新绘制
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        // 获取绘图上下文
        guard let context = UIGraphicsGetCurrentContext() else { return }

        // 清空当前矩形区域
        context.clear(rect)

        // 根据传入的字符串选择要渲染的图片
        if iconName.lowercased() == "selected" {
            drawSelected(in: rect, context: context)
        } else if iconName.lowercased() == "unselected" {
            drawUnselected(in: rect, context: context)
        }

    }
    
    // svg来源： https://www.iconfont.cn/collections/detail?cid=575
    // 画布大小100*100的svg转成Swift代码所需App：PaintCode
    // 画布大小100*100的情况下，如果frame.size设置CGSize(width:20,height:20)，绘制这个100x100的圆会超出这个UIView
    // 要想圆宽高变为20x20，那么下面的缩放比就必须设置成：20/100=0.2
    private func drawSelected(in rect: CGRect, context: CGContext) {
        // 设置填充颜色为白色
        fillColor.setFill()
        // 使用UIRectFill绘制填充矩形
        UIRectFill(rect)
        
        let w = self.frame.size.width
        let h = self.frame.size.height
        if w == 0 || h == 0 {
            return
        }
        if let context = UIGraphicsGetCurrentContext() {
            // 设置缩放比例
            context.scaleBy(x: w/100.0, y: h/100.0)
            
            //// Color Declarations
            let fillColor = UIColor(red: 0.290, green: 0.749, blue: 0.541, alpha: 1.000)
            
            //// Bezier Drawing
            let bezierPath = UIBezierPath()
            bezierPath.move(to: CGPoint(x: 50, y: 0))
            bezierPath.addCurve(to: CGPoint(x: 0, y: 50), controlPoint1: CGPoint(x: 22.39, y: 0), controlPoint2: CGPoint(x: 0, y: 22.39))
            bezierPath.addCurve(to: CGPoint(x: 50, y: 100), controlPoint1: CGPoint(x: 0, y: 77.61), controlPoint2: CGPoint(x: 22.39, y: 100))
            bezierPath.addCurve(to: CGPoint(x: 100, y: 50), controlPoint1: CGPoint(x: 77.61, y: 100), controlPoint2: CGPoint(x: 100, y: 77.61))
            bezierPath.addCurve(to: CGPoint(x: 50, y: 0), controlPoint1: CGPoint(x: 100, y: 22.39), controlPoint2: CGPoint(x: 77.61, y: 0))
            bezierPath.close()
            bezierPath.move(to: CGPoint(x: 82.16, y: 35.56))
            bezierPath.addLine(to: CGPoint(x: 42.58, y: 70.33))
            bezierPath.addCurve(to: CGPoint(x: 40.31, y: 71.19), controlPoint1: CGPoint(x: 41.95, y: 70.88), controlPoint2: CGPoint(x: 41.14, y: 71.19))
            bezierPath.addCurve(to: CGPoint(x: 40.04, y: 71.18), controlPoint1: CGPoint(x: 40.22, y: 71.19), controlPoint2: CGPoint(x: 40.13, y: 71.18))
            bezierPath.addCurve(to: CGPoint(x: 37.66, y: 69.95), controlPoint1: CGPoint(x: 39.12, y: 71.11), controlPoint2: CGPoint(x: 38.26, y: 70.66))
            bezierPath.addLine(to: CGPoint(x: 18.42, y: 46.99))
            bezierPath.addCurve(to: CGPoint(x: 18.85, y: 42.14), controlPoint1: CGPoint(x: 17.2, y: 45.53), controlPoint2: CGPoint(x: 17.39, y: 43.36))
            bezierPath.addCurve(to: CGPoint(x: 23.71, y: 42.56), controlPoint1: CGPoint(x: 20.31, y: 40.91), controlPoint2: CGPoint(x: 22.48, y: 41.11))
            bezierPath.addLine(to: CGPoint(x: 40.68, y: 62.82))
            bezierPath.addLine(to: CGPoint(x: 77.61, y: 30.38))
            bezierPath.addCurve(to: CGPoint(x: 82.47, y: 30.7), controlPoint1: CGPoint(x: 79.04, y: 29.13), controlPoint2: CGPoint(x: 81.22, y: 29.27))
            bezierPath.addCurve(to: CGPoint(x: 82.16, y: 35.56), controlPoint1: CGPoint(x: 83.73, y: 32.13), controlPoint2: CGPoint(x: 83.59, y: 34.31))
            bezierPath.close()
            fillColor.setFill()
            bezierPath.fill()
        }
        
    }

    private func drawUnselected(in rect: CGRect, context: CGContext) {
        // 设置填充颜色为白色
        fillColor.setFill()
        // 使用UIRectFill绘制填充矩形
        UIRectFill(rect)
        let w = self.frame.size.width
        let h = self.frame.size.height
        if w == 0 || h == 0 {
            return
        }
        if let context = UIGraphicsGetCurrentContext() {
            // 设置缩放比例
            context.scaleBy(x: w/100.0, y: h/100.0)
            //// Color Declarations
            let fillColor = UIColor(red: 0.784, green: 0.780, blue: 0.800, alpha: 1.000)

            //// Bezier Drawing
            let bezierPath = UIBezierPath()
            bezierPath.move(to: CGPoint(x: 50, y: 0))
            bezierPath.addCurve(to: CGPoint(x: 0, y: 50), controlPoint1: CGPoint(x: 22.39, y: 0), controlPoint2: CGPoint(x: 0, y: 22.39))
            bezierPath.addCurve(to: CGPoint(x: 50, y: 100), controlPoint1: CGPoint(x: 0, y: 77.61), controlPoint2: CGPoint(x: 22.39, y: 100))
            bezierPath.addCurve(to: CGPoint(x: 100, y: 50), controlPoint1: CGPoint(x: 77.61, y: 100), controlPoint2: CGPoint(x: 100, y: 77.61))
            bezierPath.addCurve(to: CGPoint(x: 50, y: 0), controlPoint1: CGPoint(x: 100, y: 22.39), controlPoint2: CGPoint(x: 77.61, y: 0))
            bezierPath.close()
            bezierPath.move(to: CGPoint(x: 50, y: 94.83))
            bezierPath.addCurve(to: CGPoint(x: 5.17, y: 50), controlPoint1: CGPoint(x: 25.28, y: 94.83), controlPoint2: CGPoint(x: 5.17, y: 74.72))
            bezierPath.addCurve(to: CGPoint(x: 50, y: 5.17), controlPoint1: CGPoint(x: 5.17, y: 25.28), controlPoint2: CGPoint(x: 25.28, y: 5.17))
            bezierPath.addCurve(to: CGPoint(x: 94.83, y: 50), controlPoint1: CGPoint(x: 74.72, y: 5.17), controlPoint2: CGPoint(x: 94.83, y: 25.28))
            bezierPath.addCurve(to: CGPoint(x: 50, y: 94.83), controlPoint1: CGPoint(x: 94.83, y: 74.72), controlPoint2: CGPoint(x: 74.72, y: 94.83))
            bezierPath.close()
            bezierPath.move(to: CGPoint(x: 82.47, y: 30.7))
            bezierPath.addCurve(to: CGPoint(x: 77.61, y: 30.38), controlPoint1: CGPoint(x: 81.22, y: 29.27), controlPoint2: CGPoint(x: 79.04, y: 29.12))
            bezierPath.addLine(to: CGPoint(x: 40.68, y: 62.82))
            bezierPath.addLine(to: CGPoint(x: 23.71, y: 42.56))
            bezierPath.addCurve(to: CGPoint(x: 18.85, y: 42.14), controlPoint1: CGPoint(x: 22.48, y: 41.1), controlPoint2: CGPoint(x: 20.31, y: 40.91))
            bezierPath.addCurve(to: CGPoint(x: 18.42, y: 46.99), controlPoint1: CGPoint(x: 17.39, y: 43.36), controlPoint2: CGPoint(x: 17.2, y: 45.53))
            bezierPath.addLine(to: CGPoint(x: 37.66, y: 69.95))
            bezierPath.addCurve(to: CGPoint(x: 40.04, y: 71.17), controlPoint1: CGPoint(x: 38.26, y: 70.66), controlPoint2: CGPoint(x: 39.12, y: 71.1))
            bezierPath.addCurve(to: CGPoint(x: 40.31, y: 71.18), controlPoint1: CGPoint(x: 40.13, y: 71.18), controlPoint2: CGPoint(x: 40.22, y: 71.18))
            bezierPath.addCurve(to: CGPoint(x: 42.58, y: 70.33), controlPoint1: CGPoint(x: 41.14, y: 71.18), controlPoint2: CGPoint(x: 41.95, y: 70.88))
            bezierPath.addLine(to: CGPoint(x: 82.16, y: 35.56))
            bezierPath.addCurve(to: CGPoint(x: 82.47, y: 30.7), controlPoint1: CGPoint(x: 83.59, y: 34.31), controlPoint2: CGPoint(x: 83.73, y: 32.13))
            bezierPath.close()
            fillColor.setFill()
            bezierPath.fill()
        }
    }
}
