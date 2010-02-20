require 'open-uri'
require 'cgi'
require 'rubygems'
require 'json'

class CoverFetcher
  # TODO(mateusz): Traversing music collection

  class ResponseError < StandardError; end

  DEFAULT_API_KEY = 'b25b959554ed76058ac220b7b2e0a026'
  LASTFM_API_URL = 'http://ws.audioscrobbler.com/2.0/'

  def initialize(api_key=DEFAULT_API_KEY)
    @api_key = api_key
  end

  def fetch(artist, album, size='large')
    download(find(artist, album, size))
  end

  def fetch_releases(releases, size='large')
    releases.each do |r|
      artist, album = r
      fetch(artist, album, size)
    end
  end

  def find(artist, album, size='large')
    url = "#{LASTFM_API_URL}?api_key=#{@api_key}&method=album.getInfo"
    url += '&format=json'
    url += "&artist=#{CGI.escape(artist)}"
    url += "&album=#{CGI.escape(album)}"

    cover_url = nil
    open(url) do |r|
      response = JSON.parse(r.string)
      raise ResponseError.new(response['message']) if response['error']
      covers = response["album"]["image"]
      cover_url = covers.find{|c| c["size"] == size}["#text"]
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
  end
end


cf = CoverFetcher.new
begin
  cf.fetch_releases([['Jacaszek', 'Pentral'], ['Jacaszek', 'Treny']])
rescue CoverFetcher::ResponseError => e
  p e.message
end
