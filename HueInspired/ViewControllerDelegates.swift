//
//  ViewControllerDelegates.swift
//  HueInspired
//
//  Created by Ashley Arthur on 07/03/2017.
//  Copyright © 2017 AshArthur. All rights reserved.
//

import Foundation
import PromiseKit
import UIKit
import CoreData

// shared functionality 

protocol PaletteSync {
    var appController: AppController { get set }
}

extension PaletteSync {
    func syncLatestPalettes(ctx:NSManagedObjectContext) -> Promise<Bool> {
        return appController.remotePalettes.getLatest().then { (palettes: [Promise<ColorPalette>]) in
            
            let fetch: NSFetchRequest<CDSColorPalette> = CDSColorPalette.fetchRequest()
            fetch.predicate = NSPredicate(format: "%K.@count == 0", argumentArray: [#keyPath(CDSColorPalette.sets)])
            fetch.fetchBatchSize = 50
        
            do {
                let palettes = try ctx.fetch(fetch)
                for p in palettes {
                    ctx.delete(p)
                }
            }
            catch {
                return Promise<Bool>.init(error: error)
            }
            ctx.processPendingChanges()
            
            let newCoreDataEntities = palettes.map{
                $0.then{ (palette:ColorPalette) -> () in
                    if palette.contrast(threshold:1) > 3 {
                        _ = CDSColorPalette(context: ctx, palette: palette)
                    }
                    else{
                        let interestingPalette = ImmutablePalette.init(namedButWithRandomColors: palette.name)
                        let entity = CDSColorPalette(context: ctx, palette: interestingPalette)
                        // Copy over image source
                        if let id = palette.guid {
                            entity.source = CDSImageSource(context: ctx, id: id, palette: entity, imageData: nil)
                        }
                        
                    }
                    ctx.processPendingChanges()
                }
            }
            
            return when(fulfilled: newCoreDataEntities).then { () -> Bool in
                // Because we don't delete favourite palettes, we could possibly
                // have merge conflict from duplicate image sources
                // In this case, just igore new palette, we have it already
                ctx.mergePolicy = NSMergePolicy.rollback
                try ctx.save()
                NotificationCenter.default.post(name: Notification.Name.init(rawValue: "replace"), object: nil)
                return true
            }
        }
    }
}


protocol PaletteFocus: class  {
    var appController: AppController { get set }
    var viewControllerFactory: ViewControllerFactory { get set }
    weak var dataSource: ManagedPaletteDataSource? { get set }
    
}

extension PaletteFocus {
    
    func showPaletteDetail(viewController:UIViewController, index:Int){
        
        guard
            let palette = dataSource?.getElement(at: index),
            let ctx = palette.managedObjectContext,
            let favs = try? PaletteFavourites.getSelectionSet(for: ctx)
            else {
                return 
        }
        
        let data = CDSColorPalette.getPalettes(ctx: ctx, ids: [palette.objectID])
        let vc = viewControllerFactory.showPalette(
            application: appController,
            dataSource: CoreDataPaletteDataSource(data: data, favourites: favs)
        )
        viewController.show(vc, sender: self)

    }

    
}
