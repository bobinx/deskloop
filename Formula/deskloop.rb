class Deskloop < Formula
  desc "Native macOS live wallpaper engine"
  homepage "https://github.com/bobinx/deskloop"
  url "https://codeload.github.com/bobinx/deskloop/tar.gz/116517b7e3ca6f3f894b93e4d768632fa946db65"
  version "1.0.0"
  sha256 "b7d62df18346c73632501bfdb708c13606ca16293bf14b04f646a32f4cdb8a4e"
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
