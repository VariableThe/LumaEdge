cask "lumaedge" do
  version "1.0.0"
  sha256 :no_check

  url "https://github.com/chrisdoc/MacOSEdgeLight/releases/download/v#{version}/LumaEdge.zip"
  name "LumaEdge"
  desc "Definitive native macOS edge lighting and virtual ring light for video calls"
  homepage "https://github.com/chrisdoc/MacOSEdgeLight"

  depends_on macos: ">= :sonoma"

  app "LumaEdge.app"
  binary "#{appdir}/LumaEdge.app/Contents/MacOS/lumaedge"

  zap trash: [
    "~/Library/Application Support/LumaEdge",
    "~/Library/Preferences/com.lumaedge.app.plist",
    "~/Library/Caches/com.lumaedge.app"
  ]
end
