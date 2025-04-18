import Foundation
import SwiftData

enum MealType: String, CaseIterable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case dinner = "dinner"
    case snack = "snack"
}

@Model
final class Meal {
    var id: UUID
    var name: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    
    init(id: UUID = UUID(), name: String, calories: Double, protein: Double, carbs: Double, fat: Double) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }
}

@Model
final class NutritionEntry {
    var id: UUID
    var date: Date
    private var _mealType: String
    var meal: Meal?
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    
    var mealType: MealType {
        get {
            MealType(rawValue: _mealType) ?? .breakfast
        }
        set {
            _mealType = newValue.rawValue
        }
    }
    
    init(id: UUID = UUID(), date: Date = Date(), mealType: MealType = .breakfast, meal: Meal? = nil, calories: Double = 0, protein: Double = 0, carbs: Double = 0, fat: Double = 0) {
        self.id = id
        self.date = date
        self._mealType = mealType.rawValue
        self.meal = meal
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }
} 