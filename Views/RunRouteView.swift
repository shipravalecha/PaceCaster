//
//  RunRouteView.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 8/17/26.
//

import SwiftUI
import MapKit

struct RunRouteView: View {
    let run: RunWorkout

    private var coordinates: [CLLocationCoordinate2D] {
        run.routeCoordinates
    }

    private var region: MKCoordinateRegion? {
        guard !coordinates.isEmpty else { return nil }
        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return nil }

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.005),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.005)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    var body: some View {
        VStack(spacing: 20) {
            header

            if coordinates.isEmpty {
                Text("No route data is available for this run. Outdoor runs recorded with GPS will show a route here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                mapView
            }
        }
        .padding()
        .navigationTitle("Route")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(run.startDate.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let distance = run.distanceMeters {
                Text(String(format: "%.2f mi", distance / 1609.344))
                    .font(.title2.weight(.bold))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var mapView: some View {
        Map(initialPosition: .region(region ?? MKCoordinateRegion())) {
            MapPolyline(coordinates: coordinates)
                .stroke(.blue, lineWidth: 4)

            if let start = coordinates.first {
                Marker("Start", coordinate: start).tint(.green)
            }
            if let end = coordinates.last, coordinates.count > 1 {
                Marker("Finish", coordinate: end).tint(.red)
            }
        }
        .frame(height: 400)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityLabel("Map of run route")
        .accessibilityHint("Visual route map; distance and route details are shown in the text above")
    }
}
