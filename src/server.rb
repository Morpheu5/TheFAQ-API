#!/usr/bin/env ruby
# frozen_string_literal: true

require 'elasticsearch'
require 'sinatra'
require 'sinatra/reloader' if development?

### Configure Elasticsearch
es_url = ENV['ES_URL']
if es_url.nil? || es_url.empty?
  warn "\nMust specify an ElasticSearch URL."
  exit(-3)
end
es = Elasticsearch::Client.new url: es_url, log: true

# options '*' do
#   response.headers['Allow'] = 'HEAD,GET,PUT,POST,DELETE,OPTIONS'
#   response.headers['Access-Control-Allow-Headers'] = 'X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept'
#   response.headers['Access-Control-Allow-Origin'] = '*'
#   200
# end

### Make sure every response has the correct content type.
before '*' do
  response.headers['Access-Control-Allow-Headers'] = 'X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept'
  response.headers['Access-Control-Allow-Origin'] = '*'
  content_type 'application/json'
end

### Frank takes the stage...
set :bind, '0.0.0.0'

get '/' do
  {
    version: '0.0.1',
    frank_says: 'Fly me to the moon and let me play among the stars...'
  }.to_json
end

get %r{/faq/?} do
  halt 400, {
    frank_says: '/faq/:id returns the FAQ you want.'
  }.to_json
end

get %r{/faq/([a-z\/-]+)} do |id|
  id.gsub!(%r{/$}, '')
  begin
    doc = es.get index: 'current_content',
                 type: 'doc',
                 id: id
    if doc['_source']['index']
      subdocs = es.search index: 'current_content',
                          body: {
                            query: {
                              wildcard: {
                                'id.keyword': id + '/*'
                              }
                            }
                          }
      return doc['_source'].merge(
        subdocs: subdocs['hits']['hits'].map { |d| d['_source'] }
      ).to_json
    end
    doc['_source'].to_json
  rescue Elasticsearch::Transport::Transport::Errors::NotFound
    doc = es.search index: 'current_content',
                    body: {
                      query: {
                        wildcard: {
                          'id.keyword': id + '*'
                        }
                      }
                    }
    doc['hits']['hits'].map { |d| d['_source'] }.to_json
  end
end

get '/search' do
  halt 204 unless params['q']
  q = params['q'].gsub(/[^a-zA-Z0-9 ]/, '')
  r = es.search index: 'current_content',
                body: {
                  query: {
                    match: {
                      content: {
                        query: q,
                        fuzziness: 1,
                        analyzer: 'english'
                      }
                    }
                  }
                }
  r['hits']['hits'].map { |d| d['_source'] }.to_json
end
