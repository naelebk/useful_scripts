require 'selenium-webdriver'
require 'open-uri'
require 'fileutils'

RED = "\033[1;31m"
YELLOW = "\033[1;33m"
GREEN = "\033[0;32m"
ORANGE = "\033[1;38;5;214m"
BLUE = " \033[1;34m"
PURPLE = "\033[1;35m"
CYAN = "\033[1;36m"
PINK = "\e[1m\e[38;2;255;105;180m"
NC = "\033[0m"

unless ARGV.length == 1
  puts "#{YELLOW}Usage: ruby #{$0} <youtube_url>#{NC}"
  exit 1
end

youtube_url = ARGV[0]
video_id = youtube_url[/v=([^&]+)/, 1]
invidious_url = "https://yewtu.be/watch?v=#{video_id}"

# Navigateur headless Chrome (pas forcément besoin d'être installé)
options = Selenium::WebDriver::Chrome::Options.new
options.add_argument('--headless=new')
options.add_argument('--no-sandbox')
options.add_argument('--disable-dev-shm-usage')
driver = Selenium::WebDriver.for(:chrome, options: options)
# -----------------------------------------------------------------

begin
  driver.navigate.to(invidious_url)
  sleep 5
  
  # Titre de la vidéo ---------------------------------------------
  title = driver.title 
  title.gsub!(/ - yewtu\.be$/, '') if title
  filename = title.gsub(/[\/\\:\*\?"<>\|]/, '_').strip
  # ---------------------------------------------------------------

  filename = "video_#{video_id}" if filename.empty?

  puts "#{YELLOW}Fichier MP3 final : '#{GREEN}#{filename}.mp3#{YELLOW}'#{NC}"

  video_url = nil
  video_elements = driver.find_elements(tag_name: 'video')

  video_elements.each do |video|
    sources = video.find_elements(tag_name: 'source')
    sources.each do |source|
      type = source.attribute('type') || ''
      src = source.attribute('src') || ''
      #puts "Source : #{source.attribute('type')} ;  #{sources.attribute('src')}"
      if type.start_with?('video/') && src.end_with?('.mp4') || src.include?('itag=18')
        video_url = src
        break
      end
    end
    break if video_url
  end

  if video_url.nil?
    puts "#{RED}Erreur ! Impossible de trouver l'URL MP4 dans <video>.#{NC}"
    exit 2
  end

  # Si l'on souhaite télécharger la vidéo -------------------------
  # URI.open(video_url, "User-Agent" => "Mozilla/5.0") do |video|
  #   File.open("video.mp4", 'wb') do |file|
  #     file.write(video.read)
  #   end
  # end
  # ---------------------------------------------------------------


  # Téléchargement de la miniature --------------------------------
  thumb_url = "https://i.ytimg.com/vi/#{video_id}/hqdefault.jpg"
  URI.open(thumb_url) do |img|
    File.open("cover.jpg", 'wb') { |file| file.write(img.read) }
  end
  # ---------------------------------------------------------------

  # Conversion MP3 avec ffmpeg ------------------------------------
  output_file = "#{filename}.mp3"
  pid = spawn(
    "ffmpeg", 
    "-i", video_url,
    "-i", "cover.jpg",
    "-map", "0:a",
    "-map", "1:v",
    "-c:a", "libmp3lame",
    "-b:a", "192k",
    "-c:v", "mjpeg",
    "-id3v2_version", "3",
    "-metadata:s:v", "title=Album cover",
    "-metadata:s:v", "comment=Cover (front)",
    "-y", output_file,
    :out => "/dev/null", 
    :err => "/dev/null"
  )
  Process.wait(pid)

  puts "#{GREEN}MP3 créé : '#{PINK}#{output_file}#{GREEN}'#{NC}"
  # ---------------------------------------------------------------

ensure
  driver.quit
  #FileUtils.rm_f("video.mp4")
  FileUtils.rm_f("cover.jpg")
end
