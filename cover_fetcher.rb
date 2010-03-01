require 'open-uri'
require 'cgi'
require 'rubygems'
require 'json'
require 'find'
require 'id3lib'

class CoverFetcher

  class ResponseError < StandardError; end

  DEFAULT_API_KEY = 'b25b959554ed76058ac220b7b2e0a026'
  LASTFM_API_URL = 'http://ws.audioscrobbler.com/2.0/'
  
  class << self
    def run(args)
      cover_file = /\.(jpe?g|png|gif)$/
      music_file = /\.mp3$/
      processed_dirs = []
      Find.find(args[:dir]) do |file|
        name = File.basename(file)
        if FileTest.directory?(file)
          entries = Dir.entries(file)
          if i = entries.index { |e| e =~ cover_file }
            cover = entries[i]
            puts "Skipping `#{name}` (`#{cover}` looks like a cover)" 
            Find.prune 
          end
        else
          dir = File.dirname(file)
          next if file !~ music_file || processed_dirs.include?(dir)
          info = ID3Lib::Tag.new(file)
          artist, album = info.artist, info.album
          next if !album || album.empty?
          print "=> Fetching cover for `#{album}` by `#{artist}`..."
          fetcher ||= CoverFetcher.new
          Dir.chdir(dir) do
            begin
              cover = fetcher.cover_for(:artist => artist, :title => album)
              puts " OK (`#{cover}`)"
            rescue StandardError => e
              " FAILED (#{e.message})"
            end
          end
          processed_dirs << dir 
        end
      end
    end
  end

  def initialize(api_key=DEFAULT_API_KEY)
    @api_key = api_key
  end

  def cover_for(args, size='large')
    if args.kind_of? Array
      cover_for_albums(args, size)
    else
      cover_for_album(args, size)
    end
  end

  def cover_for_album(album, size='large')
    cover_url = find(album, size)
    download(cover_url) if cover_url && !cover_url.empty?
  end

  def cover_for_albums(albums, size='large')
    covers = []
    albums.each do |a|
      covers << cover_for_album(a, size)
    end
    covers
  end

  def find(album, size='large')
    url = "#{LASTFM_API_URL}?api_key=#{@api_key}&method=album.getInfo"
    url += '&format=json'
    url += "&artist=#{CGI.escape(album[:artist])}" if album[:artist]
    url += "&album=#{CGI.escape(album[:title])}"

    cover_url = nil
    open(url) do |r|
      response = JSON.parse(r.read)
      raise ResponseError.new(response['message']) if response['error']
      covers = response['album']['image']
      cover_url = covers.find{ |c| c['size'] == size }['#text']
    end

    cover_url
  end

  def download(cover_url, as=nil)
    file = cover_url.match(/([\w_]+).(\w{3})$/)
    file_name = as || file[1]
    file_format = file[2]
    file_path = "#{file_name}.#{file_format}"

    File.open(file_path, 'w') do |f|
      open(cover_url) do |data|
        f << data.read
      end
    end
    file_path
  end
end
