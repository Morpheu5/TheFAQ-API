#!/usr/bin/env ruby
# frozen_string_literal: true

require 'elasticsearch'
require 'sinatra'

### Configure Elasticsearch

es_url = ENV['ES_URL']
if es_url.nil? || es_url.empty?
  warn "\nMust specify an ElasticSearch URL."
  exit(-3)
end
es = Elasticsearch::Client.new url: es_url, log: true

### Make sure every response has the correct content type.

before '*' do
  content_type 'application/json'
end

### Frank takes the stage...

get '/' do
  {
    version: '0.0.1',
    frank_says: 'Fly me to the moon and let me play among the stars...'
  }.to_json
end

get %r{/faq/([a-z\/-]+)} do |id|
  id.gsub!(%r{/$}, '')
  begin
    doc = es.get index: 'current_content',
                 type: 'doc',
                 id: id
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
