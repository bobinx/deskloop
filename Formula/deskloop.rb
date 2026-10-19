class Deskloop < Formula
  desc "Native macOS live wallpaper engine"
  homepage "https://github.com/bobinx/deskloop"
  url "https://github.com/bobinx/deskloop/releases/download/v1.0.0/deskloop-v1.0.0-macos-universal.tar.gz"
  sha256 "44caebcdd66942ca32c213c459d37be156d4a8ee72c53957337e2e5fe7aaf3d4"
  license "MIT"

  depends_on macos: :ventura

  def install
    bin.install "deskloop"
  end

  test do
    assert_equal "deskloop version #{version}", shell_output("#{bin}/deskloop --version").strip
  end
end
