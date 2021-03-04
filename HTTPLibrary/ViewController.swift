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

//        let sessionLoader = URLSessionLoader(session: URLSession.shared)
//        let printLoader = PrintLoader()
//
//        printLoader.nextLoader = sessionLoader
//        let loader: HTTPLoader = printLoader

        let startWars = StarWarsAPI()
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

    }


}

