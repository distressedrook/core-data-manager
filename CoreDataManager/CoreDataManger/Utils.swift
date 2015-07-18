//
//  Utils.swift
//  CoreDataManagerExample
//
//  Created by Avismara on 18/07/15.
//  Copyright (c) 2015 Avismara. All rights reserved.
//

import Foundation

func performClosureOnMainThread(closure:()->()) {
    dispatch_async(dispatch_get_main_queue()){
        closure()
    }
}

func performClosureOnBackgroundThread(closure:()->()) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
        closure()
    };
}
