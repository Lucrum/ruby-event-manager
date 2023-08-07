# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zip)
  zip.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone)
  phone.gsub!(/[^0-9]/, '')
  if phone.length == 10
    phone
  elsif phone.length == 11 && phone[0] == '1'
    phone[1..]
  else
    'Unfortunately, the number you registered with is invalid.'
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue Google::Apis::ClientError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

popular_hours = Hash.new(0)
popular_days = Hash.new(0)
day_names = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]

def count_time_popularity(regdate, hours_hash, day_names, days_hash)
  day = DateTime.strptime(regdate, '%m/%d/%Y %H:%M')
  hours_hash[day.hour] += 1
  days_hash[day_names[day.wday]] += 1
end

# returns top 3 hours for registration
def convert_hash_descending(hours_hash)
  temp = hours_hash.sort_by(&:last).reverse[0..2]
  temp.map { |elem| elem[0] }
end

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

puts 'Event Manager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone_number = clean_phone_number(row[:homephone])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  count_time_popularity(row[:regdate], popular_hours, day_names, popular_days)

  save_thank_you_letter(id, form_letter)
end

puts "Top 3 hours for registration: #{convert_hash_descending(popular_hours).join(', ')}"
puts "Top 3 days for registration: #{convert_hash_descending(popular_days).join(', ')}"
