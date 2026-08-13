import Foundation

enum NutrientFoodSources {

    struct Source {
        let food: String
        let emoji: String
        let portion: String
        let amount: String
    }

    static func sources(for nutrientId: String) -> [Source] {
        switch nutrientId {
        case "iron":
            return [
                Source(food: "Red meat (beef)", emoji: "🥩", portion: "100g cooked", amount: "3.5mg"),
                Source(food: "Lentils", emoji: "🫘", portion: "1 cup cooked", amount: "6.6mg"),
                Source(food: "Spinach", emoji: "🥬", portion: "1 cup cooked", amount: "6.4mg"),
                Source(food: "Dark chocolate (70%+)", emoji: "🍫", portion: "30g", amount: "3.4mg"),
            ]
        case "calcium":
            return [
                Source(food: "Milk", emoji: "🥛", portion: "250ml", amount: "300mg"),
                Source(food: "Greek yogurt", emoji: "🫙", portion: "200g", amount: "200mg"),
                Source(food: "Sardines (canned)", emoji: "🐟", portion: "100g", amount: "382mg"),
                Source(food: "Broccoli", emoji: "🥦", portion: "1 cup cooked", amount: "62mg"),
            ]
        case "magnesium":
            return [
                Source(food: "Pumpkin seeds", emoji: "🎃", portion: "30g", amount: "156mg"),
                Source(food: "Almonds", emoji: "🥜", portion: "30g", amount: "80mg"),
                Source(food: "Dark chocolate (70%+)", emoji: "🍫", portion: "30g", amount: "65mg"),
                Source(food: "Avocado", emoji: "🥑", portion: "1 medium", amount: "58mg"),
            ]
        case "zinc":
            return [
                Source(food: "Oysters", emoji: "🦪", portion: "6 medium", amount: "32mg"),
                Source(food: "Beef", emoji: "🥩", portion: "100g cooked", amount: "5.4mg"),
                Source(food: "Pumpkin seeds", emoji: "🎃", portion: "30g", amount: "2.2mg"),
                Source(food: "Chickpeas", emoji: "🫘", portion: "1 cup cooked", amount: "2.5mg"),
            ]
        case "vitamin_d":
            return [
                Source(food: "Salmon", emoji: "🐟", portion: "100g", amount: "11mcg"),
                Source(food: "Eggs", emoji: "🥚", portion: "2 large", amount: "2mcg"),
                Source(food: "Fortified milk", emoji: "🥛", portion: "250ml", amount: "3mcg"),
            ]
        case "potassium":
            return [
                Source(food: "Banana", emoji: "🍌", portion: "1 medium", amount: "422mg"),
                Source(food: "Sweet potato", emoji: "🍠", portion: "1 medium", amount: "541mg"),
                Source(food: "Salmon", emoji: "🐟", portion: "100g", amount: "363mg"),
                Source(food: "Avocado", emoji: "🥑", portion: "1 medium", amount: "485mg"),
            ]
        case "vitamin_c":
            return [
                Source(food: "Red bell pepper", emoji: "🫑", portion: "1 medium", amount: "152mg"),
                Source(food: "Orange", emoji: "🍊", portion: "1 medium", amount: "70mg"),
                Source(food: "Kiwi", emoji: "🥝", portion: "1 medium", amount: "64mg"),
                Source(food: "Strawberries", emoji: "🍓", portion: "1 cup", amount: "89mg"),
            ]
        case "fiber":
            return [
                Source(food: "Lentils", emoji: "🫘", portion: "1 cup cooked", amount: "15.6g"),
                Source(food: "Oats", emoji: "🌾", portion: "1 cup cooked", amount: "4g"),
                Source(food: "Avocado", emoji: "🥑", portion: "1 medium", amount: "10g"),
                Source(food: "Raspberries", emoji: "🫐", portion: "1 cup", amount: "8g"),
            ]
        case "sodium":
            return []
        default:
            return []
        }
    }
}
