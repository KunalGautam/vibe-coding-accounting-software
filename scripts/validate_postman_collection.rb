#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'yaml'

OPENAPI_PATH = File.expand_path('../docs/openapi.yaml', __dir__)
POSTMAN_PATH = File.expand_path('../docs/accounting-api.postman_collection.json', __dir__)

openapi = YAML.load_file(OPENAPI_PATH)
openapi_routes = openapi.fetch('paths').flat_map do |path, methods|
  methods.keys.grep(/^(get|post|put|patch|delete)$/).map { |method| [method.upcase, path] }
end.uniq.sort

patterns = openapi_routes.map do |method, path|
  regex = '^' + path.gsub(/\{[^}]+\}/, '[^/]+') + '$'
  [method, path, Regexp.new(regex)]
end

collection = JSON.parse(File.read(POSTMAN_PATH))
matched_routes = []
unmatched_requests = []

walk_items = lambda do |items|
  items.each do |item|
    if item['item']
      walk_items.call(item['item'])
      next
    end

    request = item['request']
    next unless request

    method = request.fetch('method')
    raw_url = request['url'].is_a?(Hash) ? request['url']['raw'].to_s : request['url'].to_s
    path = raw_url.sub('{{base_url}}', '').sub('{{root_url}}', '').split('?').first
    path = path.gsub(/{{[^}]+}}/, 'value')
    candidate_paths = [path]
    candidate_paths << "/api/v1#{path}" if raw_url.start_with?('{{base_url}}')

    match = patterns.find do |route_method, _route_path, regex|
      route_method == method && candidate_paths.any? { |candidate| candidate.match?(regex) }
    end
    if match
      matched_routes << [match[0], match[1]]
    else
      unmatched_requests << [method, raw_url]
    end
  end
end

walk_items.call(collection.fetch('item'))
matched_routes = matched_routes.uniq.sort
missing_from_postman = openapi_routes - matched_routes

if missing_from_postman.empty? && unmatched_requests.empty?
  puts "Postman route audit passed: #{matched_routes.length} OpenAPI route/method pairs covered."
  exit 0
end

unless missing_from_postman.empty?
  warn 'OpenAPI routes missing from Postman collection:'
  missing_from_postman.each { |method, path| warn "  #{method} #{path}" }
end

unless unmatched_requests.empty?
  warn 'Postman requests not matched to OpenAPI routes:'
  unmatched_requests.each { |method, url| warn "  #{method} #{url}" }
end

exit 1
