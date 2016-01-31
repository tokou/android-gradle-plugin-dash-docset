#!/usr/bin/env ruby

require 'fileutils'
require 'pathname'
require 'sqlite3'
require 'open-uri'

link = "https://github.com/google/android-gradle-dsl/archive/gh-pages.zip"

name = "android-gradle-dsl-gh-pages"
zip = "#{name}.zip"

# Download the zip file
open(zip, 'wb') do |file|
  file << open(link).read
end

title = 'Android Gradle Plugin'

plist = %{
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>CFBundleIdentifier</key>
    <string>%s</string>
    <key>CFBundleName</key>
    <string>%s</string>
    <key>DocSetPlatformFamily</key>
    <string>%s</string>
    <key>isDashDocset</key>
    <true/>
    <key>dashIndexFilePath</key>
    <string>index.html</string>
  </dict>
</plist>
}

docset_folder = File.join(Dir.pwd, "#{title}.docset")
content_folder = File.join(docset_folder, "Contents")
res_folder = File.join(content_folder, "Resources")
doc_folder = File.join(res_folder, 'Documents')
zip_folder = File.join(Dir.pwd, name)

# Make docset and resources folder
FileUtils.mkdir_p(res_folder) unless File.exist? res_folder

# Move current versions' html to docset
system("unzip #{zip} > /dev/null") unless File.exist?(zip_folder) || File.exist?(doc_folder)
current_folder = File.join(zip_folder, File.readlink(File.join(zip_folder, 'current')))
FileUtils.mv(current_folder, doc_folder) unless File.exist? doc_folder
FileUtils.rm_rf(zip_folder)

# Add icons and plist to docset
FileUtils.cp('icon.png', docset_folder)
FileUtils.cp('icon@2x.png', docset_folder)

File.open("#{content_folder}/Info.plist", 'w') do |f|
  bundle_id = title.gsub(' ', '-').downcase
  platform_family = bundle_id.gsub('-', '')
  f.write(plist %[bundle_id, title, platform_family])
end

# Create and fill datsbase
sql_create = 'CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT UNIQUE, type TEXT, path TEXT UNIQUE);'
sql_unique = 'CREATE UNIQUE INDEX anchor ON searchIndex (name, type, path);'
sql_insert = "INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES ('%s', '%s', '%s');"
db_file = "#{res_folder}/docSet.dsidx"

begin
  db = SQLite3::Database.new db_file

  db.execute sql_create
  db.execute sql_unique

  content_pathname = Pathname.new content_folder

  Dir["#{doc_folder}/com.android.build.gradle.*"].each do |path|

    class_name = path[/.*\/(?:.*\.)*(.*)\.html/, 1]

    db.execute(sql_insert %[class_name, 'cl', Pathname.new(path).relative_path_from(Pathname.new(doc_folder))])

    File.read(path).scan(/<a class="link" href="([\w.]+?#[\w.]+?:([\w.()]+?))">/) do |m|
      elem = m[1]
      type = elem.end_with?(')') ? 'Method' : 'Field'
      link = m[0]
      db.execute(sql_insert %[elem, type, link])
    end
  end

rescue SQLite3::Exception => e
  puts e
ensure
  db.close if db
end

system("tar --exclude='.DS_Store' -czf #{title.gsub(' ', '_')}.tgz '#{title}.docset'")
