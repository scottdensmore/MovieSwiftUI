//
//  ImageService.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 07/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

public class ImageService {
    public static let shared = ImageService()
    
    public enum Size: String {
        case small = "https://image.tmdb.org/t/p/w154/"
        case medium = "https://image.tmdb.org/t/p/w500/"
        case cast = "https://image.tmdb.org/t/p/w185/"
        case original = "https://image.tmdb.org/t/p/original/"
        
        public func path(poster: String) -> URL {
            return URL(string: rawValue)!.appendingPathComponent(poster)
        }
    }
    
    public enum ImageError: Error {
        case decodingError
    }
    
    public func fetchImage(poster: String, size: Size) -> AnyPublisher<Data?, Never> {
        return URLSession.shared.dataTaskPublisher(for: size.path(poster: poster))
            .map { (data, response) -> Data? in
                return data
        }.catch { error in
            return Just(nil)
        }
        .eraseToAnyPublisher()
    }
}
