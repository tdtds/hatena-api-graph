#!/usr/bin/env ruby

require 'base64'
require 'sha1'
require 'net/http'
require 'uri'
require 'time'
require 'yaml'

module Hatena
  module API
    class GraphError < StandardError; end
    class Graph
      DATE_FORMAT = '%Y-%m-%d'
      GRAPH_API_URL = 'http://graph.hatena.ne.jp/api/'
      GRAPH_API_DATA_URI = URI.parse GRAPH_API_URL + 'data'
      GRAPH_API_CONFIG_URI = URI.parse GRAPH_API_URL + 'config'

      CONFIG_BOOLEAN_KEYS = %w[showdata stack reverse formula nolabel]

      def initialize(username, password)
        @username = username
        @password = password
        @proxy = nil
      end
      attr_accessor :proxy

      # graph.post 'graphname', :value => 10
      # graph.post 'graphname', :value => 10, :date => Time.now
      def post_data(graphname, options, value = nil)
        if value.nil?
          params = {
            :graphname => graphname,
          }.merge options
        else
          # obsolute arguments.
          date = options
          params = {
            :graphname => graphname,
            :date => date,
            :value => value,
          }
        end

        if params[:value] != nil
          params[:value] = params[:value].to_f
        end

        params[:date] = params[:date].strftime(DATE_FORMAT) if params[:date]

        res = http_post GRAPH_API_DATA_URI, params
        raise GraphError.new("request not successed: #{res}") if res.code != '201'
        res
      end
      alias_method :post, :post_data

      def get_data(graphname, options = {})
        params = {
          :graphname => graphname,
          :type => 'yaml',
        }.merge options
        res = http_get GRAPH_API_DATA_URI, params
        p GRAPH_API_DATA_URI, params
        raise GraphError.new("request not successed: #{res}") if res.code != '200'
        YAML::load res.body
      end

      def get_config(graphname)
        params = {
          :graphname => graphname,
          :type => 'yaml',
        }
        res = http_get GRAPH_API_CONFIG_URI, params
        raise GraphError.new("request not successed: #{res}") if res.code != '200'
        config = YAML::load res.body
        config_booleanize config
      end

      def post_config(graphname, options)
        params = {
          :graphname => graphname,
        }.merge options
        params = boolean2queryparam(params)
        res = http_post GRAPH_API_CONFIG_URI, params
        raise GraphError.new("request not successed: #{res}") if res.code != '201'
        res
      end

      private
      def config_booleanize(config)
        CONFIG_BOOLEAN_KEYS.each do |key|
          config[key] = (config[key] == 1 ? true : false) if config.has_key? key
        end
        config
      end

      def boolean2queryparam(config)
        CONFIG_BOOLEAN_KEYS.each do |key|
          config[key] = (config[key] ? 1 : 0) if(config.has_key?(key) || config.has_key?(key.to_sym))
        end
        config
      end

      def http_post(url, params)
        http url, params, :post
      end

      def http_get(url, params)
        http url, params, :get
      end

      def http(url, params, type = :post)
        headers = {
          'Access' => 'application/x.atom+xml, application/xml, text/xml, */*',
          'X-WSSE' => wsse(@username, @password),
        }
        case type
        when :post
          req = ::Net::HTTP::Post.new(url.path, headers)
          req.form_data = params
        when :get
          url.query = params.map {|k,v| "#{URI::encode(k.to_s)}=#{URI::encode(v.to_s)}" }.join('&')
          req = ::Net::HTTP::Get.new(url.request_uri, headers)
        else
          raise ArgumentsError.new('type must be :post or :get')
        end
        req.basic_auth url.user, url.password if url.user
        if @proxy
          proxy = @proxy
        else
          proxy_host, proxy_port = (ENV['HTTP_PROXY'] || '').split(/:/)
          proxy = ::Net::HTTP::Proxy(proxy_host, proxy_port.to_i)
        end
        proxy.start(url.host, url.port) {|http| http.request(req) }
      end

      def wsse(username, password)
        nonce = (1..10).collect {|x| sprintf("%02X", rand(256)) }.join
        timestamp = Time.now.iso8601
        digest = bchomp Digest::SHA1::digest(nonce + timestamp + password)
        %Q[UsernameToken Username="#{username}", PasswordDigest="#{digest}", Nonce="#{bchomp nonce}", Created="#{timestamp}"]
      end

      def bchomp(str)
        ::Base64::encode64(str).chomp
      end
    end
  end
end
