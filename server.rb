#!/usr/bin/env ruby

require 'rubygems'
require 'bundler'
Bundler.require

require 'timeout'
require "em-websocket"
require "json"
require "./lib/cat.rb"
require "pathname"

dir = Pathname(__FILE__).parent
config = eval( (dir + "config.rb").read )

@logger = Logger.new(config[:log] || $stdout)
@cat = CAT.instance(config)

EM::run do
	@channel = EM::Channel.new
	@status  = nil

	EM::WebSocket.start(:host => "0.0.0.0", :port => 51234) do |ws|
		ws.onopen do
			@logger.info "WebSocket onopen #{ws}"
			ws.send(JSON.generate({ "id" => nil, "result" => @status })) if @status

			sid = @channel.subscribe do |mes|
				ws.send(mes)
			end

			ws.onclose do
				@logger.info "WebSocket onclose #{ws}"
				@channel.unsubscribe(sid)
			end
		end

		ws.onmessage do |msg|
			cmd = JSON.parse(msg)
			method = cmd["method"]
			params = cmd["params"]
			id     = cmd["id"]

			@logger.info "#{ws} >>> #{cmd.inspect}"

			ret = nil, error = nil
			begin
				case
				when method == "broadcast"
					# method `broadcast` is for extension of another information
					params = [ :result ].map {|i| params[i.to_s] } if params.is_a? Hash
					@channel.push JSON.generate({ "id" => nil, "result" => params[0] })
					ret = true
				when @cat.respond_to?("#{method}=")
					method = @cat.method("#{method}=")
					params = method.parameters.map {|i| params[i[1].to_s] } if params.is_a? Hash
					ret = method.call(*params)
				when @cat.respond_to?(method)
					method = @cat.method(method)
					params = method.parameters.map {|i| params[i[1].to_s] } if params.is_a? Hash
					ret = method.call(*params)
				end
			rescue NameError => e
				error = e
			rescue Timeout::Error => e
				error = e
			end

			res = { "id" => id, "result" => ret, "error" => error }
			@logger.info "#{ws} <<< #{res.inspect}"

			ws.send(JSON.generate(res))
		end

		ws.onerror do |error|
			@logger.fatal error
		end
	end

	EM::defer do
		begin
			@cat.read_status do |status|
				@logger.info status.inspect
				@status = status
				@channel.push JSON.generate({ "id" => nil, "result" => @status })
			end
		rescue Timeout::Error
			@logger.fatal "timeout"
			sleep 1
			retry
		end
	end
end


