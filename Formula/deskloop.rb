class Deskloop < Formula
  desc "CLI live video wallpaper engine for macOS (4K loops, battery-efficient)"
  homepage "https://github.com/bobinx/deskloop"
  url "https://github.com/bobinx/deskloop/releases/download/v1.2.0/deskloop-v1.2.0-macos-universal.tar.gz"
  sha256 "6d8e98baa562d9badde1c42c3b30535e027723e467cf2af07f37ecc144d34f1a"
  license "MIT"

  depends_on macos: :ventura

  def install
    bin.install "deskloop"
  end

  test do
    assert_equal "deskloop version #{version}", shell_output("#{bin}/deskloop --version").strip
  end
end
