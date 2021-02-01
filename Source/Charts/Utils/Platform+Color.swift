//
//  Platform+Color.swift
//  Charts
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

#if canImport(UIKit)
import UIKit

public typealias NSUIColor = UIColor
private func fetchLabelColor() -> UIColor
{
    if #available(iOS 13, tvOS 13, *)
    {
        return .label
    }
    else
    {
        return .black
    }
}
private let labelColor: UIColor = fetchLabelColor()

extension UIColor
{
    static var labelOrBlack: UIColor { labelColor }

    func distance(from secondColor: UIColor) -> CGFloat //ignoring the alpha component
    {
        //color components https://stackoverflow.com/a/48610603
        var alpha = CGFloat(0)
        var red = CGFloat(0); var green = CGFloat(0); var blue = CGFloat(0)
        var red2 = CGFloat(0); var green2 = CGFloat(0); var blue2 = CGFloat(0)
        //distance https://stackoverflow.com/a/11550492
        if self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) &&
            secondColor.getRed(&red2, green: &green2, blue: &blue2, alpha: &alpha)
        {
            return CGFloat(sqrtf(pow(Float(red - red2), 2) +
                pow(Float(green - green2), 2) +
                pow(Float(blue - blue2), 2)))
        }

        var hue = CGFloat(0), saturation = CGFloat(0), brightness = CGFloat(0)
        var hue2 = CGFloat(0), saturation2 = CGFloat(0), brightness2 = CGFloat(0)
        if self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) &&
            secondColor.getHue(&hue2, saturation: &saturation2, brightness: &brightness2, alpha: &alpha)
        {
            return CGFloat(sqrtf(pow(Float(hue - hue2), 2) +
                pow(Float(saturation - saturation2), 2) +
                pow(Float(brightness - brightness2), 2)))
        }

        var white = CGFloat(0); var white2 = CGFloat(0)
        if self.getWhite(&white, alpha: &alpha) && secondColor.getWhite(&white2, alpha: &alpha)
        {
            return CGFloat(sqrtf(pow(Float(white - white2), 2)))
        }

        return -1
    }
    
    func inverseColor() -> UIColor  //returns same alpha component
    {
        //https://stackoverflow.com/a/5901586
        var alpha = CGFloat(0)

        var red = CGFloat(0); var green = CGFloat(0); var blue = CGFloat(0)
        if self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        {
            return UIColor(red: 1 - red, green: 1 - green, blue: 1 - blue, alpha: alpha)
        }

        var hue = CGFloat(0), saturation = CGFloat(0), brightness = CGFloat(0)
        if self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        {
            return UIColor(hue: 1 - hue, saturation: 1 - saturation, brightness: 1 - brightness, alpha: alpha)
        }

        var white = CGFloat(0)
        if self.getWhite(&white, alpha: &alpha)
        {
            if white == 0.5
            {
                return labelColor
            }
            if white > 0.33 && white < 0.67 //adjust gray as here https://stackoverflow.com/a/19767334
            {
                if white > 0.5
                {
                    return .darkGray
                }
                else
                {
                    return .lightGray
                }
            }
            return UIColor(white: 1 - white, alpha: alpha)
        }

        return self
    }
}
#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

public typealias NSUIColor = NSColor
private func fetchLabelColor() -> NSColor
{
    if #available(macOS 10.14, *)
    {
        return .labelColor
    }
    else
    {
        return .black
    }
}
private let labelColor: NSColor = fetchLabelColor()

extension NSColor
{
    static var labelOrBlack: NSColor { labelColor }
    func distance(from secondColor: NSColor) -> CGFloat //ignoring the alpha component
    {
        //color components https://stackoverflow.com/a/48610603
        var alpha = CGFloat(0)
        var red = CGFloat(0); var green = CGFloat(0); var blue = CGFloat(0)
        var red2 = CGFloat(0); var green2 = CGFloat(0); var blue2 = CGFloat(0)
        //distance https://stackoverflow.com/a/11550492
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        secondColor.getRed(&red2, green: &green2, blue: &blue2, alpha: &alpha)

        return CGFloat(sqrtf(pow(Float(red - red2), 2) +
                pow(Float(green - green2), 2) +
                pow(Float(blue - blue2), 2)))
    }

    func inverseColor() -> NSColor  //returns same alpha component
    {
        //https://stackoverflow.com/a/5901586
        var alpha = CGFloat(0)

        var red = CGFloat(0); var green = CGFloat(0); var blue = CGFloat(0)
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return NSColor(red: 1 - red, green: 1 - green, blue: 1 - blue, alpha: alpha)
    }
}
#endif
