//
//  ExerciseServiceTests.swift
//  Super Fitness Coach App
//
//  El catálogo ahora pasa por SwiftData + importación; las pruebas antiguas de JSON estático
//  se retiraron. Smoke tests mínimos del tipo público.

import Testing
@testable import Super_Fitness_Coach_App

struct ExerciseServiceTests {

    @Test func catalogErrorNotConfiguredHasDescription() {
        let e = ExerciseService.CatalogError.notConfigured
        #expect(e.errorDescription?.isEmpty == false)
    }

    @Test func catalogErrorEmptyHasDescription() {
        let e = ExerciseService.CatalogError.emptyCatalog
        #expect(e.errorDescription?.isEmpty == false)
    }
}
