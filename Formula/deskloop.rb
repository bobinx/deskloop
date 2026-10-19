class Deskloop < Formula
  desc "CLI live video wallpaper engine for macOS (4K loops, battery-efficient)"
  homepage "https://github.com/bobinx/deskloop"
  url "https://github.com/bobinx/deskloop/releases/download/v1.1.0/deskloop-v1.1.0-macos-universal.tar.gz"
  sha256 "3592dc0c65160a0984d4a33152ef993d6d8095ddbe45b8fc0461b9dc559d66ff"
  license "MIT"

  depends_on macos: :ventura

  def install
    bin.install "deskloop"
  end

  test do
    assert_equal "deskloop version #{version}", shell_output("#{bin}/deskloop --version").strip
  end
end
