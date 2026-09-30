# Apply small source changes before Vite rebuilds fingerprinted assets.
changes = {
  '/app/app/javascript/dashboard/helper/URLHelper.js' =>
    ['const url = new URL(dataUrl);', 'const url = new URL(dataUrl, window.location.origin);'],
  '/app/app/javascript/shared/helpers/MessageFormatter.js' =>
    ['const url = new URL(imgSrc);', 'const url = new URL(imgSrc, window.location.origin);']
}

changes.each do |path, (before, after)|
  source = File.read(path)
  raise "Expected exactly one media URL expression in #{path}" unless source.scan(before).length == 1

  File.write(path, source.sub(before, after))
end
