//
//  StoryboardInstantiatable.swift
//  Twittermenti
//
//  Created by Kiran Kothapalli on 2/19/24.
//  Copyright © 2024 London App Brewery. All rights reserved.
//

import Foundation
import UIKit

protocol StoryboardInstantiatable: AnyObject {
    associatedtype Dependency
    init?(coder: NSCoder, dependency: Dependency)
}

extension StoryboardInstantiatable where Self: UIViewController {
    static func instantiateInitialViewController(_ dependency: Dependency) -> Self {
        guard let name = (NSStringFromClass(self.self) as String).components(separatedBy: ".").last else { fatalError() }
        let storyboard = UIStoryboard(name: name, bundle: nil)
        return storyboard.instantiateInitialViewController { corder in
            Self.init(coder: corder, dependency: dependency)
        }!
    }
}
