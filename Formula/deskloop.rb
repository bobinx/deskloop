class Deskloop < Formula
  desc "Native macOS live wallpaper engine"
  homepage "https://github.com/bobinx/deskloop"
  url "https://codeload.github.com/bobinx/deskloop/tar.gz/116517b7e3ca6f3f894b93e4d768632fa946db65"
  version "1.0.0"
  sha256 "ed2f020c061037590baece8cbb551d80606b697b64cb3c26e7db03b494f9087f"
  license "MIT"

  depends_on macos: :ventura
  depends_on xcode: ["15.0", :build]

  def install
    system "swift", "build", "-c", "release", "--product", "deskloop"
    bin.install ".build/release/deskloop"
  end

  test do
    assert_equal "deskloop version #{version}", shell_output("#{bin}/deskloop --version").strip
  end
end
