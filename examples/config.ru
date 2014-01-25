#!rackup
require "json"
require "./cat.rb"

@cat = CAT::FT450D.new({ :port => '/dev/tty.usbserial-FTB3L9UG' })

run lambda {|env|
	req = Rack::Request.new(env)
	res = Rack::Response.new

	case req.path
	when '/status.json'
		res["Content-Type"] = "application/json"
		res.status = 200
		res.body   = [ JSON.generate(@cat.status) ]
	else
		res["Content-Type"] = "text/plain"
		res.status = 404
		res.body   = [ "Not Found" ]
	end

	res.finish
}
