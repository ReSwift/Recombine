//
//  File.swift
//  
//
//  Created by Lotte Tortorella on 30/10/20.
//

public enum ActionStrata<Raw, Refined> {
    case raw(Raw)
    case refined(Refined)
}
