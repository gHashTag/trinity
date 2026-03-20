// Map View — Location and Maps
import SwiftUI
import MapKit

// MARK: - Map View

struct MapView: View {
    let region: MKCoordinateRegion
    let annotations: [MapAnnotation]
    let showsUserLocation: Bool
    @State private var selectedAnnotation: MapAnnotation?

    struct MapAnnotation: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
        let title: String?
        let subtitle: String?
    }

    var body: some View {
        Map(coordinateRegion: .constant(region),
             annotationItems: annotations) { annotation in
            MapMarker(coordinate: annotation.coordinate,
                     tint: .red)
        }
        .overlay(
            Button {
                // Zoom in
            } label: {
                Image(systemName: "plus")
                    .font(WernickeTypography.size14)
                    .foregroundStyle(V4Color.textPrimary)
                    .padding(ParietalSpacing.sm)
                    .background(.white)
                    .cornerRadius(V1Theme.cornerSmall)
            }
            .padding(.trailing, 12)
            .padding(.bottom, 12)
            , alignment: .bottomTrailing
        )
    }
}

// MARK: - Location Picker

struct LocationPicker: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @Binding var selectedLocation: CLLocationCoordinate2D?

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                Map(coordinateRegion: $region)
                    .frame(height: 250)
                    .onTapGesture { location in
                        // Convert tap to coordinate
                    }

                if let selectedLocation = selectedLocation {
                    Image(systemName: "mappin.circle.fill")
                        .font(WernickeTypography.size32)
                        .foregroundStyle(.red)
                        .offset(y: -16)
                }
            }

            Divider()

            HStack {
                Text("Selected Location")
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)

                Spacer()

                if let location = selectedLocation {
                    Text("\(String(format: "%.4f", location.latitude)), \(String(format: "%.4f", location.longitude))")
                        .font(.caption)
                        .foregroundStyle(V4Color.textPrimary)
                }
            }
            .padding(.horizontal, ParietalSpacing.lg)
            .padding(.vertical, ParietalSpacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(V4Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(V4Color.border, lineWidth: 1)
        )
    }
}

// MARK: - Mini Map

struct MiniMap: View {
    let coordinate: CLLocationCoordinate2D
    let span: MKCoordinateSpan

    var body: some View {
        Map(coordinateRegion: .constant(
            MKCoordinateRegion(center: coordinate, span: span)
        ))
        .frame(height: 120)
        .cornerRadius(V1Theme.cornerBase)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(V4Color.border, lineWidth: 1)
        )
    }
}

// MARK: - Coordinate Display

struct CoordinateDisplay: View {
    let coordinate: CLLocationCoordinate2D

    var body: some View {
        HStack(spacing: ParietalSpacing.sm) {
            Image(systemName: "location.fill")
                .font(WernickeTypography.size12)
                .foregroundStyle(V4Color.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Latitude")
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)
                Text(String(format: "%.6f", coordinate.latitude))
                    .font(.caption)
                    .foregroundStyle(V4Color.textPrimary)
            }

            Divider()
                .frame(height: ParietalSpacing.iconLarge)

            VStack(alignment: .leading, spacing: 2) {
                Text("Longitude")
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)
                Text(String(format: "%.6f", coordinate.longitude))
                    .font(.caption)
                    .foregroundStyle(V4Color.textPrimary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(V4Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(V4Color.border, lineWidth: 1)
        )
    }
}

// MARK: - Location Search

struct LocationSearch: View {
    @State private var searchText = ""
    let results: [LocationResult]

    struct LocationResult: Identifiable {
        let id = UUID()
        let name: String
        let address: String
        let coordinate: CLLocationCoordinate2D
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(WernickeTypography.size14)
                    .foregroundStyle(V4Color.textSecondary)

                TextField("Search location", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(WernickeTypography.size13)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(WernickeTypography.size14)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ParietalSpacing.md)
            .padding(.vertical, ParietalSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(V4Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(V4Color.border, lineWidth: 1)
            )

            if !searchText.isEmpty {
                VStack(spacing: 0) {
                    ForEach(results) { result in
                        HStack(spacing: ParietalSpacing.sm) {
                            Image(systemName: "mappin.circle.fill")
                                .font(WernickeTypography.size14)
                                .foregroundStyle(V4Color.accent)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.name)
                                    .font(WernickeTypography.size13)
                                    .foregroundStyle(V4Color.textPrimary)

                                Text(result.address)
                                    .font(.caption)
                                    .foregroundStyle(V4Color.textSecondary)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, ParietalSpacing.md)
                        .padding(.vertical, ParietalSpacing.sm)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Select location
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(V4Color.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(V4Color.border, lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Preview

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MiniMap(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
            .frame(width: ParietalSpacing.xl * 12)

            CoordinateDisplay(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            )
            .frame(width: ParietalSpacing.extraWidePanel)
        }
        .padding()
        .background(V4Color.background)
    }
}
