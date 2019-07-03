require 'net/http'
require 'json'
require 'csv'
require 'cgi'

GOOGLE_CSE_URL = 'https://www.googleapis.com/customsearch/v1/siterestrict'.freeze
CUSTOM_SEARCH_ENGINE_ID = '003362237437448988854:gn9j28nvrk0'.freeze
API_KEY = 'xxx'.freeze
DATE_RANGES = [
    {start: '20030101', end: '20130101'},
    {start: '20040101', end: '20140101'},
    {start: '20050101', end: '20150101'},
    {start: '20060101', end: '20160101'},
    {start: '20070101', end: '20170101'},
    {start: '20080101', end: '20180101'},
    {start: '20090101', end: '20190701'}
].freeze

#######################################################################
############################## FUNCTIONS ##############################
#######################################################################
def build_request_url(string_query, start_date, end_date)
  "#{GOOGLE_CSE_URL}" +
      "?q=#{string_query}" +
      "&sort=date:r:#{start_date}:#{end_date}" +
      "&cx=#{CUSTOM_SEARCH_ENGINE_ID}" +
      "&key=#{API_KEY}"
end

def call_api(string_query, start_date, end_date)
  uri = URI(build_request_url(string_query, start_date, end_date))
  Net::HTTP.get_response(uri)
end

def get_data(string_query, start_date, end_date)
  response = call_api(string_query, start_date, end_date)
  raise_http_error(response) unless response.kind_of? Net::HTTPSuccess
  json_response = JSON.parse(response.body)
  return json_response['queries']['request'][0]['totalResults']
end

def raise_http_error(response)
  raise "HTTP request failed (NOK) => #{response.code} #{response.message}"
end

def build_string_query(prenom, nom)
  CGI.escape("\"#{prenom} #{nom}\"")
end

def write_headers(csv_file)
  csv_file << build_header_line(['Prenom', 'Nom'], :start)
  csv_file << build_header_line(['', ''], :end)
end

def build_header_line(array_line, date_attribute)
  DATE_RANGES.each do |date_range|
    array_line << Date.parse(date_range[date_attribute]).to_s
  end
  array_line
end

def stop_if_too_many_errors(error_counter)
  if error_counter > 25
    puts "Something is going wrong..."
    exit
  end
end

#######################################################################
############################## VARIABLES ##############################
#######################################################################
input_filename = 'input.csv'
output_filename = 'output.csv'
error_counter = 0

#######################################################################
############################### SCRIPT ################################
#######################################################################
input_csv = CSV.read(input_filename)
output_csv = CSV.open(output_filename, 'w')

write_headers(output_csv)

input_csv.each_with_index do |input_csv_row, index|
  prenom = input_csv_row[0]
  nom = input_csv_row[1]

  output_csv_row = [prenom, nom]
  string_query = build_string_query(prenom, nom)

  DATE_RANGES.each do |date_range|
    begin
      total_results = get_data(string_query, date_range[:start], date_range[:end])
      output_csv_row << total_results
    rescue StandardError => e
      output_csv_row << e.message
      error_counter += 1
      stop_if_too_many_errors(error_counter)
    end
  end

  output_csv << output_csv_row

  puts "#{index+1} rangees traitees..." if ((index+1) % 10).zero?
end

output_csv.close
puts 'job is done!'