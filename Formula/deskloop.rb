class Deskloop < Formula
  desc "Native macOS live wallpaper engine"
  homepage "https://github.com/bobinx/deskloop"
  url "https://github.com/bobinx/deskloop/releases/download/v1.0.0/deskloop-v1.0.0-macos-universal.tar.gz"
  sha256 "3f703d1cdfd9de9933341e948fc9c7e34dd4346638af13b6460168c26c3754d9"
  license "MIT"

  depends_on macos: :ventura

  def install
    bin.install "deskloop"
  end

  test do
    assert_equal "deskloop version #{version}", shell_output("#{bin}/deskloop --version").strip
  end
end
