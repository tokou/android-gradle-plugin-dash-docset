#!/usr/bin/env ruby

require 'fileutils'
require 'pathname'
require 'sqlite3'

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
zip_folder = File.join(res_folder, 'dsl')
doc_folder = File.join(res_folder, 'Documents')

FileUtils.mkdir_p(res_folder) unless File.exist? res_folder
system("unzip #{ARGV.first} -d '#{res_folder}' > /dev/null") unless File.exist?(zip_folder) || File.exist?(doc_folder)
FileUtils.mv(zip_folder, doc_folder) unless File.exist? doc_folder

FileUtils.cp('icon.png', docset_folder)
FileUtils.cp('icon@2x.png', docset_folder)

File.open("#{content_folder}/Info.plist", 'w') do |f|
  bundle_id = title.gsub(' ', '-').downcase
  platform_family = bundle_id.gsub('-', '')
  f.write(plist %[bundle_id, title, platform_family])
end

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
