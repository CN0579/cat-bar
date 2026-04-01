import Foundation

enum AppReleaseConfiguration {
    static let repositoryOwner = "QuentinHsu"
    static let repositoryName = "cat-bar"

    static var repositorySlug: String {
        "\(self.repositoryOwner)/\(self.repositoryName)"
    }

    static var latestReleaseAPIURL: URL {
        URL(string: "https://api.github.com/repos/\(self.repositorySlug)/releases/latest")!
    }

    static var releasesPageURL: URL {
        URL(string: "https://github.com/\(self.repositorySlug)/releases")!
    }
}
