require 'rubygems'
require 'rexml/document'
require "rest_client"

class RestClient::Payload::Base
	
	alias :_read :read
	
	def read(b=nil)
		# STDOUT.print '.'
		# STDOUT.flush
		@count ||= 0
		@count += b.to_i
		puts @count
		_read(b)
	end
	
end

# A Ruby class to call the Heroku REST API.  You might use this if you want to
# manage your Heroku apps from within a Ruby program, such as Capistrano.
# 
# Example:
# 
#   require 'heroku'
#   heroku = Heroku::Client.new('me@example.com', 'mypass')
#   heroku.create('myapp')
#
class Heroku::Client
	attr_reader :host, :user, :password

	def initialize(user, password, host='heroku.com')
		@user = user
		@password = password
		@host = host
	end

	def list
		doc = xml(get('/apps'))
		doc.elements.to_a("//apps/app/name").map { |a| a.text }
	end

	def create(name=nil)
		uri = "/apps"
		uri += "?app[name]=#{name}" if name
		xml(post(uri)).elements["//app/name"].text
	end

	def destroy(name)
		delete("/apps/#{name}")
	end

	def upload_authkey(key)
		put("/user/authkey", key, { 'Content-Type' => 'text/ssh-authkey' })
	end
	
	def upload_data(name, filename)
		host = "http://" + (ENV["HEROKU_COLLAR_HOST"] || "control.%s.heroku.com")
		host = host % name
		
		r = resource('/', host)
		begin
			payload = { :data => File.open(filename, 'rb') }
			RestClient::Request.timeout(0) do
				puts "Uplading: #{filename}"
				r['data'].put payload, heroku_headers
				puts # start new action on new line
				puts "Loading data ... (this may take a long time depending on the side of your file)."
				r['rake'].put 'db:data:load', heroku_headers
			end
		end
	end
	
	def download_data(name)
		host = "http://" + (ENV["HEROKU_COLLAR_HOST"] || "control.%s.heroku.com")
		host = host % name

		File.rm('data.yml.gz') rescue nil

		r = resource('/data', host)
		r.get heroku_headers do |res|
			open('data.yml.gz', 'wb') do |f|
				puts
				res.read_body do |chunk|
					f.write(chunk)
					print '.'
				end
			end
		end
	end
	
	##################

	def resource(uri, host=nil)
		RestClient::Resource.new((host || self.host) + uri, user, password)
	end

	def get(uri, extra_headers={})    # :nodoc:
		resource(uri).get(heroku_headers.merge(extra_headers))
	end

	def post(uri, payload="")    # :nodoc:
		resource(uri).post(payload, heroku_headers)
	end

	def put(uri, payload, extra_headers={})    # :nodoc:
		resource(uri).put(payload, heroku_headers.merge(extra_headers))
	end

	def delete(uri)    # :nodoc:
		resource(uri).delete
	end

	def heroku_headers   # :nodoc:
		{ 'X-Heroku-API-Version' => '1' }
	end

	def xml(raw)   # :nodoc:
		REXML::Document.new(raw)
	end
end
