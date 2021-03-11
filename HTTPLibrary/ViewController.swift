//
//  ViewController.swift
//  HTTPLibrary
//
//  Created by chenxi on 2021/2/25.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

//        let startWars = StarWarsAPI()
//        startWars.requestPeople { (result) in
//            switch result {
//            case .success(let httpResponse):
//                print(httpResponse.status.rawValue)
//                let jsonBody = JSONBody(httpResponse.body)
//                let json = try? jsonBody.encode()
//                print(json)
//            case .failure(let httpError):
//                print(httpError.code)
//            }
//        }

        let sessionLoader = URLSessionLoader(session: URLSession.shared)
        let printLoader = PrintLoader()

        printLoader.nextLoader = sessionLoader
        let loader: HTTPLoader = printLoader

        let startWars = StarWarsAPI(loader: loader)
        startWars.requestPeople { (result) in
            switch result {
            case .success(let httpResponse):
                print(httpResponse.status.rawValue)
                let jsonBody = JSONBody(httpResponse.body)
                let json = try? jsonBody.encode()
                print(json)
            case .failure(let httpError):
                print(httpError.code)
            }
        }

//        var dogs = [Dog]()
//        [1, 2, 3, 4, 5].forEach {
//            dogs.append(Dog(id: $0))
//        }
//
//        let ret = dogs[0] --> dogs[1] --> dogs[2] --> dogs[3]
//        print(ret?.id)

    }


}

public class Dog {
    let id: Int
    var next: Dog?

    init(id: Int, next: Dog? = nil) {
        self.id = id
        self.next = next
    }
}


//precedencegroup LoaderChainingPrecedence {
//    higherThan: NilCoalescingPrecedence
//    associativity: right
//}
//
//infix operator --> : LoaderChainingPrecedence
//
//@discardableResult
//public func --> (lhs: Dog?, rhs: Dog?) -> Dog? {
//    lhs?.next = rhs
//    return lhs ?? rhs
//}
