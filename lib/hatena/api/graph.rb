#!/usr/bin/env ruby

require 'base64'
require 'sha1'
require 'net/http'
require 'uri'
require 'time'

module Hatena
  module API
    class GraphError < StandardError; end
    class Graph
      DATE_FORMAT = '%Y-%m-%d'
      GRAPH_API_URI = URI.parse 'http://graph.hatena.ne.jp/api/post'

      def initialize(username, password)
        @username = username
        @password = password
      end

      def post(graphname, date, value)
        value = value.to_f
        date = date.strftime DATE_FORMAT
        headers = {
          'Access' => 'application/x.atom+xml, application/xml, text/xml, */*',
          'X-WSSE' => wsse(@username, @password),
        }
        params = {
          :graphname => graphname,
          :date => date,
          :value => value,
        }
        res = http_post GRAPH_API_URI, params, headers
        raise GraphError.new("request not successed: #{res}") if res.code != '201'
        res
      end

      private 
      def http_post(url, params, headers)
        req = ::Net::HTTP::Post.new(url.path, headers)
        req.form_data = params
        req.basic_auth url.user, url.password if url.user
        proxy_host, proxy_port = (ENV['HTTP_PROXY'] || '').split(/:/)
        ::Net::HTTP::Proxy(proxy_host, proxy_port.to_i).start(url.host, url.port) {|http|
          http.request(req)
        }
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
