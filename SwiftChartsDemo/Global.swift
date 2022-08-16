func handleError(_ location: String, _ error: Error) {
    print("\(location) error: \(error.localizedDescription)")
}

// This simplifies print statements that use string interpolation
// to print values with types like Bool.
func sd(_ css: CustomStringConvertible) -> String {
    String(describing: css)
}
