class Deskloop < Formula
  desc "Lightweight native live wallpaper engine for macOS"
  homepage "https://github.com/your-username/deskloop"
  url "https://github.com/your-username/deskloop/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "REPLACE_WITH_TAG_SHA256"
  license "MIT"
  head "https://github.com/your-username/deskloop.git", branch: "main"

  depends_on :macos => :ventura

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/deskloop"
  end

  test do
    assert_match "deskloop version", shell_output("#{bin}/deskloop --version")
  end
end
