//
//  WeatherService.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 8/26/26.
//

import Foundation
import CoreLocation

enum WeatherService {
    static func fetchHistoricalWeather(latitude: Double, longitude: Double, date: Date) async -> (tempF: Double, condition: String)? {
        let calendar = Calendar.current
        let dateString = isoDateFormatter.string(from: date)

        var components = URLComponents(string: "https://archive-api.open-meteo.com/v1/archive")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "start_date", value: dateString),
            URLQueryItem(name: "end_date", value: dateString),
            URLQueryItem(name: "hourly", value: "temperature_2m,weathercode"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        guard let url = components.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

            let targetHour = calendar.component(.hour, from: date)
            guard targetHour < response.hourly.temperature_2m.count,
                  targetHour < response.hourly.weathercode.count else { return nil }

            let temp = response.hourly.temperature_2m[targetHour]
            let code = response.hourly.weathercode[targetHour]
            return (tempF: temp, condition: conditionLabel(for: code))
        } catch {
            return nil
        }
    }

    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    /// Simplified WMO weather code mapping — https://open-meteo.com/en/docs (weather codes table)
    private static func conditionLabel(for code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1, 2, 3: return "Partly Cloudy"
        case 45, 48: return "Foggy"
        case 51, 53, 55, 56, 57: return "Drizzle"
        case 61, 63, 65, 66, 67: return "Rain"
        case 71, 73, 75, 77: return "Snow"
        case 80, 81, 82: return "Rain Showers"
        case 85, 86: return "Snow Showers"
        case 95, 96, 99: return "Thunderstorm"
        default: return "Unknown"
        }
    }

    private struct OpenMeteoResponse: Decodable {
        let hourly: Hourly
        struct Hourly: Decodable {
            let temperature_2m: [Double]
            let weathercode: [Int]
        }
    }
}
