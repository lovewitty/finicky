//
//  FNAPI.swift
//  Finicky
//
//  Created by John Sterling on 12/06/15.
//  Copyright (c) 2015 John sterling. All rights reserved.
//

import Foundation
import JavaScriptCore

@objc protocol FinickyAPIExports : JSExport {
    static func setDefaultBrowser(browser: String?) -> Void
    static func log(message: String?) -> Void
    static func onUrl(handler: JSValue) -> Void
}

@objc public class FinickyAPI : NSObject, FinickyAPIExports {

    private static var urlHandlers = Array<JSValue>()
    private static var context : JSContext! = nil

    class func setDefaultBrowser(browser: String?) -> Void {
        AppDelegate.defaultBrowser = browser
    }

    static func log(message: String?) -> Void {
        if message != nil {
            NSLog(message!)
        }
    }

    public class func onUrl(handler: JSValue) -> Void {
        urlHandlers.append(handler)
    }

    public class func reset() -> Void {
        urlHandlers.removeAll(keepCapacity: true)
    }
    
    class func setContext(context: JSContext) {
        self.context = context
    }

    /**
        Get strategy from registered handlers

        @param originalUrl The original url that triggered finicky to start

        @param sourceBundleIdentifier Bundle identifier of the application that triggered the url to open

        @return A dictionary keyed with "url" and "bundleIdentifier" with
            the new url and bundle identifier to spawn
    */

    public class func callUrlHandlers(originalUrl: NSURL, sourceBundleIdentifier: String?, flags : Dictionary<String, Bool>) -> Dictionary<String, AnyObject> {
        var strategy : Dictionary<String, AnyObject> = [
            "url": originalUrl.absoluteString!
        ]
        
        var sourceBundleId : AnyObject
        if sourceBundleIdentifier != nil {
            sourceBundleId = sourceBundleIdentifier!
        } else {
            sourceBundleId = JSValue(nullInContext: context)
        }
    
        var options : Dictionary<String, AnyObject> = [
            "sourceBundleIdentifier": sourceBundleId,
            "flags": flags
        ]

        var previousStrategy : [NSObject : AnyObject]! = strategy
        for handler in urlHandlers {
            let url = strategy["url"]! as! String
            let val = handler.callWithArguments([url, options, previousStrategy])

            if !val.isUndefined() {
                let handlerStrategy = val.toDictionary()
                if handlerStrategy != nil {
                    if handlerStrategy["url"] != nil {
                        strategy["url"] = (handlerStrategy["url"] as! String)
                    }

                    let bundleId: AnyObject? = handlerStrategy["bundleIdentifier"]
                    if bundleId != nil {
                        strategy["bundleIdentifier"] = bundleId!
                    }
                    
                    if handlerStrategy["openInBackground"] != nil {
                        strategy["openInBackground"] = (handlerStrategy["openInBackground"] as! Bool)
                    }

                    if handlerStrategy["last"] != nil {
                        break
                    }
                }
                previousStrategy = strategy
            }
        }
        return strategy
    }
}