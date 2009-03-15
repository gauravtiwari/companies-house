require 'rubygems'
require 'net/http'
require 'uri'
require 'open-uri'
require 'digest/md5'

require 'morph'
require 'hpricot'
require 'haml'

require File.dirname(__FILE__) + '/companies_house/request'

module CompaniesHouse
  VERSION = "0.0.1" unless defined? CompaniesHouse::VERSION

  class << self
    def name_search name
      xml = CompaniesHouse::Request.name_search_xml :company_name=>name
      post(xml)
    end

    def number_search number
      xml = CompaniesHouse::Request.number_search_xml :company_number=>number
      post(xml)
    end

    def company_details number
      xml = CompaniesHouse::Request.company_details_xml :company_number=>number
      post(xml)
    end

    def post(data)
      begin
        u = "http://xmlgw.companieshouse.gov.uk/v1-0/xmlgw/Gateway"
        puts "Checking url #{u}"
        url = URI.parse u
        http = Net::HTTP.new(url.host, url.port)
        res, body = http.post(url.path, data, {'Content-type'=>'text/xml;charset=utf-8'})
        case res
          when Net::HTTPSuccess, Net::HTTPRedirection
            xml = res.body
            doc = Hpricot.XML(xml)
            xml = doc.at('Body')
            xml = xml.children.select(&:elem?).first.to_s
            hash = Hash.from_xml(xml)
            Morph.from_hash(hash, CompaniesHouse)
          else
            raise res.inspect
        end
      rescue URI::InvalidURIError
        raise "URI is no good: " + u
      end
    end

    def sender_id= id
      @sender_id = id
    end
    def sender_id
      config_setup('.') if @sender_id.blank?
      @sender_id
    end
    def password= pw
      @password = pw
    end
    def password
      config_setup('.') if @password.blank?
      @password
    end
    def email= e
      @email = e
    end
    def email
      @email
    end

    def digest_method
      'CHMD5'
    end

    def create_transaction_id_and_digest
      transaction_id = Time.now.to_i
      digest = Digest::MD5.hexdigest("#{sender_id}#{password}#{transaction_id}")
      return transaction_id, digest
    end

    def config_setup root
      config_file = "#{root}/config/companies-house.yml"
      config_file = "#{root}/companies-house.yml" unless File.exist? config_file
      if File.exist? config_file
        config = YAML.load_file(config_file)
        self.sender_id= config['sender_id']
        self.password= config['password']
        self.email= config['email']
      end
    end
  end
end
