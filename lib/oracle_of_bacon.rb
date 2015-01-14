require 'debugger'              # optional, may be helpful
require 'open-uri'              # allows open('http://...') to return body
require 'cgi'                   # for escaping URIs
require 'nokogiri'              # XML parser
require 'active_model'          # for validations

class OracleOfBacon

  OOBURI = "http://oracleofbacon.org/cgi-bin/xml"
  DEFAULT_FROM =  "Kevin Bacon"
  DEFAULT_TO =    "Kevin Bacon"
  class InvalidError < RuntimeError ; end
  class NetworkError < RuntimeError ; end
  class InvalidKeyError < RuntimeError ; end

  attr_accessor :from, :to
  attr_reader :api_key, :response, :uri

  include ActiveModel::Validations
  validates_presence_of :from
  validates_presence_of :to
  validates_presence_of :api_key
  validate :from_does_not_equal_to

  def from_does_not_equal_to
    errors.add(:from, "From cannot be the same as To") if self.from == self.to
  end

  def initialize(api_key='')
    @from = DEFAULT_FROM
    @to = DEFAULT_TO
    @api_key = api_key
  end


  def find_connections

    make_uri_from_arguments
    begin
      xml = URI.parse(uri).read
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
      Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
      Net::ProtocolError => e
      # convert all of these into a generic OracleOfBacon::NetworkError,
      #  but keep the original error message
      raise OracleOfBacon::NetworkError
    end
    @response = Response.new(xml)

  end

  def make_uri_from_arguments
    @uri = "#{OOBURI}?p=#{CGI.escape(self.api_key)}"
    @uri += "&a=#{CGI.escape(self.from)}&b=#{CGI.escape(self.to)}"
  end

  class Response

    attr_reader :type, :data

    # create a Response object from a string of XML markup.
    def initialize(xml)
      @doc = Nokogiri::XML(xml)
      parse_response
    end

    private

    def parse_response
      if ! @doc.xpath('/error').empty?
        parse_error_response
      elsif !@doc.xpath('/link').empty?
        parse_graph_response
      elsif !@doc.xpath('/spellcheck').empty?
        parse_spellcheck_response
      elsif !@doc.xpath('/other').empty?
        handle_unknown
      end
    end

    def parse_error_response
      @type = :error
      @data = 'Unauthorized access'
    end

    def parse_graph_response
        @type = :graph
        actors = @doc.xpath('//actor').map(&:text)
        movies = @doc.xpath('//movie').map(&:text)
        @data = actors.zip(movies).flatten.compact
    end

    def parse_spellcheck_response
      @type = :spellcheck
      @data = @doc.xpath('//match').map(&:text)
    end

    def handle_unknown
      @type = :unknown
      @data = 'unknown response type'
    end

  end
end

