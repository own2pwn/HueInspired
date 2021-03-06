//
//  CDSSelectionSetTests.swift
//  HueInspired
//
//  Created by Ashley Arthur on 04/05/2017.
//  Copyright © 2017 AshArthur. All rights reserved.
//

import Foundation
import XCTest
import CoreData
import PromiseKit
@testable import HueInspired


class CDSSelectionSetTests: XCTestCase {
    
    var testDataStack: NSPersistentContainer?
    
    override func setUp() {
        super.setUp()
        testDataStack = setupDataStack()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        testDataStack = nil
    }
    
    func test_init(){
        let context = testDataStack!.viewContext
        
        context.perform {
            _ = CDSSelectionSet(context: context, name: "Foo")
        }
    }
    
    func test_isMember_true_(){
        let context = testDataStack!.viewContext
        let palette =  CDSColorPalette(context: context, name:"foo" , colors: [])
        let selectionSet = CDSSelectionSet(context: context, name: "test")
        selectionSet.addPalette(palette)
        
        XCTAssertTrue(selectionSet.contains(palette))
    }
    
    func test_isMember_true_afterRefresh(){
        let context = testDataStack!.viewContext
        let selectionSet = CDSSelectionSet(context: context, name: "test")
        selectionSet.addPalette(CDSColorPalette(context: context, name:"foo" , colors: []))
        try! context.save()
        context.refreshAllObjects()
        
        XCTAssertTrue(selectionSet.palettes.count == 1)
    }
    
    
    func test_isMemeber_false(){
        let context = testDataStack!.viewContext
        let palette =  CDSColorPalette(context: context, name:nil , colors: [])
        let selectionSet = CDSSelectionSet(context: context, name: "test")
        
        XCTAssertFalse(selectionSet.contains(palette))
    }
    
    func test_isUnique(){
        // There should only be one selection set with a given name
        
        let context = testDataStack!.viewContext
        context.mergePolicy = NSMergePolicy.error
        
        // Start with Clean context
        XCTAssertFalse(context.hasChanges)
        
        context.performAndWait {
            _ = CDSSelectionSet(context: context, name: "foo")
            _ = CDSSelectionSet(context: context, name: "foo")
            
        }
        do {
            XCTAssertTrue(context.hasChanges)
            XCTAssertThrowsError(try context.save())
            XCTAssertTrue(context.hasChanges)
        }
    }
    
    func test_isUniqueAfterMerge(){
        // Background context should merge fail if contain multiple versions of enitity
        
        // SETUP
        let context = testDataStack!.viewContext
        let backgroundContext = testDataStack!.newBackgroundContext()
        
        context.mergePolicy = NSMergePolicy.error
        backgroundContext.mergePolicy = NSMergePolicy.error
        
        let fetch: NSFetchRequest<CDSSelectionSet> = CDSSelectionSet.fetchRequest()
        fetch.fetchBatchSize = fetch.defaultFetchBatchSize
        fetch.sortDescriptors = [NSSortDescriptor.init(key: #keyPath(name), ascending: true)]
        
        // We should start off with 0 objects
        XCTAssertEqual( (try? context.fetch(fetch).count) ?? -1, 0 )
        // and a clean context
        XCTAssertFalse(context.hasChanges)
        
        backgroundContext.performAndWait {
            _ = CDSSelectionSet(context: backgroundContext, name: "foo")
            _ = CDSSelectionSet(context: backgroundContext, name: "foo")
        }
        
        // This should fail due to uniquing constraint
        XCTAssertNil(try? backgroundContext.save())
        // There should be no change to main context
        XCTAssertFalse(context.hasChanges)
        // There should be 0 sets in context
        XCTAssertEqual( (try? context.fetch(fetch).count) ?? -1, 0 )
    }
}
