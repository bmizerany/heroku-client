require 'rubygems'
require 'rexml/document'
require 'rest_client'

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

		begin
			r = resource('/data', host)
			payload = { :data => File.open(filename, 'rb') }
			r.put payload, heroku_headers
		rescue IOError => e
			## This is temporary until we can fix the error with the stream
			## being cut off by nginx (ask Orion)
			sleep(3) ## try and sleep it off
			puts "There was a nasty error! #{e.message}"
			r.put :data => File.open(filename, 'rb')
		end
	end
	
	def download_data(name)
		host = "http://" + (ENV["HEROKU_COLLAR_HOST"] || "control.%s.heroku.com")
		host = host % name

		File.rm('data.yml.gz') rescue nil

		r = resource('/data', host)
		r.get heroku_headers do |res|
			open('data.yml.gz', 'wb') do |f|
				res.read_body do |chunk|
					f.write(chunk)
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
