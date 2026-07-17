#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'

OPENAPI_PATH = File.expand_path('../docs/openapi.yaml', __dir__)
HANDLERS_GLOB = File.expand_path('../backend/internal/http/handlers/*.go', __dir__)

openapi = YAML.load_file(OPENAPI_PATH)
openapi_routes = openapi.fetch('paths').flat_map do |path, methods|
  methods.keys.grep(/^(get|post|put|patch|delete)$/).map { |method| [method.upcase, path] }
end.uniq.sort

handler_routes = []
Dir[HANDLERS_GLOB].each do |file|
  File.readlines(file).each do |line|
    next unless line =~ /router\.(GET|POST|PUT|PATCH|DELETE)\("([^"]+)"/

    method = Regexp.last_match(1)
    path = Regexp.last_match(2).gsub(/:([A-Za-z0-9_]+)/, '{\1}')
    full_path = if path.start_with?('/organizations') || path.start_with?('/auth') || path.start_with?('/bootstrap')
                  path
                else
                  "/organizations/{organizationId}#{path}"
                end

    handler_routes << [method, full_path]
  end
end

handler_routes << ['GET', '/health']
handler_routes << ['GET', '/healthz']
handler_routes << ['GET', '/livez']
handler_routes << ['GET', '/readyz']
handler_routes << ['GET', '/api/v1/health']
handler_routes << ['GET', '/api/v1/healthz']
handler_routes << ['GET', '/api/v1/livez']
handler_routes << ['GET', '/api/v1/readyz']
handler_routes = handler_routes.uniq.sort

missing_from_openapi = handler_routes - openapi_routes
extra_in_openapi = openapi_routes - handler_routes

if missing_from_openapi.empty? && extra_in_openapi.empty?
  puts "OpenAPI route audit passed: #{openapi_routes.length} route/method pairs documented."
  exit 0
end

unless missing_from_openapi.empty?
  warn 'Routes registered in Gin but missing from OpenAPI:'
  missing_from_openapi.each { |method, path| warn "  #{method} #{path}" }
end

unless extra_in_openapi.empty?
  warn 'Routes documented in OpenAPI but not registered in Gin handlers:'
  extra_in_openapi.each { |method, path| warn "  #{method} #{path}" }
end

exit 1
